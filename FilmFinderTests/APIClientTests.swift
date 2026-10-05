import Foundation
import Testing
@testable import FilmFinder

@Suite(.serialized) struct APIClientTests {
    private let base = URL(string: "https://api.example.com")!
    private let request = RecommendationRequest(
        query: "algo leve", mediaType: .movie, excludeTmdbIds: [1, 2], locale: "pt-BR", region: "BR"
    )

    private func client(_ tokens: FakeTokens = FakeTokens()) -> APIClient {
        APIClient(transport: HTTPTransport(baseURL: base, session: MockURLProtocol.session()), tokens: tokens)
    }

    private func errorBody(_ code: String, _ message: String) -> Data {
        Data(#"{"error":{"code":"\#(code)","message":"\#(message)"}}"#.utf8)
    }

    @Test func sendsExpectedRequestAndDecodesTitlesAndQuota() async throws {
        let body = try fixtureData("recommendations")
        nonisolated(unsafe) var captured: URLRequest?
        MockURLProtocol.handler = { req in
            captured = req
            return (httpResponse(req.url!, status: 200), body)
        }

        let response = try await client(FakeTokens(token: "abc")).recommend(request)

        #expect(response.titles.map(\.tmdbId) == [157336, 70523])
        #expect(response.quota?.remaining == 4)
        let sent = try #require(captured)
        #expect(sent.url?.absoluteString == "https://api.example.com/v1/recommendations")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "authorization") == "Bearer abc")
        #expect(sent.value(forHTTPHeaderField: "content-type") == "application/json")
        let sentBody = try #require(sent.bodyData())
        let json = try #require(JSONSerialization.jsonObject(with: sentBody) as? [String: Any])
        #expect(json["query"] as? String == "algo leve")
        #expect(json["mediaType"] as? String == "movie")
        #expect(json["excludeTmdbIds"] as? [Int] == [1, 2])
        #expect(json["locale"] as? String == "pt-BR")
        #expect(json["region"] as? String == "BR")
    }

    @Test func retriesOnceWithARefreshedTokenAfter401() async throws {
        let body = try fixtureData("recommendations")
        nonisolated(unsafe) var seen: [String] = []
        MockURLProtocol.handler = { req in
            let auth = req.value(forHTTPHeaderField: "authorization") ?? ""
            seen.append(auth)
            if auth == "Bearer new" { return (httpResponse(req.url!, status: 200), body) }
            return (httpResponse(req.url!, status: 401), self.errorBody("unauthorized", "expired"))
        }
        let tokens = FakeTokens(token: "old", refreshed: "new")

        _ = try await client(tokens).recommend(request)

        #expect(seen == ["Bearer old", "Bearer new"])
        #expect(tokens.refreshCalls == ["old"])
    }

    @Test func doesNotLoopWhenTheRefreshedTokenIsRejectedToo() async {
        nonisolated(unsafe) var attempts = 0
        MockURLProtocol.handler = { req in
            attempts += 1
            return (httpResponse(req.url!, status: 401), self.errorBody("unauthorized", "no"))
        }
        await #expect(throws: APIError.unauthorized) { try await client().recommend(request) }
        #expect(attempts == 2)
    }

    @Test func mapsHTTPStatusToAPIError() async {
        let cases: [(Int, Data, APIError)] = [
            (402, errorBody("quota_exceeded", "limit"), .quotaExceeded),
            (403, errorBody("forbidden", "not allowed"), .forbidden("not allowed")),
            (503, errorBody("ai_unavailable", "down"), .serviceUnavailable),
            (400, errorBody("invalid_input", "query too long"), .invalidInput("query too long")),
            (500, errorBody("internal", "boom"), .server("boom")),
            (502, Data("<html>bad gateway</html>".utf8), .server("HTTP 502")),
        ]
        for (status, body, expected) in cases {
            MockURLProtocol.handler = { req in (httpResponse(req.url!, status: status), body) }
            await #expect(throws: expected, "status \(status)") { try await client().recommend(request) }
        }
    }

    @Test func mapsConnectivityFailuresToOffline() async {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed] {
            MockURLProtocol.handler = { _ in throw URLError(code) }
            await #expect(throws: APIError.offline) { try await client().recommend(request) }
        }
    }

    @Test func mapsTimeoutToServiceUnavailable() async {
        MockURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: APIError.serviceUnavailable) { try await client().recommend(request) }
    }

    @Test func malformedSuccessBodyIsInvalidResponse() async {
        MockURLProtocol.handler = { req in (httpResponse(req.url!, status: 200), Data("{}".utf8)) }
        await #expect(throws: APIError.invalidResponse) { try await client().recommend(request) }
    }

    @Test func sessionInvalidatingErrorsAreFlagged() {
        #expect(APIError.unauthorized.invalidatesSession)
        #expect(APIError.forbidden("x").invalidatesSession)
        #expect(!APIError.offline.invalidatesSession)
        #expect(!APIError.quotaExceeded.invalidatesSession)
    }
}

@Suite struct APIConfigTests {
    @Test func readsInfoDictionary() throws {
        let config = try APIConfig(infoDictionary: ["APIBaseURL": "https://api.example.com"])
        #expect(config.baseURL.absoluteString == "https://api.example.com")
    }

    @Test func rejectsMissingOrInsecureValues() {
        #expect(throws: APIConfig.ConfigError.self) { try APIConfig(infoDictionary: nil) }
        #expect(throws: APIConfig.ConfigError.self) { try APIConfig(infoDictionary: ["APIBaseURL": "http://insecure.example.com"]) }
        #expect(throws: APIConfig.ConfigError.self) { try APIConfig(infoDictionary: ["APIBaseURL": "not a url"]) }
    }
}
