//
//  BackButton.swift
//  FilmFinder
//
//  Created by Lucas Cavalherie on 30/06/23.
//

import SwiftUI

struct BackButton: View {
    var body: some View {
        HStack {
            Image(systemName: "chevron.left")
                .font(.system(size: 20))
                .fontWeight(.bold)
                .foregroundColor(Color("laranja"))
            Text("Voltar")
                .font(.system(size: 17))
                .foregroundColor(Color("laranja"))
        }
        .padding(8)
        .cornerRadius(16)
    }
}

struct BackButton_Previews: PreviewProvider {
    static var previews: some View {
        BackButton()
    }
}
