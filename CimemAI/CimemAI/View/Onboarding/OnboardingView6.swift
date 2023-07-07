//
//  OnboardingView6.swift
//  CimemAI
//
//  Created by Júlia Savaris on 06/07/23.
//

import SwiftUI

struct OnboardingView6: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @Binding var showOnboarding : Bool
    
    var body: some View {
        NavigationStack() {
            VStack(alignment: .center) {
                HStack{
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    
                }
                .padding(.top, 12)
                
                Spacer()
                
                Text("Assistidos")
                    .font(Font.custom("Poppins-Regular", size: 32) .weight(.bold))
                    .foregroundColor(Color("Azul_Escuro"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 1)
                
                Text("Já assistiu algum dos filmes \nque foram sugeridos?")
                    .font(.system(size: 22))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Clique no ícone de Assistido e o filme não será sugerido novamente!")
                    .font(.system(size: 18))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 1)
                
                
                Image("pipoco_watched")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320, height: 340)
                    .padding(.bottom, 20)
                
                HStack {
                    Button {
                        self.presentationMode.wrappedValue.dismiss()
                        
                    } label: {
                        
                        HStack {
                            
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.26, green: 0.57, blue: 0.58))
                            
                            Text("Voltar")
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.26, green: 0.57, blue: 0.58))
                            
                            
                        }
                        .frame(width: 150, height: 60, alignment: .center)
                        //  .background(Color(red: 0.26, green: 0.57, blue: 0.58))
                        .cornerRadius(16)
                        .padding(.vertical, 8)
                        
                    }
                    
                    NavigationLink {
                        OnboardingView4(showOnboarding: $showOnboarding)
                        
                    } label: {
                        
                        HStack {
                            Text("Concluir")
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0, green: 0.37, blue: 0.45))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0, green: 0.37, blue: 0.45))
                            
                            
                            
                        }
                    }
                    .frame(width: 150, height: 60, alignment: .center)
                    // .background(Color(red: 0.15, green: 0.36, blue: 0.44))
                    .cornerRadius(16)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct OnboardingView6_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView6(showOnboarding: .constant(true))
    }
}
