import { describe, expect, it, vi } from 'vitest'
import { createApp } from '../src/app'
import type { RecommendationProvider } from '../src/ai/types'
import type { Deps } from '../src/deps'
import type { Env } from '../src/env'
import { ProviderError } from '../src/lib/errors'
import type { AiPick } from '../src/schemas'
import { interstellar } from './fixtures/tmdb'
import { MemoryKV } from './helpers/memoryKV'

const env = { DEV_API_KEY: 'dev' } as Env
const picks: AiPick[] = ['A', 'B', 'C'].map((t, i) => ({ title: t, originalTitle: t, year: 2014, reason: `r${i}` }))

function makeDeps(overrides: Partial<Record<'anthropic' | 'openai', RecommendationProvider>> = {}, config = new MemoryKV()) {
  const calls: string[] = []
  const deps: Deps = {
    config,
    cache: new MemoryKV(),
    tmdb: {
      search: vi.fn(async (_m: string, q: string) => ({ A: 1, B: 2, C: 3 } as Record<string, number>)[q] ?? null),
      details: vi.fn(async (_m: string, id: number) => ({ ...interstellar, id })),
    },
    provider: (name) => {
      calls.push(name)
      return overrides[name] ?? { name, recommend: async () => picks }
    },
    log: vi.fn(),
  }
  return { deps, calls }
}

function post(app: ReturnType<typeof createApp>, body: unknown, headers: Record<string, string> = { 'x-dev-key': 'dev' }) {
  return app.request('/v1/recommendations', { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) }, env)
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const json = async (res: Response) => (await res.json()) as any

const valid = { query: 'ficção científica emocionante', mediaType: 'movie', locale: 'pt-BR', region: 'BR' }

describe('POST /v1/recommendations', () => {
  it('rejects requests without the dev key', async () => {
    const { deps } = makeDeps()
    const res = await post(createApp(() => deps), valid, {})
    expect(res.status).toBe(401)
    expect(await json(res)).toEqual({ error: { code: 'unauthorized', message: expect.any(String) } })
  })

  it('rejects invalid input', async () => {
    const { deps } = makeDeps()
    const res = await post(createApp(() => deps), { query: '', mediaType: 'movie' })
    expect(res.status).toBe(400)
    expect((await json(res)).error.code).toBe('invalid_input')
  })

  it('returns resolved titles', async () => {
    const { deps } = makeDeps()
    const res = await post(createApp(() => deps), valid)
    expect(res.status).toBe(200)
    const body = await json(res)
    expect(body.quota).toBeNull()
    expect(body.titles.map((t: { tmdbId: number }) => t.tmdbId)).toEqual([1, 2, 3])
    expect(body.titles[0].providers.region).toBe('BR')
  })

  it('filters excluded ids', async () => {
    const { deps } = makeDeps()
    const res = await post(createApp(() => deps), { ...valid, excludeTmdbIds: [2] })
    expect((await json(res)).titles.map((t: { tmdbId: number }) => t.tmdbId)).toEqual([1, 3])
  })

  it('orders providers by ai.primary from config', async () => {
    const { deps, calls } = makeDeps({}, new MemoryKV({ 'ai.primary': 'openai' }))
    await post(createApp(() => deps), valid)
    expect(calls).toEqual(['openai', 'anthropic'])
  })

  it('honours x-ai-provider by using only that provider', async () => {
    const { deps, calls } = makeDeps()
    await post(createApp(() => deps), valid, { 'x-dev-key': 'dev', 'x-ai-provider': 'openai' })
    expect(calls).toEqual(['openai'])
  })

  it('returns 503 ai_unavailable when every provider fails', async () => {
    const fail = (name: 'anthropic' | 'openai'): RecommendationProvider => ({ name, recommend: async () => { throw new ProviderError('x') } })
    const { deps } = makeDeps({ anthropic: fail('anthropic'), openai: fail('openai') })
    const res = await post(createApp(() => deps), valid)
    expect(res.status).toBe(503)
    expect((await json(res)).error.code).toBe('ai_unavailable')
  })

  it('returns 200 with empty titles when nothing resolves', async () => {
    const { deps } = makeDeps()
    deps.tmdb.search = vi.fn(async () => null)
    const res = await post(createApp(() => deps), valid)
    expect(res.status).toBe(200)
    expect((await json(res)).titles).toEqual([])
  })
})
