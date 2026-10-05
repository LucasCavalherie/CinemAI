import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LibraryStoreRemovalTests {
    private func seeded() throws -> (LibraryHarness, Title) {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.setFavorite(title, true)
        h.store.setWatched(title, true)
        h.store.markShown(title)
        return (h, title)
    }

    @Test func removeFromFavoritesKeepsOtherFlags() throws {
        let (h, title) = try seeded()
        h.store.remove(title, from: .favorites)

        let item = try #require(h.item(title.id))
        #expect(!item.isFavorite)
        #expect(item.isWatched)
        #expect(item.inHistory)
    }

    @Test func removeFromWatchedKeepsOtherFlags() throws {
        let (h, title) = try seeded()
        h.store.remove(title, from: .watched)

        let item = try #require(h.item(title.id))
        #expect(item.isFavorite)
        #expect(!item.isWatched)
        #expect(item.inHistory)
    }

    @Test func removeFromHistoryKeepsFavoriteAndWatched() throws {
        let (h, title) = try seeded()
        h.store.remove(title, from: .history)

        let item = try #require(h.item(title.id))
        #expect(item.isFavorite)
        #expect(item.isWatched)
        #expect(!item.inHistory)
    }

    @Test func restoreReappliesTheCapturedFlags() throws {
        let (h, title) = try seeded()
        let before = try #require(h.store.flags(for: title))
        h.store.remove(title, from: .history)
        h.store.remove(title, from: .favorites)
        h.store.restore(before, for: title)

        #expect(h.store.flags(for: title) == before)
    }

    @Test func flagsAreNilForUnknownTitle() throws {
        let h = try LibraryHarness()
        #expect(h.store.flags(for: .sample(id: 99)) == nil)
    }
}
