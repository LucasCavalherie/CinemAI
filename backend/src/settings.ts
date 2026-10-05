import type { AttestEnv } from './auth/appAttest'
import { APPLE_APP_ATTEST_ROOT_CA_PEM } from './auth/appleRootCa'
import type { Env } from './env'

export type Settings = {
  appId: string
  bundleId: string
  allowUnattested: boolean
  allowProviderOverride: boolean
  attestEnvs: AttestEnv[]
  rootCaPem: string
}

export function loadSettings(env: Env): Settings {
  const attestEnvs = (env.APPATTEST_ENVS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter((s): s is AttestEnv => s === 'development' || s === 'production')
  return {
    appId: `${env.APPLE_TEAM_ID}.${env.APPLE_BUNDLE_ID}`,
    bundleId: env.APPLE_BUNDLE_ID,
    allowUnattested: env.ALLOW_UNATTESTED === 'true',
    allowProviderOverride: env.ALLOW_PROVIDER_OVERRIDE === 'true',
    attestEnvs: attestEnvs.length > 0 ? attestEnvs : ['production'],
    rootCaPem: APPLE_APP_ATTEST_ROOT_CA_PEM,
  }
}
