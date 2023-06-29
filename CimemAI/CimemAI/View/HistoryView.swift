//
//  HistoryView.swift
//  Film Finder
//
//  Created by André Wozniack on 29/06/23.
//

import SwiftUI

struct HistoryView: View {
    @State private var history = DataManager.shared.getWatchedContent()
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    var body: some View {
        List {
            ForEach(history, id: \.date) { watchedContent in
                VStack(alignment: .leading) {
                    
                    
                    HStack{
                        switch watchedContent.content {
                        case .filme(let filme):
                            
                            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(filme.image)")) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)// Displays the loaded image.
                                } else if phase.error != nil {
                                    Color.red
                                } else {
                                    Color.blue
                                }
                            }
                            Text(filme.title)
                        case .serie(let serie):
                            
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
                            Text(serie.title)
                        }
                    }
                    Text(dateFormatter.string(from: watchedContent.date))
                        .font(.callout)
                }
            }
        }
    }
}



struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
