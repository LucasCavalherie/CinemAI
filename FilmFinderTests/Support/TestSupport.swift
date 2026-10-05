import Foundation
@testable import FilmFinder

private final class BundleToken {}

func fixtureData(_ name: String) throws -> Data {
    guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
}

extension Title {
    static func sample(
        id: Int = 1,
        type: MediaType = .movie,
        title: String = "Sample",
        providers: Providers? = nil
    ) -> Title {
        Title(
            tmdbId: id, mediaType: type, title: title, originalTitle: title, year: 2020,
            overview: "Overview", posterPath: "/p.jpg", backdropPath: nil, rating: 7.5,
            runtimeMinutes: type == .movie ? 120 : nil, seasons: type == .tv ? 2 : nil,
            genres: ["Drama"], reason: "Because.", providers: providers ?? .empty(region: "BR")
        )
    }
}
