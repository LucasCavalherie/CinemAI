import Foundation

/// Envia requisições autenticadas: usa o token atual e, se o servidor recusar (401),
/// pede um token renovado e tenta **uma** vez.
struct AuthorizedAPI: Sendable {
    let transport: HTTPTransport
    let tokens: any AccessTokenProvider

    func send<Response: Decodable>(_ method: String, _ path: String) async throws -> Response {
        try await authorized { token in try await transport.send(method, path, bearer: token) }
    }

    func send<Body: Encodable, Response: Decodable>(_ method: String, _ path: String, body: Body) async throws -> Response {
        try await authorized { token in try await transport.send(method, path, body: body, bearer: token) }
    }

    private func authorized<T>(_ call: (String) async throws -> T) async throws -> T {
        let token = try await tokens.accessToken()
        do {
            return try await call(token)
        } catch APIError.unauthorized {
            let fresh = try await tokens.refreshedAccessToken(after: token)
            return try await call(fresh)
        }
    }
}
