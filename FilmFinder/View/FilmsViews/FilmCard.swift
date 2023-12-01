import Foundation
import SwiftUI

struct FilmCard: View {
    let conteudo : FilmData
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
                        FilmDetail(conteudo: conteudo)
                    } label: {
                        Text(.init(systemName: "plus"))
                            .foregroundStyle(.white)
                            .font(.system(size: 25))
                            .bold()
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



#Preview {
    FilmCard(conteudo: FilmData(idFilme: 19995, title: "Forest Gump: O Contador de Histórias", image: "/iNMP8uzV2Ing6ZCw0IICgEFVNfC.jpg", releaseDate: "2009-12-15", originalTitle: nil, duration: 162, plot: "Apesar de confinado a uma cadeira de rodas, Jake Sully, um ex-marine, continua a ser um combatente. Assim, é recrutado para uma missão a Pandora, um corpo celeste que orbita um enorme planeta gasoso, para explorar um mineral alternativo chamado Unobtainium, usado na Terra como recurso energético. Porém, devido ao facto de a atmosfera de Pandora ser altamente tóxica para os humanos, é usado um programa de avatares híbridos, que possibilita a transferência da mente de qualquer humano para um corpo nativo.", rating: 7.571, favorite: false, watched: false))
}
