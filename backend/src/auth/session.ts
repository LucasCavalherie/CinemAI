import type { Deps } from '../deps'

export type Session = { accessToken: string; expiresAt: number; refreshToken: string }

export async function issueSession(deps: Pick<Deps, 'tokens'>, deviceId: string): Promise<Session> {
  const { accessToken, expiresAt } = await deps.tokens.issueAccess(deviceId)
  const refreshToken = await deps.tokens.issueRefresh(deviceId)
  return { accessToken, expiresAt, refreshToken }
}
