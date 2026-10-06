import Foundation

struct RecommendationRequest: Encodable, Sendable {
    let query: String
    let mediaType: MediaType
    let excludeTmdbIds: [Int]
    let locale: String
    let region: String
    /// Títulos já vistos ("Título original (ano)"): vão no prompt da IA; o filtro de verdade é por id no servidor.
    var excludeTitles: [String] = []
}

struct Quota: Decodable, Equatable, Sendable {
    let used: Int
    let limit: Int
    let resetsAt: Date

    var remaining: Int { max(0, limit - used) }

    var usedFraction: Double {
        limit > 0 ? min(1, Double(used) / Double(limit)) : 0
    }
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
