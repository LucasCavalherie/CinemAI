import Foundation

struct WatchedContent: Codable {
    let date: Date
    let content: Content

    enum Content: Codable {
        case filme(FilmData)
        case serie(SerieData)

        // Codificação e decodificação personalizadas para lidar com casos associados
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
