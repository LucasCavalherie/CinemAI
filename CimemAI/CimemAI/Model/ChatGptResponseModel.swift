
import Foundation

struct ChatGptResponse: Codable {
    let choices: [ChatGptResultResponse]

    enum CodingKeys: String, CodingKey {
        case choices = "choices"
    }
}

struct ChatGptResultResponse: Codable {
    let message: ChatGptResultTextResponse

    enum CodingKeys: String, CodingKey {
        case message = "message"
    }
}

struct ChatGptResultTextResponse: Codable {
    let content: String

    enum CodingKeys: String, CodingKey {
        case content = "content"
    }
}
