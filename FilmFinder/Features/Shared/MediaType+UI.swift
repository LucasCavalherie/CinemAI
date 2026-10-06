import SwiftUI

extension MediaType {
    var pluralName: LocalizedStringKey {
        switch self {
        case .movie: "Filmes"
        case .tv: "Séries"
        }
    }

    var pluralNameString: String {
        switch self {
        case .movie: String(localized: "Filmes")
        case .tv: String(localized: "Séries")
        }
    }
}
