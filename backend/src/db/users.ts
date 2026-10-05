import type { Db } from '../lib/db'

export type UserRow = {
  id: string
  apple_sub: string
  apple_refresh_token: string | null
  created_at: number
}

export function getUser(db: Db, id: string): Promise<UserRow | null> {
  return db.first<UserRow>('SELECT * FROM users WHERE id = ?', [id])
}

/** Encontra o usuário pelo `sub` do Apple (atualizando o token de revogação) ou cria um novo. */
export async function upsertUserByAppleSub(
  db: Db,
  p: { sub: string; appleRefreshToken: string; nowSec: number; newId: string },
): Promise<UserRow> {
  const existing = await db.first<UserRow>('SELECT * FROM users WHERE apple_sub = ?', [p.sub])
  if (existing) {
    await db.run('UPDATE users SET apple_refresh_token = ? WHERE id = ?', [p.appleRefreshToken, existing.id])
    return { ...existing, apple_refresh_token: p.appleRefreshToken }
  }
  await db.run('INSERT INTO users (id, apple_sub, apple_refresh_token, created_at) VALUES (?, ?, ?, ?)', [
    p.newId,
    p.sub,
    p.appleRefreshToken,
    p.nowSec,
  ])
  return { id: p.newId, apple_sub: p.sub, apple_refresh_token: p.appleRefreshToken, created_at: p.nowSec }
}
