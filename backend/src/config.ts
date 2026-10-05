import type { KVLike } from './lib/kv'

export type ProviderName = 'anthropic' | 'openai' | 'gemini'

export type AppConfig = {
  primary: ProviderName
  secondary: ProviderName
  models: Record<ProviderName, string>
  limits: { free: number; pro: number }
}

export const DEFAULT_CONFIG: AppConfig = {
  primary: 'gemini',
  secondary: 'anthropic',
  models: { anthropic: 'claude-haiku-4-5', openai: 'gpt-5-mini', gemini: 'gemini-3.5-flash-lite' },
  limits: { free: 5, pro: 100 },
}

const isProvider = (v: string | null): v is ProviderName => v === 'anthropic' || v === 'openai' || v === 'gemini'

function positiveInt(value: string | null, fallback: number): number {
  const n = Number.parseInt(value ?? '', 10)
  return Number.isFinite(n) && n >= 1 ? n : fallback
}

export async function loadConfig(kv: KVLike): Promise<AppConfig> {
  const [primary, secondary, anthropic, openai, gemini, freeLimit, proLimit] = await Promise.all([
    kv.get('ai.primary'),
    kv.get('ai.secondary'),
    kv.get('ai.models.anthropic'),
    kv.get('ai.models.openai'),
    kv.get('ai.models.gemini'),
    kv.get('limits.free.daily'),
    kv.get('limits.pro.daily'),
  ])
  const p = isProvider(primary) ? primary : DEFAULT_CONFIG.primary
  const fallbackDefault: ProviderName = p === 'gemini' ? 'anthropic' : DEFAULT_CONFIG.primary
  const s = isProvider(secondary) && secondary !== p ? secondary : fallbackDefault
  return {
    primary: p,
    secondary: s,
    models: {
      anthropic: anthropic ?? DEFAULT_CONFIG.models.anthropic,
      openai: openai ?? DEFAULT_CONFIG.models.openai,
      gemini: gemini ?? DEFAULT_CONFIG.models.gemini,
    },
    limits: {
      free: positiveInt(freeLimit, DEFAULT_CONFIG.limits.free),
      pro: positiveInt(proLimit, DEFAULT_CONFIG.limits.pro),
    },
  }
}
