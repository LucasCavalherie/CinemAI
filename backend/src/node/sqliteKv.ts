import type { DatabaseSync } from 'node:sqlite'
import type { KVLike } from '../lib/kv'

/** KV em SQLite: mesma interface do KV da Cloudflare, com TTL e prefixo (cache x config). */
export class SqliteKV implements KVLike {
  constructor(
    private readonly raw: DatabaseSync,
    private readonly prefix: string,
    private readonly nowMs: () => number = Date.now,
  ) {
    raw.exec('CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT NOT NULL, expires_at INTEGER)')
  }

  async get(key: string): Promise<string | null> {
    const row = this.raw.prepare('SELECT value, expires_at FROM kv WHERE key = ?').get(this.k(key)) as
      | { value: string; expires_at: number | null }
      | undefined
    if (!row) return null
    if (row.expires_at !== null && row.expires_at <= this.nowMs()) return null
    return row.value
  }

  async put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void> {
    const expiresAt = options?.expirationTtl ? this.nowMs() + options.expirationTtl * 1000 : null
    this.raw
      .prepare('INSERT INTO kv (key, value, expires_at) VALUES (?, ?, ?) ON CONFLICT (key) DO UPDATE SET value = excluded.value, expires_at = excluded.expires_at')
      .run(this.k(key), value, expiresAt)
  }

  /** Remove as linhas expiradas deste prefixo; devolve quantas saíram. */
  purgeExpired(): number {
    const result = this.raw.prepare('DELETE FROM kv WHERE key LIKE ? AND expires_at IS NOT NULL AND expires_at <= ?').run(`${this.prefix}:%`, this.nowMs())
    return Number(result.changes)
  }

  private k(key: string): string {
    return `${this.prefix}:${key}`
  }
}
