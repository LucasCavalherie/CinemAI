import { describe, expect, it } from 'vitest'
import { DEFAULT_CONFIG, loadConfig } from '../src/config'
import { MemoryKV } from './helpers/memoryKV'

describe('loadConfig', () => {
  it('returns defaults when KV is empty', async () => {
    expect(await loadConfig(new MemoryKV())).toEqual(DEFAULT_CONFIG)
  })

  it('reads overrides from KV', async () => {
    const kv = new MemoryKV({ 'ai.primary': 'openai', 'ai.models.anthropic': 'claude-x', 'ai.models.openai': 'gpt-y' })
    expect(await loadConfig(kv)).toEqual({ primary: 'openai', models: { anthropic: 'claude-x', openai: 'gpt-y' } })
  })

  it('falls back to anthropic for an invalid primary', async () => {
    const kv = new MemoryKV({ 'ai.primary': 'gemini' })
    expect((await loadConfig(kv)).primary).toBe('anthropic')
  })
})
