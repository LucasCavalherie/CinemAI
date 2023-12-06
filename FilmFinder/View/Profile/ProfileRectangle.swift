//
//  SwiftUIView.swift
//  FilmFinder
//
//  Created by André Wozniack on 05/12/23.
//

import SwiftUI

struct FavoriteRectangle: View {
    @ObservedObject var dataManager = DataManager.shared
    var body: some View {
        
        VStack{
            Text("Favoritos")
                .font(.system(size: 15))
                .fontWeight(.bold)
                .fontWidth(.expanded)
                .foregroundStyle(Color.laranja)
                .padding(.top)
            CustomDivider(color: .laranja, width: 2)
                .padding(.horizontal)
            
            HStack{
                switch dataManager.favorites.count{
                case 3:
                    ForEach(0..<3){ index in
                        HStack{
                            Card(content: dataManager.favorites[index])
                        }
                        
                    }
                case 2:
                    ForEach(0..<2){ index in
                        HStack{
                            Card(content: dataManager.favorites[index])
                        }
                    }
                case 1:
                    Card(content: dataManager.favorites[0])
                case 0:
                    Rectangle()
                        .frame(width: 95, height: 142)
                        .foregroundColor(.clear)
                default:
                    ForEach(0..<3){ index in
                        HStack{
                            Card(content: dataManager.favorites[index])
                        }
                    }
                }
            }
                
                
            
            
        }
        .background {
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 341, height: 207.3125)
                .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                .cornerRadius(15.5)
        }
        .frame(width: 341, height: 207.3125)
        

    }
}

struct WatchedRectangle: View {
    @ObservedObject var dataManager = DataManager.shared
    var body: some View {
        
        VStack{
            Text("Assistidos")
                .font(.system(size: 15))
                .fontWeight(.bold)
                .fontWidth(.expanded)
                .foregroundStyle(Color.laranja)
                .padding(.top)
            CustomDivider(color: .laranja, width: 2)
                .padding(.horizontal)
            
            HStack{
                switch dataManager.watched.count{
                case 3:
                    ForEach(0..<3){ index in
                        HStack{
                            Card(content: dataManager.watched[index])
                        }
                        
                    }
                case 2:
                    ForEach(0..<2){ index in
                        HStack{
                            Card(content: dataManager.watched[index])
                        }
                    }
                case 1:
                    Card(content: dataManager.watched[0])
                case 0:
                    Rectangle()
                        .frame(width: 95, height: 142)
                        .foregroundColor(.clear)
                default:
                    ForEach(0..<3){ index in
                        HStack{
                            Card(content: dataManager.watched[index])
                        }
                    }
                }
            }
                
                
            
            
        }
        .background {
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 341, height: 207.3125)
                .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                .cornerRadius(15.5)
        }
        .frame(width: 341, height: 207.3125)
        

    }
}

struct Card: View {
    
    @State var content: WatchedContent
    
    var body: some View {
        
        switch content.content {
        case .filme(let filme):
            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(filme.image)")) { phase in
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
            .frame(width: 95, height: 142)
            .clipped()
        case .serie(let serie):
            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(serie.image)")) { phase in
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
            .frame(width: 95, height: 142)
            .clipped()
        }
        

    }
}

#Preview {
    FavoriteRectangle()
}
