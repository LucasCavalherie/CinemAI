//
//  ResultsView.swift
//  CimemAI
//
//  Created by André Wozniack on 22/06/23.
//

import SwiftUI

struct ResultsView: View {
    
    let resultados: [FindData]
    
    var body: some View {
        NavigationStack{
            VStack(alignment: .leading, spacing: 16) {
                Text("Estes são os filmes mais compatíveis com você hoje:")
                  .font(
                    Font.custom("Poppins", size: 24)
                      .weight(.bold)
                  )
                  .foregroundColor(.black)
                  .frame(width: 290, height: 110, alignment: .topLeading)
                
                ScrollView(.horizontal, showsIndicators: false){
                    HStack(spacing: 20){
                        NavigationLink {
                            IMDbDetail(conteudo: resultados[0])
                        } label: {
                            IMDbCard(conteudo: resultados[0])
                        }
                        NavigationLink {
                            IMDbDetail(conteudo: resultados[1])
                        } label: {
                            IMDbCard(conteudo: resultados[1])
                        }
                        NavigationLink {
                            IMDbDetail(conteudo: resultados[2])
                        } label: {
                            IMDbCard(conteudo: resultados[2])
                        }
                        
                        
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 0)
            .ignoresSafeArea()
        }
    }
}

//struct ResultsView_Previews: PreviewProvider {
//    static var previews: some View {
//    
//    }
//}
