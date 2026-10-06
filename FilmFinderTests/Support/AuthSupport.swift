import Foundation
@testable import FilmFinder

final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]

    init(_ values: [String: String] = [:]) { self.values = values }

    func string(for key: String) -> String? {
        lock.withLock { values[key] }
    }

    func set(_ value: String?, for key: String) {
        lock.withLock { values[key] = value }
    }
}

final class FakeAppAttest: AppAttestProviding, @unchecked Sendable {
    var isSupported: Bool
    var assertionError: Error?
    private(set) var generatedKeys: [String] = []
    private(set) var attestCalls: [(keyId: String, hash: Data)] = []
    private(set) var assertionCalls: [(keyId: String, hash: Data)] = []

    init(isSupported: Bool) { self.isSupported = isSupported }

    func generateKey() async throws -> String {
        let id = "key-\(generatedKeys.count + 1)"
        generatedKeys.append(id)
        return id
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        attestCalls.append((keyId, clientDataHash))
        return Data("attestation-for-\(keyId)".utf8)
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        if let assertionError { throw assertionError }
        assertionCalls.append((keyId, clientDataHash))
        return Data("assertion-for-\(keyId)".utf8)
    }
}
