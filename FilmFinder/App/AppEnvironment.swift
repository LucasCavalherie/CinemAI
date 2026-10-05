import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let service: any RecommendationService
    let account: AccountModel

    init(service: any RecommendationService, account: AccountModel) {
        self.service = service
        self.account = account
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
            account: AccountModel(service: APIAccountService(transport: transport, api: api))
        )
    }
}
