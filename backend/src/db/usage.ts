import type { Db } from '../lib/db'

export type OwnerKind = 'user' | 'device'

/** Reserva uma busca. `false` se o contador do dia já está no limite. */
export async function reserveUsage(db: Db, kind: OwnerKind, id: string, day: string, limit: number): Promise<boolean> {
  const { changes } = await db.run(
    `INSERT INTO usage (owner_kind, owner_id, day, count) VALUES (?, ?, ?, 1)
     ON CONFLICT (owner_kind, owner_id, day) DO UPDATE SET count = count + 1 WHERE count < ?`,
    [kind, id, day, limit],
  )
  return changes === 1
}

export async function refundUsage(db: Db, kind: OwnerKind, id: string, day: string): Promise<void> {
  await db.run('UPDATE usage SET count = MAX(count - 1, 0) WHERE owner_kind = ? AND owner_id = ? AND day = ?', [kind, id, day])
}

export async function getUsage(db: Db, kind: OwnerKind, id: string, day: string): Promise<number> {
  const row = await db.first<{ count: number }>('SELECT count FROM usage WHERE owner_kind = ? AND owner_id = ? AND day = ?', [kind, id, day])
  return row?.count ?? 0
}

/** Garante que o contador do dia seja pelo menos `count` (usado ao mesclar dispositivo e usuário). */
export async function raiseUsageTo(db: Db, kind: OwnerKind, id: string, day: string, count: number): Promise<void> {
  await db.run(
    `INSERT INTO usage (owner_kind, owner_id, day, count) VALUES (?, ?, ?, ?)
     ON CONFLICT (owner_kind, owner_id, day) DO UPDATE SET count = MAX(count, excluded.count)`,
    [kind, id, day, count],
  )
}
