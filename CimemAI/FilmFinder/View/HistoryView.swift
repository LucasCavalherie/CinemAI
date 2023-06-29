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
                    
                    switch watchedContent.content {
                    case .filme(let filme):
                        Text(filme.title)
                    case .serie(let serie):
                        Text(serie.title)
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
