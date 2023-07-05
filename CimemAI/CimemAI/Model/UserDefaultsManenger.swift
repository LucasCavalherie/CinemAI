import Foundation
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var allContent: [WatchedContent] = []  // Todos os filmes
    @Published var favorites: [WatchedContent] = []   // Filmes favoritos
    @Published var watched: [WatchedContent] = []     // Filmes assistidos

    private var cancellables: Set<AnyCancellable> = []

    init() {
        loadFromUserDefaults()
        setupBindings()
    }

    private func setupBindings() {
        $allContent
            .sink { [weak self] updatedContent in
                self?.updateFavorites(with: updatedContent)
                self?.updateWatched(with: updatedContent)
                self?.saveToUserDefaults()
            }
            .store(in: &cancellables)
    }

    func saveToUserDefaults() {
        let encoder = JSONEncoder()
        if let encodedFavorites = try? encoder.encode(favorites),
           let encodedWatched = try? encoder.encode(watched),
           let encodedAllContent = try? encoder.encode(allContent) {
            UserDefaults.standard.set(encodedFavorites, forKey: "favorites")
            UserDefaults.standard.set(encodedWatched, forKey: "watched")
            UserDefaults.standard.set(encodedAllContent, forKey: "allContent")
        }
    }

    func loadFromUserDefaults() {
        let decoder = JSONDecoder()
        if let savedFavorites = UserDefaults.standard.object(forKey: "favorites") as? Data,
           let savedWatched = UserDefaults.standard.object(forKey: "watched") as? Data,
           let savedAllContent = UserDefaults.standard.object(forKey: "allContent") as? Data {
            if let loadedFavorites = try? decoder.decode([WatchedContent].self, from: savedFavorites),
               let loadedWatched = try? decoder.decode([WatchedContent].self, from: savedWatched),
               let loadedAllContent = try? decoder.decode([WatchedContent].self, from: savedAllContent) {
                favorites = loadedFavorites
                watched = loadedWatched
                allContent = loadedAllContent
            }
        }
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
                
    func checkContentsAlreadyInToWatched(content: WatchedContent) -> Bool {
        switch content.content {
        case .filme(let filmData):
            return watched.contains(where: { if case .filme(let watchedFilmData) = $0.content { return watchedFilmData.idFilme == filmData.idFilme } else { return false } })
        case .serie(let serieData):
            return watched.contains(where: { if case .serie(let watchedSerieData) = $0.content { return watchedSerieData.idFilme == serieData.idFilme } else { return false } })
        }
    }

    func addContent(_ newContent: WatchedContent) {
        switch newContent.content {
        case .filme(let filmData):
            if !allContent.contains(where: { if case .filme(let allContentFilmData) = $0.content { return allContentFilmData.idFilme == filmData.idFilme } else { return false } }) {
                allContent.append(newContent)
            }
        case .serie(let serieData):
            if !allContent.contains(where: { if case .serie(let allContentSerieData) = $0.content { return allContentSerieData.idFilme == serieData.idFilme } else { return false } }) {
                allContent.append(newContent)
            }
        }
    }

    func addFavorite(_ favoriteContent: WatchedContent) {
        switch favoriteContent.content {
        case .filme(let filmData):
            if filmData.favorite && !favorites.contains(where: { $0.content.idFilme == favoriteContent.content.idFilme }) {
                favorites.append(favoriteContent)
            }
        case .serie(let serieData):
            if serieData.favorite && !favorites.contains(where: { $0.content.idFilme == favoriteContent.content.idFilme }) {
                favorites.append(favoriteContent)
            }
        }
    }

    func addWatched(_ watchedContent: WatchedContent) {
        switch watchedContent.content {
        case .filme(let filmData):
            if filmData.watched && !watched.contains(where: { $0.content.idFilme == watchedContent.content.idFilme }) {
                watched.append(watchedContent)
            }
        case .serie(let serieData):
            if serieData.watched && !watched.contains(where: { $0.content.idFilme == watchedContent.content.idFilme }) {
                watched.append(watchedContent)
            }
        }
    }

    
    func removeFavorite(_ content: WatchedContent) {
        
        switch content.content {
        case .filme(let filmData):
            favorites.removeAll { favoriteContent -> Bool in
                if case .filme(let favoriteFilmData) = favoriteContent.content {
                    return favoriteFilmData.idFilme == filmData.idFilme
                }
                return false
            }
        case .serie(let serieData):
            favorites.removeAll { favoriteContent -> Bool in
                if case .serie(let favoriteSerieData) = favoriteContent.content {
                    return favoriteSerieData.idFilme == serieData.idFilme
                }
                return false
            }
        }
        saveToUserDefaults()
    }
    
    func removeWatched(_ content: WatchedContent) {
        
        switch content.content {
        case .filme(let filmData):
            watched.removeAll { watchedContent -> Bool in
                if case .filme(let watchedFilmData) = watchedContent.content {
                    return watchedFilmData.idFilme == filmData.idFilme
                }
                return false
            }
        case .serie(let serieData):
            watched.removeAll { watchedContent -> Bool in
                if case .serie(let watchedSerieData) = watchedContent.content {
                    return watchedSerieData.idFilme == serieData.idFilme
                }
                return false
            }
        }
        
        saveToUserDefaults()
    }
}
