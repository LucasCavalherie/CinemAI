import Foundation

struct APIConfig: Sendable, Equatable {
    let baseURL: URL

    enum ConfigError: Error, Equatable {
        case missing(String)
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    init(infoDictionary: [String: Any]?) throws {
        guard let raw = infoDictionary?["APIBaseURL"] as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil
        else { throw ConfigError.missing("APIBaseURL") }
        self.init(baseURL: url)
    }

    static func live() throws -> APIConfig {
        try APIConfig(infoDictionary: Bundle.main.infoDictionary)
    }
}
