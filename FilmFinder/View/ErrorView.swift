//
//  ErrorPage.swift
//  CimemAI
//
//  Created by Júlia Savaris on 27/06/23.
// 

import SwiftUI

struct ErrorView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        VStack(alignment: .center) {
            Spacer()
            
            Image("onboardingTop")
                .padding()
            
            Image("error")
                .padding(.bottom, 2)
                .padding(.top, 20)

            VStack {
                Text("Não encontramos nada...")
                    .foregroundColor(Color("branco"))
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                Text("Tente novamente mais tarde ou descreva algo diferente")
                    .foregroundColor(Color("branco"))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
            }
            .padding(.vertical)
            .padding(.horizontal, 32)
            

            Button{
                presentationMode.wrappedValue.dismiss()
            } label: {
                HStack {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(Color("laranja"))

                    Text("Voltar")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(Color("laranja"))
                }
            }
            .padding(.vertical, 8)
            
            Spacer()
        }
    }
}

struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorView()
    }
}
