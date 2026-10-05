import { describe, expect, it, vi } from 'vitest'
import { createGeminiProvider } from '../src/ai/gemini'
import { ProviderError } from '../src/lib/errors'

const input = { query: 'q', mediaType: 'movie' as const, locale: 'pt-BR', excludeLabels: [], count: 15 }
const picksJson = JSON.stringify({ picks: [{ title: 'Up', originalTitle: 'Up', year: 2009, reason: 'r' }] })
const signal = new AbortController().signal
const baseUrl = 'https://gw.example/google-ai-studio'

function stub(body: unknown, status = 200) {
  const fetchFn = vi.fn(async (_url: string, _init?: RequestInit) => new Response(JSON.stringify(body), { status }))
  return { fetchFn, provider: createGeminiProvider({ apiKey: 'k', baseUrl, model: 'gemini-x', fetchFn }) }
}

const okBody = { candidates: [{ finishReason: 'STOP', content: { parts: [{ text: picksJson }] } }] }

describe('GeminiProvider', () => {
  it('calls generateContent with schema, system instruction, key header and signal', async () => {
    const { fetchFn, provider } = stub(okBody)
    const picks = await provider.recommend(input, signal)
    expect(picks[0]?.originalTitle).toBe('Up')
    const [url, init] = fetchFn.mock.calls[0]!
    expect(url).toBe(`${baseUrl}/v1beta/models/gemini-x:generateContent`)
    expect((init?.headers as Record<string, string>)['x-goog-api-key']).toBe('k')
    expect(init?.signal).toBe(signal)
    const body = JSON.parse(init?.body as string)
    expect(body.generationConfig.responseMimeType).toBe('application/json')
    expect(body.generationConfig.responseJsonSchema.required).toEqual(['picks'])
    expect(body.systemInstruction.parts[0].text).toContain('recommendation engine')
    expect(body.contents[0].role).toBe('user')
    expect(body.contents[0].parts[0].text).toContain('<request>')
  })

  it('ignores thought parts', async () => {
    const { provider } = stub({
      candidates: [{ finishReason: 'STOP', content: { parts: [{ thought: true, text: 'thinking' }, { text: picksJson }] } }],
    })
    expect(await provider.recommend(input, signal)).toHaveLength(1)
  })

  it('throws ProviderError on non-2xx', async () => {
    const { provider } = stub({ error: { message: 'bad key' } }, 400)
    await expect(provider.recommend(input, signal)).rejects.toBeInstanceOf(ProviderError)
  })

  it('throws ProviderError when blocked by prompt feedback', async () => {
    const { provider } = stub({ promptFeedback: { blockReason: 'SAFETY' } })
    await expect(provider.recommend(input, signal)).rejects.toBeInstanceOf(ProviderError)
  })

  it('throws ProviderError when finishReason is not STOP', async () => {
    const { provider } = stub({ candidates: [{ finishReason: 'MAX_TOKENS', content: { parts: [{ text: '{' }] } }] })
    await expect(provider.recommend(input, signal)).rejects.toBeInstanceOf(ProviderError)
  })

  it('throws ProviderError when there are no candidates', async () => {
    const { provider } = stub({ candidates: [] })
    await expect(provider.recommend(input, signal)).rejects.toBeInstanceOf(ProviderError)
  })
})
