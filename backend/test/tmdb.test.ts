import { describe, expect, it, vi } from 'vitest'
import { TmdbClient, TmdbError } from '../src/tmdb/client'
import { labelOf, toTitle } from '../src/tmdb/map'
import { darkSeries, interstellar } from './fixtures/tmdb'

function fakeFetch(body: unknown, status = 200) {
  return vi.fn(async (_url: string, _init?: RequestInit) => new Response(JSON.stringify(body), { status }))
}

describe('TmdbClient.search', () => {
  it('builds a movie search URL with year and auth header', async () => {
    const fetchFn = fakeFetch({ results: [{ id: 157336 }, { id: 1 }] })
    const id = await new TmdbClient('tok', fetchFn).search('movie', 'Interstellar', { year: 2014, language: 'pt-BR' })
    expect(id).toBe(157336)
    const [url, init] = fetchFn.mock.calls[0]!
    const u = new URL(url)
    expect(u.pathname).toBe('/3/search/movie')
    expect(u.searchParams.get('query')).toBe('Interstellar')
    expect(u.searchParams.get('year')).toBe('2014')
    expect(u.searchParams.get('language')).toBe('pt-BR')
    expect(u.searchParams.get('include_adult')).toBe('false')
    expect((init?.headers as Record<string, string>).Authorization).toBe('Bearer tok')
  })

  it('uses first_air_date_year for tv and omits year when absent', async () => {
    const fetchFn = fakeFetch({ results: [] })
    const client = new TmdbClient('tok', fetchFn)
    expect(await client.search('tv', 'Dark', { year: 2017, language: 'en-US' })).toBeNull()
    expect(new URL(fetchFn.mock.calls[0]![0]).searchParams.get('first_air_date_year')).toBe('2017')
    await client.search('tv', 'Dark', { language: 'en-US' })
    expect(new URL(fetchFn.mock.calls[1]![0]).searchParams.has('first_air_date_year')).toBe(false)
  })

  it('throws TmdbError on non-2xx', async () => {
    const client = new TmdbClient('tok', fakeFetch({}, 429))
    await expect(client.search('movie', 'x', { language: 'en-US' })).rejects.toBeInstanceOf(TmdbError)
  })
})

describe('TmdbClient.details', () => {
  it('appends watch/providers', async () => {
    const fetchFn = fakeFetch(interstellar)
    const d = await new TmdbClient('tok', fetchFn).details('movie', 157336, 'pt-BR')
    expect(d.id).toBe(157336)
    const u = new URL(fetchFn.mock.calls[0]![0])
    expect(u.pathname).toBe('/3/movie/157336')
    expect(u.searchParams.get('append_to_response')).toBe('watch/providers')
  })
})

describe('toTitle', () => {
  it('maps a movie with providers for the region, sorted by priority', () => {
    const t = toTitle(interstellar, 'movie', 'BR', 'Porque sim.')
    expect(t).toMatchObject({
      tmdbId: 157336,
      mediaType: 'movie',
      title: 'Interestelar',
      originalTitle: 'Interstellar',
      year: 2014,
      rating: 8.5,
      runtimeMinutes: 169,
      seasons: null,
      genres: ['Aventura', 'Ficção científica'],
      reason: 'Porque sim.',
    })
    expect(t.providers.region).toBe('BR')
    expect(t.providers.link).toBe('https://www.themoviedb.org/movie/157336/watch?locale=BR')
    expect(t.providers.flatrate.map((p) => p.name)).toEqual(['Prime Video', 'Max'])
    expect(t.providers.rent).toEqual([{ id: 2, name: 'Apple TV', logoPath: '/apple.jpg' }])
    expect(t.providers.buy).toEqual([])
  })

  it('maps a series and handles a region without providers', () => {
    const t = toTitle(darkSeries, 'tv', 'BR', 'r')
    expect(t).toMatchObject({ title: 'Dark', year: 2017, seasons: 3, runtimeMinutes: null, backdropPath: null })
    expect(t.providers).toEqual({ region: 'BR', link: null, flatrate: [], rent: [], buy: [] })
  })
})

describe('labelOf', () => {
  it('uses original title and year', () => {
    expect(labelOf(interstellar, 'movie')).toBe('Interstellar (2014)')
    expect(labelOf({ ...darkSeries, first_air_date: '' }, 'tv')).toBe('Dark')
  })
})
