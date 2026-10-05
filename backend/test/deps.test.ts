import { describe, expect, it, vi } from 'vitest'
import { createDeps, gatewayBaseUrl, gatewayHeaders } from '../src/deps'
import type { Env } from '../src/env'
import { MemoryKV } from './helpers/memoryKV'

const writeDataPoint = vi.fn()
const env = {
  CACHE: new MemoryKV(),
  CONFIG: new MemoryKV(),
  DB: {},
  AI_EVENTS: { writeDataPoint },
  ANTHROPIC_API_KEY: 'a',
  OPENAI_API_KEY: 'o',
  GEMINI_API_KEY: 'g',
  TMDB_TOKEN: 't',
  CF_ACCOUNT_ID: 'acct',
  AI_GATEWAY_ID: 'gw',
  JWT_SECRET: 'a-test-secret-with-more-than-32-characters',
  APPLE_TEAM_ID: 'TEAM123456',
  APPLE_KEY_ID: 'KEY1234567',
  APPLE_BUNDLE_ID: 'com.andre.filmfinder',
  APPLE_PRIVATE_KEY: 'pem',
  ALLOW_UNATTESTED: 'true',
  ALLOW_PROVIDER_OVERRIDE: 'false',
  APPATTEST_ENVS: 'development',
} as unknown as Env

describe('gatewayBaseUrl', () => {
  it('builds AI Gateway URLs per provider', () => {
    expect(gatewayBaseUrl(env, 'anthropic')).toBe('https://gateway.ai.cloudflare.com/v1/acct/gw/anthropic')
    expect(gatewayBaseUrl(env, 'openai')).toBe('https://gateway.ai.cloudflare.com/v1/acct/gw/openai')
    expect(gatewayBaseUrl(env, 'gemini')).toBe('https://gateway.ai.cloudflare.com/v1/acct/gw/google-ai-studio')
  })
})

describe('gatewayHeaders', () => {
  it('adds the AI Gateway token only when configured', () => {
    expect(gatewayHeaders(env)).toEqual({})
    expect(gatewayHeaders({ ...env, CF_AIG_TOKEN: 'tok' } as Env)).toEqual({ 'cf-aig-authorization': 'Bearer tok' })
  })
})

describe('createDeps', () => {
  it('wires identity services and settings', () => {
    const deps = createDeps(env)
    expect(deps.settings.appId).toBe('TEAM123456.com.andre.filmfinder')
    expect(deps.settings.allowUnattested).toBe(true)
    expect(typeof deps.tokens.issueAccess).toBe('function')
    expect(typeof deps.attest.verifyAttestation).toBe('function')
    expect(typeof deps.now()).toBe('number')
  })
  it('creates named providers', () => {
    const deps = createDeps(env)
    expect(deps.provider('anthropic', 'claude-haiku-4-5').name).toBe('anthropic')
    expect(deps.provider('openai', 'gpt-5-mini').name).toBe('openai')
    expect(deps.provider('gemini', 'gemini-3.5-flash-lite').name).toBe('gemini')
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
