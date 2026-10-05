import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LibraryFilterTests {
    private func entries(_ h: LibraryHarness) -> [LibraryEntry] {
        LibraryFilter.entries(from: h.items.sorted { $0.libraryKey < $1.libraryKey })
    }

    private func pianist() -> Title {
        Title(
            tmdbId: 9, mediaType: .movie, title: "O Pianista", originalTitle: "The Pianist", year: 2002,
            overview: "", posterPath: nil, backdropPath: nil, rating: 8, runtimeMinutes: 150, seasons: nil,
            genres: [], reason: "", providers: .empty(region: "BR")
        )
    }

    @Test func segmentsSelectByFlag() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1), true)
        h.store.setWatched(.sample(id: 2), true)
        h.store.markShown(.sample(id: 3))
        let all = entries(h)

        #expect(LibraryFilter(segment: .favorites).apply(to: all).map(\.title.tmdbId) == [1])
        #expect(LibraryFilter(segment: .watched).apply(to: all).map(\.title.tmdbId) == [2])
        #expect(LibraryFilter(segment: .history).apply(to: all).map(\.title.tmdbId) == [3])
    }

    @Test func itemWithSeveralFlagsAppearsInEachSegment() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.setFavorite(title, true)
        h.store.setWatched(title, true)
        let all = entries(h)

        #expect(LibraryFilter(segment: .favorites).apply(to: all).count == 1)
        #expect(LibraryFilter(segment: .watched).apply(to: all).count == 1)
        #expect(LibraryFilter(segment: .history).apply(to: all).isEmpty)
    }

    @Test func searchIgnoresCaseAndAccentsAndMatchesOriginalTitle() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1, title: "Amélie"), true)
        h.store.setFavorite(pianist(), true)
        let all = entries(h)

        #expect(LibraryFilter(segment: .favorites, query: "amelie").apply(to: all).map(\.title.tmdbId) == [1])
        #expect(LibraryFilter(segment: .favorites, query: "PIANISTA").apply(to: all).map(\.title.tmdbId) == [9])
        #expect(LibraryFilter(segment: .favorites, query: "the pian").apply(to: all).map(\.title.tmdbId) == [9])
        #expect(LibraryFilter(segment: .favorites, query: "   ").apply(to: all).count == 2)
        #expect(LibraryFilter(segment: .favorites, query: "zzz").apply(to: all).isEmpty)
    }

    @Test func mediaTypeFilterKeepsOnlyThatType() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1, type: .movie), true)
        h.store.setFavorite(.sample(id: 2, type: .tv), true)
        let all = entries(h)

        #expect(LibraryFilter(segment: .favorites, mediaType: .tv).apply(to: all).map(\.title.tmdbId) == [2])
        #expect(LibraryFilter(segment: .favorites, mediaType: nil).apply(to: all).count == 2)
    }

    @Test func applyPreservesInputOrder() throws {
        let h = try LibraryHarness()
        for id in 1...3 { h.store.setFavorite(.sample(id: id), true) }
        let reversed = Array(entries(h).reversed())

        #expect(LibraryFilter(segment: .favorites).apply(to: reversed).map(\.title.tmdbId) == [3, 2, 1])
    }

    @Test func itemsWithUndecodableSnapshotAreSkipped() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.setFavorite(title, true)
        try #require(h.item(title.id)).snapshotData = Data()

        #expect(entries(h).isEmpty)
    }

    @Test func countsPerSegment() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1), true)
        h.store.setFavorite(.sample(id: 2), true)
        h.store.setWatched(.sample(id: 2), true)
        let all = entries(h)

        #expect(LibraryFilter.count(.favorites, in: all) == 2)
        #expect(LibraryFilter.count(.watched, in: all) == 1)
        #expect(LibraryFilter.count(.history, in: all) == 0)
    }
}
