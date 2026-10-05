import { describe, expect, it } from 'vitest'
import { loadConfig } from '../../src/config'
import { createNodeApp } from '../../src/node/app'
import { readNodeConfig } from '../../src/node/config'
import { openSqlite } from '../../src/node/sqlite'
import { json } from '../helpers/appHarness'

const base = {
  JWT_SECRET: 'a-secret-with-more-than-32-characters!!',
  TMDB_TOKEN: 'tmdb',
  GEMINI_API_KEY: 'g',
  APPLE_TEAM_ID: 'TEAM123456',
  APPLE_BUNDLE_ID: 'com.andre.filmfinder',
  DATABASE_PATH: ':memory:',
}

describe('readNodeConfig', () => {
  it('accepts a minimal valid environment and applies defaults', () => {
    const cfg = readNodeConfig(base)
    expect(cfg.port).toBe(3000)
    expect(cfg.databasePath).toBe(':memory:')
    expect(cfg.env.ALLOW_UNATTESTED).toBe('false')
    expect(cfg.env.ALLOW_PROVIDER_OVERRIDE).toBe('false')
    expect(cfg.env.APPATTEST_ENVS).toBe('production')
  })

  it('lists every missing or invalid setting at once', () => {
    expect(() => readNodeConfig({})).toThrowError(/JWT_SECRET[\s\S]*TMDB_TOKEN[\s\S]*APPLE_TEAM_ID[\s\S]*APPLE_BUNDLE_ID[\s\S]*AI provider/)
    expect(() => readNodeConfig({ ...base, JWT_SECRET: 'short' })).toThrowError(/JWT_SECRET/)
    expect(() => readNodeConfig({ ...base, PORT: 'abc' })).toThrowError(/PORT/)
  })

  it('turns literal \\n in the Apple private key into real newlines (single-line env vars)', () => {
    const cfg = readNodeConfig({ ...base, APPLE_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\\nABC\\n-----END PRIVATE KEY-----' })
    expect(cfg.env.APPLE_PRIVATE_KEY).toBe('-----BEGIN PRIVATE KEY-----\nABC\n-----END PRIVATE KEY-----')
  })

  it('collects the runtime config overrides to seed', () => {
    const cfg = readNodeConfig({ ...base, AI_PRIMARY: 'anthropic', AI_MODEL_GEMINI: 'gem-x', LIMIT_FREE_DAILY: '9' })
    expect(cfg.seed).toEqual({ 'ai.primary': 'anthropic', 'ai.models.gemini': 'gem-x', 'limits.free.daily': '9' })
  })
})

describe('createNodeApp', () => {
  const make = (extra: Record<string, string> = {}, rateLimit?: { max: number; windowMs: number }) => {
    const sqlite = openSqlite(':memory:')
    return createNodeApp(readNodeConfig({ ...base, ALLOW_UNATTESTED: 'true', ...extra }), sqlite, { rateLimit })
  }
  const post = (app: ReturnType<typeof make>['app'], path: string, body?: unknown, ip = '1.1.1.1') =>
    app.request(path, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-forwarded-for': ip },
      body: body === undefined ? undefined : JSON.stringify(body),
    })

  it('serves health and runs the full identity cycle on SQLite', async () => {
    const { app } = make()
    expect(await (await app.request('/health')).json()).toEqual({ ok: true })

    const registered = await json(await post(app, '/v1/devices', { unattested: true }))
    expect(Object.keys(registered).sort()).toEqual(['accessToken', 'expiresAt', 'refreshToken'])

    const me = await app.request('/v1/me', { headers: { authorization: `Bearer ${registered.accessToken}` } })
    expect(await me.json()).toMatchObject({ user: null, entitlements: [], quota: { used: 0, limit: 5 } })

    const refreshed = await post(app, '/v1/auth/refresh', { refreshToken: registered.refreshToken })
    expect(refreshed.status).toBe(200)
    expect((await post(app, '/v1/auth/refresh', { refreshToken: registered.refreshToken })).status).toBe(401)
  })

  it('refuses unattested devices unless explicitly enabled', async () => {
    const { app } = make({ ALLOW_UNATTESTED: 'false' })
    expect((await post(app, '/v1/devices', { unattested: true })).status).toBe(403)
  })

  it('seeds the runtime config from environment variables', async () => {
    const { deps } = make({ AI_PRIMARY: 'anthropic', LIMIT_FREE_DAILY: '9' })
    const config = await loadConfig(deps.config)
    expect(config.primary).toBe('anthropic')
    expect(config.limits.free).toBe(9)
  })

  it('rate limits the public auth routes per client IP', async () => {
    const { app } = make({}, { max: 3, windowMs: 60_000 })
    for (let i = 0; i < 3; i++) expect((await post(app, '/v1/auth/challenge')).status).toBe(200)
    const blocked = await post(app, '/v1/auth/challenge')
    expect(blocked.status).toBe(429)
    expect(blocked.headers.get('retry-after')).toBeTruthy()
    expect((await json(blocked)).error.code).toBe('rate_limited')
    expect((await post(app, '/v1/auth/challenge', undefined, '2.2.2.2')).status).toBe(200)
  })

  it('does not rate limit authenticated routes with the public limiter', async () => {
    const { app } = make({}, { max: 1, windowMs: 60_000 })
    const r = await json(await post(app, '/v1/devices', { unattested: true }))
    for (let i = 0; i < 4; i++) {
      const res = await app.request('/v1/me', { headers: { authorization: `Bearer ${r.accessToken}`, 'x-forwarded-for': '1.1.1.1' } })
      expect(res.status).toBe(200)
    }
  })
})
