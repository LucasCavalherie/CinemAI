import { describe, expect, it } from 'vitest'
import { getDevice } from '../src/db/devices'
import { createHarness, json } from './helpers/appHarness'

async function challenge(h: Awaited<ReturnType<typeof createHarness>>): Promise<string> {
  return (await json(await h.request('/v1/auth/challenge', { method: 'POST' }))).challenge
}

describe('POST /v1/auth/challenge', () => {
  it('returns a fresh challenge each time', async () => {
    const h = await createHarness()
    const a = await challenge(h)
    expect(a.length).toBeGreaterThan(20)
    expect(a).not.toBe(await challenge(h))
  })
})

describe('POST /v1/devices', () => {
  it('registers an unattested device when the dev switch is on', async () => {
    const h = await createHarness()
    const res = await h.request('/v1/devices', { body: { unattested: true } })
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(body.accessToken).toBeTruthy()
    expect(body.refreshToken).toBeTruthy()
    expect(body.expiresAt).toBe(Math.floor(Date.UTC(2026, 9, 5, 12, 15) / 1000))
    const { deviceId } = await h.tokens.verifyAccess(body.accessToken)
    expect(await getDevice(h.db, deviceId)).toMatchObject({ key_id: null, user_id: null, counter: 0 })
  })

  it('forbids unattested devices when the dev switch is off', async () => {
    const h = await createHarness({ settings: { allowUnattested: false } })
    const res = await h.request('/v1/devices', { body: { unattested: true } })
    expect(res.status).toBe(403)
    expect((await json(res)).error.code).toBe('forbidden')
  })

  it('registers an attested device and stores its public key', async () => {
    const h = await createHarness()
    const c = await challenge(h)
    const att = await h.fakeApple.makeAttestation(c)
    const res = await h.request('/v1/devices', { body: { keyId: att.keyId, attestation: att.attestation, challenge: c } })
    expect(res.status).toBe(200)
    const { deviceId } = await h.tokens.verifyAccess((await json(res)).accessToken)
    const device = await getDevice(h.db, deviceId)
    expect(device?.key_id).toBe(att.keyId)
    expect(device?.public_key).toBeTruthy()
    expect(device?.counter).toBe(0)
  })

  it('rejects an unknown or reused challenge', async () => {
    const h = await createHarness()
    const att = await h.fakeApple.makeAttestation('whatever')
    const unknown = await h.request('/v1/devices', { body: { keyId: att.keyId, attestation: att.attestation, challenge: 'whatever' } })
    expect(unknown.status).toBe(400)
    expect((await json(unknown)).error.code).toBe('invalid_challenge')

    const c = await challenge(h)
    const good = await h.fakeApple.makeAttestation(c)
    const body = { keyId: good.keyId, attestation: good.attestation, challenge: c }
    expect((await h.request('/v1/devices', { body })).status).toBe(200)
    expect((await h.request('/v1/devices', { body })).status).toBe(400) // replay
  })

  it('rejects an invalid attestation with 403 attestation_failed', async () => {
    const h = await createHarness()
    const c = await challenge(h)
    const att = await h.fakeApple.makeAttestation('another-challenge')
    const res = await h.request('/v1/devices', { body: { keyId: att.keyId, attestation: att.attestation, challenge: c } })
    expect(res.status).toBe(403)
    expect((await json(res)).error.code).toBe('attestation_failed')
  })

  it('rejects malformed bodies', async () => {
    const h = await createHarness()
    expect((await h.request('/v1/devices', { body: { nope: true } })).status).toBe(400)
    expect((await h.request('/v1/devices', { body: { unattested: false } })).status).toBe(400)
  })
})

describe('POST /v1/auth/refresh', () => {
  async function attested(h: Awaited<ReturnType<typeof createHarness>>) {
    const c = await challenge(h)
    const att = await h.fakeApple.makeAttestation(c)
    const registered = await json(await h.request('/v1/devices', { body: { keyId: att.keyId, attestation: att.attestation, challenge: c } }))
    return { att, refreshToken: registered.refreshToken as string }
  }

  it('rotates tokens for an attested device with a valid assertion and persists the counter', async () => {
    const h = await createHarness()
    const { att, refreshToken } = await attested(h)
    const c = await challenge(h)
    const assertion = await h.fakeApple.makeAssertion(att.credKeys, `${c}:${refreshToken}`, 1)

    const res = await h.request('/v1/auth/refresh', { body: { refreshToken, challenge: c, assertion } })
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(body.refreshToken).not.toBe(refreshToken)
    const { deviceId } = await h.tokens.verifyAccess(body.accessToken)
    expect((await getDevice(h.db, deviceId))?.counter).toBe(1)

    // o refresh antigo não vale mais
    const c2 = await challenge(h)
    const again = await h.fakeApple.makeAssertion(att.credKeys, `${c2}:${refreshToken}`, 2)
    expect((await h.request('/v1/auth/refresh', { body: { refreshToken, challenge: c2, assertion: again } })).status).toBe(401)
  })

  it('rejects a replayed assertion (counter did not increase)', async () => {
    const h = await createHarness()
    const { att, refreshToken } = await attested(h)
    const c = await challenge(h)
    const assertion = await h.fakeApple.makeAssertion(att.credKeys, `${c}:${refreshToken}`, 1)
    const first = await json(await h.request('/v1/auth/refresh', { body: { refreshToken, challenge: c, assertion } }))

    const c2 = await challenge(h)
    const replay = await h.fakeApple.makeAssertion(att.credKeys, `${c2}:${first.refreshToken}`, 1)
    const res = await h.request('/v1/auth/refresh', { body: { refreshToken: first.refreshToken, challenge: c2, assertion: replay } })
    expect(res.status).toBe(403)
    expect((await json(res)).error.code).toBe('attestation_failed')
  })

  it('requires challenge and assertion for attested devices', async () => {
    const h = await createHarness()
    const { refreshToken } = await attested(h)
    const res = await h.request('/v1/auth/refresh', { body: { refreshToken } })
    expect(res.status).toBe(400)
  })

  it('rejects an assertion with a reused challenge', async () => {
    const h = await createHarness()
    const { att, refreshToken } = await attested(h)
    const c = await challenge(h)
    const assertion = await h.fakeApple.makeAssertion(att.credKeys, `${c}:${refreshToken}`, 1)
    await h.request('/v1/auth/refresh', { body: { refreshToken, challenge: c, assertion } })
    // mesma challenge de novo (com um refresh válido) deve falhar como invalid_challenge
    const second = await h.newDevice({ keyId: 'k', publicKey: 'p' })
    const res = await h.request('/v1/auth/refresh', { body: { refreshToken: second.refreshToken, challenge: c, assertion } })
    expect(res.status).toBe(400)
    expect((await json(res)).error.code).toBe('invalid_challenge')
  })

  it('renews an unattested device with just the refresh token', async () => {
    const h = await createHarness()
    const registered = await json(await h.request('/v1/devices', { body: { unattested: true } }))
    const res = await h.request('/v1/auth/refresh', { body: { refreshToken: registered.refreshToken } })
    expect(res.status).toBe(200)
    expect((await json(res)).refreshToken).not.toBe(registered.refreshToken)
  })

  it('rejects unknown and expired refresh tokens', async () => {
    const h = await createHarness()
    expect((await h.request('/v1/auth/refresh', { body: { refreshToken: 'nope' } })).status).toBe(401)
    const registered = await json(await h.request('/v1/devices', { body: { unattested: true } }))
    h.advance(61 * 24 * 3600 * 1000)
    expect((await h.request('/v1/auth/refresh', { body: { refreshToken: registered.refreshToken } })).status).toBe(401)
  })
})
