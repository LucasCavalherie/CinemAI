import type OpenAI from 'openai'
import { ProviderError } from '../lib/errors'
import { AI_PICKS_JSON_SCHEMA } from '../schemas'
import { buildSystemPrompt, buildUserMessage } from './prompt'
import { parsePicks, type RecommendationProvider } from './types'

export type OpenAILike = Pick<OpenAI, 'chat'>

export function createOpenAIProvider(client: OpenAILike, model: string): RecommendationProvider {
  return {
    name: 'openai',
    async recommend(input, signal) {
      const res = await client.chat.completions.create(
        {
          model,
          messages: [
            { role: 'system', content: buildSystemPrompt() },
            { role: 'user', content: buildUserMessage(input) },
          ],
          response_format: {
            type: 'json_schema',
            json_schema: { name: 'recommendations', strict: true, schema: AI_PICKS_JSON_SCHEMA },
          },
        },
        { signal },
      )
      const choice = res.choices[0]
      if (!choice) throw new ProviderError('OpenAI returned no choices')
      if (choice.message.refusal) throw new ProviderError('OpenAI refused')
      if (choice.finish_reason !== 'stop') throw new ProviderError(`OpenAI finish_reason: ${choice.finish_reason}`)
      if (!choice.message.content) throw new ProviderError('OpenAI returned empty content')
      return parsePicks(choice.message.content)
    },
  }
}
