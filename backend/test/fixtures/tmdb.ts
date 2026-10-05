import type { TmdbDetails } from '../../src/tmdb/types'

export const interstellar: TmdbDetails = {
  id: 157336,
  title: 'Interestelar',
  original_title: 'Interstellar',
  release_date: '2014-11-05',
  runtime: 169,
  overview: 'As reservas naturais da Terra estão chegando ao fim...',
  poster_path: '/poster.jpg',
  backdrop_path: '/backdrop.jpg',
  vote_average: 8.456,
  genres: [{ id: 12, name: 'Aventura' }, { id: 878, name: 'Ficção científica' }],
  'watch/providers': {
    results: {
      BR: {
        link: 'https://www.themoviedb.org/movie/157336/watch?locale=BR',
        flatrate: [
          { provider_id: 384, provider_name: 'Max', logo_path: '/max.jpg', display_priority: 5 },
          { provider_id: 119, provider_name: 'Prime Video', logo_path: '/prime.jpg', display_priority: 1 },
        ],
        rent: [{ provider_id: 2, provider_name: 'Apple TV', logo_path: '/apple.jpg', display_priority: 3 }],
        ads: [{ provider_id: 300, provider_name: 'Pluto TV', logo_path: '/pluto.jpg', display_priority: 7 }],
        free: [
          { provider_id: 73, provider_name: 'Tubi', logo_path: '/tubi.jpg', display_priority: 2 },
          { provider_id: 300, provider_name: 'Pluto TV', logo_path: '/pluto.jpg', display_priority: 7 },
        ],
      },
      US: { link: 'https://example.com/us', buy: [{ provider_id: 2, provider_name: 'Apple TV', logo_path: '/apple.jpg', display_priority: 3 }] },
    },
  },
}

export const darkSeries: TmdbDetails = {
  id: 70523,
  name: 'Dark',
  original_name: 'Dark',
  first_air_date: '2017-12-01',
  number_of_seasons: 3,
  overview: 'Uma criança desaparece...',
  poster_path: '/dark.jpg',
  backdrop_path: null,
  vote_average: 8.4,
  genres: [{ id: 18, name: 'Drama' }],
  'watch/providers': { results: {} },
}
