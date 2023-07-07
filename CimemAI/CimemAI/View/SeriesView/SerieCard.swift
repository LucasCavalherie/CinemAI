import Foundation
import SwiftUI

struct SerieCard: View {
    let conteudo : SerieData
    
    var ratingAsStars: Int {
        return Int((Double(conteudo.rating)) / 2.0 + 0.5)
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
                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(conteudo.image)")) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Rectangle()
                                    .foregroundColor(Color(uiColor: .red))
                            } else {
                                Rectangle()
                                    .foregroundColor(Color(uiColor: .gray))
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
                  .padding(.bottom, 0.5)

                
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

struct SerieCard_Previews: PreviewProvider {
    static var previews: some View {
        SerieCard(conteudo: SerieData(idFilme: 19995, title: "Dark", image: "/5LoHuHWA4H8jElFlZDvsmU2n63b.jpg", releaseDate: "2017-12-01", originalTitle: nil, duration: 3, plot: "Quatro famílias iniciam uma desesperada busca por respostas quando uma criança desaparece e um complexo mistério envolvendo três gerações começa a se revelar.", rating: 8.427, favorite: false, watched: false))
    }
}
