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
            Text("Infelizmente não \nfuncionou desta vez.")
                .multilineTextAlignment(.center)
                .font(Font.custom("Poppins-regular", size: 28))
                .fontWeight(.bold)
                .padding(.bottom, 8)
            
            Text("Tente novamente mais tarde \nou descreva algo diferente.")
                .font(Font.custom("Poppins-regular", size: 18))
                .multilineTextAlignment(.center)
                .padding(.bottom)
            
            Image("pipoco")
                .resizable()
                .scaledToFit()
                .frame(width: 240)
                .padding(.bottom, 60)
                .padding(.top, 40)
            
            Button{
                presentationMode.wrappedValue.dismiss()
            } label: {
                HStack {
                    Image(systemName: "chevron.backward.circle")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Voltar")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 150, height: 60, alignment: .center)
            .background(Color(red: 0.15, green: 0.36, blue: 0.44))
            .cornerRadius(16)
            .padding(.vertical, 8)
        }
    }
}

struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorView()
    }
}
