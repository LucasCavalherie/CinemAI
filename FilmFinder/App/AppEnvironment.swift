import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let service: any RecommendationService
    let account: AccountModel
    /// Registra o dispositivo em segundo plano ao abrir o app, para a primeira busca não esperar a atestação.
    let warmUp: @Sendable () async -> Void

    init(service: any RecommendationService, account: AccountModel, warmUp: @escaping @Sendable () async -> Void = {}) {
        self.service = service
        self.account = account
        self.warmUp = warmUp
    }

    /// Monta os serviços reais: transporte HTTP, identidade do dispositivo (Keychain + App Attest) e conta.
    /// Se `APIBaseURL` estiver ausente, usa um endereço inválido: qualquer busca falha com erro de rede.
    static func live() -> AppEnvironment {
        let baseURL = (try? APIConfig.live().baseURL) ?? URL(string: "https://invalid.invalid")!
        let transport = HTTPTransport(baseURL: baseURL)
        let auth = AuthService(transport: transport, secrets: KeychainSecretStore(), attest: DeviceAppAttest())
        let api = AuthorizedAPI(transport: transport, tokens: auth)
        return AppEnvironment(
            service: APIClient(api: api),
            account: AccountModel(service: APIAccountService(transport: transport, api: api)),
            warmUp: { _ = try? await auth.accessToken() }
        )
    }
}
