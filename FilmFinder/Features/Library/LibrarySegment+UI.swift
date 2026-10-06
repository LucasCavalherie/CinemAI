import SwiftUI

extension LibrarySegment {
    var title: LocalizedStringKey {
        switch self {
        case .favorites: "Favoritos"
        case .watched: "Assistidos"
        case .history: "Histórico"
        }
    }

    var emptyTitle: LocalizedStringKey {
        switch self {
        case .favorites: "Nada favoritado ainda"
        case .watched: "Nada assistido ainda"
        case .history: "Seu histórico está vazio"
        }
    }

    var emptyMessage: LocalizedStringKey {
        switch self {
        case .favorites: "Toque no coração de um título para guardá-lo aqui."
        case .watched: "Marque títulos como assistidos para acompanhá-los aqui."
        case .history: "Os títulos que o app recomendar aparecem aqui."
        }
    }

    var emptyIcon: String {
        switch self {
        case .favorites: "heart"
        case .watched: "eye"
        case .history: "clock.arrow.circlepath"
        }
    }

    var removedMessage: LocalizedStringKey {
        switch self {
        case .favorites: "Removido dos favoritos"
        case .watched: "Removido dos assistidos"
        case .history: "Removido do histórico"
        }
    }
}
