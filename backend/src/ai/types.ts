import type { ProviderName } from '../config'
import { ProviderError } from '../lib/errors'
import { AiPicks, type AiPick, type MediaType } from '../schemas'

export type PromptInput = {
  query: string
  mediaType: MediaType
  locale: string
  excludeLabels: string[]
  count: number
}

export interface RecommendationProvider {
  name: ProviderName
  recommend(input: PromptInput, signal: AbortSignal): Promise<AiPick[]>
}

export function parsePicks(raw: string): AiPick[] {
  let json: unknown
  try {
    json = JSON.parse(raw)
  } catch {
    throw new ProviderError('Provider returned invalid JSON')
  }
  const result = AiPicks.safeParse(json)
  if (!result.success) throw new ProviderError('Provider output does not match schema')
  return result.data.picks
}
