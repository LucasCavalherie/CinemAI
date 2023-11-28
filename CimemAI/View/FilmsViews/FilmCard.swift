import Foundation
import SwiftUI

struct FilmCard: View {
    let conteudo : FilmData
    
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
                .cornerRadius(13)
                .opacity(0.5)
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
            VStack{
                Spacer()
                Text(conteudo.title)
                  .font(
                    Font.custom("Poppins-Regular", size: 23)
                        .weight(.bold)
                  )
                  .foregroundColor(.white)
                  .padding(.bottom, 0.5)

                
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
                HStack(spacing: 5){
                    Spacer()
                    Text(.init(systemName: "ellipsis.circle"))
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                        .bold()
                        .padding(.trailing)
//                    Text("Ver mais")
//                        .foregroundColor(.white)
//                        .font(.system(size: 14))
//                        .bold()
                        
                    
                }.padding(.bottom)
                    
                
            }.frame(width: 290, height: 416)
                
        }.ignoresSafeArea()
    }
}
struct FilmCard_Previews: PreviewProvider {
    static var previews: some View {
        FilmCard(conteudo: FilmData(idFilme: 19995, title: "Fantástica Fábrica de Chocolate", image: "/iNMP8uzV2Ing6ZCw0IICgEFVNfC.jpg", releaseDate: "2009-12-15", originalTitle: nil, duration: 162, plot: "Apesar de confinado a uma cadeira de rodas, Jake Sully, um ex-marine, continua a ser um combatente. Assim, é recrutado para uma missão a Pandora, um corpo celeste que orbita um enorme planeta gasoso, para explorar um mineral alternativo chamado Unobtainium, usado na Terra como recurso energético. Porém, devido ao facto de a atmosfera de Pandora ser altamente tóxica para os humanos, é usado um programa de avatares híbridos, que possibilita a transferência da mente de qualquer humano para um corpo nativo.", rating: 7.571, favorite: false, watched: false))
    }
}
