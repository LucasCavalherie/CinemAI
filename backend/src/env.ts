export interface Env {
  CACHE: KVNamespace
  CONFIG: KVNamespace
  AI_EVENTS?: AnalyticsEngineDataset
  ANTHROPIC_API_KEY: string
  OPENAI_API_KEY: string
  TMDB_TOKEN: string
  DEV_API_KEY: string
  CF_ACCOUNT_ID: string
  AI_GATEWAY_ID: string
}
