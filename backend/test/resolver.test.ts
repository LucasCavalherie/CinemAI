import { describe, expect, it, vi } from 'vitest'
import { resolvePicks, TTL_DETAILS } from '../src/tmdb/resolver'
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

  it('caches details (7 days) and reuses them, but does not write search or label entries', async () => {
    const cache = new MemoryKV()
    const tmdb = tmdbStub({ 'A|2014': 1 })
    await resolvePicks([pick('A')], req, { tmdb, cache })
    expect(cache.puts).toEqual([expect.objectContaining({ key: 'tmdb:movie:1:pt-BR', ttl: TTL_DETAILS })])
    tmdb.details.mockClear()
    await resolvePicks([pick('A')], req, { tmdb, cache })
    expect(tmdb.details).not.toHaveBeenCalled()
  })

  it('still resolves when the KV cache cannot be written (daily put limit) or read', async () => {
    const cache = {
      get: async () => {
        throw new Error('KV get() failed')
      },
      put: async () => {
        throw new Error('KV put() limit exceeded for the day.')
      },
    }
    const tmdb = tmdbStub({ 'A|2014': 1, 'B|2014': 2 })
    const titles = await resolvePicks([pick('A'), pick('B')], req, { tmdb, cache })
    expect(titles.map((t) => t.tmdbId)).toEqual([1, 2])
  })

  it('reports why a pick was dropped', async () => {
    const tmdb = tmdbStub({ 'A|2014': 1 })
    const drops: string[] = []
    await resolvePicks([pick('A'), pick('Ghost')], req, { tmdb, cache: new MemoryKV() }, { onDrop: (p, reason) => drops.push(`${p.originalTitle}: ${reason}`) })
    expect(drops).toEqual(['Ghost: not found on TMDB'])
  })
})

