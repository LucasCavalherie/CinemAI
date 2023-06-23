//
//  ResultsView.swift
//  CimemAI
//
//  Created by André Wozniack on 22/06/23.
//

import SwiftUI

struct ResultsView: View {
    
    let resultados: [FindData]
    
    var body: some View {
        NavigationStack{
            VStack(alignment: .leading, spacing: 16) {
                Text("Estes são os três filmes mais compatíveis com você hoje:")
                  .font(
                    Font.custom("Poppins", size: 24)
                      .weight(.bold)
                  )
                  .foregroundColor(.black)
                  .frame(width: 290, height: 110, alignment: .topLeading)
                
                ScrollView(.horizontal, showsIndicators: false){
                    HStack(spacing: 20){
                        NavigationLink {
                            IMDbDetail(conteudo: resultados[0])
                        } label: {
                            IMDbCard(conteudo: resultados[0])
                        }
                        NavigationLink {
                            IMDbDetail(conteudo: resultados[1])
                        } label: {
                            IMDbCard(conteudo: resultados[1])
                        }
                        NavigationLink {
                            IMDbDetail(conteudo: resultados[2])
                        } label: {
                            IMDbCard(conteudo: resultados[2])
                        }
                        
                        
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 0)
            .ignoresSafeArea()
        }
    }
}

struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        
        ResultsView(resultados: [
            FindData(idImdb: "tt0068646", title: "The Godfather", originalTitle: "", image: "https://m.media-amazon.com/images/M/MV5BM2MyNjYxNmUtYTAwNi00MTYxLWJmNWYtYzZlODY3ZTk3OTFlXkEyXkFqcGdeQXVyNzkwMjQ5NzM@._V1_Ratio0.7046_AL_.jpg", releaseDate: "1972-03-24",year: "1972" , duracao: "2h 55min", plot: "Baseado no best-seller de Mário Puzo, o filme acompanha o percurso de Don Vito Corleone, o patriarca de uma das mais notáveis e importantes famílias da máfia italiana de Nova Iorque.", type: "Movie", imDbRating: "9.8", director: "Francis Ford Coppola", stars: "Marlon Brando, Al Pacino, James Caan"),

            FindData(idImdb: "tt1216475", title: "Cars 2", originalTitle: "", image:"https://m.media-amazon.com/images/M/MV5BMTUzNTc3MTU3M15BMl5BanBnXkFtZTcwMzIxNTc3NA@@._V1_Ratio0.6762_AL_.jpg", releaseDate: "2011-06-24",year: "2011", duracao: "1h 46min", plot: "Relâmpago McQueen, a sua equipa e novas personagens percorrem o mundo na Corrida dos Campeões (World Grand Prix), que decorrerá em cinco países diferentes: Japão, Alemanha, Itália, França e Inglaterra. No entanto, Mate, envolvido numa confusão de identidade, salva a vida de um agente secreto britânico, Aston Martin, chamado Finn McMissile, e acaba envolvido num esquema de espionagem que dura 24 horas.", type: "Movie", imDbRating: "6.2", director: "John Lasseter, Bradford Lewis", stars: "Owen Wilson, Larry the Cable Guy, Michael Caine"),
            
            FindData(idImdb: "tt4154796", title: "Avengers: Endgame", originalTitle: "Avengers: Endgame (2019)", image:  "https://m.media-amazon.com/images/M/MV5BMTc5MDE2ODcwNV5BMl5BanBnXkFtZTgwMzI2NzQ2NzM@._V1_Ratio0.6762_AL_.jpg", releaseDate: "2019-04-26",year: "2019", duracao: "3h 1min", plot: "Depois dos eventos devastadores de “Guerra do Infinito”, o universo está em ruínas. Com a ajuda dos aliados que restam, os Vingadores juntam-se mais uma vez para tentar desfazer as ações de Thanos e restaurar a ordem ao universo.", type: "Movie", imDbRating: "8.4", director: "Anthony Russo, Joe Russo", stars: "Robert Downey Jr., Chris Evans, Mark Ruffalo")]
        )
    }
}