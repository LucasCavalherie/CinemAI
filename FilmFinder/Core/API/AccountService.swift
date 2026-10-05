import Foundation

protocol AccountService: Sendable {
    func challenge() async throws -> String
    func me() async throws -> MeResponse
    func signIn(identityToken: String, authorizationCode: String, challenge: String) async throws -> MeResponse
    func signOut() async throws
    func deleteAccount() async throws
}

struct APIAccountService: AccountService {
    let transport: HTTPTransport
    let api: AuthorizedAPI

    private struct SignInBody: Encodable, Sendable {
        let identityToken: String
        let authorizationCode: String
        let challenge: String
    }

    func challenge() async throws -> String {
        try await transport.fetchChallenge()
    }

    func me() async throws -> MeResponse {
        try await api.send("GET", "v1/me")
    }

    func signIn(identityToken: String, authorizationCode: String, challenge: String) async throws -> MeResponse {
        try await api.send(
            "POST", "v1/auth/apple",
            body: SignInBody(identityToken: identityToken, authorizationCode: authorizationCode, challenge: challenge)
        )
    }

    func signOut() async throws {
        let _: OKResponse = try await api.send("POST", "v1/auth/logout")
    }

    func deleteAccount() async throws {
        let _: OKResponse = try await api.send("DELETE", "v1/me")
    }
}
