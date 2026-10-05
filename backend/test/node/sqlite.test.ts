import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { openSqlite } from '../../src/node/sqlite'
import { SqliteKV } from '../../src/node/sqliteKv'

const dirs: string[] = []
afterEach(() => {
  while (dirs.length) rmSync(dirs.pop()!, { recursive: true, force: true })
})
const tempFile = () => {
  const dir = mkdtempSync(join(tmpdir(), 'ff-'))
  dirs.push(dir)
  return join(dir, 'test.db')
}

describe('openSqlite', () => {
  it('applies the migrations once and keeps data across reopen', async () => {
    const file = tempFile()
    const first = openSqlite(file)
    await first.db.run('INSERT INTO challenges (id, expires_at) VALUES (?, ?)', ['a', 10])
    first.close()

    const second = openSqlite(file) // não reaplica a migração (senão falharia com "table already exists")
    expect(await second.db.all('SELECT id FROM challenges')).toHaveLength(1)
    const applied = await second.db.all<{ name: string }>('SELECT name FROM _migrations')
    expect(applied.map((m) => m.name)).toEqual(['0001_init.sql'])
    second.close()
  })

  it('supports the Db contract (changes, first, all, atomic batch, foreign keys)', async () => {
    const { db, close } = openSqlite(':memory:')
    expect((await db.run('INSERT INTO challenges (id, expires_at) VALUES (?, ?)', ['x', 1])).changes).toBe(1)
    expect(await db.first('SELECT id FROM challenges WHERE id = ?', ['nope'])).toBeNull()
    await expect(
      db.batch([
        { sql: 'INSERT INTO challenges (id, expires_at) VALUES (?, ?)', params: ['y', 1] },
        { sql: 'INSERT INTO challenges (id, expires_at) VALUES (?, ?)', params: ['y', 2] },
      ]),
    ).rejects.toThrow()
    expect(await db.all('SELECT id FROM challenges')).toHaveLength(1)
    await expect(db.run('INSERT INTO refresh_tokens (token_hash, device_id, expires_at) VALUES (?, ?, ?)', ['h', 'missing', 1])).rejects.toThrow()
    close()
  })
})

describe('SqliteKV', () => {
  it('stores values with an optional TTL and isolates prefixes', async () => {
    const { raw, close } = openSqlite(':memory:')
    let now = 1_000_000
    const cache = new SqliteKV(raw, 'cache', () => now)
    const config = new SqliteKV(raw, 'config', () => now)

    await cache.put('k', 'v1', { expirationTtl: 60 })
    await config.put('k', 'cfg')
    expect(await cache.get('k')).toBe('v1')
    expect(await config.get('k')).toBe('cfg')
    expect(await cache.get('missing')).toBeNull()

    now += 61_000
    expect(await cache.get('k')).toBeNull() // expirou
    expect(await config.get('k')).toBe('cfg') // sem TTL
    close()
  })

  it('overwrites existing keys and purges expired rows', async () => {
    const { raw, close } = openSqlite(':memory:')
    let now = 0
    const kv = new SqliteKV(raw, 'cache', () => now)
    await kv.put('a', '1', { expirationTtl: 10 })
    await kv.put('a', '2', { expirationTtl: 10 })
    expect(await kv.get('a')).toBe('2')
    now += 11_000
    expect(kv.purgeExpired()).toBe(1)
    close()
  })
})
