//
//  MethodScreen.swift
//  CimemAI
//
//  Created by Lucas Cavalherie on 22/06/23.
//

import SwiftUI

struct MethodScreen: View {
    var body: some View {
        NavigationStack {
            VStack (alignment: .center) {
                Text("Qual método você prefere usar para encontrar o que assistir?")
                    .font(.system(size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.17, green: 0.17, blue: 0.17))
                
                NavigationLink {
                    SearchView()
                } label: {
                    Text("Escrever uma descrição")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(width: 300, height: 60, alignment: .center)
                .background(Color(red: 0.15, green: 0.36, blue: 0.44))
                .cornerRadius(16)
                .padding(.vertical, 8)
                
                NavigationLink {
                    SearchView()
                } label: {
                    Text("Selecione entre opções")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(width: 300, height: 60, alignment: .center)
                .background(Color(red: 0.26, green: 0.57, blue: 0.58))
                .cornerRadius(16)
                .padding(.vertical, 8)
            }
            .padding()
        }
    }
}

struct MethodScreen_Previews: PreviewProvider {
    static var previews: some View {
        MethodScreen()
    }
}
