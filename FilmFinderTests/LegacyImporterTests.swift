import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LegacyImporterTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "legacy-\(UUID().uuidString)")!
    }

    private func movie(_ id: Int, title: String = "Avatar", favorite: Bool = false, watched: Bool = false, date: Double = 700_000_000) -> String {
        """
        {"id":"A1B2C3D4-0000-0000-0000-000000000001","date":\(date),"content":{"filme":{"id":"A1B2C3D4-0000-0000-0000-000000000002","idFilme":\(id),"title":"\(title)","image":"/abc.jpg","releaseDate":"2009-12-15","originalTitle":"2009-12-15","duration":162,"plot":"Plot","rating":7.5,"favorite":\(favorite),"watched":\(watched)}}}
        """
    }

    private func serie(_ id: Int, title: String = "Dark") -> String {
        """
        {"id":"A1B2C3D4-0000-0000-0000-000000000003","date":700000000,"content":{"serie":{"id":"A1B2C3D4-0000-0000-0000-000000000004","idFilme":\(id),"title":"\(title)","image":"","releaseDate":"2017-12-01","originalTitle":null,"duration":3,"plot":"Plot","rating":8.4,"favorite":false,"watched":false}}}
        """
    }

    private func set(_ defaults: UserDefaults, _ key: String, _ items: [String]) {
        defaults.set(Data("[\(items.joined(separator: ","))]".utf8), forKey: key)
    }

    @Test func importsAllContentWithFlagsFromListsAndItems() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1), movie(2), serie(3)])
        set(defaults, "favorites", [movie(1, favorite: true)])
        set(defaults, "watched", [movie(2, watched: true)])
        set(defaults, "history", [movie(1), serie(3)])

        let count = LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        #expect(count == 3)
        #expect(h.items.count == 3)
        let one = try #require(h.item("movie-1"))
        #expect(one.isFavorite && !one.isWatched && one.inHistory)
        let two = try #require(h.item("movie-2"))
        #expect(two.isWatched && !two.isFavorite && !two.inHistory)
        #expect(try #require(h.item("tv-3")).inHistory)
    }

    @Test func itemsOnlyPresentInFavoritesOrWatchedListsAreStillImported() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "favorites", [movie(7, favorite: true)])
        set(defaults, "watched", [movie(8, watched: true)])

        LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        #expect(try #require(h.item("movie-7")).isFavorite)
        #expect(try #require(h.item("movie-8")).isWatched)
    }

    @Test func mapsLegacyFieldsToTitle() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1), serie(3)])

        LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        let filmItem = try #require(h.item("movie-1"))
        let film = try #require(filmItem.snapshot)
        #expect(film.title == "Avatar")
        #expect(film.originalTitle == "Avatar")        // o campo legado guardava a data de lançamento
        #expect(film.year == 2009)
        #expect(film.posterPath == "/abc.jpg")
        #expect(film.runtimeMinutes == 162)
        #expect(film.seasons == nil)
        #expect(film.providers == .empty(region: "BR"))

        let showItem = try #require(h.item("tv-3"))
        let show = try #require(showItem.snapshot)
        #expect(show.seasons == 3)                      // `duration` de série era o nº de temporadas
        #expect(show.runtimeMinutes == nil)
        #expect(show.posterPath == nil)                 // imagem vazia
    }

    @Test func keepsTheLegacyDate() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1, date: 700_000_000)])

        LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded()

        let date = try #require(h.item("movie-1")).recommendedAt
        #expect(date == Date(timeIntervalSinceReferenceDate: 700_000_000))
    }

    @Test func runsOnlyOnceAndRemovesLegacyKeys() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [movie(1)])

        let importer = LegacyImporter(defaults: defaults, store: h.store, region: "BR")
        #expect(importer.runIfNeeded() == 1)
        #expect(importer.runIfNeeded() == 0)
        #expect(h.items.count == 1)
        #expect(LegacyImporter.legacyKeys.allSatisfy { defaults.object(forKey: $0) == nil })
        #expect(defaults.bool(forKey: LegacyImporter.doneKey))
    }

    @Test func skipsCorruptElementsButImportsTheRest() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        set(defaults, "allContent", [#"{"nonsense":true}"#, movie(1)])

        #expect(LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded() == 1)
    }

    @Test func noLegacyDataJustMarksDone() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()

        #expect(LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded() == 0)
        #expect(defaults.bool(forKey: LegacyImporter.doneKey))
    }

    @Test func undecodableDataIsKeptInsteadOfDeleted() throws {
        let h = try LibraryHarness()
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "allContent")

        #expect(LegacyImporter(defaults: defaults, store: h.store, region: "BR").runIfNeeded() == 0)
        #expect(defaults.data(forKey: "allContent") != nil)
    }
}
