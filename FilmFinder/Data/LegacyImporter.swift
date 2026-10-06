import Foundation

/// Converte os dados do app antigo (UserDefaults) para a biblioteca SwiftData, uma única vez.
@MainActor
struct LegacyImporter {
    static let doneKey = "legacyImportDone.v1"
    static let legacyKeys = ["allContent", "favorites", "watched", "history"]

    let defaults: UserDefaults
    let store: LibraryStore
    let region: String

    init(defaults: UserDefaults, store: LibraryStore, region: String = LocaleInfo().region) {
        self.defaults = defaults
        self.store = store
        self.region = region
    }

    @discardableResult
    func runIfNeeded() -> Int {
        guard !defaults.bool(forKey: Self.doneKey) else { return 0 }
        defaults.set(true, forKey: Self.doneKey)

        let hasLegacyData = Self.legacyKeys.contains { defaults.data(forKey: $0) != nil }
        guard hasLegacyData else { return 0 }

        var merged: [String: Merged] = [:]
        absorb(decodeList("allContent"), into: &merged)
        absorb(decodeList("favorites"), favorite: true, into: &merged)
        absorb(decodeList("watched"), watched: true, into: &merged)
        absorb(decodeList("history"), inHistory: true, into: &merged)

        for entry in merged.values {
            let item = store.upsert(entry.title)
            item.isFavorite = entry.favorite
            item.isWatched = entry.watched
            item.inHistory = entry.inHistory
            item.recommendedAt = entry.date
        }
        store.save()

        // Só apaga o legado se algo foi realmente importado.
        if !merged.isEmpty {
            Self.legacyKeys.forEach(defaults.removeObject(forKey:))
        }
        return merged.count
    }

    // MARK: - Mesclagem

    private struct Merged {
        var title: Title
        var date: Date
        var favorite: Bool
        var watched: Bool
        var inHistory: Bool
    }

    private func absorb(
        _ entries: [LegacyEntry],
        favorite: Bool = false,
        watched: Bool = false,
        inHistory: Bool = false,
        into merged: inout [String: Merged]
    ) {
        for entry in entries {
            let title = makeTitle(from: entry)
            let flags = entry.item
            if var existing = merged[title.id] {
                existing.favorite = existing.favorite || favorite || flags.favorite
                existing.watched = existing.watched || watched || flags.watched
                existing.inHistory = existing.inHistory || inHistory
                existing.date = max(existing.date, entry.date)
                merged[title.id] = existing
            } else {
                merged[title.id] = Merged(
                    title: title,
                    date: entry.date,
                    favorite: favorite || flags.favorite,
                    watched: watched || flags.watched,
                    inHistory: inHistory
                )
            }
        }
    }

    private func makeTitle(from entry: LegacyEntry) -> Title {
        let item = entry.item
        let type = entry.mediaType
        return Title(
            tmdbId: Int(item.idFilme),
            mediaType: type,
            title: item.title,
            originalTitle: item.title,
            year: Int(item.releaseDate.prefix(4)),
            overview: item.plot,
            posterPath: item.image.isEmpty ? nil : item.image,
            backdropPath: nil,
            rating: item.rating,
            runtimeMinutes: type == .movie && item.duration > 0 ? item.duration : nil,
            seasons: type == .tv ? item.duration : nil,
            genres: [],
            reason: "",
            providers: .empty(region: region)
        )
    }

    // MARK: - Decodificação do formato legado

    private func decodeList(_ key: String) -> [LegacyEntry] {
        guard let data = defaults.data(forKey: key),
              let lossy = try? JSONDecoder().decode([Lossy<LegacyEntry>].self, from: data)
        else { return [] }
        return lossy.compactMap(\.value)
    }

    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    private struct LegacyItem: Decodable {
        let idFilme: Int32
        let title: String
        let image: String
        let releaseDate: String
        let duration: Int
        let plot: String
        let rating: Double
        let favorite: Bool
        let watched: Bool
    }

    private struct LegacyEntry: Decodable {
        let date: Date
        private let content: Content

        private struct Content: Decodable {
            let filme: LegacyItem?
            let serie: LegacyItem?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(Date.self, forKey: .date)
            content = try container.decode(Content.self, forKey: .content)
            guard content.filme != nil || content.serie != nil else {
                throw DecodingError.dataCorruptedError(forKey: .content, in: container, debugDescription: "Empty content")
            }
        }

        private enum CodingKeys: String, CodingKey { case date, content }

        var mediaType: MediaType { content.filme != nil ? .movie : .tv }
        var item: LegacyItem { content.filme ?? content.serie! }
    }
}
