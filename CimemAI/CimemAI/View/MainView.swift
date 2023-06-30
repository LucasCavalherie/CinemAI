//
//  MainView.swift
//  FilmFinder
//
//  Created by Lucas Cavalherie on 30/06/23.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
                HistoryView()
                    .tabItem {
                        Label("Histórico", systemImage: "clock.arrow.circlepath")
                    }
            
                TypeView()
                    .tabItem {
                        Label("Recomendações", systemImage: "popcorn.circle.fill")
                    }
            
                ProfileView()
                    .tabItem {
                        Label("Perfil", systemImage: "person.circle.fill")
                    }

                
            }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
