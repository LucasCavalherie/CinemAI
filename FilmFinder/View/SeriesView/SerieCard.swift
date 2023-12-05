import Foundation
import SwiftUI

struct SerieCard: View {
    let conteudo : SerieData
    let width : CGFloat = 265
    let height : CGFloat = 375
    
    var ratingAsStars: Int {
        return Int((Double(conteudo.rating)) / 2.0 + 0.5)
    }

    var body: some View {
        ZStack{
            Rectangle()
            .foregroundColor(.clear)
            .frame(width: width, height: height)
            .background(
                LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0), location: 0.51),
                            Gradient.Stop(color: Color(red: 0.29, green: 0.01, blue: 0.46), location: 0.98),
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                )
            )
            .cornerRadius(14.1655)
                .background(Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: width, height: height)
                    .background(
                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(conteudo.image)")) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Rectangle()
                                    .foregroundColor(Color(uiColor: .red))
                            } else {
                                ProgressView()
                            }
                        }
                            .frame(width: width, height: height)
                            .clipped()
                    ).cornerRadius(17))
            VStack{
                HStack{
                    Spacer()
                    NavigationLink {
                        SerieDetail(conteudo: conteudo)
                    } label: {
                        Text(.init(systemName: "plus"))
                            .foregroundStyle(.white)
                            .font(.system(size: 25))
                            .bold()
                            .shadow(color: .preto, radius: 5)
                    }


                }
                .padding()
                Spacer()
                Text(conteudo.title)
                    .font(.system(size: 20))
                    .bold()
                  .foregroundColor(.white)
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 16)
                  .padding(.bottom, 8)

                
                HStack(alignment: .center) {
                    Spacer()
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
                    Spacer()
                }
                .padding(.bottom, 22)
            }
            .frame(width: width, height: height)
                
        }
    }
}

struct SerieCard_Previews: PreviewProvider {
    static var previews: some View {
        SerieCard(conteudo: SerieData(idFilme: 19995, title: "Dark", image: "/5LoHuHWA4H8jElFlZDvsmU2n63b.jpg", releaseDate: "2017-12-01", originalTitle: nil, duration: 3, plot: "Quatro famílias iniciam uma desesperada busca por respostas quando uma criança desaparece e um complexo mistério envolvendo três gerações começa a se revelar.", rating: 8.427, favorite: false, watched: false))
    }
}
