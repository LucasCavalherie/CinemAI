import Foundation

struct MeResponse: Decodable, Equatable, Sendable {
    struct User: Decodable, Equatable, Sendable {
        let id: String
    }

    let user: User?
    let entitlements: [String]
    let quota: Quota
}
