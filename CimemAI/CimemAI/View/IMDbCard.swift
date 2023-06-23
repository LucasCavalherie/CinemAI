import Foundation
import SwiftUI

struct IMDbCard: View {
    let conteudo : FindData
    
    var ratingAsStars: Int {
        return Int((Double(conteudo.imDbRating) ?? 0) / 2.0 + 0.5)
    }

    var body: some View {
        ZStack{
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 290, height: 416)
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
                .cornerRadius(13).opacity(0.3)
                .background(Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 290, height: 416)
                    .background(
                        AsyncImage(url: URL(string: conteudo.image)) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)// Displays the loaded image.
                            } else if phase.error != nil {
                                Color.red
                            } else {
                                Color.blue
                            }
                        }
                            .frame(width: 290, height: 416)
                            .clipped()
                    ).cornerRadius(17))
            VStack(alignment: .leading){
                Spacer()
                Text(conteudo.title)
                  .font(
                    Font.custom("Poppins-Regular", size: 23)
                        .weight(.bold)
                  )
                  .foregroundColor(.white)

                
                HStack {
                    ForEach(0..<ratingAsStars, id: \.self) { _ in
                        Text(.init(systemName: "star.fill"))
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                    }
                    ForEach(0..<(5-ratingAsStars), id: \.self) { _ in
                        Text(.init(systemName: "star"))
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                    }
                }
                .padding(.bottom)
                  
            }.frame(width: 290, height: 416)
                
        }.ignoresSafeArea()
    }
}

struct IMDbCard_Previews: PreviewProvider {
    static var previews: some View {
        IMDbCard(conteudo: FindData(idImdb: "tt4154796", title: "Avengers: Endgame", originalTitle: "Avengers: Endgame (2019)", image:  "https://m.media-amazon.com/images/M/MV5BMTc5MDE2ODcwNV5BMl5BanBnXkFtZTgwMzI2NzQ2NzM@._V1_Ratio0.6762_AL_.jpg", releaseDate: "2019-04-26",year: "2019", duracao: "3h 1min", plot: "Depois dos eventos devastadores de “Guerra do Infinito”, o universo está em ruínas. Com a ajuda dos aliados que restam, os Vingadores juntam-se mais uma vez para tentar desfazer as ações de Thanos e restaurar a ordem ao universo.", type: "Movie", imDbRating: "8.4", director: "Anthony Russo, Joe Russo", stars: "Robert Downey Jr., Chris Evans, Mark Ruffalo"))
    }
}
