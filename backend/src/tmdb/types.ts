type RawProvider = { provider_id: number; provider_name: string; logo_path: string; display_priority: number }

export type RawRegionProviders = {
  link?: string
  flatrate?: RawProvider[]
  rent?: RawProvider[]
  buy?: RawProvider[]
}

export type TmdbDetails = {
  id: number
  // filmes
  title?: string
  original_title?: string
  release_date?: string
  runtime?: number | null
  // séries
  name?: string
  original_name?: string
  first_air_date?: string
  number_of_seasons?: number | null
  // ambos
  overview: string
  poster_path: string | null
  backdrop_path: string | null
  vote_average: number
  genres: { id: number; name: string }[]
  'watch/providers'?: { results: Record<string, RawRegionProviders> }
}
