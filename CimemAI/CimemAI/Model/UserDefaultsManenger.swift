import Foundation
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var allContent: [WatchedContent] = []  // Todos os filmes
    @Published var favorites: [WatchedContent] = []   // Filmes favoritos
    @Published var watched: [WatchedContent] = []     // Filmes assistidos

    private var cancellables: Set<AnyCancellable> = []

    init() {
        setupBindings()
    }

    private func setupBindings() {
        $allContent
            .sink { [weak self] updatedContent in
                self?.updateFavorites(with: updatedContent)
                self?.updateWatched(with: updatedContent)
            }
            .store(in: &cancellables)
    }

    private func updateFavorites(with content: [WatchedContent]) {
        favorites = content.filter { watchedContent in
            switch watchedContent.content {
            case .filme(let filmData):
                return filmData.favorite
            case .serie(let serieData):
                return serieData.favorite
            }
        }
    }

    private func updateWatched(with content: [WatchedContent]) {
        watched = content.filter { watchedContent in
            switch watchedContent.content {
            case .filme(let filmData):
                return filmData.watched
            case .serie(let serieData):
                return serieData.watched
            }
        }
    }

    func addContent(_ newContent: WatchedContent) {
        allContent.append(newContent)
    }

    func addFavorite(_ favoriteContent: WatchedContent) {
        switch favoriteContent.content {
        case .filme(let filmData):
            if filmData.favorite {
                favorites.append(favoriteContent)
            }
        case .serie(let serieData):
            if serieData.favorite {
                favorites.append(favoriteContent)
            }
        }
    }

    func addWatched(_ watchedContent: WatchedContent) {
        switch watchedContent.content {
        case .filme(let filmData):
            if filmData.watched {
                watched.append(watchedContent)
            }
        case .serie(let serieData):
            if serieData.watched {
                watched.append(watchedContent)
            }
        }
    }
    
    func removeFavorite(_ content: WatchedContent) {
        favorites.removeAll { favoriteContent -> Bool in
            favoriteContent.id == content.id
        }
    }

    func removeWatched(_ content: WatchedContent) {
        watched.removeAll { watchedContent -> Bool in
            watchedContent.id == content.id
        }
    }

}
