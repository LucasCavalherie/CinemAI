import type { KVLike } from '../lib/kv'
import { mapLimit } from '../lib/mapLimit'
import type { AiPick, MediaType, Title } from '../schemas'
import type { TmdbClient } from './client'
import { toTitle } from './map'
import type { TmdbDetails } from './types'

export const TTL_DETAILS = 60 * 60 * 24 * 7

export type ResolverDeps = { tmdb: Pick<TmdbClient, 'search' | 'details'>; cache: KVLike }

type ResolveRequest = { mediaType: MediaType; locale: string; region: string; excludeTmdbIds: number[] }

async function findId(deps: ResolverDeps, pick: AiPick, req: ResolveRequest): Promise<number | null> {
  const attempts: [string, number | undefined][] = [
    [pick.originalTitle, pick.year],
    [pick.originalTitle, undefined],
    [pick.title, undefined],
  ]
  for (const [query, year] of attempts) {
    const id = await deps.tmdb.search(req.mediaType, query, { year, language: req.locale })
    if (id !== null) return id
  }
  return null
}

/**
 * Cache de detalhes é só otimização: o plano gratuito do KV limita as escritas por dia, e falhar
 * ao ler ou gravar o cache nunca pode derrubar um título.
 */
async function cachedDetails(deps: ResolverDeps, mediaType: MediaType, id: number, locale: string): Promise<TmdbDetails> {
  const key = `tmdb:${mediaType}:${id}:${locale}`
  const hit = await deps.cache.get(key).catch(() => null)
  if (hit) return JSON.parse(hit) as TmdbDetails
  const raw = await deps.tmdb.details(mediaType, id, locale)
  await deps.cache.put(key, JSON.stringify(raw), { expirationTtl: TTL_DETAILS }).catch(() => undefined)
  return raw
}

async function resolveOne(deps: ResolverDeps, pick: AiPick, req: ResolveRequest): Promise<Title | null> {
  const id = await findId(deps, pick, req)
  if (id === null) return null
  const raw = await cachedDetails(deps, req.mediaType, id, req.locale)
  return toTitle(raw, req.mediaType, req.region, pick.reason)
}

export async function resolvePicks(
  picks: AiPick[],
  req: ResolveRequest,
  deps: ResolverDeps,
  opts: { concurrency?: number; max?: number; onDrop?: (pick: AiPick, reason: string) => void } = {},
): Promise<Title[]> {
  const resolved = await mapLimit(picks, opts.concurrency ?? 6, async (pick) => {
    try {
      const title = await resolveOne(deps, pick, req)
      if (!title) opts.onDrop?.(pick, 'not found on TMDB')
      return title
    } catch (err) {
      opts.onDrop?.(pick, err instanceof Error ? err.message : String(err))
      return null
    }
  })
  const seen = new Set(req.excludeTmdbIds)
  const out: Title[] = []
  for (const title of resolved) {
    if (!title || seen.has(title.tmdbId)) continue
    seen.add(title.tmdbId)
    out.push(title)
    if (out.length === (opts.max ?? 12)) break
  }
  return out
}
