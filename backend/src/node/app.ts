import { Hono } from 'hono'
import { createApp } from '../app'
import type { Deps } from '../deps'
import type { NodeConfig } from './config'
import { createNodeDeps } from './deps'
import { rateLimit, type RateLimitOptions } from './rateLimit'
import type { Sqlite } from './sqlite'

/** App Hono pronto para o servidor Node: a mesma API do Worker + limitação de taxa nas rotas públicas. */
export function createNodeApp(
  cfg: NodeConfig,
  sqlite: Sqlite,
  opts: { rateLimit?: RateLimitOptions } = {},
): { app: Hono; deps: Deps } {
  const deps = createNodeDeps(cfg, sqlite)
  const limiter = rateLimit(opts.rateLimit ?? { max: 30, windowMs: 60_000 })

  const app = new Hono()
  app.use('/v1/devices', limiter)
  app.use('/v1/auth/challenge', limiter)
  app.use('/v1/auth/refresh', limiter)
  app.route('/', createApp(() => deps))
  return { app, deps }
}
