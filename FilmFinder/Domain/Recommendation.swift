import Foundation

struct RecommendationRequest: Encodable, Sendable {
    let query: String
    let mediaType: MediaType
    let excludeTmdbIds: [Int]
    let locale: String
    let region: String
}

struct Quota: Decodable, Equatable, Sendable {
    let used: Int
    let limit: Int
    let resetsAt: Date

    var remaining: Int { max(0, limit - used) }
}

struct RecommendationsResponse: Decodable, Sendable {
    let titles: [Title]
    let quota: Quota?
}

extension JSONDecoder {
    /// Decodificador da API: datas em ISO 8601 (`2026-10-06T00:00:00Z`).
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
