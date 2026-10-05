import Anthropic from '@anthropic-ai/sdk'
import OpenAI from 'openai'
import { createAnthropicProvider } from './ai/anthropic'
import { createGeminiProvider } from './ai/gemini'
import { createOpenAIProvider } from './ai/openai'
import type { AiEvent } from './ai/orchestrator'
import type { RecommendationProvider } from './ai/types'
import { createAppleClient, type AppleClient } from './auth/apple'
import { verifyAssertion, verifyAttestation, type AttestVerifier } from './auth/appAttest'
import { TokenService } from './auth/tokens'
import type { ProviderName } from './config'
import type { Env } from './env'
import { d1Db, type Db } from './lib/db'
import type { KVLike } from './lib/kv'
import { loadSettings, type Settings } from './settings'
import { TmdbClient } from './tmdb/client'

export type Deps = {
  config: KVLike
  cache: KVLike
  tmdb: Pick<TmdbClient, 'search' | 'details'>
  provider(name: ProviderName, model: string): RecommendationProvider
  log(e: AiEvent): void
  db: Db
  tokens: TokenService
  apple: AppleClient
  attest: AttestVerifier
  now: () => number
  settings: Settings
}

const GATEWAY_SLUG: Record<ProviderName, string> = {
  anthropic: 'anthropic',
  openai: 'openai',
  gemini: 'google-ai-studio',
}

export function gatewayBaseUrl(env: Env, provider: ProviderName): string {
  return `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/${env.AI_GATEWAY_ID}/${GATEWAY_SLUG[provider]}`
}

export function gatewayHeaders(env: Env): Record<string, string> {
  return env.CF_AIG_TOKEN ? { 'cf-aig-authorization': `Bearer ${env.CF_AIG_TOKEN}` } : {}
}

export function createDeps(env: Env): Deps {
  const db = d1Db(env.DB)
  const now = () => Date.now()
  return {
    config: env.CONFIG,
    cache: env.CACHE,
    tmdb: new TmdbClient(env.TMDB_TOKEN),
    provider(name, model) {
      if (name === 'anthropic') {
        const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, baseURL: gatewayBaseUrl(env, 'anthropic'), defaultHeaders: gatewayHeaders(env), maxRetries: 0 })
        return createAnthropicProvider(client, model)
      }
      if (name === 'gemini') {
        return createGeminiProvider({ apiKey: env.GEMINI_API_KEY ?? '', baseUrl: gatewayBaseUrl(env, 'gemini'), model, extraHeaders: gatewayHeaders(env) })
      }
      const client = new OpenAI({ apiKey: env.OPENAI_API_KEY ?? '', baseURL: gatewayBaseUrl(env, 'openai'), defaultHeaders: gatewayHeaders(env), maxRetries: 0 })
      return createOpenAIProvider(client, model)
    },
    log(e) {
      console.log(JSON.stringify({ event: 'ai_call', ...e }))
      env.AI_EVENTS?.writeDataPoint({
        indexes: [e.provider],
        blobs: [e.provider, e.ok ? 'ok' : 'fail', e.error ?? '', String(e.promptVersion)],
        doubles: [e.latencyMs, e.picks, e.fallback ? 1 : 0],
      })
    },
    db,
    tokens: new TokenService(env.JWT_SECRET, db, now),
    apple: createAppleClient({
      teamId: env.APPLE_TEAM_ID,
      keyId: env.APPLE_KEY_ID,
      privateKeyPem: env.APPLE_PRIVATE_KEY,
      bundleId: env.APPLE_BUNDLE_ID,
    }),
    attest: { verifyAttestation, verifyAssertion },
    now,
    settings: loadSettings(env),
  }
}
