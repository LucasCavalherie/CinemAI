import CryptoKit
import Foundation
import Testing
@testable import FilmFinder

private final class Clock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    func now() -> Date { date }
}

private func sha256(_ text: String) -> Data { Data(SHA256.hash(data: Data(text.utf8))) }

@Suite(.serialized) struct AuthServiceTests {
    private let base = URL(string: "https://api.example.com")!

    private func makeService(
        attest: FakeAppAttest,
        secrets: InMemorySecretStore = InMemorySecretStore(),
        clock: Clock = Clock()
    ) -> AuthService {
        AuthService(
            transport: HTTPTransport(baseURL: base, session: MockURLProtocol.session()),
            secrets: secrets,
            attest: attest,
            now: { clock.now() }
        )
    }

    private func sessionJSON(access: String, refresh: String, expiresIn: TimeInterval, clock: Clock) -> Data {
        let expiresAt = Int(clock.date.addingTimeInterval(expiresIn).timeIntervalSince1970)
        return Data(#"{"accessToken":"\#(access)","expiresAt":\#(expiresAt),"refreshToken":"\#(refresh)"}"#.utf8)
    }

    /// Instala um handler que roteia por caminho e registra o que chegou.
    private func route(_ routes: [String: (URLRequest) throws -> (Int, Data)]) -> RecordBox {
        let box = RecordBox()
        MockURLProtocol.handler = { req in
            let path = req.url!.path
            box.append(path, body: req.bodyData())
            guard let handler = routes[path] else { return (httpResponse(req.url!, status: 404), Data()) }
            let (status, data) = try handler(req)
            return (httpResponse(req.url!, status: status), data)
        }
        return box
    }

    @Test func registersWithoutAttestationWhenAppAttestIsUnsupported() async throws {
        let clock = Clock()
        let secrets = InMemorySecretStore()
        let box = route(["/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) }])
        let service = makeService(attest: FakeAppAttest(isSupported: false), secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "A1")
        #expect(try await service.accessToken() == "A1") // cache: sem nova requisição

        #expect(box.paths == ["/v1/devices"])
        #expect(box.json(0) as? [String: Bool] == ["unattested": true])
        #expect(secrets.string(for: AuthService.Keys.refreshToken) == "R1")
        #expect(secrets.string(for: AuthService.Keys.keyId) == nil)
    }

    @Test func registersWithAttestationOverTheChallenge() async throws {
        let clock = Clock()
        let attest = FakeAppAttest(isSupported: true)
        let secrets = InMemorySecretStore()
        let box = route([
            "/v1/auth/challenge": { _ in (200, Data(#"{"challenge":"c1"}"#.utf8)) },
            "/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) },
        ])
        let service = makeService(attest: attest, secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "A1")

        #expect(attest.attestCalls.map(\.keyId) == ["key-1"])
        #expect(attest.attestCalls.first?.hash == sha256("c1"))
        let body = try #require(box.json(1) as? [String: String])
        #expect(body["keyId"] == "key-1")
        #expect(body["challenge"] == "c1")
        #expect(body["attestation"] == Data("attestation-for-key-1".utf8).base64EncodedString())
        #expect(secrets.string(for: AuthService.Keys.keyId) == "key-1")
    }

    @Test func refreshesAnExpiredTokenWithAnAssertionAndRotatesTheRefreshToken() async throws {
        let clock = Clock()
        let attest = FakeAppAttest(isSupported: true)
        let secrets = InMemorySecretStore()
        nonisolated(unsafe) var challengeCount = 0
        let box = route([
            "/v1/auth/challenge": { _ in
                challengeCount += 1
                return (200, Data(#"{"challenge":"c\#(challengeCount)"}"#.utf8))
            },
            "/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) },
            "/v1/auth/refresh": { _ in (200, self.sessionJSON(access: "A2", refresh: "R2", expiresIn: 900, clock: clock)) },
        ])
        let service = makeService(attest: attest, secrets: secrets, clock: clock)
        _ = try await service.accessToken()

        clock.date = clock.date.addingTimeInterval(900) // expirou (restam < 60 s)
        #expect(try await service.accessToken() == "A2")

        #expect(box.paths == ["/v1/auth/challenge", "/v1/devices", "/v1/auth/challenge", "/v1/auth/refresh"])
        #expect(attest.assertionCalls.first?.hash == sha256("c2:R1"))
        let body = try #require(box.json(3) as? [String: String])
        #expect(body["refreshToken"] == "R1")
        #expect(body["challenge"] == "c2")
        #expect(body["assertion"] == Data("assertion-for-key-1".utf8).base64EncodedString())
        #expect(secrets.string(for: AuthService.Keys.refreshToken) == "R2")
    }

    @Test func refreshesAnUnattestedDeviceWithJustTheRefreshToken() async throws {
        let clock = Clock()
        let secrets = InMemorySecretStore([AuthService.Keys.refreshToken: "R1"])
        let box = route(["/v1/auth/refresh": { _ in (200, self.sessionJSON(access: "A2", refresh: "R2", expiresIn: 900, clock: clock)) }])
        let service = makeService(attest: FakeAppAttest(isSupported: false), secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "A2")

        #expect(box.paths == ["/v1/auth/refresh"])
        #expect(box.json(0) as? [String: String] == ["refreshToken": "R1"])
    }

    @Test func registersAgainWhenTheServerRejectsTheRefreshToken() async throws {
        let clock = Clock()
        let secrets = InMemorySecretStore([AuthService.Keys.refreshToken: "stale", AuthService.Keys.keyId: "old-key"])
        let attest = FakeAppAttest(isSupported: true)
        let box = route([
            "/v1/auth/challenge": { _ in (200, Data(#"{"challenge":"c"}"#.utf8)) },
            "/v1/auth/refresh": { _ in (401, Data(#"{"error":{"code":"unauthorized","message":"no"}}"#.utf8)) },
            "/v1/devices": { _ in (200, self.sessionJSON(access: "NEW", refresh: "R9", expiresIn: 900, clock: clock)) },
        ])
        let service = makeService(attest: attest, secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "NEW")

        #expect(box.paths.contains("/v1/devices"))
        #expect(secrets.string(for: AuthService.Keys.refreshToken) == "R9")
        #expect(secrets.string(for: AuthService.Keys.keyId) == "key-1")   // chave nova; a antiga foi descartada
    }

    @Test func registersAgainWhenTheAssertionCannotBeGenerated() async throws {
        let clock = Clock()
        let secrets = InMemorySecretStore([AuthService.Keys.refreshToken: "R1", AuthService.Keys.keyId: "lost-key"])
        let attest = FakeAppAttest(isSupported: true)
        attest.assertionError = URLError(.unknown) // ex.: chave perdida após reinstalar o app
        let box = route([
            "/v1/auth/challenge": { _ in (200, Data(#"{"challenge":"c"}"#.utf8)) },
            "/v1/devices": { _ in (200, self.sessionJSON(access: "NEW", refresh: "R2", expiresIn: 900, clock: clock)) },
        ])
        let service = makeService(attest: attest, secrets: secrets, clock: clock)

        #expect(try await service.accessToken() == "NEW")
        #expect(!box.paths.contains("/v1/auth/refresh"))
    }

    @Test func refreshedAccessTokenReturnsTheCachedOneWhenAnotherCallerAlreadyRenewed() async throws {
        let clock = Clock()
        let box = route(["/v1/devices": { _ in (200, self.sessionJSON(access: "B", refresh: "R1", expiresIn: 900, clock: clock)) }])
        let service = makeService(attest: FakeAppAttest(isSupported: false), clock: clock)
        _ = try await service.accessToken()

        #expect(try await service.refreshedAccessToken(after: "A-rejected") == "B")
        #expect(box.paths == ["/v1/devices"])
    }

    @Test func refreshedAccessTokenRenewsWhenTheCachedTokenIsTheRejectedOne() async throws {
        let clock = Clock()
        nonisolated(unsafe) var n = 0
        _ = route([
            "/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) },
            "/v1/auth/refresh": { _ in
                n += 1
                return (200, self.sessionJSON(access: "A2", refresh: "R2", expiresIn: 900, clock: clock))
            },
        ])
        let service = makeService(attest: FakeAppAttest(isSupported: false), clock: clock)
        let first = try await service.accessToken()

        #expect(try await service.refreshedAccessToken(after: first) == "A2")
        #expect(n == 1)
    }

    @Test func concurrentCallsShareASingleRegistration() async throws {
        let clock = Clock()
        let box = route(["/v1/devices": { _ in (200, self.sessionJSON(access: "A1", refresh: "R1", expiresIn: 900, clock: clock)) }])
        let service = makeService(attest: FakeAppAttest(isSupported: false), clock: clock)

        async let a = service.accessToken()
        async let b = service.accessToken()
        async let c = service.accessToken()
        let tokens = try await [a, b, c]

        #expect(tokens == ["A1", "A1", "A1"])
        #expect(box.paths.count == 1)
    }

    @Test func offlineDuringRefreshKeepsTheCredentials() async {
        let secrets = InMemorySecretStore([AuthService.Keys.refreshToken: "R1"])
        MockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let service = makeService(attest: FakeAppAttest(isSupported: false), secrets: secrets)

        await #expect(throws: APIError.offline) { try await service.accessToken() }
        #expect(secrets.string(for: AuthService.Keys.refreshToken) == "R1")
    }
}

/// Coleta os caminhos e corpos recebidos pelo `MockURLProtocol` (acessado de threads de rede).
private final class RecordBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _paths: [String] = []
    private var _bodies: [Data?] = []

    var paths: [String] { lock.withLock { _paths } }

    func append(_ path: String, body: Data?) {
        lock.withLock {
            _paths.append(path)
            _bodies.append(body)
        }
    }

    func json(_ index: Int) -> Any? {
        let data = lock.withLock { index < _bodies.count ? _bodies[index] : nil }
        return data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
    }
}
