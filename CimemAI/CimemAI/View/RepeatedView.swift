//
//  RepeatedView.swift
//  FilmFinder
//
//  Created by Lucas Cavalherie on 04/07/23.
//

import SwiftUI

struct RepeatedView: View {
    var type: String
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var btnBack : some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }){
            BackButton()
    }}
    
    var body: some View {
        NavigationStack {
            VStack (alignment: .center, spacing: 8) {
                Text("Você deseja filtrar por filmes não repetidos?")
                    .font(.system(size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(Color("Azul_Quase_Preto"))
                
                HStack {
                    NavigationLink {
                        MethodScreen(type: "filme", onlyRepeated: true)
                    } label: {
                        Text("Sim")
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
                        MethodScreen(type: "série", onlyRepeated: false)
                    } label: {
                        Text("Não")
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
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
    }
}

struct RepeatedView_Previews: PreviewProvider {
    static var previews: some View {
        RepeatedView(type: "filme")
    }
}
