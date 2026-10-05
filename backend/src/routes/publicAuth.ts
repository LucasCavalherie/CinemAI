import { Hono } from 'hono'
import { z } from 'zod'
import { AttestationError } from '../auth/appAttest'
import { consumeChallenge, createChallenge } from '../auth/challenge'
import { issueSession } from '../auth/session'
import type { AppEnv } from '../context'
import { createDevice, getDevice, updateCounter } from '../db/devices'
import { ApiError } from '../lib/errors'

export const publicAuthRoutes = new Hono<AppEnv>()

publicAuthRoutes.post('/auth/challenge', async (c) => {
  const { db, now } = c.get('deps')
  return c.json({ challenge: await createChallenge(db, now()) })
})

const RegisterBody = z.union([
  z.object({ unattested: z.literal(true) }),
  z.object({ keyId: z.string().min(1), attestation: z.string().min(1), challenge: z.string().min(1) }),
])

publicAuthRoutes.post('/devices', async (c) => {
  const deps = c.get('deps')
  const parsed = RegisterBody.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) throw new ApiError('invalid_input', 'Invalid registration body', 400)
  const body = parsed.data

  const deviceId = crypto.randomUUID()
  const nowSec = Math.floor(deps.now() / 1000)

  if ('unattested' in body) {
    if (!deps.settings.allowUnattested) throw new ApiError('forbidden', 'Unattested devices are not allowed', 403)
    await createDevice(deps.db, { id: deviceId, keyId: null, publicKey: null, nowSec })
  } else {
    if (!(await consumeChallenge(deps.db, body.challenge, deps.now()))) {
      throw new ApiError('invalid_challenge', 'Unknown or expired challenge', 400)
    }
    let publicKeySpki: string
    try {
      ;({ publicKeySpki } = await deps.attest.verifyAttestation({
        attestation: body.attestation,
        keyId: body.keyId,
        challenge: body.challenge,
        appId: deps.settings.appId,
        allowedEnvs: deps.settings.attestEnvs,
        rootCaPem: deps.settings.rootCaPem,
        nowMs: deps.now(),
      }))
    } catch (err) {
      if (err instanceof AttestationError) throw new ApiError('attestation_failed', err.reason, 403)
      throw err
    }
    try {
      await createDevice(deps.db, { id: deviceId, keyId: body.keyId, publicKey: publicKeySpki, nowSec })
    } catch {
      throw new ApiError('attestation_failed', 'Key already registered', 403)
    }
  }

  return c.json(await issueSession(deps, deviceId))
})

const RefreshBody = z.object({
  refreshToken: z.string().min(1),
  challenge: z.string().min(1).optional(),
  assertion: z.string().min(1).optional(),
})

publicAuthRoutes.post('/auth/refresh', async (c) => {
  const deps = c.get('deps')
  const parsed = RefreshBody.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) throw new ApiError('invalid_input', 'Invalid refresh body', 400)
  const { refreshToken, challenge, assertion } = parsed.data

  const deviceId = await deps.tokens.deviceForRefresh(refreshToken)
  const device = deviceId ? await getDevice(deps.db, deviceId) : null
  if (!device) throw new ApiError('unauthorized', 'Invalid refresh token', 401)

  if (device.key_id && device.public_key) {
    if (!challenge || !assertion) throw new ApiError('invalid_input', 'An App Attest assertion is required', 400)
    if (!(await consumeChallenge(deps.db, challenge, deps.now()))) {
      throw new ApiError('invalid_challenge', 'Unknown or expired challenge', 400)
    }
    try {
      const { counter } = await deps.attest.verifyAssertion({
        assertion,
        clientData: `${challenge}:${refreshToken}`,
        publicKeySpki: device.public_key,
        storedCounter: device.counter,
        appId: deps.settings.appId,
      })
      await updateCounter(deps.db, device.id, counter)
    } catch (err) {
      if (err instanceof AttestationError) throw new ApiError('attestation_failed', err.reason, 403)
      throw err
    }
  }

  if (!(await deps.tokens.consumeRefresh(refreshToken))) throw new ApiError('unauthorized', 'Invalid refresh token', 401)
  return c.json(await issueSession(deps, device.id))
})
