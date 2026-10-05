import Foundation
import SwiftData

/// Estado dos marcadores de um título; guardado antes de uma remoção para poder desfazê-la.
struct LibraryFlags: Equatable, Sendable {
    var isFavorite: Bool
    var isWatched: Bool
    var inHistory: Bool
}

@MainActor
final class LibraryStore {
    /// Teto de ids enviados ao backend (`excludeTmdbIds`).
    static let maxExcluded = 200

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func item(for title: Title) -> LibraryItem? {
        fetch(key: title.id)
    }

    @discardableResult
    func upsert(_ title: Title) -> LibraryItem {
        if let existing = fetch(key: title.id) {
            existing.updateSnapshot(title)
            return existing
        }
        let created = LibraryItem(title: title)
        context.insert(created)
        return created
    }

    /// Grava os títulos como "já recomendados" (para exclusão futura); não entram no Histórico.
    func recordRecommended(_ titles: [Title]) {
        titles.forEach { upsert($0) }
        save()
    }

    /// O título foi exibido ao usuário: entra no Histórico (uma vez).
    func markShown(_ title: Title) {
        let item = upsert(title)
        if !item.inHistory {
            item.inHistory = true
            item.recommendedAt = Date()
        }
        save()
    }

    func setFavorite(_ title: Title, _ value: Bool) {
        upsert(title).isFavorite = value
        save()
    }

    func setWatched(_ title: Title, _ value: Bool) {
        upsert(title).isWatched = value
        save()
    }

    func removeFromHistory(_ title: Title) {
        fetch(key: title.id)?.inHistory = false
        save()
    }

    func clearHistory() {
        let descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.inHistory })
        for item in (try? context.fetch(descriptor)) ?? [] { item.inHistory = false }
        save()
    }

    /// Ids do mesmo tipo de mídia: favoritos e assistidos primeiro, depois os mais recentes; máx. 200.
    func excludedIDs(for mediaType: MediaType) -> [Int] {
        excludedItems(for: mediaType).map(\.tmdbId)
    }

    /// Mesmos itens e ordem de `excludedIDs`, como rótulos "Título original (ano)" para o prompt da IA.
    func excludedTitles(for mediaType: MediaType) -> [String] {
        excludedItems(for: mediaType).compactMap { $0.snapshot?.excludeLabel }
    }

    private func excludedItems(for mediaType: MediaType) -> [LibraryItem] {
        let raw = mediaType.rawValue
        let descriptor = FetchDescriptor<LibraryItem>(
            predicate: #Predicate { $0.mediaTypeRaw == raw },
            sortBy: [SortDescriptor(\.recommendedAt, order: .reverse)]
        )
        let items = (try? context.fetch(descriptor)) ?? []
        let pinned = items.filter { $0.isFavorite || $0.isWatched }
        let rest = items.filter { !($0.isFavorite || $0.isWatched) }
        return Array((pinned + rest).prefix(Self.maxExcluded))
    }

    func flags(for title: Title) -> LibraryFlags? {
        guard let item = fetch(key: title.id) else { return nil }
        return LibraryFlags(isFavorite: item.isFavorite, isWatched: item.isWatched, inHistory: item.inHistory)
    }

    /// Tira o título só do segmento indicado; os outros marcadores ficam como estão.
    func remove(_ title: Title, from segment: LibrarySegment) {
        switch segment {
        case .favorites: setFavorite(title, false)
        case .watched: setWatched(title, false)
        case .history: removeFromHistory(title)
        }
    }

    func restore(_ flags: LibraryFlags, for title: Title) {
        let item = upsert(title)
        item.isFavorite = flags.isFavorite
        item.isWatched = flags.isWatched
        item.inHistory = flags.inHistory
        save()
    }

    func save() {
        try? context.save()
    }

    private func fetch(key: String) -> LibraryItem? {
        var descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.libraryKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
