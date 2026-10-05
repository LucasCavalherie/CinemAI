import { mkdirSync, readdirSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { DatabaseSync } from 'node:sqlite'
import type { Db, SqlParam } from '../lib/db'

const MIGRATIONS_DIR = join(import.meta.dirname, '../../migrations')

export type Sqlite = {
  db: Db
  /** Acesso síncrono ao mesmo banco (usado pelo cache KV e por manutenção). */
  raw: DatabaseSync
  close(): void
}

/** Abre (ou cria) o SQLite em `path` e aplica as migrações pendentes. `:memory:` serve para testes. */
export function openSqlite(path: string): Sqlite {
  if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true })
  const raw = new DatabaseSync(path)
  raw.exec('PRAGMA journal_mode = WAL')
  raw.exec('PRAGMA foreign_keys = ON')
  raw.exec('PRAGMA busy_timeout = 5000')
  migrate(raw)

  const run = (sql: string, params: SqlParam[] = []) => raw.prepare(sql).run(...params)

  const db: Db = {
    async run(sql, params) {
      return { changes: Number(run(sql, params).changes) }
    },
    async first<T>(sql: string, params: SqlParam[] = []) {
      return ((raw.prepare(sql).get(...params) as T | undefined) ?? null) as T | null
    },
    async all<T>(sql: string, params: SqlParam[] = []) {
      return raw.prepare(sql).all(...params) as T[]
    },
    async batch(statements) {
      raw.exec('BEGIN')
      try {
        for (const s of statements) run(s.sql, s.params)
        raw.exec('COMMIT')
      } catch (error) {
        raw.exec('ROLLBACK')
        throw error
      }
    },
  }
  return { db, raw, close: () => raw.close() }
}

function migrate(raw: DatabaseSync): void {
  raw.exec('CREATE TABLE IF NOT EXISTS _migrations (name TEXT PRIMARY KEY, applied_at INTEGER NOT NULL)')
  const applied = new Set((raw.prepare('SELECT name FROM _migrations').all() as { name: string }[]).map((r) => r.name))
  for (const file of readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith('.sql')).sort()) {
    if (applied.has(file)) continue
    raw.exec('BEGIN')
    try {
      raw.exec(readFileSync(join(MIGRATIONS_DIR, file), 'utf8'))
      raw.prepare('INSERT INTO _migrations (name, applied_at) VALUES (?, ?)').run(file, Math.floor(Date.now() / 1000))
      raw.exec('COMMIT')
    } catch (error) {
      raw.exec('ROLLBACK')
      throw new Error(`Migration ${file} failed: ${error instanceof Error ? error.message : String(error)}`)
    }
  }
}
