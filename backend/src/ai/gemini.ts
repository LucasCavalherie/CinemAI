import { ProviderError } from '../lib/errors'
import { AI_PICKS_JSON_SCHEMA } from '../schemas'
import type { FetchLike } from '../tmdb/client'
import { buildSystemPrompt, buildUserMessage } from './prompt'
import { parsePicks, type RecommendationProvider } from './types'

type GeminiResponse = {
  promptFeedback?: { blockReason?: string }
  candidates?: { finishReason?: string; content?: { parts?: { text?: string; thought?: boolean }[] } }[]
}

export function createGeminiProvider(opts: {
  apiKey: string
  baseUrl: string
  model: string
  fetchFn?: FetchLike
  extraHeaders?: Record<string, string>
}): RecommendationProvider {
  // Wrapper evita "Illegal invocation" ao chamar o fetch global desacoplado no Workers.
  const fetchFn: FetchLike = opts.fetchFn ?? ((url, init) => fetch(url, init))
  return {
    name: 'gemini',
    async recommend(input, signal) {
      const res = await fetchFn(`${opts.baseUrl}/v1beta/models/${opts.model}:generateContent`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': opts.apiKey, ...opts.extraHeaders },
        signal,
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: buildSystemPrompt() }] },
          contents: [{ role: 'user', parts: [{ text: buildUserMessage(input) }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            responseJsonSchema: AI_PICKS_JSON_SCHEMA,
            maxOutputTokens: 4000,
          },
        }),
      })
      if (!res.ok) throw new ProviderError(`Gemini responded ${res.status}`)
      const data = (await res.json()) as GeminiResponse
      if (data.promptFeedback?.blockReason) throw new ProviderError(`Gemini blocked: ${data.promptFeedback.blockReason}`)
      const candidate = data.candidates?.[0]
      if (!candidate) throw new ProviderError('Gemini returned no candidates')
      if (candidate.finishReason !== 'STOP') throw new ProviderError(`Gemini finishReason: ${candidate.finishReason}`)
      const text = (candidate.content?.parts ?? []).filter((p) => !p.thought && p.text).map((p) => p.text).join('')
      if (!text) throw new ProviderError('Gemini returned empty content')
      return parsePicks(text)
    },
  }
}
