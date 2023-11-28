import Foundation

struct SerieFindResponse: Codable {
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
        case title = "name"
        case image = "poster_path"
        case releaseDate = "first_air_date"
        case originalTitle = "originalTitle"
        case duration = "number_of_seasons"
        case plot = "overview"
        case rating = "vote_average"
        
    }
}

struct SerieSearchResponse: Codable {
    let results: [SerieSearchResultResponse]

    enum CodingKeys: String, CodingKey {
        case results = "results"
    }
}

struct SerieSearchResultResponse: Codable {
    let id: Int32

    enum CodingKeys: String, CodingKey {
        case id = "id"
    }
}
