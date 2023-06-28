import Foundation

struct SerieData: Identifiable, Codable{
    let id = UUID()
    let idFilme: Int32
    let title: String
    let image: String
    let releaseDate: String
    let originalTitle: String?
    let duration: Int
    let plot: String
    let rating : Double
    var favorite : Bool?
    var saved : Bool?
    var watched : Bool?

    
}

struct SerieSearchData: Identifiable{
    let id = UUID()
    let idImdb: String
}


