import { describe, expect, it } from 'vitest'
import { DEFAULT_CONFIG, loadConfig } from '../src/config'
import { MemoryKV } from './helpers/memoryKV'

describe('loadConfig', () => {
  it('returns defaults when KV is empty', async () => {
    expect(await loadConfig(new MemoryKV())).toEqual(DEFAULT_CONFIG)
    expect(DEFAULT_CONFIG.primary).toBe('gemini')
    expect(DEFAULT_CONFIG.secondary).toBe('anthropic')
  })

  it('reads overrides from KV', async () => {
    const kv = new MemoryKV({
      'ai.primary': 'gemini',
      'ai.secondary': 'openai',
      'ai.models.anthropic': 'claude-x',
      'ai.models.openai': 'gpt-y',
      'ai.models.gemini': 'gem-z',
    })
    expect(await loadConfig(kv)).toEqual({
      primary: 'gemini',
      secondary: 'openai',
      models: { anthropic: 'claude-x', openai: 'gpt-y', gemini: 'gem-z' },
    })
  })

  it('falls back to gemini for an invalid primary', async () => {
    const kv = new MemoryKV({ 'ai.primary': 'mistral' })
    expect((await loadConfig(kv)).primary).toBe('gemini')
  })

  it('derives a different secondary when none is set', async () => {
    expect((await loadConfig(new MemoryKV({ 'ai.primary': 'gemini' }))).secondary).toBe('anthropic')
    expect((await loadConfig(new MemoryKV({ 'ai.primary': 'openai' }))).secondary).toBe('gemini')
    expect((await loadConfig(new MemoryKV({ 'ai.primary': 'anthropic' }))).secondary).toBe('gemini')
  })

  it('ignores a secondary equal to the primary', async () => {
    const kv = new MemoryKV({ 'ai.primary': 'gemini', 'ai.secondary': 'gemini' })
    expect((await loadConfig(kv)).secondary).toBe('anthropic')
  })
})
