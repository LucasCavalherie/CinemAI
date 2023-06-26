import SwiftUI

struct IMDbDetail: View {
    let conteudo: FindData
    
    var ratingAsStars: Int {
        return Int((Double(conteudo.imDbRating) ?? 0) / 2.0 + 0.5)
    }

    
    var body: some View {
        ScrollView{
            VStack(spacing: -25){
                AsyncImage(url: URL(string: conteudo.image)) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Color.red
                    } else {
                        Color.blue
                    }
                }
                VStack(alignment: .leading, spacing: 19){
                    VStack(alignment: .leading, spacing: 5){
                        Text(conteudo.title)
                            .font(Font.custom("Poppins-Regular", size: 24))
                            .foregroundColor(Color("Azul _Escuro"))
                            .fontWeight(.semibold)
                            .padding(.top)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            ForEach(0..<ratingAsStars, id: \.self) { _ in
                                Text(.init(systemName: "star.fill"))
                                    .foregroundColor(.black)
                                    .font(.system(size: 14))
                            }
                            ForEach(0..<(5-ratingAsStars), id: \.self) { _ in
                                Text(.init(systemName: "star"))
                                    .foregroundColor(.black)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    HStack(spacing: 10){
                        HStack{
                            Text(.init(systemName: "clock"))
                                .font(Font.custom("SF Pro", size: 14))
                            Text("\(conteudo.duracao) min")
                                .font(Font.custom("SF Pro", size: 14))
                                .multilineTextAlignment(.center)
                                
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 10)
                        .background(Rectangle()
                            .foregroundColor(.clear)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .inset(by: 0.5)
                                    .stroke(Color(red: 0, green: 0.07, blue: 0.1), lineWidth: 1)
                            ))
                        Text(conteudo.year)
                            .font(Font.custom("SF Pro", size: 14))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 20)
                            .background(Rectangle()
                                .foregroundColor(.clear)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .inset(by: 0.5)
                                        .stroke(Color(red: 0, green: 0.07, blue: 0.1), lineWidth: 1)
                                ))
                            
                        Spacer()
                    }.padding(.leading, 30)
                    HStack{
                        Text("DIRIGIDO POR:")
                            .font(Font.custom("Poppins-Regular", size: 14))
                        Text(conteudo.director)
                            .font(Font.custom("Poppins-Regular", size: 14))
                            .bold()
                    }.padding(.horizontal, 30)
                    Text(conteudo.plot)
                        .font(Font.custom("SF Pro", size: 16))
                        .padding(.horizontal, 30)
                    
                    
                    
                }.background(Rectangle()
                    .foregroundColor(.white)
                    .cornerRadius(28))
            }
        }.ignoresSafeArea()
    }
}

struct IMDbDetail_Previews: PreviewProvider {
    static var previews: some View {
        IMDbDetail(conteudo: FindData(idImdb: "tt4154796", title: "Avengers: Endgame", originalTitle: "Avengers: Endgame (2019)", image:  "https://m.media-amazon.com/images/M/MV5BMTc5MDE2ODcwNV5BMl5BanBnXkFtZTgwMzI2NzQ2NzM@._V1_Ratio0.6762_AL_.jpg", releaseDate: "2019-04-26",year: "2019", duracao: "181", plot: "Depois dos eventos devastadores de “Guerra do Infinito”, o universo está em ruínas. Com a ajuda dos aliados que restam, os Vingadores juntam-se mais uma vez para tentar desfazer as ações de Thanos e restaurar a ordem ao universo.", type: "Movie", imDbRating: "8.4", director: "Anthony Russo, Joe Russo", stars: "Robert Downey Jr., Chris Evans, Mark Ruffalo"))
    }
}
