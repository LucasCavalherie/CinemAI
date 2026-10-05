import type Anthropic from '@anthropic-ai/sdk'
import { ProviderError } from '../lib/errors'
import { AI_PICKS_JSON_SCHEMA } from '../schemas'
import { buildSystemPrompt, buildUserMessage } from './prompt'
import { parsePicks, type RecommendationProvider } from './types'

export type AnthropicLike = Pick<Anthropic, 'messages'>

export function createAnthropicProvider(client: AnthropicLike, model: string): RecommendationProvider {
  return {
    name: 'anthropic',
    async recommend(input, signal) {
      const res = await client.messages.create(
        {
          model,
          max_tokens: 4000,
          system: buildSystemPrompt(),
          messages: [{ role: 'user', content: buildUserMessage(input) }],
          output_config: { format: { type: 'json_schema', schema: AI_PICKS_JSON_SCHEMA } },
        },
        { signal },
      )
      if (res.stop_reason !== 'end_turn') {
        throw new ProviderError(`Anthropic stop_reason: ${res.stop_reason}`)
      }
      const block = res.content.find((b) => b.type === 'text')
      if (!block || block.type !== 'text') throw new ProviderError('Anthropic returned no text block')
      return parsePicks(block.text)
    },
  }
}
