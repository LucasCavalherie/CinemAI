import { describe, expect, it, vi } from 'vitest'
import { createAnthropicProvider, type AnthropicLike } from '../src/ai/anthropic'
import { createOpenAIProvider, type OpenAILike } from '../src/ai/openai'
import { ProviderError } from '../src/lib/errors'

const input = { query: 'q', mediaType: 'movie' as const, locale: 'pt-BR', excludeLabels: [], count: 15 }
const picksJson = JSON.stringify({ picks: [{ title: 'Up', originalTitle: 'Up', year: 2009, reason: 'r' }] })
const signal = new AbortController().signal

function anthropicStub(response: unknown) {
  const create = vi.fn().mockResolvedValue(response)
  return { client: { messages: { create } } as unknown as AnthropicLike, create }
}

function openaiStub(response: unknown) {
  const create = vi.fn().mockResolvedValue(response)
  return { client: { chat: { completions: { create } } } as unknown as OpenAILike, create }
}

describe('AnthropicProvider', () => {
  it('sends model, schema and signal, and parses picks', async () => {
    const { client, create } = anthropicStub({ stop_reason: 'end_turn', content: [{ type: 'text', text: picksJson }] })
    const picks = await createAnthropicProvider(client, 'claude-haiku-4-5').recommend(input, signal)
    expect(picks[0]?.originalTitle).toBe('Up')
    const [body, opts] = create.mock.calls[0]!
    expect(body.model).toBe('claude-haiku-4-5')
    expect(body.output_config.format.type).toBe('json_schema')
    expect(body.messages[0].role).toBe('user')
    expect(opts.signal).toBe(signal)
  })

  it('throws ProviderError when stop_reason is not end_turn', async () => {
    const { client } = anthropicStub({ stop_reason: 'max_tokens', content: [{ type: 'text', text: '{' }] })
    await expect(createAnthropicProvider(client, 'm').recommend(input, signal)).rejects.toBeInstanceOf(ProviderError)
  })

  it('throws ProviderError on refusal', async () => {
    const { client } = anthropicStub({ stop_reason: 'refusal', content: [] })
    await expect(createAnthropicProvider(client, 'm').recommend(input, signal)).rejects.toBeInstanceOf(ProviderError)
  })
})

describe('OpenAIProvider', () => {
  it('sends strict json_schema and parses picks', async () => {
    const { client, create } = openaiStub({ choices: [{ finish_reason: 'stop', message: { content: picksJson, refusal: null } }] })
    const picks = await createOpenAIProvider(client, 'gpt-5-mini').recommend(input, signal)
    expect(picks).toHaveLength(1)
    const [body, opts] = create.mock.calls[0]!
    expect(body.model).toBe('gpt-5-mini')
    expect(body.response_format.type).toBe('json_schema')
    expect(body.response_format.json_schema.strict).toBe(true)
    expect(body.messages.map((m: { role: string }) => m.role)).toEqual(['system', 'user'])
    expect(opts.signal).toBe(signal)
  })

  it('throws ProviderError on refusal', async () => {
    const { client } = openaiStub({ choices: [{ finish_reason: 'stop', message: { content: null, refusal: 'no' } }] })
    await expect(createOpenAIProvider(client, 'm').recommend(input, signal)).rejects.toBeInstanceOf(ProviderError)
  })

  it('throws ProviderError when finish_reason is length', async () => {
    const { client } = openaiStub({ choices: [{ finish_reason: 'length', message: { content: '{', refusal: null } }] })
    await expect(createOpenAIProvider(client, 'm').recommend(input, signal)).rejects.toBeInstanceOf(ProviderError)
  })
})
