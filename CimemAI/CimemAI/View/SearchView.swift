//
//  SearchView.swift
//  CimemAI
//
//  Created by Lucas Cavalherie on 22/06/23.
//

import SwiftUI

struct SearchView: View {
    var type: String
    @State var message = ""
    
    var body: some View {
        NavigationStack {
            VStack (alignment: .center) {
                Text("Descreva tipo de entretenimento que você busca.")
                    .font(.system(size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.17, green: 0.17, blue: 0.17))
                    .padding(.bottom)
                
                TextField("Ex: filmes de romance que se passam em Nova York", text: $message, axis: .vertical)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(width: 300, height: 200, alignment: .topLeading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                
                NavigationLink {
                    ChatGptView(type: type, inputText: message)
                } label: {
                    Text("Pesquisar")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(width: 300, height: 60, alignment: .center)
                .background(Color(red: 0.15, green: 0.36, blue: 0.44))
                .cornerRadius(16)
                .padding(.vertical, 8)
            }
            .padding()
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(type: "filmes")
    }
}
