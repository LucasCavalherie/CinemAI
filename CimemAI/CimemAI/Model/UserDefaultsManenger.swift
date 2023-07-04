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
    
    func saveFilmeToFavorites(filme: FilmData) {
        var filmes = getFilmesFromFavorites()
        if !filmes.contains(where: { $0.idFilme == filme.idFilme }) {
            filmes.append(filme)
            saveFilmesToFavorites(filmes: filmes)
        }
    }
    func removeFilmeFromFavorites(filme: FilmData) {
        var filmes = getFilmesFromFavorites()
        filmes.removeAll { $0.idFilme == filme.idFilme }
        saveFilmesToFavorites(filmes: filmes)
    }
    func getFilmesFromFavorites() -> [FilmData] {
        guard let data = defaults.data(forKey: favoritesKey) else {
            return []
        }
        do {
            let filmes = try JSONDecoder().decode([FilmData].self, from: data)
            return filmes
        } catch {
            print("Erro ao decodificar filmes favoritos: \(error)")
            return []
        }
    }
    private func saveFilmesToFavorites(filmes: [FilmData]) {
        do {
            let data = try JSONEncoder().encode(filmes)
            defaults.set(data, forKey: favoritesKey)
        } catch {
            print("Erro ao codificar filmes favoritos: \(error)")
        }
    }
    
    func saveFilmeToWatched(filme: FilmData) {
        var filmes = getFilmesFromWatched()
        if !filmes.contains(where: { $0.idFilme == filme.idFilme }) {
            filmes.append(filme)
            saveFilmesToWatched(filmes: filmes)
        }
    }
    func removeFilmeFromWatched(filme: FilmData) {
        var filmes = getFilmesFromWatched()
        filmes.removeAll { $0.idFilme == filme.idFilme }
        saveFilmesToWatched(filmes: filmes)
    }
    func getFilmesFromWatched() -> [FilmData] {
        guard let data = defaults.data(forKey: watchedKey) else {
            return []
        }
        do {
            let filmes = try JSONDecoder().decode([FilmData].self, from: data)
            return filmes
        } catch {
            print("Erro ao decodificar filmes assistidos: \(error)")
            return []
        }
    }
    private func saveFilmesToWatched(filmes: [FilmData]) {
        do {
            let data = try JSONEncoder().encode(filmes)
            defaults.set(data, forKey: watchedKey)
        } catch {
            print("Erro ao codificar filmes assistidos: \(error)")
        }
    }
    func checkFilmesAlreadyInToWatched(filme: FilmData) -> Bool {
        var filmes = getFilmesFromFavorites()
        if !filmes.contains(where: { $0.idFilme == filme.idFilme }) {
            return false
        }
        return true
    }
    
    // MARK: - Séries
    
    func saveSerieToFavorites(serie: SerieData) {
        var series = getSeriesFromFavorites()
        if !series.contains(where: { $0.idFilme == serie.idFilme }) {
            series.append(serie)
            saveSeriesToFavorites(series: series)
        }
    }
    func removeSerieFromFavorites(serie: SerieData) {
        var series = getSeriesFromFavorites()
        series.removeAll { $0.idFilme == serie.idFilme }
        saveSeriesToFavorites(series: series)
    }
    func getSeriesFromFavorites() -> [SerieData] {
        guard let data = defaults.data(forKey: favoritesKey) else {
            return []
        }
        do {
            let series = try JSONDecoder().decode([SerieData].self, from: data)
            return series
        } catch {
            print("Erro ao decodificar séries favoritas: \(error)")
            return []
        }
    }
    private func saveSeriesToFavorites(series: [SerieData]) {
        do {
            let data = try JSONEncoder().encode(series)
            defaults.set(data, forKey: favoritesKey)
        } catch {
            print("Erro ao codificar séries favoritas: \(error)")
        }
    }
    
    func saveSerieToWatched(serie: SerieData) {
        var series = getSeriesFromWatched()
        if !series.contains(where: { $0.idFilme == serie.idFilme }) {
            series.append(serie)
            saveSeriesToWatched(series: series)
        }
    }
    func removeSerieFromWatched(serie: SerieData) {
        var series = getSeriesFromWatched()
        series.removeAll { $0.idFilme == serie.idFilme }
        saveSeriesToWatched(series: series)
    }
    func getSeriesFromWatched() -> [SerieData] {
        guard let data = defaults.data(forKey: watchedKey) else {
            return []
        }
        do {
            let series = try JSONDecoder().decode([SerieData].self, from: data)
            return series
        } catch {
            print("Erro ao decodificar séries assistidas: \(error)")
            return []
        }
    }
    private func saveSeriesToWatched(series: [SerieData]) {
        do {
            let data = try JSONEncoder().encode(series)
            defaults.set(data, forKey: watchedKey)
        } catch {
            print("Erro ao codificar séries assistidas: \(error)")
        }
    }
    
    // MARK: - Custom
    
    func createCustomList(name: String, filmes: [FilmData], series: [SerieData]) {
        var customLists = getCustomLists()
    
        let filmeIds = Set(filmes.map { $0.idFilme })
        let existingFilmeIds = customLists.flatMap { $0.filmes }.map { $0.idFilme }
        let newFilmes = filmes.filter { !existingFilmeIds.contains($0.idFilme) }
        
        let newList = CustomList(name: name, filmes: newFilmes, series: series)
        customLists.append(newList)
        saveCustomLists(customLists)
    }
    func removeCustomList(at index: Int) {
        var customLists = getCustomLists()
        if index >= 0 && index < customLists.count {
            customLists.remove(at: index)
            saveCustomLists(customLists)
        }
    }
    func getCustomLists() -> [CustomList] {
        guard let data = defaults.data(forKey: customListsKey) else {
            return []
        }
        do {
            let customLists = try JSONDecoder().decode([CustomList].self, from: data)
            return customLists
        } catch {
            print("Erro ao decodificar listas personalizadas: \(error)")
            return []
        }
    }
    private func saveCustomLists(_ customLists: [CustomList]) {
        do {
            let data = try JSONEncoder().encode(customLists)
            defaults.set(data, forKey: customListsKey)
        } catch {
            print("Erro ao codificar listas personalizadas: \(error)")
        }
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
}

