import type { ProviderName } from '../config'
import { AiUnavailableError, ProviderError } from '../lib/errors'
import type { AiPick } from '../schemas'
import { PROMPT_VERSION } from './prompt'
import type { PromptInput, RecommendationProvider } from './types'

export type AiEvent = {
  provider: ProviderName
  ok: boolean
  latencyMs: number
  picks: number
  fallback: boolean
  error?: string
  promptVersion: number
}

export async function recommendWithFallback(
  providers: RecommendationProvider[],
  input: PromptInput,
  opts: { timeoutMs: number; minPicks: number; log?: (e: AiEvent) => void },
): Promise<{ picks: AiPick[]; provider: ProviderName }> {
  for (const [index, provider] of providers.entries()) {
    const started = Date.now()
    const fallback = index > 0
    try {
      const picks = await provider.recommend(input, AbortSignal.timeout(opts.timeoutMs))
      if (picks.length < opts.minPicks) {
        throw new ProviderError(`Only ${picks.length} picks`)
      }
      opts.log?.({ provider: provider.name, ok: true, latencyMs: Date.now() - started, picks: picks.length, fallback, promptVersion: PROMPT_VERSION })
      return { picks, provider: provider.name }
    } catch (err) {
      opts.log?.({
        provider: provider.name,
        ok: false,
        latencyMs: Date.now() - started,
        picks: 0,
        fallback,
        error: err instanceof Error ? err.message : String(err),
        promptVersion: PROMPT_VERSION,
      })
    }
  }
  throw new AiUnavailableError()
}
