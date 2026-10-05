import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LibraryStoreTests {
    @Test func recordRecommendedUpsertsWithoutTouchingHistory() throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 1), .sample(id: 2)])
        h.store.recordRecommended([.sample(id: 1)])

        #expect(h.items.count == 2)
        #expect(h.items.allSatisfy { !$0.inHistory && !$0.isFavorite && !$0.isWatched })
    }

    @Test func sameTmdbIdWithDifferentMediaTypeAreDistinctItems() throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 5, type: .movie), .sample(id: 5, type: .tv)])
        #expect(h.items.count == 2)
    }

    @Test func markShownAddsToHistoryOnce() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.markShown(title)
        let first = try #require(h.item(title.id)).recommendedAt
        h.store.markShown(title)

        let item = try #require(h.item(title.id))
        #expect(item.inHistory)
        #expect(item.recommendedAt == first)
        #expect(h.items.count == 1)
    }

    @Test func favoriteAndWatchedAreIndependentFlags() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.setFavorite(title, true)
        h.store.setWatched(title, true)
        h.store.setFavorite(title, false)

        let item = try #require(h.item(title.id))
        #expect(!item.isFavorite)
        #expect(item.isWatched)
    }

    @Test func removeFromHistoryKeepsTheItemExcluded() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.markShown(title)
        h.store.removeFromHistory(title)

        #expect(try #require(h.item(title.id)).inHistory == false)
        #expect(h.store.excludedIDs(for: .movie) == [1])
    }

    @Test func clearHistoryOnlyClearsTheHistoryFlag() throws {
        let h = try LibraryHarness()
        h.store.markShown(.sample(id: 1))
        h.store.markShown(.sample(id: 2))
        h.store.setFavorite(.sample(id: 2), true)
        h.store.clearHistory()

        #expect(h.items.allSatisfy { !$0.inHistory })
        #expect(h.items.count == 2)
        #expect(try #require(h.item("movie-2")).isFavorite)
    }

    @Test func upsertRefreshesTheSnapshotButKeepsFlags() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1, title: "Old"), true)
        h.store.recordRecommended([.sample(id: 1, title: "New")])

        let item = try #require(h.item("movie-1"))
        #expect(item.isFavorite)
        #expect(item.snapshot?.title == "New")
    }

    @Test func excludedIDsAreFilteredByMediaType() throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 1, type: .movie), .sample(id: 2, type: .tv)])
        #expect(h.store.excludedIDs(for: .movie) == [1])
        #expect(h.store.excludedIDs(for: .tv) == [2])
    }

    @Test func excludedIDsAreCappedWithFavoritesAndWatchedFirst() throws {
        let h = try LibraryHarness()
        for i in 0..<205 {
            let item = h.store.upsert(.sample(id: 100 + i))
            item.recommendedAt = Date(timeIntervalSince1970: 1_000_000 + Double(i))
        }
        let pinned = h.store.upsert(.sample(id: 1))
        pinned.isFavorite = true
        pinned.recommendedAt = Date(timeIntervalSince1970: 1)
        h.store.save()

        let ids = h.store.excludedIDs(for: .movie)
        #expect(ids.count == LibraryStore.maxExcluded)
        #expect(ids.first == 1)
        #expect(ids[1] == 304)            // mais recente depois dos fixados
        #expect(!ids.contains(100))       // os mais antigos caem fora do teto
    }
}
