import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT, type JWTVerifyGetKey } from 'jose'
import type { FetchLike } from '../tmdb/client'

export class AppleAuthError extends Error {
  override name = 'AppleAuthError'
}

export type AppleConfig = {
  teamId: string
  keyId: string
  /** Conteúdo do arquivo .p8 (PKCS#8, ES256) da chave de Sign in with Apple. */
  privateKeyPem: string
  bundleId: string
}

export interface AppleClient {
  verifyIdentityToken(idToken: string, expectedNonce: string): Promise<{ sub: string }>
  exchangeCode(code: string): Promise<{ refreshToken: string }>
  revoke(refreshToken: string): Promise<void>
}

const APPLE = 'https://appleid.apple.com'

export function createAppleClient(
  config: AppleConfig,
  deps: { fetchFn?: FetchLike; jwks?: JWTVerifyGetKey; nowMs?: () => number } = {},
): AppleClient {
  const fetchFn: FetchLike = deps.fetchFn ?? ((url, init) => fetch(url, init))
  const jwks = deps.jwks ?? createRemoteJWKSet(new URL(`${APPLE}/auth/keys`))
  const nowMs = deps.nowMs ?? Date.now

  async function clientSecret(): Promise<string> {
    const key = await importPKCS8(config.privateKeyPem, 'ES256')
    const iat = Math.floor(nowMs() / 1000)
    return new SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: config.keyId })
      .setIssuer(config.teamId)
      .setIssuedAt(iat)
      .setExpirationTime(iat + 600)
      .setAudience(APPLE)
      .setSubject(config.bundleId)
      .sign(key)
  }

  async function postForm(path: string, params: Record<string, string>): Promise<Response> {
    return fetchFn(`${APPLE}${path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: config.bundleId, client_secret: await clientSecret(), ...params }).toString(),
    })
  }

  return {
    async verifyIdentityToken(idToken, expectedNonce) {
      try {
        const { payload } = await jwtVerify(idToken, jwks, {
          issuer: APPLE,
          audience: config.bundleId,
          currentDate: new Date(nowMs()),
        })
        if (payload.nonce !== expectedNonce || !payload.sub) throw new Error('nonce or subject mismatch')
        return { sub: payload.sub }
      } catch {
        throw new AppleAuthError('Invalid identity token')
      }
    },

    async exchangeCode(code) {
      const response = await postForm('/auth/token', { code, grant_type: 'authorization_code' })
      if (!response.ok) throw new AppleAuthError(`Apple token endpoint responded ${response.status}`)
      const body = (await response.json()) as { refresh_token?: string }
      if (!body.refresh_token) throw new AppleAuthError('Apple did not return a refresh token')
      return { refreshToken: body.refresh_token }
    },

    async revoke(refreshToken) {
      const response = await postForm('/auth/revoke', { token: refreshToken, token_type_hint: 'refresh_token' })
      if (!response.ok) throw new AppleAuthError(`Apple revoke endpoint responded ${response.status}`)
    },
  }
}
