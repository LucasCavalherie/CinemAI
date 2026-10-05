import type { MediaType } from '../schemas'
import type { TmdbDetails } from './types'

export type FetchLike = (url: string, init?: RequestInit) => Promise<Response>

export class TmdbError extends Error {
  override name = 'TmdbError'
  constructor(readonly status: number) {
    super(`TMDB responded ${status}`)
  }
}

const BASE = 'https://api.themoviedb.org/3'

export class TmdbClient {
  constructor(
    private readonly token: string,
    // Wrapper evita "Illegal invocation" ao chamar o fetch global desacoplado no Workers.
    private readonly fetchFn: FetchLike = (url, init) => fetch(url, init),
  ) {}

  private async get<T>(path: string, params: Record<string, string>): Promise<T> {
    const url = new URL(BASE + path)
    for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v)
    const res = await this.fetchFn(url.toString(), {
      headers: { Authorization: `Bearer ${this.token}`, accept: 'application/json' },
    })
    if (!res.ok) throw new TmdbError(res.status)
    return (await res.json()) as T
  }

  async search(mediaType: MediaType, query: string, opts: { year?: number; language: string }): Promise<number | null> {
    const params: Record<string, string> = { query, language: opts.language, include_adult: 'false', page: '1' }
    if (opts.year) params[mediaType === 'movie' ? 'year' : 'first_air_date_year'] = String(opts.year)
    const data = await this.get<{ results: { id: number }[] }>(`/search/${mediaType}`, params)
    return data.results[0]?.id ?? null
  }

  details(mediaType: MediaType, id: number, language: string): Promise<TmdbDetails> {
    return this.get<TmdbDetails>(`/${mediaType}/${id}`, { language, append_to_response: 'watch/providers' })
  }
}
