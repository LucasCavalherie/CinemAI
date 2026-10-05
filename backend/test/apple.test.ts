import { createLocalJWKSet, decodeJwt, decodeProtectedHeader, exportJWK, exportPKCS8, generateKeyPair, SignJWT } from 'jose'
import { describe, expect, it } from 'vitest'
import { AppleAuthError, createAppleClient } from '../src/auth/apple'

const BUNDLE = 'com.andre.filmfinder'
const NOW = Date.UTC(2026, 9, 5, 12, 0, 0)
const nowSec = Math.floor(NOW / 1000)

async function setup() {
  const appleKeys = await generateKeyPair('RS256', { extractable: true })
  const jwks = createLocalJWKSet({ keys: [{ ...(await exportJWK(appleKeys.publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' }] })
  const teamKey = await generateKeyPair('ES256', { extractable: true })
  const privateKeyPem = await exportPKCS8(teamKey.privateKey)

  const calls: { url: string; form: URLSearchParams }[] = []
  const state = { status: 200, body: { refresh_token: 'apple-refresh-1' } as unknown }
  const fetchFn = async (url: string, init?: RequestInit) => {
    calls.push({ url, form: new URLSearchParams(String(init?.body)) })
    return new Response(JSON.stringify(state.body), { status: state.status })
  }
  const client = createAppleClient(
    { teamId: 'TEAM123456', keyId: 'KEY1234567', privateKeyPem, bundleId: BUNDLE },
    { fetchFn, jwks, nowMs: () => NOW },
  )

  const token = (over: { iss?: string; aud?: string; sub?: string; nonce?: string; exp?: number; key?: CryptoKey } = {}) =>
    new SignJWT({ nonce: over.nonce ?? 'nonce-1' })
      .setProtectedHeader({ alg: 'RS256', kid: 'k1' })
      .setIssuer(over.iss ?? 'https://appleid.apple.com')
      .setAudience(over.aud ?? BUNDLE)
      .setSubject(over.sub ?? '000123.abcdef')
      .setIssuedAt(nowSec)
      .setExpirationTime(over.exp ?? nowSec + 600)
      .sign(over.key ?? appleKeys.privateKey)

  return { client, calls, state, token }
}

describe('verifyIdentityToken', () => {
  it('accepts a valid token and returns the subject', async () => {
    const { client, token } = await setup()
    expect(await client.verifyIdentityToken(await token(), 'nonce-1')).toEqual({ sub: '000123.abcdef' })
  })

  it.each([
    ['wrong nonce', { nonce: 'other' }],
    ['wrong audience', { aud: 'com.other.app' }],
    ['wrong issuer', { iss: 'https://evil.example' }],
    ['expired token', { exp: nowSec - 10 }],
  ])('rejects %s', async (_name, over) => {
    const { client, token } = await setup()
    await expect(client.verifyIdentityToken(await token(over), 'nonce-1')).rejects.toBeInstanceOf(AppleAuthError)
  })

  it('rejects a token signed by an unknown key and garbage', async () => {
    const { client, token } = await setup()
    const stranger = await generateKeyPair('RS256', { extractable: true })
    await expect(client.verifyIdentityToken(await token({ key: stranger.privateKey }), 'nonce-1')).rejects.toBeInstanceOf(AppleAuthError)
    await expect(client.verifyIdentityToken('garbage', 'nonce-1')).rejects.toBeInstanceOf(AppleAuthError)
  })
})

describe('exchangeCode', () => {
  it('posts the code with a valid ES256 client secret and returns the refresh token', async () => {
    const { client, calls } = await setup()
    expect(await client.exchangeCode('code-1')).toEqual({ refreshToken: 'apple-refresh-1' })

    const call = calls[0]!
    expect(call.url).toBe('https://appleid.apple.com/auth/token')
    expect(call.form.get('grant_type')).toBe('authorization_code')
    expect(call.form.get('code')).toBe('code-1')
    expect(call.form.get('client_id')).toBe(BUNDLE)

    const secret = call.form.get('client_secret')!
    expect(decodeProtectedHeader(secret)).toMatchObject({ alg: 'ES256', kid: 'KEY1234567' })
    expect(decodeJwt(secret)).toMatchObject({ iss: 'TEAM123456', sub: BUNDLE, aud: 'https://appleid.apple.com' })
    expect((decodeJwt(secret).exp ?? 0) - nowSec).toBeLessThanOrEqual(15_777_000) // Apple aceita até ~6 meses
  })

  it('fails when Apple rejects the code or returns no refresh token', async () => {
    const { client, state } = await setup()
    state.status = 400
    await expect(client.exchangeCode('bad')).rejects.toBeInstanceOf(AppleAuthError)
    state.status = 200
    state.body = {}
    await expect(client.exchangeCode('bad')).rejects.toBeInstanceOf(AppleAuthError)
  })
})

describe('revoke', () => {
  it('posts the refresh token with a type hint', async () => {
    const { client, calls } = await setup()
    await client.revoke('apple-refresh-1')
    const call = calls[0]!
    expect(call.url).toBe('https://appleid.apple.com/auth/revoke')
    expect(call.form.get('token')).toBe('apple-refresh-1')
    expect(call.form.get('token_type_hint')).toBe('refresh_token')
    expect(call.form.get('client_id')).toBe(BUNDLE)
  })

  it('throws when Apple responds with an error', async () => {
    const { client, state } = await setup()
    state.status = 500
    await expect(client.revoke('t')).rejects.toBeInstanceOf(AppleAuthError)
  })
})
