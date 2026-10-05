import type { Identity } from './auth/identity'
import type { AppConfig } from './config'
import { hasActiveEntitlement, UNLIMITED_SEARCH, type Owner } from './db/entitlements'
import { getUsage, refundUsage, reserveUsage } from './db/usage'
import type { Db } from './lib/db'

export type Quota = { used: number; limit: number; resetsAt: string }

export class QuotaExceededError extends Error {
  override name = 'QuotaExceededError'
  constructor(readonly quota: Quota) {
    super('Daily search limit reached')
  }
}

export function dayKey(nowMs: number): string {
  return new Date(nowMs).toISOString().slice(0, 10)
}

export function resetsAt(nowMs: number): string {
  const d = new Date(nowMs)
  const next = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1)
  return new Date(next).toISOString().replace(/\.\d{3}Z$/, 'Z')
}

export function ownersOf(identity: Identity): Owner[] {
  const owners: Owner[] = [{ kind: 'device', id: identity.deviceId }]
  if (identity.userId) owners.push({ kind: 'user', id: identity.userId })
  return owners
}

async function limitFor(db: Db, config: AppConfig, identity: Identity, nowMs: number): Promise<number> {
  const pro = await hasActiveEntitlement(db, ownersOf(identity), UNLIMITED_SEARCH, Math.floor(nowMs / 1000))
  return pro ? config.limits.pro : config.limits.free
}

export async function quotaSnapshot(db: Db, config: AppConfig, identity: Identity, nowMs: number): Promise<Quota> {
  const day = dayKey(nowMs)
  const counts = await Promise.all(ownersOf(identity).map((o) => getUsage(db, o.kind, o.id, day)))
  return {
    used: Math.max(...counts),
    limit: await limitFor(db, config, identity, nowMs),
    resetsAt: resetsAt(nowMs),
  }
}

/** Reserva uma busca em todos os donos (dispositivo e, se logado, usuário). */
export async function reserveSearch(db: Db, config: AppConfig, identity: Identity, nowMs: number): Promise<Quota> {
  const limit = await limitFor(db, config, identity, nowMs)
  const day = dayKey(nowMs)
  const reserved: Owner[] = []
  for (const owner of ownersOf(identity)) {
    if (!(await reserveUsage(db, owner.kind, owner.id, day, limit))) {
      for (const done of reserved) await refundUsage(db, done.kind, done.id, day)
      throw new QuotaExceededError(await quotaSnapshot(db, config, identity, nowMs))
    }
    reserved.push(owner)
  }
  return quotaSnapshot(db, config, identity, nowMs)
}

export async function refundSearch(db: Db, identity: Identity, nowMs: number): Promise<void> {
  const day = dayKey(nowMs)
  for (const owner of ownersOf(identity)) await refundUsage(db, owner.kind, owner.id, day)
}
