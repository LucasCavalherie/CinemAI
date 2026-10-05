import { z } from 'zod'

export const MediaType = z.enum(['movie', 'tv'])
export type MediaType = z.infer<typeof MediaType>

export const RecommendationRequest = z.object({
  query: z.string().trim().min(1).max(500),
  mediaType: MediaType,
  excludeTmdbIds: z.array(z.number().int().positive()).max(200).default([]),
  locale: z.string().regex(/^[a-z]{2}-[A-Z]{2}$/).default('en-US'),
  region: z.string().regex(/^[A-Z]{2}$/).default('US'),
})
export type RecommendationRequest = z.infer<typeof RecommendationRequest>

export const AiPick = z.object({
  title: z.string().min(1),
  originalTitle: z.string().min(1),
  year: z.number().int().min(1888).max(2100),
  reason: z.string().min(1).max(300),
})
export type AiPick = z.infer<typeof AiPick>

export const AiPicks = z.object({ picks: z.array(AiPick) })

// Mesmo contrato do Zod acima, no formato aceito por ambos os provedores
// (OpenAI strict exige additionalProperties:false e todos os campos em required).
export const AI_PICKS_JSON_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['picks'],
  properties: {
    picks: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'originalTitle', 'year', 'reason'],
        properties: {
          title: { type: 'string' },
          originalTitle: { type: 'string' },
          year: { type: 'integer' },
          reason: { type: 'string' },
        },
      },
    },
  },
} as const

export type Provider = { id: number; name: string; logoPath: string }

export type Title = {
  tmdbId: number
  mediaType: MediaType
  title: string
  originalTitle: string
  year: number | null
  overview: string
  posterPath: string | null
  backdropPath: string | null
  rating: number
  runtimeMinutes: number | null
  seasons: number | null
  genres: string[]
  reason: string
  providers: {
    region: string
    link: string | null
    flatrate: Provider[]
    rent: Provider[]
    buy: Provider[]
  }
}
