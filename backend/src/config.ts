import type { KVLike } from './lib/kv'

export type ProviderName = 'anthropic' | 'openai' | 'gemini'

export type AppConfig = {
  primary: ProviderName
  secondary: ProviderName
  models: Record<ProviderName, string>
}

export const DEFAULT_CONFIG: AppConfig = {
  primary: 'anthropic',
  secondary: 'gemini',
  models: { anthropic: 'claude-haiku-4-5', openai: 'gpt-5-mini', gemini: 'gemini-3.1-flash-lite' },
}

const isProvider = (v: string | null): v is ProviderName => v === 'anthropic' || v === 'openai' || v === 'gemini'

export async function loadConfig(kv: KVLike): Promise<AppConfig> {
  const [primary, secondary, anthropic, openai, gemini] = await Promise.all([
    kv.get('ai.primary'),
    kv.get('ai.secondary'),
    kv.get('ai.models.anthropic'),
    kv.get('ai.models.openai'),
    kv.get('ai.models.gemini'),
  ])
  const p = isProvider(primary) ? primary : DEFAULT_CONFIG.primary
  const fallbackDefault: ProviderName = p === 'anthropic' ? 'gemini' : 'anthropic'
  const s = isProvider(secondary) && secondary !== p ? secondary : fallbackDefault
  return {
    primary: p,
    secondary: s,
    models: {
      anthropic: anthropic ?? DEFAULT_CONFIG.models.anthropic,
      openai: openai ?? DEFAULT_CONFIG.models.openai,
      gemini: gemini ?? DEFAULT_CONFIG.models.gemini,
    },
  }
}
