import { describe, expect, it, vi } from 'vitest'
import type { RecommendationProvider } from '../src/ai/types'
import type { ProviderName } from '../src/config'
import { grantEntitlement, UNLIMITED_SEARCH } from '../src/db/entitlements'
import { getUsage } from '../src/db/usage'
import { ProviderError } from '../src/lib/errors'
import { createHarness, json, T0 } from './helpers/appHarness'

const valid = { query: 'ficção científica emocionante', mediaType: 'movie', locale: 'pt-BR', region: 'BR' }
const failing = (name: ProviderName): RecommendationProvider => ({
  name,
  recommend: async () => {
    throw new ProviderError('x')
  },
})
const ids = (body: { titles: { tmdbId: number }[] }) => body.titles.map((t) => t.tmdbId)

describe('POST /v1/recommendations', () => {
  it('requires a bearer token', async () => {
    const h = await createHarness()
    const res = await h.request('/v1/recommendations', { body: valid })
    expect(res.status).toBe(401)
    expect(await json(res)).toEqual({ error: { code: 'unauthorized', message: expect.any(String) } })
  })

  it('rejects tokens for devices that no longer exist', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await h.db.run('DELETE FROM devices WHERE id = ?', [d.deviceId])
    expect((await h.request('/v1/recommendations', { body: valid, token: d.accessToken })).status).toBe(401)
  })

  it('rejects invalid input without consuming quota', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: { query: '', mediaType: 'movie' }, token: d.accessToken })
    expect(res.status).toBe(400)
    expect((await json(res)).error.code).toBe('invalid_input')
    expect(await getUsage(h.db, 'device', d.deviceId, '2026-10-05')).toBe(0)
  })

  it('returns resolved titles and the quota', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(ids(body)).toEqual([1, 2, 3])
    expect(body.titles[0].providers.region).toBe('BR')
    expect(body.quota).toEqual({ used: 1, limit: 5, resetsAt: '2026-10-06T00:00:00Z' })
  })

  it('filters excluded ids', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: { ...valid, excludeTmdbIds: [2] }, token: d.accessToken })
    expect(ids(await json(res))).toEqual([1, 3])
  })

  it('passes the excluded titles to the AI prompt', async () => {
    const h = await createHarness()
    const seen: string[][] = []
    h.providers.gemini = { name: 'gemini', recommend: async (input) => (seen.push(input.excludeLabels), [{ title: 'A', originalTitle: 'A', year: 2014, reason: 'r' }, { title: 'B', originalTitle: 'B', year: 2014, reason: 'r' }, { title: 'C', originalTitle: 'C', year: 2014, reason: 'r' }]) }
    const d = await h.newDevice()
    await h.request('/v1/recommendations', { body: { ...valid, excludeTitles: ['Up (2009)', 'Dark (2017)'] }, token: d.accessToken })
    expect(seen).toEqual([['Up (2009)', 'Dark (2017)']])
  })

  it('uses gemini then anthropic by default and honours ai.primary/secondary', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(h.providerCalls).toEqual(['gemini', 'anthropic'])
  })

  it('ignores x-ai-provider unless the override switch is on', async () => {
    const off = await createHarness()
    const d1 = await off.newDevice()
    await off.request('/v1/recommendations', { body: valid, token: d1.accessToken, headers: { 'x-ai-provider': 'openai' } })
    expect(off.providerCalls).toEqual(['gemini', 'anthropic'])

    const on = await createHarness({ settings: { allowProviderOverride: true } })
    const d2 = await on.newDevice()
    await on.request('/v1/recommendations', { body: valid, token: d2.accessToken, headers: { 'x-ai-provider': 'openai' } })
    expect(on.providerCalls).toEqual(['openai'])
  })

  it('returns 503 and gives the search back when every provider fails', async () => {
    const h = await createHarness()
    h.providers.gemini = failing('gemini')
    h.providers.anthropic = failing('anthropic')
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(res.status).toBe(503)
    expect((await json(res)).error.code).toBe('ai_unavailable')
    expect(await getUsage(h.db, 'device', d.deviceId, '2026-10-05')).toBe(0)
  })

  it('returns 200 with empty titles and does not consume quota when nothing resolves', async () => {
    const h = await createHarness()
    h.deps.tmdb.search = vi.fn(async () => null)
    const d = await h.newDevice()
    const res = await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(body.titles).toEqual([])
    expect(body.quota.used).toBe(0)
  })

  it('blocks the 6th free search with 402 quota_exceeded', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    for (let i = 1; i <= 5; i++) {
      expect((await json(await h.request('/v1/recommendations', { body: valid, token: d.accessToken }))).quota.used).toBe(i)
    }
    const res = await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    expect(res.status).toBe(402)
    expect((await json(res)).error.code).toBe('quota_exceeded')
  })

  it('resets the next UTC day', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    for (let i = 0; i < 5; i++) await h.request('/v1/recommendations', { body: valid, token: d.accessToken })
    h.setNow(Date.UTC(2026, 9, 6, 0, 0, 5))
    const token = (await h.tokens.issueAccess(d.deviceId)).accessToken
    expect((await h.request('/v1/recommendations', { body: valid, token })).status).toBe(200)
  })

  it('applies the pro limit for devices/users with unlimited_search', async () => {
    const h = await createHarness()
    const d = await h.newDevice()
    await grantEntitlement(h.db, { id: 'e1', ownerKind: 'device', ownerId: d.deviceId, kind: UNLIMITED_SEARCH, expiresAt: T0 / 1000 + 3600 })
    for (let i = 0; i < 6; i++) {
      expect((await h.request('/v1/recommendations', { body: valid, token: d.accessToken })).status).toBe(200)
    }
  })
})
