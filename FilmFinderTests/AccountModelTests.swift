import Foundation
import Testing
@testable import FilmFinder

private let quota = Quota(used: 2, limit: 5, resetsAt: Date(timeIntervalSince1970: 1_791_244_800))

final class FakeAccountService: AccountService, @unchecked Sendable {
    var meResults: [Result<MeResponse, APIError>] = []
    var signInResult: Result<MeResponse, APIError> = .success(MeResponse(user: .init(id: "u1"), entitlements: [], quota: quota))
    var challenges = ["c1", "c2", "c3"]
    var signOutError: APIError?
    var deleteError: APIError?
    private(set) var signInCalls: [(token: String, code: String, challenge: String)] = []
    private(set) var signOutCalls = 0
    private(set) var deleteCalls = 0

    func challenge() async throws -> String { challenges.removeFirst() }

    func me() async throws -> MeResponse {
        guard !meResults.isEmpty else { return MeResponse(user: nil, entitlements: [], quota: quota) }
        return try meResults.removeFirst().get()
    }

    func signIn(identityToken: String, authorizationCode: String, challenge: String) async throws -> MeResponse {
        signInCalls.append((identityToken, authorizationCode, challenge))
        return try signInResult.get()
    }

    func signOut() async throws {
        signOutCalls += 1
        if let signOutError { throw signOutError }
    }

    func deleteAccount() async throws {
        deleteCalls += 1
        if let deleteError { throw deleteError }
    }
}

@Suite struct HashingTests {
    @Test func sha256HexMatchesTheKnownVector() {
        #expect(sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}

@MainActor
@Suite struct AccountModelTests {
    @Test func refreshLoadsQuotaAndSignedInState() async {
        let service = FakeAccountService()
        service.meResults = [.success(MeResponse(user: .init(id: "u1"), entitlements: ["unlimited_search"], quota: quota))]
        let model = AccountModel(service: service)

        await model.refresh()

        #expect(model.isSignedIn)
        #expect(model.quota == quota)
        #expect(model.quota?.remaining == 3)
        #expect(model.lastError == nil)
    }

    @Test func refreshFailureKeepsThePreviousStateAndReportsTheError() async {
        let service = FakeAccountService()
        service.meResults = [.success(MeResponse(user: nil, entitlements: [], quota: quota)), .failure(.offline)]
        let model = AccountModel(service: service)
        await model.refresh()

        await model.refresh()

        #expect(model.quota == quota)
        #expect(model.lastError == .offline)
    }

    @Test func updateQuotaReplacesTheCurrentValue() {
        let model = AccountModel(service: FakeAccountService())
        model.update(quota: quota)
        #expect(model.quota == quota)
    }

    @Test func prepareSignInExposesTheHashedChallengeAsNonce() async {
        let service = FakeAccountService()
        let model = AccountModel(service: service)
        #expect(model.signInNonce == nil)

        await model.prepareSignIn()

        #expect(model.signInNonce == sha256Hex("c1"))
    }

    @Test func completeSignInSendsTheChallengeAndPreparesANewOne() async {
        let service = FakeAccountService()
        let model = AccountModel(service: service)
        await model.prepareSignIn()

        await model.completeSignIn(identityToken: "idt", authorizationCode: "code")

        #expect(service.signInCalls.count == 1)
        #expect(service.signInCalls.first?.challenge == "c1")
        #expect(service.signInCalls.first?.token == "idt")
        #expect(service.signInCalls.first?.code == "code")
        #expect(model.isSignedIn)
        #expect(model.signInNonce == sha256Hex("c2"))
        #expect(!model.isBusy)
    }

    @Test func completeSignInWithoutPreparationFails() async {
        let service = FakeAccountService()
        let model = AccountModel(service: service)

        await model.completeSignIn(identityToken: "idt", authorizationCode: "code")

        #expect(service.signInCalls.isEmpty)
        #expect(model.lastError != nil)
        #expect(!model.isSignedIn)
    }

    @Test func signInFailureReportsTheErrorAndStillPreparesANewChallenge() async {
        let service = FakeAccountService()
        service.signInResult = .failure(.unauthorized)
        let model = AccountModel(service: service)
        await model.prepareSignIn()

        await model.completeSignIn(identityToken: "idt", authorizationCode: "code")

        #expect(model.lastError == .unauthorized)
        #expect(!model.isSignedIn)
        #expect(model.signInNonce == sha256Hex("c2"))
    }

    @Test func signOutCallsTheServiceAndRefreshes() async {
        let service = FakeAccountService()
        service.meResults = [
            .success(MeResponse(user: .init(id: "u1"), entitlements: [], quota: quota)),
            .success(MeResponse(user: nil, entitlements: [], quota: quota)),
        ]
        let model = AccountModel(service: service)
        await model.refresh()
        #expect(model.isSignedIn)

        await model.signOut()

        #expect(service.signOutCalls == 1)
        #expect(!model.isSignedIn)
    }

    @Test func deleteAccountCallsTheServiceAndRefreshes() async {
        let service = FakeAccountService()
        service.meResults = [
            .success(MeResponse(user: .init(id: "u1"), entitlements: [], quota: quota)),
            .success(MeResponse(user: nil, entitlements: [], quota: quota)),
        ]
        let model = AccountModel(service: service)
        await model.refresh()

        await model.deleteAccount()

        #expect(service.deleteCalls == 1)
        #expect(!model.isSignedIn)
    }

    @Test func deleteFailureKeepsTheUserSignedInAndReportsTheError() async {
        let service = FakeAccountService()
        service.deleteError = .server("apple_unavailable")
        service.meResults = [.success(MeResponse(user: .init(id: "u1"), entitlements: [], quota: quota))]
        let model = AccountModel(service: service)
        await model.refresh()

        await model.deleteAccount()

        #expect(model.isSignedIn)
        #expect(model.lastError == .server("apple_unavailable"))
    }

    @Test func clearErrorResetsTheLastError() async {
        let service = FakeAccountService()
        service.meResults = [.failure(.offline)]
        let model = AccountModel(service: service)
        await model.refresh()
        model.clearError()
        #expect(model.lastError == nil)
    }
}
