//
//  IMDbDetail.swift
//  CimemAI
//
//  Created by André Wozniack on 22/06/23.
//

import SwiftUI

struct IMDbDetail: View {
    let conteudo: FindData
    
    var ratingAsStars: Int {
        return Int((Double(conteudo.imDbRating) ?? 0) / 2.0 + 0.5)
    }
    
    var body: some View {
        ScrollView{
            VStack(alignment: .leading){
                ZStack{
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
                    VStack(alignment: .leading){
                        Spacer()
                        Text(conteudo.title)
                          .font(
                            Font.custom("Poppins-Regular", size: 23)
                                .weight(.bold)
                          )
                          .foregroundColor(.white)
                        
                        //Estrelas
                        HStack{
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
                        .padding(.trailing, 200)
                          
                    }.frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 8){
                    Text("Sinopse:")
                      .font(
                        Font.custom("Poppins", size: 16)
                          .weight(.bold)
                      )
                      .foregroundColor(Color(red: 0.04, green: 0.58, blue: 0.59))
                      .frame(width: 98, height: 20, alignment: .topLeading)
                      .padding(.horizontal)

                    Text("\(conteudo.plot)")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                .padding()
                .background(Rectangle()
                .foregroundColor(.white))
            }
        }
        .ignoresSafeArea()

    }
}

struct IMDbDetail_Previews: PreviewProvider {
    static var previews: some View {
        IMDbDetail(conteudo: FindData(idImdb: "tt4154796", title: "Avengers: Endgame", originalTitle: "Avengers: Endgame (2019)", image:  "https://m.media-amazon.com/images/M/MV5BMTc5MDE2ODcwNV5BMl5BanBnXkFtZTgwMzI2NzQ2NzM@._V1_Ratio0.6762_AL_.jpg", releaseDate: "2019-04-26",year: "2019", duracao: "3h 1min", plot: "Depois dos eventos devastadores de “Guerra do Infinito”, o universo está em ruínas. Com a ajuda dos aliados que restam, os Vingadores juntam-se mais uma vez para tentar desfazer as ações de Thanos e restaurar a ordem ao universo.", type: "Movie", imDbRating: "8.4", director: "Anthony Russo, Joe Russo", stars: "Robert Downey Jr., Chris Evans, Mark Ruffalo"))
    }
}
