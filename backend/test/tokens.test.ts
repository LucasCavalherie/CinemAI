import { describe, expect, it } from 'vitest'
import { createDevice } from '../src/db/devices'
import { TokenService } from '../src/auth/tokens'
import { ApiError } from '../src/lib/errors'
import { createTestDb } from './helpers/sqliteDb'

const SECRET = 'a-test-secret-with-more-than-32-characters'
const T0 = Date.UTC(2026, 9, 5, 12, 0, 0)

async function setup() {
  const db = createTestDb()
  await createDevice(db, { id: 'd1', keyId: null, publicKey: null, nowSec: 1 })
  let now = T0
  const tokens = new TokenService(SECRET, db, () => now)
  return { db, tokens, advance: (ms: number) => (now += ms) }
}

describe('access tokens', () => {
  it('issue and verify round-trip with a 15 minute lifetime', async () => {
    const { tokens } = await setup()
    const { accessToken, expiresAt } = await tokens.issueAccess('d1')
    expect(expiresAt).toBe(Math.floor(T0 / 1000) + 15 * 60)
    expect(await tokens.verifyAccess(accessToken)).toEqual({ deviceId: 'd1' })
  })

  it('rejects expired tokens', async () => {
    const { tokens, advance } = await setup()
    const { accessToken } = await tokens.issueAccess('d1')
    advance(15 * 60 * 1000 + 1000)
    await expect(tokens.verifyAccess(accessToken)).rejects.toMatchObject({ code: 'unauthorized', status: 401 })
  })

  it('rejects tampered tokens and tokens signed with another secret', async () => {
    const { db, tokens } = await setup()
    const { accessToken } = await tokens.issueAccess('d1')
    await expect(tokens.verifyAccess(accessToken.slice(0, -2) + 'xx')).rejects.toBeInstanceOf(ApiError)
    const other = new TokenService('another-secret-with-more-than-32-chars!!', db, () => T0)
    await expect(other.verifyAccess(accessToken)).rejects.toBeInstanceOf(ApiError)
    await expect(tokens.verifyAccess('not-a-jwt')).rejects.toBeInstanceOf(ApiError)
  })
})

describe('refresh tokens', () => {
  it('are stored hashed, resolve to the device and are single use', async () => {
    const { db, tokens } = await setup()
    const refresh = await tokens.issueRefresh('d1')
    const stored = await db.all<{ token_hash: string }>('SELECT token_hash FROM refresh_tokens')
    expect(stored).toHaveLength(1)
    expect(stored[0]?.token_hash).not.toContain(refresh)

    expect(await tokens.deviceForRefresh(refresh)).toBe('d1')
    expect(await tokens.consumeRefresh(refresh)).toBe(true)
    expect(await tokens.consumeRefresh(refresh)).toBe(false)
    expect(await tokens.deviceForRefresh(refresh)).toBeNull()
  })

  it('expire after 60 days', async () => {
    const { tokens, advance } = await setup()
    const refresh = await tokens.issueRefresh('d1')
    advance(60 * 24 * 3600 * 1000 + 1000)
    expect(await tokens.deviceForRefresh(refresh)).toBeNull()
    expect(await tokens.consumeRefresh(refresh)).toBe(false)
  })

  it('unknown tokens resolve to nothing', async () => {
    const { tokens } = await setup()
    expect(await tokens.deviceForRefresh('nope')).toBeNull()
  })
})
