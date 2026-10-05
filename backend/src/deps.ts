import type { AiEvent } from './ai/orchestrator'
import type { RecommendationProvider } from './ai/types'
import type { ProviderName } from './config'
import type { Env } from './env'
import type { KVLike } from './lib/kv'
import type { TmdbClient } from './tmdb/client'

export type Deps = {
  config: KVLike
  cache: KVLike
  tmdb: Pick<TmdbClient, 'search' | 'details'>
  provider(name: ProviderName, model: string): RecommendationProvider
  log(e: AiEvent): void
}

export function createDeps(_env: Env): Deps {
  throw new Error('createDeps is wired in Task 9')
}
