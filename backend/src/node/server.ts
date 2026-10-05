import { serve } from '@hono/node-server'
import { createNodeApp } from './app'
import { readNodeConfig } from './config'
import { openSqlite } from './sqlite'
import { SqliteKV } from './sqliteKv'

let cfg
try {
  cfg = readNodeConfig(process.env)
} catch (error) {
  console.error(error instanceof Error ? error.message : error)
  process.exit(1)
}

const sqlite = openSqlite(cfg.databasePath)
const { app } = createNodeApp(cfg, sqlite)

// Manutenção: apaga cache expirado e refresh tokens vencidos (o D1 da Cloudflare não precisava disso).
const cache = new SqliteKV(sqlite.raw, 'cache')
const maintenance = setInterval(() => {
  try {
    cache.purgeExpired()
    sqlite.raw.prepare('DELETE FROM refresh_tokens WHERE expires_at <= ?').run(Math.floor(Date.now() / 1000))
  } catch (error) {
    console.error('maintenance failed', error)
  }
}, 60 * 60 * 1000)
maintenance.unref()

const server = serve({ fetch: app.fetch, port: cfg.port }, (info) => {
  console.log(JSON.stringify({ event: 'listening', port: info.port, database: cfg.databasePath }))
})

function shutdown(signal: string) {
  console.log(JSON.stringify({ event: 'shutdown', signal }))
  server.close(() => {
    sqlite.close()
    process.exit(0)
  })
  setTimeout(() => process.exit(1), 10_000).unref()
}
process.on('SIGTERM', () => shutdown('SIGTERM'))
process.on('SIGINT', () => shutdown('SIGINT'))
