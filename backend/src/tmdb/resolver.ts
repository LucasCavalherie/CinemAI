import type { KVLike } from '../lib/kv'
import { mapLimit } from '../lib/mapLimit'
import type { AiPick, MediaType, Title } from '../schemas'
import type { TmdbClient } from './client'
import { labelOf, toTitle } from './map'
import type { TmdbDetails } from './types'

export const TTL_SEARCH = 60 * 60 * 24 * 30
export const TTL_DETAILS = 60 * 60 * 24 * 7
export const TTL_LABEL = 60 * 60 * 24 * 365

export type ResolverDeps = { tmdb: Pick<TmdbClient, 'search' | 'details'>; cache: KVLike }

type ResolveRequest = { mediaType: MediaType; locale: string; region: string; excludeTmdbIds: number[] }

async function cachedSearch(deps: ResolverDeps, mediaType: MediaType, query: string, year: number | undefined, language: string) {
  const key = `search:${mediaType}:${query.trim().toLowerCase().slice(0, 200)}:${year ?? ''}`
  const hit = await deps.cache.get(key)
  if (hit) return Number(hit)
  const id = await deps.tmdb.search(mediaType, query, { year, language })
  if (id !== null) await deps.cache.put(key, String(id), { expirationTtl: TTL_SEARCH })
  return id
}

async function findId(deps: ResolverDeps, pick: AiPick, req: ResolveRequest): Promise<number | null> {
  const attempts: [string, number | undefined][] = [
    [pick.originalTitle, pick.year],
    [pick.originalTitle, undefined],
    [pick.title, undefined],
  ]
  for (const [query, year] of attempts) {
    const id = await cachedSearch(deps, req.mediaType, query, year, req.locale)
    if (id !== null) return id
  }
  return null
}

async function cachedDetails(deps: ResolverDeps, mediaType: MediaType, id: number, locale: string): Promise<TmdbDetails> {
  const key = `tmdb:${mediaType}:${id}:${locale}`
  const hit = await deps.cache.get(key)
  if (hit) return JSON.parse(hit) as TmdbDetails
  const raw = await deps.tmdb.details(mediaType, id, locale)
  await Promise.all([
    deps.cache.put(key, JSON.stringify(raw), { expirationTtl: TTL_DETAILS }),
    deps.cache.put(`label:${mediaType}:${id}`, labelOf(raw, mediaType), { expirationTtl: TTL_LABEL }),
  ])
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
  opts: { concurrency?: number; max?: number } = {},
): Promise<Title[]> {
  const resolved = await mapLimit(picks, opts.concurrency ?? 6, (pick) => resolveOne(deps, pick, req).catch(() => null))
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

export async function loadExcludeLabels(cache: KVLike, mediaType: MediaType, ids: number[]): Promise<string[]> {
  const labels = await Promise.all(ids.map((id) => cache.get(`label:${mediaType}:${id}`)))
  return labels.filter((l): l is string => l !== null)
}
