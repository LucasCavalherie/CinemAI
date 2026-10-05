import type { Context } from 'hono'
import { recommendWithFallback } from '../ai/orchestrator'
import { loadConfig, type AppConfig, type ProviderName } from '../config'
import type { Deps } from '../deps'
import type { Env } from '../env'
import { AiUnavailableError, ApiError } from '../lib/errors'
import { RecommendationRequest, type AiPick } from '../schemas'
import { loadExcludeLabels, resolvePicks } from '../tmdb/resolver'

const AI_TIMEOUT_MS = 15000
const MIN_PICKS = 3
const PICKS_REQUESTED = 12

function providerOrder(config: AppConfig, forced: string | undefined): ProviderName[] {
  if (forced === 'anthropic' || forced === 'openai' || forced === 'gemini') return [forced]
  return [config.primary, config.secondary]
}

export async function postRecommendations(c: Context<{ Bindings: Env }>, deps: Deps) {
  const parsed = RecommendationRequest.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) {
    throw new ApiError('invalid_input', parsed.error.issues[0]?.message ?? 'Invalid request', 400)
  }
  const req = parsed.data

  const [config, excludeLabels] = await Promise.all([
    loadConfig(deps.config),
    loadExcludeLabels(deps.cache, req.mediaType, req.excludeTmdbIds),
  ])
  const providers = providerOrder(config, c.req.header('x-ai-provider')).map((name) =>
    deps.provider(name, config.models[name]),
  )

  let picks: AiPick[]
  try {
    ;({ picks } = await recommendWithFallback(
      providers,
      { query: req.query, mediaType: req.mediaType, locale: req.locale, excludeLabels, count: PICKS_REQUESTED },
      { timeoutMs: AI_TIMEOUT_MS, minPicks: MIN_PICKS, log: deps.log },
    ))
  } catch (err) {
    if (err instanceof AiUnavailableError) {
      throw new ApiError('ai_unavailable', 'Recommendation service is temporarily unavailable', 503)
    }
    throw err
  }

  const titles = await resolvePicks(picks, req, { tmdb: deps.tmdb, cache: deps.cache })
  return c.json({ titles, quota: null })
}
