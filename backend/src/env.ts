export interface Env {
  CACHE: KVNamespace
  CONFIG: KVNamespace
  DB: D1Database
  AI_EVENTS?: AnalyticsEngineDataset
  ANTHROPIC_API_KEY: string
  OPENAI_API_KEY?: string
  GEMINI_API_KEY?: string
  TMDB_TOKEN: string
  CF_ACCOUNT_ID: string
  CF_AIG_TOKEN?: string
  AI_GATEWAY_ID: string
  JWT_SECRET: string
  APPLE_TEAM_ID: string
  APPLE_KEY_ID: string
  APPLE_BUNDLE_ID: string
  APPLE_PRIVATE_KEY: string
  ALLOW_UNATTESTED: string
  ALLOW_PROVIDER_OVERRIDE: string
  APPATTEST_ENVS: string
}
