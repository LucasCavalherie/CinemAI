import Foundation

class SerieData: Identifiable, Codable{
    let id = UUID()
    let idFilme: Int32
    let title: String
    let image: String
    let releaseDate: String
    let originalTitle: String?
    let duration: Int
    let plot: String
    let rating : Double
    var favorite : Bool
    var watched : Bool
    
    init(idFilme: Int32, title: String, image: String, releaseDate: String, originalTitle: String?, duration: Int, plot: String, rating : Double, favorite : Bool, watched : Bool) {
        self.idFilme = idFilme
        self.title = title
        self.image = image
        self.releaseDate = releaseDate
        self.originalTitle = originalTitle
        self.duration = duration
        self.plot = plot
        self.rating = rating
        self.favorite = favorite
        self.watched = watched
    }
}

struct SerieSearchData: Identifiable{
    let id = UUID()
    let idImdb: String
}


