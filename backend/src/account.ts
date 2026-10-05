import { moveDeviceEntitlementsToUser } from './db/entitlements'
import { linkDeviceToUser } from './db/devices'
import { getUsage, raiseUsageTo } from './db/usage'
import type { Db } from './lib/db'
import { dayKey } from './quota'

/** Vincula o dispositivo ao usuário, mesclando a cota do dia (maior valor) e as entitlements. */
export async function attachUserToDevice(db: Db, deviceId: string, userId: string, nowMs: number): Promise<void> {
  const day = dayKey(nowMs)
  const deviceCount = await getUsage(db, 'device', deviceId, day)
  const userCount = await getUsage(db, 'user', userId, day)
  await raiseUsageTo(db, 'user', userId, day, deviceCount)
  await raiseUsageTo(db, 'device', deviceId, day, userCount)
  await moveDeviceEntitlementsToUser(db, deviceId, userId)
  await linkDeviceToUser(db, deviceId, userId)
}

/** Remove o usuário e tudo que pertence só a ele; o uso dos dispositivos permanece (anti-abuso). */
export async function deleteUserData(db: Db, userId: string): Promise<void> {
  await db.batch([
    { sql: "DELETE FROM entitlements WHERE owner_kind = 'user' AND owner_id = ?", params: [userId] },
    { sql: "DELETE FROM usage WHERE owner_kind = 'user' AND owner_id = ?", params: [userId] },
    { sql: 'UPDATE devices SET user_id = NULL WHERE user_id = ?', params: [userId] },
    { sql: 'DELETE FROM users WHERE id = ?', params: [userId] },
  ])
}
