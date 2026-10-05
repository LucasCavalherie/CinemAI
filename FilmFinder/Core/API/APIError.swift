import Foundation

enum APIError: Error, Equatable, Sendable {
    case unauthorized
    case quotaExceeded
    case serviceUnavailable
    case offline
    case invalidResponse
    case forbidden(String)
    case invalidInput(String)
    case server(String)

    /// Erros que indicam que as credenciais do dispositivo não valem mais.
    var invalidatesSession: Bool {
        switch self {
        case .unauthorized, .forbidden: true
        default: false
        }
    }
}

protocol RecommendationService: Sendable {
    func recommend(_ request: RecommendationRequest) async throws -> RecommendationsResponse
}

protocol AccessTokenProvider: Sendable {
    func accessToken() async throws -> String
    /// Chamado depois de um 401: devolve um token novo (ou o que outra chamada já renovou).
    func refreshedAccessToken(after rejected: String) async throws -> String
}

struct OKResponse: Decodable, Sendable {
    let ok: Bool
}

struct ChallengeResponse: Decodable, Sendable {
    let challenge: String
}
