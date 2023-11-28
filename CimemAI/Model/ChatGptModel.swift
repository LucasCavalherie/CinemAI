import Foundation

struct Prompt: Codable {
    let role: String
    let content: String
}

struct Request: Codable {
    let model: String
    let messages: [Prompt]
}
