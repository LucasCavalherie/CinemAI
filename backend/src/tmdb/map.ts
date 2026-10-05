import type { MediaType, Provider, Title } from '../schemas'
import type { RawRegionProviders, TmdbDetails } from './types'

function yearOf(date: string | undefined): number | null {
  const y = Number.parseInt((date ?? '').slice(0, 4), 10)
  return Number.isFinite(y) ? y : null
}

function mapProviders(list: RawRegionProviders['flatrate']): Provider[] {
  return [...(list ?? [])]
    .sort((a, b) => a.display_priority - b.display_priority)
    .map((p) => ({ id: p.provider_id, name: p.provider_name, logoPath: p.logo_path }))
}

function originalTitleOf(raw: TmdbDetails, mediaType: MediaType): string {
  return (mediaType === 'movie' ? raw.original_title : raw.original_name) ?? ''
}

export function toTitle(raw: TmdbDetails, mediaType: MediaType, region: string, reason: string): Title {
  const isMovie = mediaType === 'movie'
  const regional = raw['watch/providers']?.results[region]
  return {
    tmdbId: raw.id,
    mediaType,
    title: (isMovie ? raw.title : raw.name) ?? originalTitleOf(raw, mediaType),
    originalTitle: originalTitleOf(raw, mediaType),
    year: yearOf(isMovie ? raw.release_date : raw.first_air_date),
    overview: raw.overview,
    posterPath: raw.poster_path,
    backdropPath: raw.backdrop_path,
    rating: Math.round(raw.vote_average * 10) / 10,
    runtimeMinutes: isMovie ? (raw.runtime ?? null) : null,
    seasons: isMovie ? null : (raw.number_of_seasons ?? null),
    genres: raw.genres.map((g) => g.name),
    reason,
    providers: {
      region,
      link: regional?.link ?? null,
      flatrate: mapProviders(regional?.flatrate),
      rent: mapProviders(regional?.rent),
      buy: mapProviders(regional?.buy),
    },
  }
}

export function labelOf(raw: TmdbDetails, mediaType: MediaType): string {
  const year = yearOf(mediaType === 'movie' ? raw.release_date : raw.first_air_date)
  const title = originalTitleOf(raw, mediaType)
  return year ? `${title} (${year})` : title
}
