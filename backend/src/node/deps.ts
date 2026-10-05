import Anthropic from '@anthropic-ai/sdk'
import OpenAI from 'openai'
import { createAnthropicProvider } from '../ai/anthropic'
import { createGeminiProvider } from '../ai/gemini'
import { createOpenAIProvider } from '../ai/openai'
import { createAppleClient } from '../auth/apple'
import { verifyAssertion, verifyAttestation } from '../auth/appAttest'
import { TokenService } from '../auth/tokens'
import type { Deps } from '../deps'
import { loadSettings } from '../settings'
import { TmdbClient } from '../tmdb/client'
import type { NodeConfig } from './config'
import type { Sqlite } from './sqlite'
import { SqliteKV } from './sqliteKv'

const GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com'

/** Dependências para rodar fora da Cloudflare: SQLite no lugar do D1/KV e provedores de IA chamados direto. */
export function createNodeDeps(cfg: NodeConfig, sqlite: Sqlite, now: () => number = Date.now): Deps {
  const env = cfg.env
  const config = new SqliteKV(sqlite.raw, 'config', now)
  const cache = new SqliteKV(sqlite.raw, 'cache', now)
  for (const [key, value] of Object.entries(cfg.seed)) void config.put(key, value)

  return {
    config,
    cache,
    tmdb: new TmdbClient(env.TMDB_TOKEN),
    provider(name, model) {
      if (name === 'anthropic') {
        return createAnthropicProvider(new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, maxRetries: 0 }), model)
      }
      if (name === 'gemini') {
        return createGeminiProvider({ apiKey: env.GEMINI_API_KEY ?? '', baseUrl: GEMINI_BASE_URL, model })
      }
      return createOpenAIProvider(new OpenAI({ apiKey: env.OPENAI_API_KEY ?? '', maxRetries: 0 }), model)
    },
    log(e) {
      console.log(JSON.stringify({ event: 'ai_call', ...e }))
    },
    db: sqlite.db,
    tokens: new TokenService(env.JWT_SECRET, sqlite.db, now),
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
