import Foundation

struct APIClient: RecommendationService {
    let api: AuthorizedAPI

    init(api: AuthorizedAPI) {
        self.api = api
    }

    init(transport: HTTPTransport, tokens: any AccessTokenProvider) {
        self.init(api: AuthorizedAPI(transport: transport, tokens: tokens))
    }

    func recommend(_ request: RecommendationRequest) async throws -> RecommendationsResponse {
        try await api.send("POST", "v1/recommendations", body: request)
    }
}
