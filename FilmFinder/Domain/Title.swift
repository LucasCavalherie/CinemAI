import Foundation

struct StreamingProvider: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String
}

struct Providers: Codable, Hashable, Sendable {
    var region: String
    var link: URL?
    var flatrate: [StreamingProvider]
    var rent: [StreamingProvider]
    var buy: [StreamingProvider]
    var free: [StreamingProvider]

    static func empty(region: String) -> Providers {
        Providers(region: region, link: nil, flatrate: [], rent: [], buy: [], free: [])
    }

    var isEmpty: Bool {
        flatrate.isEmpty && rent.isEmpty && buy.isEmpty && free.isEmpty
    }

    /// Logos exibidos no card: assinatura primeiro; sem assinatura, os gratuitos.
    func highlighted(limit: Int = 3) -> [StreamingProvider] {
        Array((flatrate.isEmpty ? free : flatrate).prefix(limit))
    }
}

struct Title: Codable, Hashable, Sendable, Identifiable {
    let tmdbId: Int
    let mediaType: MediaType
    let title: String
    let originalTitle: String
    let year: Int?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let rating: Double
    let runtimeMinutes: Int?
    let seasons: Int?
    let genres: [String]
    let reason: String
    let providers: Providers

    var id: String { "\(mediaType.rawValue)-\(tmdbId)" }

    /// Nota TMDB (0–10) convertida para 0–5 estrelas, como no app antigo.
    static func stars(for rating: Double) -> Int {
        min(5, max(0, Int(rating / 2 + 0.5)))
    }

    var stars: Int { Title.stars(for: rating) }
}
