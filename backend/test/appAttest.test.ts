import { describe, expect, it } from 'vitest'
import { verifyAssertion, verifyAttestation, type AttestEnv } from '../src/auth/appAttest'
import { APPLE_APP_ATTEST_ROOT_CA_PEM } from '../src/auth/appleRootCa'
import { fromBase64, toBase64 } from '../src/lib/crypto'
import { createFakeApple } from './helpers/fakeApple'

const APP_ID = 'ABCDE12345.com.andre.filmfinder'
const NOW = Date.UTC(2026, 5, 1)

async function setup(env: AttestEnv[] = ['development']) {
  const apple = await createFakeApple(APP_ID)
  const input = (att: { keyId: string; attestation: string }, overrides: Record<string, unknown> = {}) => ({
    attestation: att.attestation,
    keyId: att.keyId,
    challenge: 'challenge-1',
    appId: APP_ID,
    allowedEnvs: env,
    rootCaPem: apple.rootPem,
    nowMs: NOW,
    ...overrides,
  })
  return { apple, input }
}

describe('Apple root CA constant', () => {
  it('is a well-formed PEM', () => {
    expect(APPLE_APP_ATTEST_ROOT_CA_PEM.startsWith('-----BEGIN CERTIFICATE-----')).toBe(true)
    expect(APPLE_APP_ATTEST_ROOT_CA_PEM.endsWith('-----END CERTIFICATE-----')).toBe(true)
  })
})

describe('verifyAttestation', () => {
  it('accepts a valid attestation and returns the credential public key (SPKI, base64)', async () => {
    const { apple, input } = await setup()
    const att = await apple.makeAttestation('challenge-1')
    const result = await verifyAttestation(input(att))
    const spki = new Uint8Array((await crypto.subtle.exportKey('spki', att.credKeys.publicKey)) as ArrayBuffer)
    expect(result.publicKeySpki).toBe(toBase64(spki))
  })

  it('accepts production attestations when production is allowed', async () => {
    const { apple, input } = await setup(['development', 'production'])
    const att = await apple.makeAttestation('challenge-1', { env: 'production' })
    await expect(verifyAttestation(input(att))).resolves.toBeDefined()
  })

  const rejections: [string, (apple: Awaited<ReturnType<typeof createFakeApple>>) => Promise<{ att: { keyId: string; attestation: string }; overrides?: Record<string, unknown> }>, string][] = [
    ['a different challenge', async (a) => ({ att: await a.makeAttestation('challenge-1'), overrides: { challenge: 'challenge-2' } }), 'nonce does not match challenge'],
    ['a different app id', async (a) => ({ att: await a.makeAttestation('challenge-1', { appId: 'OTHER.com.example' }) }), 'rpIdHash does not match appId'],
    ['a production attestation when only development is allowed', async (a) => ({ att: await a.makeAttestation('challenge-1', { env: 'production' }) }), 'aaguid does not match an allowed environment'],
    ['a non-zero counter', async (a) => ({ att: await a.makeAttestation('challenge-1', { counter: 1 }) }), 'counter must be 0'],
    ['a forged nonce in the certificate', async (a) => ({ att: await a.makeAttestation('challenge-1', { nonce: new Uint8Array(32) }) }), 'nonce does not match challenge'],
    ['a different key id', async (a) => ({ att: { ...(await a.makeAttestation('challenge-1')), keyId: toBase64(new Uint8Array(32)) } }), 'keyId does not match credCert public key'],
    ['an unexpected format', async (a) => ({ att: await a.makeAttestation('challenge-1', { fmt: 'packed' }) }), 'unexpected attestation format'],
    ['malformed data', async () => ({ att: { keyId: 'AAAA', attestation: 'AAAA' } }), 'attestation is not valid CBOR'],
    ['an expired certificate chain', async (a) => ({ att: await a.makeAttestation('challenge-1'), overrides: { nowMs: Date.UTC(2030, 0, 1) } }), 'certificate chain is not trusted'],
  ]
  it.each(rejections)('rejects %s', async (_name, build, reason) => {
    const { apple, input } = await setup()
    const { att, overrides } = await build(apple)
    await expect(verifyAttestation(input(att, overrides))).rejects.toMatchObject({ name: 'AttestationError', reason })
  })

  it('rejects a chain that does not lead to the trusted root', async () => {
    const { apple, input } = await setup()
    const other = await createFakeApple(APP_ID)
    const att = await apple.makeAttestation('challenge-1')
    await expect(verifyAttestation(input(att, { rootCaPem: other.rootPem }))).rejects.toMatchObject({
      reason: 'certificate chain is not trusted',
    })
  })
})

describe('verifyAssertion', () => {
  async function registered() {
    const { apple, input } = await setup()
    const att = await apple.makeAttestation('challenge-1')
    const { publicKeySpki } = await verifyAttestation(input(att))
    return { apple, att, publicKeySpki }
  }
  const base = (publicKeySpki: string, assertion: string, over: Record<string, unknown> = {}) => ({
    assertion,
    clientData: 'challenge-2:refresh-token',
    publicKeySpki,
    storedCounter: 0,
    appId: APP_ID,
    ...over,
  })

  it('accepts a valid assertion and returns the new counter', async () => {
    const { apple, att, publicKeySpki } = await registered()
    const assertion = await apple.makeAssertion(att.credKeys, 'challenge-2:refresh-token', 1)
    expect(await verifyAssertion(base(publicKeySpki, assertion))).toEqual({ counter: 1 })
  })

  it('rejects a counter that did not increase (replay)', async () => {
    const { apple, att, publicKeySpki } = await registered()
    const assertion = await apple.makeAssertion(att.credKeys, 'challenge-2:refresh-token', 5)
    await expect(verifyAssertion(base(publicKeySpki, assertion, { storedCounter: 5 }))).rejects.toMatchObject({
      reason: 'counter did not increase',
    })
  })

  it('rejects an assertion over different client data', async () => {
    const { apple, att, publicKeySpki } = await registered()
    const assertion = await apple.makeAssertion(att.credKeys, 'other-data', 1)
    await expect(verifyAssertion(base(publicKeySpki, assertion))).rejects.toMatchObject({
      reason: 'assertion signature is invalid',
    })
  })

  it('rejects an assertion signed by another key', async () => {
    const { apple, publicKeySpki } = await registered()
    const stranger = await apple.makeAttestation('x')
    const assertion = await apple.makeAssertion(stranger.credKeys, 'challenge-2:refresh-token', 1)
    await expect(verifyAssertion(base(publicKeySpki, assertion))).rejects.toMatchObject({
      reason: 'assertion signature is invalid',
    })
  })

  it('rejects another app id, tampered signatures and malformed data', async () => {
    const { apple, att, publicKeySpki } = await registered()
    const wrongApp = await apple.makeAssertion(att.credKeys, 'challenge-2:refresh-token', 1, { appId: 'OTHER.com.example' })
    await expect(verifyAssertion(base(publicKeySpki, wrongApp))).rejects.toMatchObject({ reason: 'rpIdHash does not match appId' })

    const good = fromBase64(await apple.makeAssertion(att.credKeys, 'challenge-2:refresh-token', 1))
    good[good.length - 3] = (good[good.length - 3] ?? 0) ^ 0xff
    await expect(verifyAssertion(base(publicKeySpki, toBase64(good)))).rejects.toMatchObject({ name: 'AttestationError' })

    await expect(verifyAssertion(base(publicKeySpki, 'AAAA'))).rejects.toMatchObject({ reason: 'assertion is not valid CBOR' })
  })
})
