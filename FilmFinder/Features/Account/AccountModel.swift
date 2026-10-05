import Foundation
import Observation

@MainActor
@Observable
final class AccountModel {
    private(set) var quota: Quota?
    private(set) var isSignedIn = false
    private(set) var isBusy = false
    private(set) var lastError: APIError?
    private(set) var pendingChallenge: String?

    private let service: any AccountService

    init(service: any AccountService) {
        self.service = service
    }

    /// Valor para `request.nonce` do Sign in with Apple: o hash do desafio do servidor.
    var signInNonce: String? {
        pendingChallenge.map(sha256Hex)
    }

    func refresh() async {
        do {
            apply(try await service.me())
        } catch is CancellationError {
            return
        } catch {
            lastError = Self.apiError(from: error)
        }
    }

    func update(quota: Quota) {
        self.quota = quota
    }

    /// Busca o desafio que será embutido no `nonce` antes de abrir a folha do Sign in with Apple.
    func prepareSignIn() async {
        pendingChallenge = try? await service.challenge()
    }

    func completeSignIn(identityToken: String, authorizationCode: String) async {
        guard let challenge = pendingChallenge else {
            lastError = .invalidInput("Sign-in was not prepared")
            return
        }
        pendingChallenge = nil
        isBusy = true
        defer { isBusy = false }
        do {
            apply(try await service.signIn(identityToken: identityToken, authorizationCode: authorizationCode, challenge: challenge))
        } catch is CancellationError {
            // sem estado a atualizar
        } catch {
            lastError = Self.apiError(from: error)
        }
        await prepareSignIn() // o desafio é de uso único: prepara o próximo
    }

    func signOut() async {
        await perform { try await self.service.signOut() }
    }

    func deleteAccount() async {
        await perform { try await self.service.deleteAccount() }
    }

    func clearError() {
        lastError = nil
    }

    private func perform(_ action: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await action()
            await refresh()
            await prepareSignIn()
        } catch is CancellationError {
            return
        } catch {
            lastError = Self.apiError(from: error)
        }
    }

    private func apply(_ me: MeResponse) {
        isSignedIn = me.user != nil
        quota = me.quota
        lastError = nil
    }

    private static func apiError(from error: Error) -> APIError {
        (error as? APIError) ?? .server(error.localizedDescription)
    }
}
