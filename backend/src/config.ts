import type { KVLike } from './lib/kv'

export type ProviderName = 'anthropic' | 'openai'

export type AppConfig = {
  primary: ProviderName
  models: { anthropic: string; openai: string }
}

export const DEFAULT_CONFIG: AppConfig = {
  primary: 'anthropic',
  models: { anthropic: 'claude-haiku-4-5', openai: 'gpt-5-mini' },
}

export async function loadConfig(kv: KVLike): Promise<AppConfig> {
  const [primary, anthropic, openai] = await Promise.all([
    kv.get('ai.primary'),
    kv.get('ai.models.anthropic'),
    kv.get('ai.models.openai'),
  ])
  return {
    primary: primary === 'openai' || primary === 'anthropic' ? primary : DEFAULT_CONFIG.primary,
    models: {
      anthropic: anthropic ?? DEFAULT_CONFIG.models.anthropic,
      openai: openai ?? DEFAULT_CONFIG.models.openai,
    },
  }
}
