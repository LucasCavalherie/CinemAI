import { Hono } from 'hono'
import type { Deps } from './deps'
import type { Env } from './env'

export function createApp(makeDeps: (env: Env) => Deps) {
  const app = new Hono<{ Bindings: Env }>()
  app.get('/health', (c) => c.json({ ok: true }))
  void makeDeps
  return app
}
