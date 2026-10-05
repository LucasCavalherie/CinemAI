import { describe, expect, it } from 'vitest'
import { consumeChallenge, createChallenge } from '../src/auth/challenge'
import { createTestDb } from './helpers/sqliteDb'

const T0 = Date.UTC(2026, 9, 5, 12, 0, 0)

describe('challenges', () => {
  it('are unique and consumable exactly once', async () => {
    const db = createTestDb()
    const a = await createChallenge(db, T0)
    expect(a).not.toBe(await createChallenge(db, T0))
    expect(await consumeChallenge(db, a, T0 + 1000)).toBe(true)
    expect(await consumeChallenge(db, a, T0 + 1000)).toBe(false)
  })

  it('expire after 5 minutes', async () => {
    const db = createTestDb()
    const c = await createChallenge(db, T0)
    expect(await consumeChallenge(db, c, T0 + 5 * 60 * 1000 + 1)).toBe(false)
  })

  it('unknown challenges are rejected and old ones are purged on creation', async () => {
    const db = createTestDb()
    expect(await consumeChallenge(db, 'nope', T0)).toBe(false)
    await createChallenge(db, T0)
    await createChallenge(db, T0 + 10 * 60 * 1000)
    expect(await db.all('SELECT id FROM challenges')).toHaveLength(1)
  })
})
