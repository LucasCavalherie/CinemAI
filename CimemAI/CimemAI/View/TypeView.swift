//
//  TypeView.swift
//  CimemAI
//
//  Created by Lucas Cavalherie on 22/06/23.
//

import SwiftUI

struct TypeView: View {
    
    var body: some View {
        NavigationStack {
            VStack (alignment: .center) {
                VStack (alignment: .leading) {
                    Text("Qual tipo de conteúdo você procura agora?")
                        .font(.system(size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(Color("Azul_Quase_Preto"))
                }
                .padding(.horizontal)
                
                
                HStack {
                    NavigationLink {
                        MethodScreen(type: "filme")
                    } label: {
                        Text("Filme")
                            .font(.system(size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 150, height: 60, alignment: .center)
                            .background(Color("Azul_Escuro"))
                            .cornerRadius(16)
                    }
                    
                    .padding(.vertical, 8)

                    Spacer()
                    
                    NavigationLink {
                        MethodScreen(type: "série")
                    } label: {
                        Text("Série")
                            .font(.system(size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 150, height: 60, alignment: .center)
                            .background(Color("Azul"))
                            .cornerRadius(16)
                    }
                    
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 32)
            }
        }
        
    }
}

struct TypeView_Previews: PreviewProvider {
    static var previews: some View {
        TypeView()
    }
}
