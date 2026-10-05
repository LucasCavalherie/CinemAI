import { describe, expect, it } from 'vitest'
import { createTestDb } from './helpers/sqliteDb'

describe('test database', () => {
  it('applies the migrations', async () => {
    const db = createTestDb()
    const tables = await db.all<{ name: string }>(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    )
    expect(tables.map((t) => t.name)).toEqual(['challenges', 'devices', 'entitlements', 'refresh_tokens', 'usage', 'users'])
  })

  it('reports changes and supports first/all', async () => {
    const db = createTestDb()
    expect((await db.run('INSERT INTO challenges (id, expires_at) VALUES (?, ?)', ['a', 10])).changes).toBe(1)
    expect((await db.run('DELETE FROM challenges WHERE id = ?', ['nope'])).changes).toBe(0)
    expect(await db.first<{ id: string }>('SELECT id FROM challenges WHERE id = ?', ['a'])).toMatchObject({ id: 'a' })
    expect(await db.first('SELECT id FROM challenges WHERE id = ?', ['zzz'])).toBeNull()
    expect(await db.all('SELECT id FROM challenges')).toHaveLength(1)
  })

  it('batch is atomic', async () => {
    const db = createTestDb()
    await expect(
      db.batch([
        { sql: 'INSERT INTO challenges (id, expires_at) VALUES (?, ?)', params: ['x', 1] },
        { sql: 'INSERT INTO challenges (id, expires_at) VALUES (?, ?)', params: ['x', 2] }, // viola a PK
      ]),
    ).rejects.toThrow()
    expect(await db.all('SELECT id FROM challenges')).toHaveLength(0)
  })

  it('enforces foreign keys and cascades refresh tokens', async () => {
    const db = createTestDb()
    await expect(
      db.run('INSERT INTO refresh_tokens (token_hash, device_id, expires_at) VALUES (?, ?, ?)', ['h', 'missing', 1]),
    ).rejects.toThrow()
    await db.run('INSERT INTO devices (id, created_at) VALUES (?, ?)', ['d1', 1])
    await db.run('INSERT INTO refresh_tokens (token_hash, device_id, expires_at) VALUES (?, ?, ?)', ['h', 'd1', 1])
    await db.run('DELETE FROM devices WHERE id = ?', ['d1'])
    expect(await db.all('SELECT * FROM refresh_tokens')).toHaveLength(0)
  })

  it('upsert with a WHERE clause reports 0 changes when the limit is reached', async () => {
    const db = createTestDb()
    const sql = `INSERT INTO usage (owner_kind, owner_id, day, count) VALUES ('device', 'd', '2026-10-05', 1)
      ON CONFLICT (owner_kind, owner_id, day) DO UPDATE SET count = count + 1 WHERE count < ?`
    expect((await db.run(sql, [2])).changes).toBe(1) // insere
    expect((await db.run(sql, [2])).changes).toBe(1) // incrementa para 2
    expect((await db.run(sql, [2])).changes).toBe(0) // bloqueado
  })
})
