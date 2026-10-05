import type { Env } from '../env'

export type NodeConfig = {
  port: number
  databasePath: string
  /** Mesmos nomes de variáveis do Worker, já validados e normalizados. */
  env: Env
  /** Ajustes de runtime vindos do ambiente, gravados no "KV de config" ao subir. */
  seed: Record<string, string>
}

const SEED_VARS: Record<string, string> = {
  AI_PRIMARY: 'ai.primary',
  AI_SECONDARY: 'ai.secondary',
  AI_MODEL_ANTHROPIC: 'ai.models.anthropic',
  AI_MODEL_OPENAI: 'ai.models.openai',
  AI_MODEL_GEMINI: 'ai.models.gemini',
  LIMIT_FREE_DAILY: 'limits.free.daily',
  LIMIT_PRO_DAILY: 'limits.pro.daily',
}

export function readNodeConfig(source: Record<string, string | undefined>): NodeConfig {
  const get = (key: string) => source[key]?.trim() || undefined
  const problems: string[] = []

  const jwtSecret = get('JWT_SECRET')
  if (!jwtSecret || jwtSecret.length < 32) problems.push('JWT_SECRET (required, at least 32 characters)')
  if (!get('TMDB_TOKEN')) problems.push('TMDB_TOKEN (required)')
  if (!get('APPLE_TEAM_ID')) problems.push('APPLE_TEAM_ID (required)')
  if (!get('APPLE_BUNDLE_ID')) problems.push('APPLE_BUNDLE_ID (required)')
  if (!get('ANTHROPIC_API_KEY') && !get('GEMINI_API_KEY') && !get('OPENAI_API_KEY')) {
    problems.push('AI provider key (set at least one of ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENAI_API_KEY)')
  }
  const port = get('PORT') === undefined ? 3000 : Number(get('PORT'))
  if (!Number.isInteger(port) || port < 1 || port > 65535) problems.push('PORT (must be an integer between 1 and 65535)')
  if (problems.length > 0) throw new Error(`Invalid configuration:\n - ${problems.join('\n - ')}`)

  const seed: Record<string, string> = {}
  for (const [variable, key] of Object.entries(SEED_VARS)) {
    const value = get(variable)
    if (value !== undefined) seed[key] = value
  }

  const env = {
    ANTHROPIC_API_KEY: get('ANTHROPIC_API_KEY') ?? '',
    OPENAI_API_KEY: get('OPENAI_API_KEY'),
    GEMINI_API_KEY: get('GEMINI_API_KEY'),
    TMDB_TOKEN: get('TMDB_TOKEN')!,
    JWT_SECRET: jwtSecret!,
    APPLE_TEAM_ID: get('APPLE_TEAM_ID')!,
    APPLE_KEY_ID: get('APPLE_KEY_ID') ?? '',
    APPLE_BUNDLE_ID: get('APPLE_BUNDLE_ID')!,
    // Variáveis de uma linha só (comuns em painéis de deploy) trazem "\n" literal no lugar das quebras.
    APPLE_PRIVATE_KEY: (get('APPLE_PRIVATE_KEY') ?? '').replace(/\\n/g, '\n'),
    ALLOW_UNATTESTED: get('ALLOW_UNATTESTED') ?? 'false',
    ALLOW_PROVIDER_OVERRIDE: get('ALLOW_PROVIDER_OVERRIDE') ?? 'false',
    APPATTEST_ENVS: get('APPATTEST_ENVS') ?? 'production',
  } as unknown as Env

  return { port, databasePath: get('DATABASE_PATH') ?? '/data/filmfinder.db', env, seed }
}
