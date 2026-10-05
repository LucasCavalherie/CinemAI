import { describe, expect, it, vi } from 'vitest'
import { createDeps, gatewayBaseUrl } from '../src/deps'
import type { Env } from '../src/env'
import { MemoryKV } from './helpers/memoryKV'

const writeDataPoint = vi.fn()
const env = {
  CACHE: new MemoryKV(),
  CONFIG: new MemoryKV(),
  AI_EVENTS: { writeDataPoint },
  ANTHROPIC_API_KEY: 'a',
  OPENAI_API_KEY: 'o',
  TMDB_TOKEN: 't',
  DEV_API_KEY: 'd',
  CF_ACCOUNT_ID: 'acct',
  AI_GATEWAY_ID: 'gw',
} as unknown as Env

describe('gatewayBaseUrl', () => {
  it('builds AI Gateway URLs per provider', () => {
    expect(gatewayBaseUrl(env, 'anthropic')).toBe('https://gateway.ai.cloudflare.com/v1/acct/gw/anthropic')
    expect(gatewayBaseUrl(env, 'openai')).toBe('https://gateway.ai.cloudflare.com/v1/acct/gw/openai')
  })
})

describe('createDeps', () => {
  it('creates named providers', () => {
    const deps = createDeps(env)
    expect(deps.provider('anthropic', 'claude-haiku-4-5').name).toBe('anthropic')
    expect(deps.provider('openai', 'gpt-5-mini').name).toBe('openai')
  })

  it('writes AI events to Analytics Engine', () => {
    createDeps(env).log({ provider: 'openai', ok: false, latencyMs: 120, picks: 0, fallback: true, error: 'boom', promptVersion: 1 })
    expect(writeDataPoint).toHaveBeenCalledWith({
      indexes: ['openai'],
      blobs: ['openai', 'fail', 'boom', '1'],
      doubles: [120, 0, 1],
    })
  })
})
