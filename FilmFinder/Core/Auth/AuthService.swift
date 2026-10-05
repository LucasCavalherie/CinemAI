import CryptoKit
import Foundation

private struct SessionResponse: Decodable, Sendable {
    let accessToken: String
    let expiresAt: Int
    let refreshToken: String
}

private struct RegisterBody: Encodable, Sendable {
    let keyId: String
    let attestation: String
    let challenge: String
}

private struct UnattestedBody: Encodable, Sendable {
    let unattested = true
}

private struct RefreshBody: Encodable, Sendable {
    let refreshToken: String
    var challenge: String?
    var assertion: String?
}

private enum AuthError: Error {
    case attestationUnavailable
}

/// Mantém a identidade do dispositivo: registra sozinho no primeiro uso e renova o token de acesso.
actor AuthService: AccessTokenProvider {
    enum Keys {
        static let refreshToken = "refreshToken"
        static let keyId = "appAttestKeyId"
    }

    private static let renewalMargin: TimeInterval = 60

    private let transport: HTTPTransport
    private let secrets: any SecretStore
    private let attest: any AppAttestProviding
    private let now: @Sendable () -> Date

    private var cached: (token: String, expiresAt: Date)?
    private var inflight: Task<String, Error>?

    init(
        transport: HTTPTransport,
        secrets: any SecretStore,
        attest: any AppAttestProviding,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.secrets = secrets
        self.attest = attest
        self.now = now
    }

    func accessToken() async throws -> String {
        if let cached, isFresh(cached.expiresAt) { return cached.token }
        return try await renew()
    }

    func refreshedAccessToken(after rejected: String) async throws -> String {
        if let cached, cached.token != rejected, isFresh(cached.expiresAt) { return cached.token }
        cached = nil
        return try await renew()
    }

    // MARK: - Renovação

    private func isFresh(_ expiresAt: Date) -> Bool {
        expiresAt.timeIntervalSince(now()) > Self.renewalMargin
    }

    /// Renovações simultâneas viram uma só.
    private func renew() async throws -> String {
        if let inflight { return try await inflight.value }
        let task = Task { try await self.performRenewal() }
        inflight = task
        defer { inflight = nil }
        return try await task.value
    }

    private func performRenewal() async throws -> String {
        if secrets.string(for: Keys.refreshToken) != nil {
            do {
                return try await refresh()
            } catch let error as APIError where error.invalidatesSession {
                clearCredentials()
            } catch AuthError.attestationUnavailable {
                clearCredentials()
            }
        }
        return try await register()
    }

    private func register() async throws -> String {
        let response: SessionResponse
        if attest.isSupported {
            let challenge = try await transport.fetchChallenge()
            let keyId = try await attest.generateKey()
            let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
            let attestation = try await attest.attestKey(keyId, clientDataHash: clientDataHash)
            response = try await transport.send(
                "POST", "v1/devices",
                body: RegisterBody(keyId: keyId, attestation: attestation.base64EncodedString(), challenge: challenge)
            )
            secrets.set(keyId, for: Keys.keyId)
        } else {
            response = try await transport.send("POST", "v1/devices", body: UnattestedBody())
            secrets.set(nil, for: Keys.keyId)
        }
        return store(response)
    }

    private func refresh() async throws -> String {
        guard let refreshToken = secrets.string(for: Keys.refreshToken) else { throw APIError.unauthorized }
        var body = RefreshBody(refreshToken: refreshToken)
        if let keyId = secrets.string(for: Keys.keyId) {
            guard attest.isSupported else { throw AuthError.attestationUnavailable }
            let challenge = try await transport.fetchChallenge()
            let clientDataHash = Data(SHA256.hash(data: Data("\(challenge):\(refreshToken)".utf8)))
            do {
                let assertion = try await attest.generateAssertion(keyId, clientDataHash: clientDataHash)
                body.challenge = challenge
                body.assertion = assertion.base64EncodedString()
            } catch {
                throw AuthError.attestationUnavailable
            }
        }
        let response: SessionResponse = try await transport.send("POST", "v1/auth/refresh", body: body)
        return store(response)
    }

    private func store(_ response: SessionResponse) -> String {
        secrets.set(response.refreshToken, for: Keys.refreshToken)
        cached = (response.accessToken, Date(timeIntervalSince1970: TimeInterval(response.expiresAt)))
        return response.accessToken
    }

    private func clearCredentials() {
        secrets.set(nil, for: Keys.refreshToken)
        secrets.set(nil, for: Keys.keyId)
        cached = nil
    }
}
