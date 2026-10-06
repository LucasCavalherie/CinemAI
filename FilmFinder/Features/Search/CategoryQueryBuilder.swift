import Foundation

enum CategoryQueryBuilder {
    private static let maxLength = 500

    /// Monta o pedido em linguagem natural a partir das categorias escolhidas.
    /// Os nomes das categorias vão como estão (o modelo entende português e inglês).
    static func query(mediaType: MediaType, moods: [String], genres: [String], themes: [String]) -> String? {
        guard !(moods.isEmpty && genres.isEmpty && themes.isEmpty) else { return nil }
        var parts = ["I want to watch \(mediaType == .movie ? "a movie" : "a TV series")."]
        if !moods.isEmpty { parts.append("Mood: \(moods.joined(separator: ", ")).") }
        if !genres.isEmpty { parts.append("Genres: \(genres.joined(separator: ", ")).") }
        if !themes.isEmpty { parts.append("Themes: \(themes.joined(separator: ", ")).") }
        return String(parts.joined(separator: " ").prefix(maxLength))
    }
}
