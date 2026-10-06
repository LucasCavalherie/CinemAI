import Testing
@testable import FilmFinder

@Suite struct CategoryQueryBuilderTests {
    @Test func returnsNilWhenNothingIsSelected() {
        #expect(CategoryQueryBuilder.query(mediaType: .movie, moods: [], genres: [], themes: []) == nil)
    }

    @Test func buildsOnlyTheSelectedParts() {
        let q = CategoryQueryBuilder.query(mediaType: .movie, moods: [], genres: ["Drama", "Romance"], themes: [])
        #expect(q == "I want to watch a movie. Genres: Drama, Romance.")
    }

    @Test func buildsAllPartsForSeries() {
        let q = CategoryQueryBuilder.query(mediaType: .tv, moods: ["Relaxado"], genres: ["Suspense"], themes: ["Crime", "Enigmas"])
        #expect(q == "I want to watch a TV series. Mood: Relaxado. Genres: Suspense. Themes: Crime, Enigmas.")
    }

    @Test func neverExceedsTheBackendLimit() {
        let many = (0..<80).map { "Categoria número \($0)" }
        let q = CategoryQueryBuilder.query(mediaType: .movie, moods: many, genres: many, themes: many)
        #expect((q?.count ?? 0) <= 500)
    }
}
