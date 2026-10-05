import { createMiddleware } from 'hono/factory'
import { errorBody } from '../lib/errors'

export type RateLimitOptions = { max: number; windowMs: number }

/** IP do cliente atrás do proxy (Traefik/Dokploy envia X-Forwarded-For). */
export function clientIp(headers: Headers): string {
  return headers.get('x-forwarded-for')?.split(',')[0]?.trim() || headers.get('x-real-ip') || 'unknown'
}

/** Limitador em memória por IP (janela fixa). Protege as rotas públicas de abuso sem a Cloudflare na frente. */
export function rateLimit({ max, windowMs }: RateLimitOptions, nowMs: () => number = Date.now) {
  const hits = new Map<string, { count: number; resetAt: number }>()
  return createMiddleware(async (c, next) => {
    const now = nowMs()
    if (hits.size > 10_000) for (const [ip, h] of hits) if (h.resetAt <= now) hits.delete(ip)

    const ip = clientIp(c.req.raw.headers)
    const entry = hits.get(ip)
    if (!entry || entry.resetAt <= now) {
      hits.set(ip, { count: 1, resetAt: now + windowMs })
    } else if (entry.count >= max) {
      c.header('retry-after', String(Math.max(1, Math.ceil((entry.resetAt - now) / 1000))))
      return c.json(errorBody('rate_limited', 'Too many requests'), 429)
    } else {
      entry.count++
    }
    await next()
  })
}
