import Foundation

struct FindData: Identifiable{
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

struct SearchData: Identifiable{
    let id = UUID()
    let idImdb: String
}
