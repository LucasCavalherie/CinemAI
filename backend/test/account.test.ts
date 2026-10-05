import { describe, expect, it } from 'vitest'
import { grantEntitlement, UNLIMITED_SEARCH } from '../src/db/entitlements'
import { getUser } from '../src/db/users'
import { getUsage } from '../src/db/usage'
import { sha256Hex } from '../src/lib/crypto'
import { createHarness, json, T0 } from './helpers/appHarness'

type Harness = Awaited<ReturnType<typeof createHarness>>

async function login(h: Harness, token: string, sub: string, code = 'code-1') {
  const { challenge } = await json(await h.request('/v1/auth/challenge', { method: 'POST' }))
  const identityToken = `fake:${sub}:${await sha256Hex(challenge)}`
  return h.request('/v1/auth/apple', { body: { identityToken, authorizationCode: code, challenge }, token })
}

describe('POST /v1/auth/apple', () => {
  it('creates the user, links the device and keeps the Apple refresh token for revocation', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await login(h, d.accessToken, 'apple-sub-1')
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(body.user.id).toBeTruthy()
    expect((await getUser(h.db, body.user.id))?.apple_refresh_token).toBe('apple-refresh-code-1')
    const me = await json(await h.request('/v1/me', { token: d.accessToken }))
    expect(me.user.id).toBe(body.user.id)
  })

  it('reuses the same user when the same Apple account signs in on another device', async () => {
    const h = await createHarness()
    const a = await h.newDevice()
    const b = await h.newDevice()
    const first = await json(await login(h, a.accessToken, 'apple-sub-1'))
    const second = await json(await login(h, b.accessToken, 'apple-sub-1', 'code-2'))
    expect(second.user.id).toBe(first.user.id)
  })

  it('merges the day usage using the highest counter', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await h.db.run("INSERT INTO usage (owner_kind, owner_id, day, count) VALUES ('device', ?, '2026-10-05', 4)", [d.deviceId])
    const { user } = await json(await login(h, d.accessToken, 'apple-sub-1'))
    expect(await getUsage(h.db, 'user', user.id, '2026-10-05')).toBe(4)
    expect((await json(await h.request('/v1/me', { token: d.accessToken }))).quota.used).toBe(4)
  })

  it('moves device entitlements to the user so every device of the user has them', async () => {
    const h = await createHarness()
    const a = await h.newDevice()
    const b = await h.newDevice()
    await grantEntitlement(h.db, { id: 'e1', ownerKind: 'device', ownerId: a.deviceId, kind: UNLIMITED_SEARCH, expiresAt: T0 / 1000 + 3600 })
    await login(h, a.accessToken, 'apple-sub-1')
    await login(h, b.accessToken, 'apple-sub-1', 'code-2')
    const me = await json(await h.request('/v1/me', { token: b.accessToken }))
    expect(me.entitlements).toEqual([UNLIMITED_SEARCH])
    expect(me.quota.limit).toBe(100)
  })

  it('rejects an unknown challenge, a replayed challenge and a token with the wrong nonce', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const bogus = await h.request('/v1/auth/apple', { body: { identityToken: 'fake:s:n', authorizationCode: 'c', challenge: 'unknown' }, token: d.accessToken })
    expect(bogus.status).toBe(400)
    expect((await json(bogus)).error.code).toBe('invalid_challenge')

    const { challenge } = await json(await h.request('/v1/auth/challenge', { method: 'POST' }))
    const wrongNonce = await h.request('/v1/auth/apple', { body: { identityToken: 'fake:s:wrong', authorizationCode: 'c', challenge }, token: d.accessToken })
    expect(wrongNonce.status).toBe(401)
    expect((await json(wrongNonce)).error.code).toBe('apple_auth_failed')
    // o desafio foi consumido mesmo na falha: não pode ser reaproveitado
    const replay = await h.request('/v1/auth/apple', { body: { identityToken: `fake:s:${await sha256Hex(challenge)}`, authorizationCode: 'c', challenge }, token: d.accessToken })
    expect(replay.status).toBe(400)
  })

  it('requires authentication', async () => {
    const h = await createHarness()
    expect((await h.request('/v1/auth/apple', { body: { identityToken: 'x', authorizationCode: 'x', challenge: 'x' } })).status).toBe(401)
  })
})

describe('POST /v1/auth/logout', () => {
  it('unlinks the device; the Pro entitlement stays with the user', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await grantEntitlement(h.db, { id: 'e1', ownerKind: 'device', ownerId: d.deviceId, kind: UNLIMITED_SEARCH, expiresAt: T0 / 1000 + 3600 })
    await login(h, d.accessToken, 'apple-sub-1')

    expect((await h.request('/v1/auth/logout', { method: 'POST', token: d.accessToken })).status).toBe(200)
    const me = await json(await h.request('/v1/me', { token: d.accessToken }))
    expect(me.user).toBeNull()
    expect(me.entitlements).toEqual([])
    expect(me.quota.limit).toBe(5)
  })
})

describe('GET /v1/me', () => {
  it('returns the anonymous profile with the free quota', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    expect(await json(await h.request('/v1/me', { token: d.accessToken }))).toEqual({
      user: null,
      entitlements: [],
      quota: { used: 0, limit: 5, resetsAt: '2026-10-06T00:00:00Z' },
    })
  })
})

describe('DELETE /v1/me', () => {
  it('revokes the Apple token and removes the user and its data', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const { user } = await json(await login(h, d.accessToken, 'apple-sub-1'))
    await grantEntitlement(h.db, { id: 'e1', ownerKind: 'user', ownerId: user.id, kind: UNLIMITED_SEARCH, expiresAt: T0 / 1000 + 3600 })

    const res = await h.request('/v1/me', { method: 'DELETE', token: d.accessToken })
    expect(res.status).toBe(200)
    expect(h.revoked).toEqual(['apple-refresh-code-1'])
    expect(await getUser(h.db, user.id)).toBeNull()
    expect(await h.db.all('SELECT * FROM entitlements WHERE owner_id = ?', [user.id])).toHaveLength(0)
    const me = await json(await h.request('/v1/me', { token: d.accessToken }))
    expect(me.user).toBeNull()
  })

  it('does nothing and answers 502 when Apple cannot revoke, so the person can retry', async () => {
    const h = await createHarness({ failRevoke: true })
    const d = await h.newDevice()
    const { user } = await json(await login(h, d.accessToken, 'apple-sub-1'))
    const res = await h.request('/v1/me', { method: 'DELETE', token: d.accessToken })
    expect(res.status).toBe(502)
    expect((await json(res)).error.code).toBe('apple_unavailable')
    expect(await getUser(h.db, user.id)).not.toBeNull()
  })

  it('rejects anonymous devices', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await h.request('/v1/me', { method: 'DELETE', token: d.accessToken })
    expect(res.status).toBe(400)
  })
})
