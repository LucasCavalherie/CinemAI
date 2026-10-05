import type { Identity } from './auth/identity'
import type { Deps } from './deps'
import type { Env } from './env'

export type AppEnv = {
  Bindings: Env
  Variables: { deps: Deps; identity: Identity }
}
