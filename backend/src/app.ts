import { Hono } from 'hono'
import type { Deps } from './deps'
import type { Env } from './env'
import { ApiError, errorBody } from './lib/errors'
import { postRecommendations } from './routes/recommendations'

export function createApp(makeDeps: (env: Env) => Deps) {
  const app = new Hono<{ Bindings: Env }>()

  app.get('/health', (c) => c.json({ ok: true }))

  // Fatia 1: proteção temporária até App Attest/SIWA (Fatia 3).
  app.use('/v1/*', async (c, next) => {
    if (!c.env.DEV_API_KEY || c.req.header('x-dev-key') !== c.env.DEV_API_KEY) {
      throw new ApiError('unauthorized', 'Missing or invalid credentials', 401)
    }
    await next()
  })

  app.post('/v1/recommendations', (c) => postRecommendations(c, makeDeps(c.env)))

  app.onError((err, c) => {
    if (err instanceof ApiError) return c.json(errorBody(err.code, err.message), err.status)
    console.error(err)
    return c.json(errorBody('internal', 'Unexpected error'), 500)
  })

  return app
}
