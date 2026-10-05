import { describe, expect, it, vi } from 'vitest'
import { loadExcludeLabels, resolvePicks, TTL_DETAILS, TTL_LABEL, TTL_SEARCH } from '../src/tmdb/resolver'
import type { TmdbDetails } from '../src/tmdb/types'
import type { AiPick } from '../src/schemas'
import { interstellar } from './fixtures/tmdb'
import { MemoryKV } from './helpers/memoryKV'

const req = { mediaType: 'movie' as const, locale: 'pt-BR', region: 'BR', excludeTmdbIds: [] as number[] }
const pick = (originalTitle: string, year = 2014, title = originalTitle): AiPick => ({ title, originalTitle, year, reason: `por ${originalTitle}` })
const detailsFor = (id: number, original = `Movie ${id}`): TmdbDetails => ({ ...interstellar, id, original_title: original, title: original })

function tmdbStub(searchTable: Record<string, number | null>) {
  const search = vi.fn(async (_m: string, query: string, opts: { year?: number }) => {
    return searchTable[`${query}|${opts.year ?? ''}`] ?? null
  })
  const details = vi.fn(async (_m: string, id: number) => detailsFor(id))
  return { search, details }
}

describe('resolvePicks', () => {
  it('resolves picks in AI order with reason and region providers', async () => {
    const tmdb = tmdbStub({ 'A|2014': 1, 'B|2014': 2 })
    const titles = await resolvePicks([pick('A'), pick('B')], req, { tmdb, cache: new MemoryKV() })
    expect(titles.map((t) => t.tmdbId)).toEqual([1, 2])
    expect(titles[0]?.reason).toBe('por A')
    expect(titles[0]?.providers.region).toBe('BR')
  })

  it('cascades: without year, then localized title, then drops', async () => {
    const tmdb = tmdbStub({ 'NoYear|': 10, 'Localizado|': 11 })
    const titles = await resolvePicks(
      [pick('NoYear'), pick('Original', 2014, 'Localizado'), pick('Ghost')],
      req,
      { tmdb, cache: new MemoryKV() },
    )
    expect(titles.map((t) => t.tmdbId)).toEqual([10, 11])
  })

  it('filters excluded ids and duplicates, and caps at max', async () => {
    const tmdb = tmdbStub({ 'A|2014': 1, 'B|2014': 2, 'C|2014': 2, 'D|2014': 3, 'E|2014': 4 })
    const titles = await resolvePicks(
      [pick('A'), pick('B'), pick('C'), pick('D'), pick('E')],
      { ...req, excludeTmdbIds: [1] },
      { tmdb, cache: new MemoryKV() },
      { max: 2 },
    )
    expect(titles.map((t) => t.tmdbId)).toEqual([2, 3])
  })

  it('drops a pick when TMDB throws instead of failing the batch', async () => {
    const tmdb = tmdbStub({ 'A|2014': 1, 'B|2014': 2 })
    tmdb.details.mockImplementationOnce(async () => {
      throw new Error('429')
    })
    const titles = await resolvePicks([pick('A'), pick('B')], req, { tmdb, cache: new MemoryKV() })
    expect(titles).toHaveLength(1)
  })

  it('writes search, details and label cache with TTLs, and reuses them', async () => {
    const cache = new MemoryKV()
    const tmdb = tmdbStub({ 'A|2014': 1 })
    await resolvePicks([pick('A')], req, { tmdb, cache })
    expect(cache.puts).toEqual(
      expect.arrayContaining([
        { key: 'search:movie:a:2014', value: '1', ttl: TTL_SEARCH },
        expect.objectContaining({ key: 'tmdb:movie:1:pt-BR', ttl: TTL_DETAILS }),
        { key: 'label:movie:1', value: 'Movie 1 (2014)', ttl: TTL_LABEL },
      ]),
    )
    tmdb.search.mockClear()
    tmdb.details.mockClear()
    await resolvePicks([pick('A')], req, { tmdb, cache })
    expect(tmdb.search).not.toHaveBeenCalled()
    expect(tmdb.details).not.toHaveBeenCalled()
  })
})

describe('loadExcludeLabels', () => {
  it('returns labels that exist in cache, skipping unknown ids', async () => {
    const cache = new MemoryKV({ 'label:movie:1': 'Up (2009)', 'label:tv:2': 'Dark (2017)' })
    expect(await loadExcludeLabels(cache, 'movie', [1, 2, 3])).toEqual(['Up (2009)'])
  })
})
