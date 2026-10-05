import Foundation
import SwiftData

@Model
final class LibraryItem {
    var libraryKey: String = ""
    var tmdbId: Int = 0
    var mediaTypeRaw: String = MediaType.movie.rawValue
    var snapshotData: Data = Data()
    var isFavorite: Bool = false
    var isWatched: Bool = false
    var inHistory: Bool = false
    var recommendedAt: Date = Date()

    init(title: Title, recommendedAt: Date = Date()) {
        libraryKey = title.id
        tmdbId = title.tmdbId
        mediaTypeRaw = title.mediaType.rawValue
        snapshotData = (try? JSONEncoder().encode(title)) ?? Data()
        self.recommendedAt = recommendedAt
    }

    var mediaType: MediaType { MediaType(rawValue: mediaTypeRaw) ?? .movie }

    var snapshot: Title? { try? JSONDecoder().decode(Title.self, from: snapshotData) }

    func updateSnapshot(_ title: Title) {
        snapshotData = (try? JSONEncoder().encode(title)) ?? snapshotData
    }
}
