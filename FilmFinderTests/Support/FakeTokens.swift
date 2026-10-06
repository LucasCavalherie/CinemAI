import Foundation
@testable import FilmFinder

final class FakeTokens: AccessTokenProvider, @unchecked Sendable {
    var token: String
    var refreshed: String
    private(set) var refreshCalls: [String] = []

    init(token: String = "tok", refreshed: String = "tok2") {
        self.token = token
        self.refreshed = refreshed
    }

    func accessToken() async throws -> String { token }

    func refreshedAccessToken(after rejected: String) async throws -> String {
        refreshCalls.append(rejected)
        return refreshed
    }
}
