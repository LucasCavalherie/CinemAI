//
//  HistoryView.swift
//  CimemAI
//
//  Created by Júlia Savaris on 29/06/23.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(alignment: .center){
            
            Image("perfil")
                .resizable()
                .scaledToFit()
                .frame(width: 128)
                .padding(.top, 40)
            
            Text("Usuário")
                .font(Font.custom("Poppins-regular", size: 25))
                .fontWeight(.bold)
                .padding(.bottom, 30)
                .foregroundColor(Color(red: 0.22, green: 0.48, blue: 0.53))
                
            Button {
                print("ir para favoritos")
            } label: {
                VStack() {
                    HStack {
                        Text("Favoritos")
                            .font(Font.custom("Poppins-regular", size: 20))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0, green: 0.07, blue: 0.1))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0, green: 0.07, blue: 0.1))
                        
                    }
                    .padding(.horizontal, 36)
                    HStack (alignment: .center) {
                        Rectangle()
                            .foregroundColor(.gray)
                            .frame(width: 95, height: 143)
                            .padding(.horizontal, 2)
                        
                        Rectangle()
                            .foregroundColor(.gray)
                            .frame(width: 95, height: 143)
                            .padding(.horizontal, 2)

                        
                        Rectangle()
                            .foregroundColor(.gray)
                            .frame(width: 95, height: 143)
                            .padding(.horizontal, 2)

                    }
                    .padding(.horizontal, 42)
                }
                .background( Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 350, height: 230)
                    .background(Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.3))
                    .cornerRadius(16))
                
                .padding(.bottom, 40)
                
            }
            Button {
                print("ir para assistidos")
            } label: {
                VStack() {
                    HStack {
                        Text("Assistidos")
                            .font(Font.custom("Poppins-regular", size: 20))
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 0, green: 0.07, blue: 0.1))
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0, green: 0.07, blue: 0.1))
                        
                    }
                    .padding(.horizontal, 42)
                    
                    HStack (alignment: .center) {
                        Rectangle()
                            .foregroundColor(.gray)
                            .frame(width: 95, height: 143)
                            .padding(.horizontal, 2)
                        
                        Rectangle()
                            .foregroundColor(.gray)
                            .frame(width: 95, height: 143)
                            .padding(.horizontal, 2)
                        
                        
                        Rectangle()
                            .foregroundColor(.gray)
                            .frame(width: 95, height: 143)
                            .padding(.horizontal, 2)
                        
                    }
                    .padding(.horizontal, 36)
                }
                .background( Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 350, height: 230)
                    .background(Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.3))
                    .cornerRadius(16))
            }

            .padding(.vertical)
            Spacer()
        }

    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
