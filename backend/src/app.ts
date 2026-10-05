import { Hono } from 'hono'
import { requireAuth } from './auth/middleware'
import type { AppEnv } from './context'
import type { Deps } from './deps'
import type { Env } from './env'
import { ApiError, errorBody } from './lib/errors'
import { publicAuthRoutes } from './routes/publicAuth'
import { postRecommendations } from './routes/recommendations'

export function createApp(makeDeps: (env: Env) => Deps) {
  const app = new Hono<AppEnv>()

  app.use('*', async (c, next) => {
    c.set('deps', makeDeps(c.env))
    await next()
  })

  app.get('/health', (c) => c.json({ ok: true }))

  // Rotas públicas (sem token): desafio, registro de dispositivo e renovação.
  app.route('/v1', publicAuthRoutes)

  const authed = new Hono<AppEnv>()
  authed.use('*', requireAuth)
  authed.post('/recommendations', postRecommendations)
  // Rotas de conta entram aqui (Task BE-8).
  app.route('/v1', authed)

  app.onError((err, c) => {
    if (err instanceof ApiError) return c.json(errorBody(err.code, err.message), err.status)
    console.error(err)
    return c.json(errorBody('internal', 'Unexpected error'), 500)
  })

  return app
}
