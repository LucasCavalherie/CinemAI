import Foundation

class DataManager {
    static let shared = DataManager()
    
    private let favoritesKey = "favorites"
    private let watchedKey = "watched"
    private let customListsKey = "customLists"
    private let watchedContentKey = "watchedContent"
    private let defaults = UserDefaults.standard
    
    struct CustomList: Codable {
        let name: String
        let filmes: [FilmData]
        let series: [SerieData]
    }
    
    // MARK: - Filmes
    
    func saveContentToFavorites(content: WatchedContent) {
        var contents = getContentsFromFavorites()
        if !contents.contains(where: { $0.content.idFilme == content.content.idFilme }) {
            contents.append(content)
            saveContentsToFavorites(contents: contents)
        }
    }

    func removeContentFromFavorites(content: WatchedContent) {
        var contents = getContentsFromFavorites()
        contents.removeAll { $0.content.idFilme == content.content.idFilme }
        saveContentsToFavorites(contents: contents)
    }

    func getContentsFromFavorites() -> [WatchedContent] {
        guard let data = defaults.data(forKey: favoritesKey) else {
            return []
        }
        do {
            let contents = try JSONDecoder().decode([WatchedContent].self, from: data)
            return contents
        } catch {
            print("Erro ao decodificar conteúdos favoritos: \(error)")
            return []
        }
    }

    private func saveContentsToFavorites(contents: [WatchedContent]) {
        do {
            let data = try JSONEncoder().encode(contents)
            defaults.set(data, forKey: favoritesKey)
        } catch {
            print("Erro ao codificar conteúdos favoritos: \(error)")
        }
    }

    func saveContentToWatched(content: WatchedContent) {
        var contents = getContentsFromWatched()
        if !contents.contains(where: { $0.content.idFilme == content.content.idFilme }) {
            contents.append(content)
            saveContentsToWatched(contents: contents)
        }
    }

    func removeContentFromWatched(content: WatchedContent) {
        var contents = getContentsFromWatched()
        contents.removeAll { $0.content.idFilme == content.content.idFilme }
        saveContentsToWatched(contents: contents)
    }

    func getContentsFromWatched() -> [WatchedContent] {
        guard let data = defaults.data(forKey: watchedKey) else {
            return []
        }
        do {
            let contents = try JSONDecoder().decode([WatchedContent].self, from: data)
            return contents
        } catch {
            print("Erro ao decodificar conteúdos assistidos: \(error)")
            return []
        }
    }

    private func saveContentsToWatched(contents: [WatchedContent]) {
        do {
            let data = try JSONEncoder().encode(contents)
            defaults.set(data, forKey: watchedKey)
        } catch {
            print("Erro ao codificar conteúdos assistidos: \(error)")
        }
    }
    func checkFilmesAlreadyInToWatched(filme: FilmData) -> Bool {
        var filmes = getFilmesFromFavorites()
        if !filmes.contains(where: { $0.idFilme == filme.idFilme }) {
            return false
        }
        return true
    }

    
    // MARK: - History
    
    func saveWatchedContent(_ content: WatchedContent) {
        var watchedContent = getWatchedContent()
        watchedContent.append(content)
        saveWatchedContent(watchedContent)
    }
    func removeWatchedContent(at index: Int) {
        var watchedContent = getWatchedContent()
        if index >= 0 && index < watchedContent.count {
            watchedContent.remove(at: index)
            saveWatchedContent(watchedContent)
        }
    }
    func getWatchedContent() -> [WatchedContent] {
        guard let data = defaults.data(forKey: watchedContentKey) else {
            return []
        }
        do {
            let watchedContent = try JSONDecoder().decode([WatchedContent].self, from: data)
            return watchedContent
        } catch {
            print("Erro ao decodificar conteúdo assistido: \(error)")
            return []
        }
    }
    private func saveWatchedContent(_ content: [WatchedContent]) {
        do {
            let data = try JSONEncoder().encode(content)
            defaults.set(data, forKey: watchedContentKey)
        } catch {
            print("Erro ao codificar conteúdo assistido: \(error)")
        }
    }
    func getFilm(by id: Int32) -> FilmData? {
        let watchedContent = getWatchedContent()
        
        for content in watchedContent {
            if let film = content as? FilmData, film.idFilme == id {
                return film
            }
        }
        
        return nil
    }
    func getSerie(by id: Int32) -> SerieData? {
        let watchedContent = getWatchedContent()

        for content in watchedContent {
            if let serie = content as? SerieData, serie.idFilme == id {
                return serie
            }
        }
        
        return nil
    }
}
