import Foundation

struct FindData: Identifiable{
    let id = UUID()
    let idFilme: Int32
    let title: String
    let image: String
    let releaseDate: String
    let originalTitle: String?
    let duration: Int
    let plot: String
    let rating : Double
    
}

struct SearchData: Identifiable{
    let id = UUID()
    let idImdb: String
}


