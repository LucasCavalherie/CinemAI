export class ProviderError extends Error {
  override name = 'ProviderError'
}

export class AiUnavailableError extends Error {
  override name = 'AiUnavailableError'
  constructor() {
    super('All AI providers failed')
  }
}

export type ErrorCode =
  | 'unauthorized'
  | 'invalid_input'
  | 'invalid_challenge'
  | 'forbidden'
  | 'attestation_failed'
  | 'quota_exceeded'
  | 'apple_auth_failed'
  | 'apple_unavailable'
  | 'ai_unavailable'
  | 'internal'

export type ErrorStatus = 400 | 401 | 402 | 403 | 500 | 502 | 503

export class ApiError extends Error {
  override name = 'ApiError'
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly status: ErrorStatus,
  ) {
    super(message)
  }
}

export function errorBody(code: ErrorCode, message: string) {
  return { error: { code, message } }
}
