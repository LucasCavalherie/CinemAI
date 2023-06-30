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
                    
                    
                    VStack{
                        switch watchedContent.content {
                        case .filme(let filme):
                            HStack {
                                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(filme.image)")) { phase in
                                    if let image = phase.image {
                                        image.resizable()
                                    } else if phase.error != nil {
                                        Color.red
                                    } else {
                                        Color.blue
                                    }
                                }
                                .frame(width:75, height: 105)
                                .scaledToFit()
                                .cornerRadius(8)
                                
                                VStack (alignment: .leading) {
                                    Text(filme.title)
                                        .padding(.bottom, 4)
                                        .fontWeight(.bold)
                                    Text(dateFormatter.string(from: watchedContent.date))
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                            }
                            
                        case .serie(let serie):
                            
                            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(serie.image)")) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                } else if phase.error != nil {
                                    Color.red
                                } else {
                                    Color.blue
                                }
                            }
                            .frame(width:75, height: 105)
                            .scaledToFit()
                            .cornerRadius(8)
                            
                            VStack (alignment: .leading) {
                                Text(serie.title)
                                    .padding(.bottom, 4)
                                    .fontWeight(.bold)
                                Text(dateFormatter.string(from: watchedContent.date))
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                }
                .padding(.vertical, 4)
            }
        }
    }
}



struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
