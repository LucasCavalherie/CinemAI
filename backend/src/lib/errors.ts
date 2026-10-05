export class ProviderError extends Error {
  override name = 'ProviderError'
}

export class AiUnavailableError extends Error {
  override name = 'AiUnavailableError'
  constructor() {
    super('All AI providers failed')
  }
}

export type ErrorCode = 'unauthorized' | 'invalid_input' | 'ai_unavailable' | 'internal'

export class ApiError extends Error {
  override name = 'ApiError'
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly status: 400 | 401 | 500 | 503,
  ) {
    super(message)
  }
}

export function errorBody(code: ErrorCode, message: string) {
  return { error: { code, message } }
}
