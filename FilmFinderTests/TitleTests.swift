import Foundation
import Testing
@testable import FilmFinder

@Suite struct TitleTests {
    @Test func decodesBackendContract() throws {
        let response = try JSONDecoder.api.decode(RecommendationsResponse.self, from: fixtureData("recommendations"))
        #expect(response.titles.count == 2)
        let quota = try #require(response.quota)
        #expect(quota.used == 1)
        #expect(quota.limit == 5)
        #expect(quota.remaining == 4)
        #expect(quota.resetsAt == Date(timeIntervalSince1970: 1_791_244_800))

        let movie = response.titles[0]
        #expect(movie.id == "movie-157336")
        #expect(movie.mediaType == .movie)
        #expect(movie.originalTitle == "Interstellar")
        #expect(movie.year == 2014)
        #expect(movie.runtimeMinutes == 169)
        #expect(movie.seasons == nil)
        #expect(movie.genres == ["Aventura", "Ficção científica"])
        #expect(movie.providers.region == "BR")
        #expect(movie.providers.link?.absoluteString == "https://www.themoviedb.org/movie/157336/watch?locale=BR")
        #expect(movie.providers.flatrate.map(\.name) == ["Amazon Prime Video", "Max"])
        #expect(movie.providers.free.map(\.name) == ["Tubi"])

        let show = response.titles[1]
        #expect(show.id == "tv-70523")
        #expect(show.posterPath == nil)
        #expect(show.seasons == 3)
        #expect(show.providers.link == nil)
        #expect(show.providers.isEmpty)
    }

    @Test func quotaIsOptionalAndRemainingNeverGoesNegative() throws {
        let response = try JSONDecoder.api.decode(RecommendationsResponse.self, from: Data(#"{"titles":[],"quota":null}"#.utf8))
        #expect(response.titles.isEmpty)
        #expect(response.quota == nil)
        #expect(Quota(used: 7, limit: 5, resetsAt: .now).remaining == 0)
    }

    @Test func titleSurvivesJSONRoundTrip() throws {
        let original = Title.sample(id: 9, type: .tv)
        let decoded = try JSONDecoder().decode(Title.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func starsAreRoundedAndClamped() {
        #expect(Title.stars(for: 0) == 0)
        #expect(Title.stars(for: 7.571) == 4)
        #expect(Title.stars(for: 9.0) == 5)
        #expect(Title.stars(for: 10) == 5)
        #expect(Title.stars(for: 11) == 5)
        #expect(Title.stars(for: -1) == 0)
    }

    @Test func highlightedPrefersSubscriptionThenFree() throws {
        let response = try JSONDecoder.api.decode(RecommendationsResponse.self, from: fixtureData("recommendations"))
        #expect(response.titles[0].providers.highlighted(limit: 1).map(\.name) == ["Amazon Prime Video"])
        #expect(response.titles[0].providers.highlighted().count == 2)

        var onlyFree = response.titles[0].providers
        onlyFree.flatrate = []
        #expect(onlyFree.highlighted().map(\.name) == ["Tubi"])
        #expect(response.titles[1].providers.highlighted().isEmpty)
    }

    @Test func requestEncodesBackendFieldNames() throws {
        let request = RecommendationRequest(
            query: "algo leve", mediaType: .tv, excludeTmdbIds: [1, 2], locale: "pt-BR", region: "BR"
        )
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(json["query"] as? String == "algo leve")
        #expect(json["mediaType"] as? String == "tv")
        #expect(json["excludeTmdbIds"] as? [Int] == [1, 2])
        #expect(json["locale"] as? String == "pt-BR")
        #expect(json["region"] as? String == "BR")
    }
}

@Suite struct TMDBImageTests {
    @Test func buildsSizedURLs() {
        #expect(TMDBImage.poster("/a.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w500/a.jpg")
        #expect(TMDBImage.backdrop("/b.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w780/b.jpg")
        #expect(TMDBImage.logo("/c.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w92/c.jpg")
    }

    @Test func rejectsMissingOrMalformedPaths() {
        #expect(TMDBImage.poster(nil) == nil)
        #expect(TMDBImage.poster("") == nil)
        #expect(TMDBImage.poster("a.jpg") == nil)
    }
}

@Suite struct LocaleInfoTests {
    @Test func usesLanguageAndRegion() {
        #expect(LocaleInfo(Locale(identifier: "pt_BR")) == LocaleInfo(locale: "pt-BR", region: "BR"))
        #expect(LocaleInfo(Locale(identifier: "en_GB")) == LocaleInfo(locale: "en-GB", region: "GB"))
    }

    @Test func fallsBackWhenRegionIsMissingOrNotTwoLetters() {
        #expect(LocaleInfo(Locale(identifier: "en")) == LocaleInfo(locale: "en-US", region: "US"))
        #expect(LocaleInfo(Locale(identifier: "es_419")) == LocaleInfo(locale: "en-US", region: "US"))
    }
}
