import type { Db } from '../lib/db'
import { randomBase64Url } from '../lib/crypto'

const CHALLENGE_TTL_SEC = 300

export async function createChallenge(db: Db, nowMs: number): Promise<string> {
  const nowSec = Math.floor(nowMs / 1000)
  await db.run('DELETE FROM challenges WHERE expires_at <= ?', [nowSec])
  const challenge = randomBase64Url(32)
  await db.run('INSERT INTO challenges (id, expires_at) VALUES (?, ?)', [challenge, nowSec + CHALLENGE_TTL_SEC])
  return challenge
}

/** Uso único e atômico: `true` só para a primeira chamada com um desafio válido. */
export async function consumeChallenge(db: Db, challenge: string, nowMs: number): Promise<boolean> {
  const { changes } = await db.run('DELETE FROM challenges WHERE id = ? AND expires_at > ?', [
    challenge,
    Math.floor(nowMs / 1000),
  ])
  return changes === 1
}
