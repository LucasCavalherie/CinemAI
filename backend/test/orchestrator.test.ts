import { describe, expect, it, vi } from 'vitest'
import { recommendWithFallback, type AiEvent } from '../src/ai/orchestrator'
import type { RecommendationProvider } from '../src/ai/types'
import { AiUnavailableError, ProviderError } from '../src/lib/errors'
import type { AiPick } from '../src/schemas'

const input = { query: 'q', mediaType: 'movie' as const, locale: 'en-US', excludeLabels: [], count: 15 }
const pick = (n: number): AiPick => ({ title: `T${n}`, originalTitle: `T${n}`, year: 2000 + n, reason: 'r' })
const picks = (count: number) => Array.from({ length: count }, (_, i) => pick(i))

const ok = (name: 'anthropic' | 'openai', count = 5): RecommendationProvider => ({
  name,
  recommend: vi.fn().mockResolvedValue(picks(count)),
})
const failing = (name: 'anthropic' | 'openai'): RecommendationProvider => ({
  name,
  recommend: vi.fn().mockRejectedValue(new ProviderError('boom')),
})
const hanging = (name: 'anthropic' | 'openai'): RecommendationProvider => ({
  name,
  recommend: (_i, signal) => new Promise((_, reject) => signal.addEventListener('abort', () => reject(signal.reason))),
})

const opts = { timeoutMs: 20, minPicks: 3 }

describe('recommendWithFallback', () => {
  it('uses the primary when it succeeds', async () => {
    const secondary = ok('openai')
    const r = await recommendWithFallback([ok('anthropic'), secondary], input, opts)
    expect(r.provider).toBe('anthropic')
    expect(r.picks).toHaveLength(5)
    expect(secondary.recommend).not.toHaveBeenCalled()
  })

  it('falls back when the primary throws', async () => {
    const r = await recommendWithFallback([failing('anthropic'), ok('openai')], input, opts)
    expect(r.provider).toBe('openai')
  })

  it('falls back when the primary times out', async () => {
    const r = await recommendWithFallback([hanging('anthropic'), ok('openai')], input, opts)
    expect(r.provider).toBe('openai')
  })

  it('falls back when the primary returns fewer than minPicks', async () => {
    const r = await recommendWithFallback([ok('anthropic', 2), ok('openai', 4)], input, opts)
    expect(r.provider).toBe('openai')
  })

  it('throws AiUnavailableError when all fail', async () => {
    await expect(recommendWithFallback([failing('anthropic'), failing('openai')], input, opts)).rejects.toBeInstanceOf(
      AiUnavailableError,
    )
  })

  it('logs one event per attempt with fallback flag', async () => {
    const events: AiEvent[] = []
    await recommendWithFallback([failing('anthropic'), ok('openai')], input, { ...opts, log: (e) => events.push(e) })
    expect(events.map((e) => [e.provider, e.ok, e.fallback])).toEqual([
      ['anthropic', false, false],
      ['openai', true, true],
    ])
    expect(events[0]?.error).toBe('boom')
    expect(events[1]?.picks).toBe(5)
    expect(events[1]?.promptVersion).toBe(1)
  })
})
