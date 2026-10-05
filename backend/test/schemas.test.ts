import { describe, expect, it } from 'vitest'
import { AiPicks, RecommendationRequest } from '../src/schemas'

describe('RecommendationRequest', () => {
  it('applies defaults', () => {
    const r = RecommendationRequest.parse({ query: '  algo leve  ', mediaType: 'movie' })
    expect(r).toEqual({ query: 'algo leve', mediaType: 'movie', excludeTmdbIds: [], locale: 'en-US', region: 'US' })
  })

  it('rejects query over 500 chars', () => {
    expect(RecommendationRequest.safeParse({ query: 'a'.repeat(501), mediaType: 'movie' }).success).toBe(false)
  })

  it('rejects more than 200 excluded ids', () => {
    const ids = Array.from({ length: 201 }, (_, i) => i + 1)
    expect(RecommendationRequest.safeParse({ query: 'x', mediaType: 'tv', excludeTmdbIds: ids }).success).toBe(false)
  })

  it('rejects bad locale and region', () => {
    expect(RecommendationRequest.safeParse({ query: 'x', mediaType: 'tv', locale: 'pt' }).success).toBe(false)
    expect(RecommendationRequest.safeParse({ query: 'x', mediaType: 'tv', region: 'bra' }).success).toBe(false)
  })

  it('rejects unknown mediaType', () => {
    expect(RecommendationRequest.safeParse({ query: 'x', mediaType: 'Filmes' }).success).toBe(false)
  })
})

describe('AiPicks', () => {
  it('accepts valid picks', () => {
    const v = { picks: [{ title: 'Interestelar', originalTitle: 'Interstellar', year: 2014, reason: 'Ficção científica emotiva.' }] }
    expect(AiPicks.parse(v)).toEqual(v)
  })

  it('rejects non-integer year', () => {
    const v = { picks: [{ title: 'A', originalTitle: 'A', year: 2014.5, reason: 'r' }] }
    expect(AiPicks.safeParse(v).success).toBe(false)
  })
})
