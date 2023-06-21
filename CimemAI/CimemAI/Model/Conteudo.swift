import Foundation

struct Conteudo: Identifiable{
    let id = UUID()
    let idImdb: String
    let title: String
    let originalTitle: String
    let image: String
    let releaseDate: String
    let duracao: String
    let plot: String
    let type : String
}
