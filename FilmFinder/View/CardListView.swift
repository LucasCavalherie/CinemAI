import SwiftUI

struct ContentCard: View {
    let watchedContent: WatchedContent
    
    var body: some View {
        HStack{
            switch watchedContent.content {
            case .filme(let film):
                NavigationLink(destination: FilmDetail(conteudo: film)) {
                    ContentCardMiniView(title: film.title,
                                        releaseDate: film.releaseDate,
                                        imageUrl: film.image,
                                        date: watchedContent.date)
                }
            case .serie(let serie):
                NavigationLink(destination: SerieDetail(conteudo: serie)) {
                    ContentCardMiniView(title: serie.title,
                                        releaseDate: serie.releaseDate,
                                        imageUrl: serie.image,
                                        date: watchedContent.date)
                }
            }
        }
    }
}

struct ContentCardMiniView: View {
    let title: String
    let releaseDate: String
    let imageUrl: String
    let date: Date
    
    var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()
    
    var body: some View {
        HStack {
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 70, height: 105)
                .background(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0), location: 0.00),
                            Gradient.Stop(color: .black, location: 0.98),
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                )
                .opacity(0.3)
                .background(Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 70, height: 105)
                    .background(
                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(imageUrl)")) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Color.red
                            } else {
                                Color.blue
                            }
                        }
                            .frame(width: 70, height: 105)
                            .clipped()
                    ))
            VStack(alignment: .leading, spacing: 8){
                Text(title)
                    .font(.system(size: 16))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(Color("Azul_Quase_Preto"))
                Text(releaseDate)
                    .font(.system(size: 13))
                    .foregroundColor(Color("Azul_Quase_Preto"))
                Text(dateFormatter.string(from: date))
                    .font(.system(size: 10))
                    .foregroundColor(Color(uiColor: .gray))
            }
            Spacer()
        }
        .padding(.leading)
        .frame(maxWidth: .infinity)
    }
}



struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        ContentCard(watchedContent: WatchedContent(date: Date(), content: .filme(FilmData(idFilme: 19995, title: "Avatar", image: "/iNMP8uzV2Ing6ZCw0IICgEFVNfC.jpg", releaseDate: "2009-12-15", originalTitle: nil, duration: 162, plot: "Apesar de confinado a uma cadeira de rodas, Jake Sully, um ex-marine, continua a ser um combatente. Assim, é recrutado para uma missão a Pandora, um corpo celeste que orbita um enorme planeta gasoso, para explorar um mineral alternativo chamado Unobtainium, usado na Terra como recurso energético. Porém, devido ao facto de a atmosfera de Pandora ser altamente tóxica para os humanos, é usado um programa de avatares híbridos, que possibilita a transferência da mente de qualquer humano para um corpo nativo.", rating: 7.571, favorite: false, watched: false))))
    }
}
