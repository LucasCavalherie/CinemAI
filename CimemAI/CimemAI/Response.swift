import Foundation

struct Response: Codable {
    let id: String
    let title: String
    let image: String
    let fullTitle: String?
    let duration: String?
    let plot: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case title = "title"
        case image = "image"
        case fullTitle = "fullTitle"
        case duration = "runtimeStr"
        case plot = "plotLocal"
        case type = "type"
    }
}
