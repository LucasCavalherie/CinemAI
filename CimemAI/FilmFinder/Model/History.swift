import Foundation

struct WatchedContent: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let content: Content

    enum Content: Codable {
        var idFilme: Int32 {
            switch self {
            case .filme(let filmData):
                return filmData.idFilme
            case .serie(let serieData):
                return serieData.idFilme
            }
        }
        case filme(FilmData)
        case serie(SerieData)
        enum CodingKeys: CodingKey {
            case filme, serie
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let filme = try? container.decode(FilmData.self, forKey: .filme) {
                self = .filme(filme)
            } else if let serie = try? container.decode(SerieData.self, forKey: .serie) {
                self = .serie(serie)
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                          debugDescription: "Invalid value"))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .filme(let filme):
                try container.encode(filme, forKey: .filme)
            case .serie(let serie):
                try container.encode(serie, forKey: .serie)
            }
        }
    }
}
