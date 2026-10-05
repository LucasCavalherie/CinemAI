import type { Env } from './env'

export type Deps = Record<string, never>

export function createDeps(_env: Env): Deps {
  return {}
}
