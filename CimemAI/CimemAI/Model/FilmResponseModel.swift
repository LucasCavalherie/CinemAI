import Foundation

struct FindResponse: Codable {
    let id: Int32
    let title: String
    let image: String
    let releaseDate: String
    let originalTitle: String?
    let duration: Int
    let plot: String
    let rating : Double

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case title = "title"
        case image = "poster_path"
        case releaseDate = "release_date"
        case originalTitle = "originalTitle"
        case duration = "runtime"
        case plot = "overview"
        case rating = "vote_average"
        
    }
}

struct SearchResponse: Codable {
    let results: [SearchResultResponse]

    enum CodingKeys: String, CodingKey {
        case results = "results"
    }
}

struct SearchResultResponse: Codable {
    let id: Int32

    enum CodingKeys: String, CodingKey {
        case id = "id"
    }
}
