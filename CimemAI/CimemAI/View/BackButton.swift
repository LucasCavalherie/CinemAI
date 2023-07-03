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
                .font(.system(size: 16))
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("Voltar")
                .font(.system(size: 16))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color("Azul"))
        .cornerRadius(16)
    }
}

struct BackButton_Previews: PreviewProvider {
    static var previews: some View {
        BackButton()
    }
}
