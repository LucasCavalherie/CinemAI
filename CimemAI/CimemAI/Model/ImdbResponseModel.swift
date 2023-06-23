import Foundation

struct FindResponse: Codable {
    let id: String
    let title: String
    let image: String
    let releaseDate: String
    let year: String
    let originalTitle: String?
    let duration: String?
    let plot: String
    let type: String
    let imDbRating : String
    let director: String
    let stars: String

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case title = "title"
        case image = "image"
        case releaseDate = "releaseDate"
        case year = "year"
        case originalTitle = "originalTitle"
        case duration = "runtimeMins"
        case plot = "plotLocal"
        case type = "type"
        case imDbRating = "imDbRating"
        case director = "directors"
        case stars = "stars"
        
    }
}

struct SearchResponse: Codable {
    let results: [SearchResultResponse]

    enum CodingKeys: String, CodingKey {
        case results = "results"
    }
}

struct SearchResultResponse: Codable {
    let id: String

    enum CodingKeys: String, CodingKey {
        case id = "id"
    }
}
