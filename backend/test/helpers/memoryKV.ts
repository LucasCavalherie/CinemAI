import type { KVLike } from '../../src/lib/kv'

export class MemoryKV implements KVLike {
  readonly store = new Map<string, string>()
  readonly puts: { key: string; value: string; ttl?: number }[] = []

  constructor(initial: Record<string, string> = {}) {
    for (const [k, v] of Object.entries(initial)) this.store.set(k, v)
  }

  async get(key: string) {
    return this.store.get(key) ?? null
  }

  async put(key: string, value: string, options?: { expirationTtl?: number }) {
    this.store.set(key, value)
    this.puts.push({ key, value, ttl: options?.expirationTtl })
  }
}
