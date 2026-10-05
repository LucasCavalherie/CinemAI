import Foundation
import Testing
@testable import FilmFinder

final class FakeService: RecommendationService, @unchecked Sendable {
    var results: [Result<[Title], APIError>]
    var quota: Quota? = Quota(used: 1, limit: 5, resetsAt: Date(timeIntervalSince1970: 1_791_244_800))
    private(set) var requests: [RecommendationRequest] = []

    init(_ results: [Result<[Title], APIError>]) { self.results = results }

    func recommend(_ request: RecommendationRequest) async throws -> RecommendationsResponse {
        requests.append(request)
        guard !results.isEmpty else { return RecommendationsResponse(titles: [], quota: quota) }
        return RecommendationsResponse(titles: try results.removeFirst().get(), quota: quota)
    }
}

private func titles(_ ids: ClosedRange<Int>, type: MediaType = .movie) -> [Title] {
    ids.map { Title.sample(id: $0, type: type, title: "T\($0)") }
}

@MainActor
@Suite struct ResultsModelTests {
    private func makeModel(
        _ service: FakeService, harness: LibraryHarness, type: MediaType = .movie,
        onQuota: (@MainActor (Quota) -> Void)? = nil
    ) -> ResultsModel {
        ResultsModel(
            mediaType: type, query: "algo leve", service: service, store: harness.store,
            localeInfo: LocaleInfo(locale: "pt-BR", region: "BR"), onQuota: onQuota
        )
    }

    @Test func loadShowsThreeAndBuffersTheRest() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...12))])
        let model = makeModel(service, harness: h)

        await model.load()

        #expect(model.phase == .loaded)
        #expect(model.visible.map(\.tmdbId) == [1, 2, 3])
        #expect(model.buffer.count == 9)
        #expect(service.requests.count == 1)
    }

    @Test func sendsLocaleRegionAndExclusionsOfTheSameMediaType() async throws {
        let h = try LibraryHarness()
        h.store.recordRecommended([.sample(id: 50, type: .movie), .sample(id: 60, type: .tv)])
        let service = FakeService([.success(titles(1...5))])

        await makeModel(service, harness: h).load()

        let sent = try #require(service.requests.first)
        #expect(sent.query == "algo leve")
        #expect(sent.mediaType == .movie)
        #expect(sent.locale == "pt-BR")
        #expect(sent.region == "BR")
        #expect(sent.excludeTmdbIds == [50])
        #expect(sent.excludeTitles == ["Sample (2020)"])
    }

    @Test func recordsAllTitlesButOnlyShownOnesEnterHistory() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...12))])

        await makeModel(service, harness: h).load()

        #expect(h.items.count == 12)
        #expect(h.items.filter(\.inHistory).count == 3)
        #expect(h.store.excludedIDs(for: .movie).count == 12)
    }

    @Test func swapUsesTheBufferWithoutANewRequest() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...12))])
        let model = makeModel(service, harness: h)
        await model.load()

        await model.swap(model.visible[1])

        #expect(model.visible.map(\.tmdbId) == [1, 4, 3])
        #expect(model.buffer.count == 8)
        #expect(service.requests.count == 1)
        #expect(try #require(h.item("movie-4")).inHistory)
    }

    @Test func swapWithEmptyBufferFetchesAgainExcludingRecordedTitles() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .success(titles(10...14))])
        let model = makeModel(service, harness: h)
        await model.load()
        #expect(model.buffer.isEmpty)

        await model.swap(model.visible[0])

        #expect(service.requests.count == 2)
        #expect(Set(service.requests[1].excludeTmdbIds) == [1, 2, 3])
        #expect(model.visible.map(\.tmdbId) == [10, 2, 3])
        #expect(model.buffer.map(\.tmdbId) == [11, 12, 13, 14])
    }

    @Test func swapFailureKeepsTheVisibleTitlesAndReportsTheError() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .failure(.offline)])
        let model = makeModel(service, harness: h)
        await model.load()

        await model.swap(model.visible[0])

        #expect(model.visible.map(\.tmdbId) == [1, 2, 3])
        #expect(model.swapError == .offline)
        #expect(model.phase == .loaded)
    }

    @Test func swapWithNothingNewLeavesTheCardInPlace() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .success([])])
        let model = makeModel(service, harness: h)
        await model.load()

        await model.swap(model.visible[0])

        #expect(model.visible.map(\.tmdbId) == [1, 2, 3])
        #expect(model.swapError == nil)
    }

    @Test func reportsTheQuotaOfEveryResponse() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...3)), .success(titles(10...12))])
        var seen: [Int] = []
        let model = makeModel(service, harness: h) { seen.append($0.used) }

        await model.load()
        service.quota = Quota(used: 2, limit: 5, resetsAt: Date(timeIntervalSince1970: 1_791_244_800))
        await model.swap(model.visible[0])

        #expect(seen == [1, 2])
    }

    @Test func emptyResponseIsTheEmptyPhase() async throws {
        let h = try LibraryHarness()
        let model = makeModel(FakeService([.success([])]), harness: h)
        await model.load()
        #expect(model.phase == .empty)
    }

    @Test func failureThenRetrySucceeds() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.failure(.serviceUnavailable), .success(titles(1...4))])
        let model = makeModel(service, harness: h)

        await model.load()
        #expect(model.phase == .failed(.serviceUnavailable))

        await model.retry()
        #expect(model.phase == .loaded)
        #expect(model.visible.count == 3)
    }

    @Test func loadRunsOnlyOnce() async throws {
        let h = try LibraryHarness()
        let service = FakeService([.success(titles(1...5)), .success(titles(6...9))])
        let model = makeModel(service, harness: h)

        await model.load()
        await model.load()

        #expect(service.requests.count == 1)
    }
}
