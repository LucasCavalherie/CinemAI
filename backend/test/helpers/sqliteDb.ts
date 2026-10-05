import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { DatabaseSync } from 'node:sqlite'
import type { Db, SqlParam } from '../../src/lib/db'

const MIGRATIONS_DIR = join(import.meta.dirname, '../../migrations')

/** SQLite em memória com as migrações reais aplicadas (mesmo SQL do D1). */
export function createTestDb(): Db {
  const sqlite = new DatabaseSync(':memory:')
  sqlite.exec('PRAGMA foreign_keys = ON')
  for (const file of readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith('.sql')).sort()) {
    sqlite.exec(readFileSync(join(MIGRATIONS_DIR, file), 'utf8'))
  }

  const run = (sql: string, params: SqlParam[] = []) => sqlite.prepare(sql).run(...params)

  return {
    async run(sql, params) {
      return { changes: Number(run(sql, params).changes) }
    },
    async first<T>(sql: string, params: SqlParam[] = []) {
      return ((sqlite.prepare(sql).get(...params) as T | undefined) ?? null) as T | null
    },
    async all<T>(sql: string, params: SqlParam[] = []) {
      return sqlite.prepare(sql).all(...params) as T[]
    },
    async batch(statements) {
      sqlite.exec('BEGIN')
      try {
        for (const s of statements) run(s.sql, s.params)
        sqlite.exec('COMMIT')
      } catch (error) {
        sqlite.exec('ROLLBACK')
        throw error
      }
    },
  }
}
