import { describe, expect, it } from 'vitest'
import type { Env } from '../src/env'
import { loadSettings } from '../src/settings'

const env = (over: Partial<Record<keyof Env, string>> = {}) =>
  ({
    APPLE_TEAM_ID: 'TEAM123456',
    APPLE_BUNDLE_ID: 'com.andre.filmfinder',
    ALLOW_UNATTESTED: 'false',
    ALLOW_PROVIDER_OVERRIDE: 'false',
    APPATTEST_ENVS: 'production',
    ...over,
  }) as unknown as Env

describe('loadSettings', () => {
  it('builds the app id and parses flags', () => {
    const s = loadSettings(env())
    expect(s).toMatchObject({
      appId: 'TEAM123456.com.andre.filmfinder',
      bundleId: 'com.andre.filmfinder',
      allowUnattested: false,
      allowProviderOverride: false,
      attestEnvs: ['production'],
    })
    expect(s.rootCaPem).toContain('BEGIN CERTIFICATE')
  })

  it('only enables the dev switches when exactly "true"', () => {
    const s = loadSettings(env({ ALLOW_UNATTESTED: 'true', ALLOW_PROVIDER_OVERRIDE: 'TRUE' }))
    expect(s.allowUnattested).toBe(true)
    expect(s.allowProviderOverride).toBe(false)
  })

  it('parses environments and falls back to production for junk', () => {
    expect(loadSettings(env({ APPATTEST_ENVS: 'development, production' })).attestEnvs).toEqual(['development', 'production'])
    expect(loadSettings(env({ APPATTEST_ENVS: 'bogus' })).attestEnvs).toEqual(['production'])
    expect(loadSettings(env({ APPATTEST_ENVS: '' })).attestEnvs).toEqual(['production'])
  })
})
