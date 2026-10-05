import { describe, expect, it } from 'vitest'
import { DEFAULT_CONFIG, type AppConfig } from '../src/config'
import { grantEntitlement, UNLIMITED_SEARCH } from '../src/db/entitlements'
import { getUsage } from '../src/db/usage'
import { dayKey, QuotaExceededError, quotaSnapshot, refundSearch, reserveSearch, resetsAt } from '../src/quota'
import { createTestDb } from './helpers/sqliteDb'

const NOW = Date.UTC(2026, 9, 5, 12, 0, 0)
const small: AppConfig = { ...DEFAULT_CONFIG, limits: { free: 2, pro: 4 } }

async function seed() {
  const db = createTestDb()
  await db.run('INSERT INTO users (id, apple_sub, created_at) VALUES (?, ?, ?)', ['u1', 'sub', 1])
  await db.run('INSERT INTO devices (id, user_id, created_at) VALUES (?, ?, ?)', ['d1', null, 1])
  await db.run('INSERT INTO devices (id, user_id, created_at) VALUES (?, ?, ?)', ['d2', 'u1', 1])
  return db
}

describe('dayKey / resetsAt', () => {
  it('uses UTC days and the next UTC midnight without milliseconds', () => {
    expect(dayKey(NOW)).toBe('2026-10-05')
    expect(resetsAt(NOW)).toBe('2026-10-06T00:00:00Z')
    expect(resetsAt(Date.UTC(2026, 11, 31, 23, 59, 59))).toBe('2027-01-01T00:00:00Z')
  })
})

describe('reserveSearch', () => {
  it('counts per device and blocks past the free limit', async () => {
    const db = await seed()
    const id = { deviceId: 'd1', userId: null }
    expect((await reserveSearch(db, small, id, NOW)).used).toBe(1)
    expect((await reserveSearch(db, small, id, NOW)).used).toBe(2)
    await expect(reserveSearch(db, small, id, NOW)).rejects.toBeInstanceOf(QuotaExceededError)
    expect(await getUsage(db, 'device', 'd1', '2026-10-05')).toBe(2)
  })

  it('resets on the next UTC day', async () => {
    const db = await seed()
    const id = { deviceId: 'd1', userId: null }
    await reserveSearch(db, small, id, NOW)
    await reserveSearch(db, small, id, NOW)
    const tomorrow = Date.UTC(2026, 9, 6, 0, 0, 1)
    expect((await reserveSearch(db, small, id, tomorrow)).used).toBe(1)
  })

  it('counts on the user too and blocks when either reaches the limit', async () => {
    const db = await seed()
    const asUser = { deviceId: 'd2', userId: 'u1' }
    await reserveSearch(db, small, asUser, NOW)
    await reserveSearch(db, small, asUser, NOW)
    expect(await getUsage(db, 'user', 'u1', '2026-10-05')).toBe(2)
    // outro dispositivo do mesmo usuário já esbarra no limite do usuário
    await db.run('INSERT INTO devices (id, user_id, created_at) VALUES (?, ?, ?)', ['d3', 'u1', 1])
    await expect(reserveSearch(db, small, { deviceId: 'd3', userId: 'u1' }, NOW)).rejects.toBeInstanceOf(QuotaExceededError)
    // e a reserva parcial no d3 foi desfeita
    expect(await getUsage(db, 'device', 'd3', '2026-10-05')).toBe(0)
  })

  it('uses the pro limit when the user has an active unlimited_search entitlement', async () => {
    const db = await seed()
    await grantEntitlement(db, { id: 'e1', ownerKind: 'user', ownerId: 'u1', kind: UNLIMITED_SEARCH, expiresAt: NOW / 1000 + 3600 })
    const id = { deviceId: 'd2', userId: 'u1' }
    for (let i = 1; i <= 4; i++) expect((await reserveSearch(db, small, id, NOW)).limit).toBe(4)
    await expect(reserveSearch(db, small, id, NOW)).rejects.toBeInstanceOf(QuotaExceededError)
  })

  it('ignores expired entitlements', async () => {
    const db = await seed()
    await grantEntitlement(db, { id: 'e1', ownerKind: 'device', ownerId: 'd1', kind: UNLIMITED_SEARCH, expiresAt: NOW / 1000 - 1 })
    expect((await reserveSearch(db, small, { deviceId: 'd1', userId: null }, NOW)).limit).toBe(2)
  })
})

describe('refundSearch / quotaSnapshot', () => {
  it('refund gives the search back on every owner and never goes negative', async () => {
    const db = await seed()
    const id = { deviceId: 'd2', userId: 'u1' }
    await reserveSearch(db, small, id, NOW)
    await refundSearch(db, id, NOW)
    await refundSearch(db, id, NOW)
    expect(await getUsage(db, 'device', 'd2', '2026-10-05')).toBe(0)
    expect(await getUsage(db, 'user', 'u1', '2026-10-05')).toBe(0)
  })

  it('snapshot reports the highest usage among the owners', async () => {
    const db = await seed()
    await reserveSearch(db, small, { deviceId: 'd1', userId: null }, NOW)
    await db.run("INSERT INTO usage (owner_kind, owner_id, day, count) VALUES ('user', 'u1', '2026-10-05', 2)")
    const snap = await quotaSnapshot(db, small, { deviceId: 'd1', userId: 'u1' }, NOW)
    expect(snap).toEqual({ used: 2, limit: 2, resetsAt: '2026-10-06T00:00:00Z' })
  })
})
