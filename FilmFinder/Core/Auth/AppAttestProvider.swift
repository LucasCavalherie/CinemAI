import DeviceCheck
import Foundation

protocol AppAttestProviding: Sendable {
    var isSupported: Bool { get }
    func generateKey() async throws -> String
    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data
}

/// App Attest do sistema. `isSupported` é `false` no simulador e em aparelhos sem suporte.
struct DeviceAppAttest: AppAttestProviding {
    private var service: DCAppAttestService { DCAppAttestService.shared }

    var isSupported: Bool { service.isSupported }

    func generateKey() async throws -> String {
        try await service.generateKey()
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await service.attestKey(keyId, clientDataHash: clientDataHash)
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
    }
}
