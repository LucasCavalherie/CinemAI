import type { Db } from '../lib/db'
import type { OwnerKind } from './usage'

export const UNLIMITED_SEARCH = 'unlimited_search'

export type Owner = { kind: OwnerKind; id: string }

export async function grantEntitlement(
  db: Db,
  e: { id: string; ownerKind: OwnerKind; ownerId: string; kind: string; expiresAt: number; originalTransactionId?: string },
): Promise<void> {
  await db.run(
    'INSERT INTO entitlements (id, owner_kind, owner_id, kind, expires_at, original_transaction_id) VALUES (?, ?, ?, ?, ?, ?)',
    [e.id, e.ownerKind, e.ownerId, e.kind, e.expiresAt, e.originalTransactionId ?? null],
  )
}

export async function listActiveEntitlements(db: Db, owners: Owner[], nowSec: number): Promise<string[]> {
  const kinds = new Set<string>()
  for (const owner of owners) {
    const rows = await db.all<{ kind: string }>(
      'SELECT DISTINCT kind FROM entitlements WHERE owner_kind = ? AND owner_id = ? AND expires_at > ?',
      [owner.kind, owner.id, nowSec],
    )
    rows.forEach((r) => kinds.add(r.kind))
  }
  return [...kinds].sort()
}

export async function hasActiveEntitlement(db: Db, owners: Owner[], kind: string, nowSec: number): Promise<boolean> {
  return (await listActiveEntitlements(db, owners, nowSec)).includes(kind)
}

export async function moveDeviceEntitlementsToUser(db: Db, deviceId: string, userId: string): Promise<void> {
  await db.run("UPDATE entitlements SET owner_kind = 'user', owner_id = ? WHERE owner_kind = 'device' AND owner_id = ?", [userId, deviceId])
}
