import { jwtVerify, SignJWT } from 'jose'
import type { Db } from '../lib/db'
import { randomBase64Url, sha256Hex, utf8 } from '../lib/crypto'
import { ApiError } from '../lib/errors'

const ISSUER = 'filmfinder-api'
const ACCESS_TTL_SEC = 15 * 60
const REFRESH_TTL_SEC = 60 * 24 * 3600

export class TokenService {
  private readonly key: Uint8Array

  constructor(
    secret: string,
    private readonly db: Db,
    private readonly nowMs: () => number,
  ) {
    this.key = utf8(secret)
  }

  async issueAccess(deviceId: string): Promise<{ accessToken: string; expiresAt: number }> {
    const iat = Math.floor(this.nowMs() / 1000)
    const expiresAt = iat + ACCESS_TTL_SEC
    const accessToken = await new SignJWT({})
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer(ISSUER)
      .setSubject(deviceId)
      .setIssuedAt(iat)
      .setExpirationTime(expiresAt)
      .sign(this.key)
    return { accessToken, expiresAt }
  }

  async verifyAccess(token: string): Promise<{ deviceId: string }> {
    try {
      const { payload } = await jwtVerify(token, this.key, {
        issuer: ISSUER,
        algorithms: ['HS256'],
        currentDate: new Date(this.nowMs()),
      })
      if (!payload.sub) throw new Error('missing subject')
      return { deviceId: payload.sub }
    } catch {
      throw new ApiError('unauthorized', 'Invalid or expired access token', 401)
    }
  }

  async issueRefresh(deviceId: string): Promise<string> {
    const token = randomBase64Url(32)
    const expiresAt = Math.floor(this.nowMs() / 1000) + REFRESH_TTL_SEC
    await this.db.run('INSERT INTO refresh_tokens (token_hash, device_id, expires_at) VALUES (?, ?, ?)', [
      await sha256Hex(token),
      deviceId,
      expiresAt,
    ])
    return token
  }

  /** Consulta sem consumir: a quem pertence um refresh token válido. */
  async deviceForRefresh(token: string): Promise<string | null> {
    const row = await this.db.first<{ device_id: string }>(
      'SELECT device_id FROM refresh_tokens WHERE token_hash = ? AND expires_at > ?',
      [await sha256Hex(token), Math.floor(this.nowMs() / 1000)],
    )
    return row?.device_id ?? null
  }

  /** Consome (uso único). `false` se já foi usado, expirou ou não existe. */
  async consumeRefresh(token: string): Promise<boolean> {
    const { changes } = await this.db.run('DELETE FROM refresh_tokens WHERE token_hash = ? AND expires_at > ?', [
      await sha256Hex(token),
      Math.floor(this.nowMs() / 1000),
    ])
    return changes === 1
  }
}
