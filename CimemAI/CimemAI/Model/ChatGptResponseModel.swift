
import Foundation

struct ChatGptResponse: Codable {
    let choices: [ChatGptResultResponse]

    enum CodingKeys: String, CodingKey {
        case choices = "choices"
    }
}

struct ChatGptResultResponse: Codable {
    let text: String

    enum CodingKeys: String, CodingKey {
        case text = "text"
    }
}
