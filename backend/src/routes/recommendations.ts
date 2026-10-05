import type { Context } from 'hono'
import { recommendWithFallback } from '../ai/orchestrator'
import { loadConfig, type AppConfig, type ProviderName } from '../config'
import type { AppEnv } from '../context'
import { AiUnavailableError, ApiError } from '../lib/errors'
import { QuotaExceededError, quotaSnapshot, refundSearch, reserveSearch } from '../quota'
import { RecommendationRequest, type AiPick } from '../schemas'
import { loadExcludeLabels, resolvePicks } from '../tmdb/resolver'

const AI_TIMEOUT_MS = 15000
const MIN_PICKS = 3
const PICKS_REQUESTED = 12

function providerOrder(config: AppConfig, forced: string | undefined): ProviderName[] {
  if (forced === 'anthropic' || forced === 'openai' || forced === 'gemini') return [forced]
  return [config.primary, config.secondary]
}

export async function postRecommendations(c: Context<AppEnv>) {
  const deps = c.get('deps')
  const identity = c.get('identity')

  const parsed = RecommendationRequest.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) {
    throw new ApiError('invalid_input', parsed.error.issues[0]?.message ?? 'Invalid request', 400)
  }
  const req = parsed.data
  const config = await loadConfig(deps.config)

  try {
    await reserveSearch(deps.db, config, identity, deps.now())
  } catch (err) {
    if (err instanceof QuotaExceededError) throw new ApiError('quota_exceeded', 'Daily search limit reached', 402)
    throw err
  }

  // A busca só consome cota se devolver pelo menos 1 título.
  let refunded = false
  const giveBack = async () => {
    if (refunded) return
    refunded = true
    await refundSearch(deps.db, identity, deps.now())
  }

  try {
    const excludeLabels = await loadExcludeLabels(deps.cache, req.mediaType, req.excludeTmdbIds)
    const forced = deps.settings.allowProviderOverride ? c.req.header('x-ai-provider') : undefined
    const providers = providerOrder(config, forced).map((name) => deps.provider(name, config.models[name]))

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
    if (titles.length === 0) await giveBack()
    return c.json({ titles, quota: await quotaSnapshot(deps.db, config, identity, deps.now()) })
  } catch (err) {
    await giveBack()
    throw err
  }
}
