import { Hono } from 'hono'
import { z } from 'zod'
import { attachUserToDevice, deleteUserData } from '../account'
import { AppleAuthError } from '../auth/apple'
import { consumeChallenge } from '../auth/challenge'
import type { AppEnv } from '../context'
import { linkDeviceToUser } from '../db/devices'
import { listActiveEntitlements } from '../db/entitlements'
import { getUser, upsertUserByAppleSub } from '../db/users'
import { loadConfig } from '../config'
import { sha256Hex } from '../lib/crypto'
import { ApiError } from '../lib/errors'
import { ownersOf, quotaSnapshot } from '../quota'

export const accountRoutes = new Hono<AppEnv>()

async function profile(c: import('hono').Context<AppEnv>) {
  const deps = c.get('deps')
  const identity = c.get('identity')
  const config = await loadConfig(deps.config)
  return {
    user: identity.userId ? { id: identity.userId } : null,
    entitlements: await listActiveEntitlements(deps.db, ownersOf(identity), Math.floor(deps.now() / 1000)),
    quota: await quotaSnapshot(deps.db, config, identity, deps.now()),
  }
}

const AppleBody = z.object({
  identityToken: z.string().min(1),
  authorizationCode: z.string().min(1),
  challenge: z.string().min(1),
})

accountRoutes.post('/auth/apple', async (c) => {
  const deps = c.get('deps')
  const identity = c.get('identity')
  const parsed = AppleBody.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) throw new ApiError('invalid_input', 'Invalid sign-in body', 400)
  const { identityToken, authorizationCode, challenge } = parsed.data

  // O desafio é consumido antes de validar: uma tentativa falha não pode ser repetida.
  if (!(await consumeChallenge(deps.db, challenge, deps.now()))) {
    throw new ApiError('invalid_challenge', 'Unknown or expired challenge', 400)
  }

  let sub: string
  let appleRefreshToken: string
  try {
    ;({ sub } = await deps.apple.verifyIdentityToken(identityToken, await sha256Hex(challenge)))
    ;({ refreshToken: appleRefreshToken } = await deps.apple.exchangeCode(authorizationCode))
  } catch (err) {
    if (err instanceof AppleAuthError) throw new ApiError('apple_auth_failed', 'Apple sign-in failed', 401)
    throw err
  }

  const user = await upsertUserByAppleSub(deps.db, {
    sub,
    appleRefreshToken,
    nowSec: Math.floor(deps.now() / 1000),
    newId: crypto.randomUUID(),
  })
  await attachUserToDevice(deps.db, identity.deviceId, user.id, deps.now())

  c.set('identity', { deviceId: identity.deviceId, userId: user.id })
  return c.json(await profile(c))
})

accountRoutes.post('/auth/logout', async (c) => {
  const { db } = c.get('deps')
  await linkDeviceToUser(db, c.get('identity').deviceId, null)
  return c.json({ ok: true })
})

accountRoutes.get('/me', async (c) => c.json(await profile(c)))

accountRoutes.delete('/me', async (c) => {
  const deps = c.get('deps')
  const { userId } = c.get('identity')
  if (!userId) throw new ApiError('invalid_input', 'Not signed in', 400)

  const user = await getUser(deps.db, userId)
  if (user?.apple_refresh_token) {
    try {
      await deps.apple.revoke(user.apple_refresh_token)
    } catch (err) {
      if (err instanceof AppleAuthError) {
        throw new ApiError('apple_unavailable', 'Could not revoke the Apple credential; try again', 502)
      }
      throw err
    }
  }
  await deleteUserData(deps.db, userId)
  return c.json({ ok: true })
})
