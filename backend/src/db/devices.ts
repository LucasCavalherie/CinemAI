import type { Db } from '../lib/db'

export type DeviceRow = {
  id: string
  key_id: string | null
  public_key: string | null
  counter: number
  user_id: string | null
  created_at: number
}

export async function createDevice(
  db: Db,
  d: { id: string; keyId: string | null; publicKey: string | null; nowSec: number },
): Promise<void> {
  await db.run('INSERT INTO devices (id, key_id, public_key, counter, user_id, created_at) VALUES (?, ?, ?, 0, NULL, ?)', [
    d.id,
    d.keyId,
    d.publicKey,
    d.nowSec,
  ])
}

export function getDevice(db: Db, id: string): Promise<DeviceRow | null> {
  return db.first<DeviceRow>('SELECT * FROM devices WHERE id = ?', [id])
}

export async function updateCounter(db: Db, id: string, counter: number): Promise<void> {
  await db.run('UPDATE devices SET counter = ? WHERE id = ?', [counter, id])
}

export async function linkDeviceToUser(db: Db, deviceId: string, userId: string | null): Promise<void> {
  await db.run('UPDATE devices SET user_id = ? WHERE id = ?', [userId, deviceId])
}
