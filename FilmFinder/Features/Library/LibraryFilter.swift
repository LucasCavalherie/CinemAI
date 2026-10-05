import Foundation

enum LibrarySegment: String, CaseIterable, Identifiable, Sendable {
    case favorites
    case watched
    case history

    var id: String { rawValue }
}

/// `LibraryItem` com o snapshot já decodificado: a decodificação acontece uma vez por render, não por consulta.
struct LibraryEntry: Identifiable {
    let id: String
    let title: Title
    let date: Date
    let isFavorite: Bool
    let isWatched: Bool
    let inHistory: Bool

    init?(_ item: LibraryItem) {
        guard let title = item.snapshot else { return nil }
        id = item.libraryKey
        self.title = title
        date = item.recommendedAt
        isFavorite = item.isFavorite
        isWatched = item.isWatched
        inHistory = item.inHistory
    }

    func isIn(_ segment: LibrarySegment) -> Bool {
        switch segment {
        case .favorites: isFavorite
        case .watched: isWatched
        case .history: inHistory
        }
    }
}

struct LibraryFilter {
    var segment: LibrarySegment
    var query: String = ""
    var mediaType: MediaType?

    static func entries(from items: [LibraryItem]) -> [LibraryEntry] {
        items.compactMap(LibraryEntry.init)
    }

    static func count(_ segment: LibrarySegment, in entries: [LibraryEntry]) -> Int {
        entries.filter { $0.isIn(segment) }.count
    }

    /// Mantém a ordem recebida.
    func apply(to entries: [LibraryEntry]) -> [LibraryEntry] {
        let needle = Self.normalize(query)
        return entries.filter { entry in
            guard entry.isIn(segment) else { return false }
            if let mediaType, entry.title.mediaType != mediaType { return false }
            guard !needle.isEmpty else { return true }
            return Self.normalize(entry.title.title).contains(needle)
                || Self.normalize(entry.title.originalTitle).contains(needle)
        }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
