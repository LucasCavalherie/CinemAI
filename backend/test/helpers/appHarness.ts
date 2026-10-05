import { verifyAssertion, verifyAttestation } from '../../src/auth/appAttest'
import { AppleAuthError, type AppleClient } from '../../src/auth/apple'
import { TokenService } from '../../src/auth/tokens'
import { createApp } from '../../src/app'
import type { RecommendationProvider } from '../../src/ai/types'
import type { ProviderName } from '../../src/config'
import { createDevice, linkDeviceToUser } from '../../src/db/devices'
import type { Deps } from '../../src/deps'
import type { Env } from '../../src/env'
import type { AiPick } from '../../src/schemas'
import type { Settings } from '../../src/settings'
import { interstellar } from '../fixtures/tmdb'
import { createFakeApple } from './fakeApple'
import { MemoryKV } from './memoryKV'
import { createTestDb } from './sqliteDb'
import { vi } from 'vitest'

export const APP_ID = 'TEAM123456.com.andre.filmfinder'
export const T0 = Date.UTC(2026, 9, 5, 12, 0, 0)

const DEFAULT_PICKS: AiPick[] = ['A', 'B', 'C'].map((t, i) => ({ title: t, originalTitle: t, year: 2014, reason: `r${i}` }))

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const json = async (res: Response) => (await res.json()) as any

export async function createHarness(options: { settings?: Partial<Settings>; failRevoke?: boolean } = {}) {
  const db = createTestDb()
  let nowMs = T0
  const now = () => nowMs
  const fakeApple = await createFakeApple(APP_ID)
  const tokens = new TokenService('harness-secret-with-more-than-32-characters', db, now)

  const state = { failRevoke: options.failRevoke ?? false }
  const revoked: string[] = []
  // Token de identidade de teste: `fake:<sub>:<nonce>`.
  const apple: AppleClient = {
    async verifyIdentityToken(token, expectedNonce) {
      const [prefix, sub, nonce] = token.split(':')
      if (prefix !== 'fake' || !sub || nonce !== expectedNonce) throw new AppleAuthError('bad identity token')
      return { sub }
    },
    async exchangeCode(code) {
      return { refreshToken: `apple-refresh-${code}` }
    },
    async revoke(refreshToken) {
      if (state.failRevoke) throw new AppleAuthError('revoke failed')
      revoked.push(refreshToken)
    },
  }

  const settings: Settings = {
    appId: APP_ID,
    bundleId: 'com.andre.filmfinder',
    allowUnattested: true,
    allowProviderOverride: false,
    attestEnvs: ['development'],
    rootCaPem: fakeApple.rootPem,
    ...options.settings,
  }

  const providers: Partial<Record<ProviderName, RecommendationProvider>> = {}
  const providerCalls: ProviderName[] = []
  const deps: Deps = {
    config: new MemoryKV(),
    cache: new MemoryKV(),
    tmdb: {
      search: vi.fn(async (_m: string, q: string) => ({ A: 1, B: 2, C: 3 } as Record<string, number>)[q] ?? null),
      details: vi.fn(async (_m: string, id: number) => ({ ...interstellar, id })),
    },
    provider: (name) => {
      providerCalls.push(name)
      return providers[name] ?? { name, recommend: async () => DEFAULT_PICKS }
    },
    log: vi.fn(),
    db,
    tokens,
    apple,
    attest: { verifyAttestation, verifyAssertion },
    now,
    settings,
  }
  const app = createApp(() => deps)

  async function request(
    path: string,
    init: { method?: string; body?: unknown; token?: string; headers?: Record<string, string> } = {},
  ) {
    const headers: Record<string, string> = { ...init.headers }
    if (init.body !== undefined) headers['content-type'] = 'application/json'
    if (init.token) headers.authorization = `Bearer ${init.token}`
    return app.request(
      path,
      {
        method: init.method ?? (init.body !== undefined ? 'POST' : 'GET'),
        headers,
        body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
      },
      {} as Env,
    )
  }

  /** Cria um dispositivo direto no banco e emite tokens (atalho para testes de rotas autenticadas). */
  async function newDevice(opts: { keyId?: string; publicKey?: string; userId?: string } = {}) {
    const deviceId = crypto.randomUUID()
    await createDevice(db, { id: deviceId, keyId: opts.keyId ?? null, publicKey: opts.publicKey ?? null, nowSec: Math.floor(nowMs / 1000) })
    if (opts.userId) await linkDeviceToUser(db, deviceId, opts.userId)
    const { accessToken } = await tokens.issueAccess(deviceId)
    const refreshToken = await tokens.issueRefresh(deviceId)
    return { deviceId, accessToken, refreshToken }
  }

  return {
    app,
    deps,
    db,
    tokens,
    fakeApple,
    request,
    newDevice,
    state,
    revoked,
    providers,
    providerCalls,
    setNow: (ms: number) => (nowMs = ms),
    advance: (ms: number) => (nowMs += ms),
  }
}
