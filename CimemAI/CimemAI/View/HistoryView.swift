//
//  HistoryView.swift
//  Film Finder
//
//  Created by André Wozniack on 29/06/23.
//

import SwiftUI

struct HistoryView: View {
    @State private var history = DataManager.shared.getWatchedContent()
    @State private var favoriteFilms = DataManager.shared.getFilmesFromFavorites()
    @State private var favoriteSeries = DataManager.shared.getSeriesFromFavorites()
       
    
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    var body: some View {
        NavigationStack{
            VStack{
                Button {
                    let domain = Bundle.main.bundleIdentifier!
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    UserDefaults.standard.synchronize()
                    print(DataManager.shared.getWatchedContent())

                } label: {
                    Text("RESET")
                }
                List {
                    ForEach(history, id: \.date) { watchedContent in
                        VStack(alignment: .leading) {
                            
                            HStack{
                                switch watchedContent.content {
                                case .filme(let filme):
                                    NavigationLink{
                                        let favoritoFilme = favoriteFilms.first(where: { $0.idFilme == filme.idFilme }) ?? filme
                                        FilmDetail(conteudo: favoritoFilme)
                                        
                                        
                                    } label: {
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
                                                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(filme.image)")) { phase in
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
                                            Text(filme.title)
                                                .font(.system(size: 16))
                                                .fontWeight(.bold)
                                            Text(filme.releaseDate)
                                                .font(.system(size: 13))
                                            Text(dateFormatter.string(from: watchedContent.date))
                                                .font(.system(size: 10))
                                                .foregroundColor(Color(uiColor: .gray))
                                        }
                                    }
                                case .serie(let serie):
                                    NavigationLink{
                                        let favoritoSerie = favoriteSeries.first(where: { $0.idFilme == serie.idFilme }) ?? serie
                                        SerieDetail(conteudo: favoritoSerie)
                                        
                                    } label: {
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
                                                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(serie.image)")) { phase in
                                                        if let image = phase.image {
                                                            image.resizable()
                                                                .aspectRatio(contentMode: .fill)// Displays the loaded image.
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
                                            Text(serie.title)
                                                .font(.system(size: 16))
                                                .fontWeight(.bold)
                                            Text(serie.releaseDate)
                                                .font(.system(size: 13))
                                            
                                            Text(dateFormatter.string(from: watchedContent.date))
                                                .font(.system(size: 10))
                                                .foregroundColor(Color(uiColor: .gray))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }.onAppear(perform: reload)
    }
    
    func reload(){
        self.history = DataManager.shared.getWatchedContent()
        self.favoriteFilms = DataManager.shared.getFilmesFromFavorites()
        self.favoriteSeries = DataManager.shared.getSeriesFromFavorites()
        print(favoriteFilms)
                
    }
}


struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
