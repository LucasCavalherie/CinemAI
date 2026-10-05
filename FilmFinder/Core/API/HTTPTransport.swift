import Foundation

struct HTTPTransport: Sendable {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func send<Response: Decodable>(_ method: String, _ path: String, bearer: String? = nil) async throws -> Response {
        try await perform(method, path, body: nil, bearer: bearer)
    }

    func send<Body: Encodable, Response: Decodable>(
        _ method: String, _ path: String, body: Body, bearer: String? = nil
    ) async throws -> Response {
        try await perform(method, path, body: try JSONEncoder().encode(body), bearer: bearer)
    }

    func fetchChallenge() async throws -> String {
        let response: ChallengeResponse = try await send("POST", "v1/auth/challenge")
        return response.challenge
    }

    private func perform<Response: Decodable>(
        _ method: String, _ path: String, body: Data?, bearer: String?
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 45
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "content-type")
        }
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "authorization") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw Self.map(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw Self.map(status: http.statusCode, body: data) }
        do {
            return try JSONDecoder.api.decode(Response.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    private struct ErrorEnvelope: Decodable {
        struct Body: Decodable { let code: String; let message: String }
        let error: Body
    }

    private static func map(status: Int, body: Data) -> APIError {
        let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: body))?.error.message
        switch status {
        case 401: return .unauthorized
        case 402: return .quotaExceeded
        case 403: return .forbidden(message ?? "Forbidden")
        case 503: return .serviceUnavailable
        case 400: return .invalidInput(message ?? "Invalid request")
        default: return .server(message ?? "HTTP \(status)")
        }
    }

    private static func map(_ error: URLError) -> Error {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return APIError.offline
        case .timedOut:
            return APIError.serviceUnavailable
        case .cancelled:
            return CancellationError()
        default:
            return APIError.server(error.localizedDescription)
        }
    }
}
