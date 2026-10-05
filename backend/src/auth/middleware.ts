import { createMiddleware } from 'hono/factory'
import type { AppEnv } from '../context'
import { getDevice } from '../db/devices'
import { ApiError } from '../lib/errors'

/** Exige `Authorization: Bearer <accessToken>`; o usuário vem do banco (logout/exclusão valem na hora). */
export const requireAuth = createMiddleware<AppEnv>(async (c, next) => {
  const { tokens, db } = c.get('deps')
  const header = c.req.header('authorization') ?? ''
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : ''
  if (!token) throw new ApiError('unauthorized', 'Missing credentials', 401)

  const { deviceId } = await tokens.verifyAccess(token)
  const device = await getDevice(db, deviceId)
  if (!device) throw new ApiError('unauthorized', 'Unknown device', 401)

  c.set('identity', { deviceId, userId: device.user_id })
  await next()
})
