//
//  OnboardingView5.swift
//  CimemAI
//
//  Created by Júlia Savaris on 06/07/23.
//

import SwiftUI

struct OnboardingView5: View {
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
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    
                }
                .padding(.top, 12)
                
                Spacer()
                
                Text("Favoritos")
                    .font(Font.custom("Poppins-Regular", size: 32) .weight(.bold))
                    .foregroundColor(Color("Vermelho"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 1)
                
                Text("Salve suas sugestões favoritas!")
                    .font(.system(size: 22))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Selecione o coração e guarde seus filmes favoritos!")
                    .font(.system(size: 18))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 1)
                
                Image("coracao_favoritos")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320, height: 340)
                    .padding(.bottom, 40)
                
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
                        OnboardingView6(showOnboarding: $showOnboarding)
                        
                    } label: {
                        
                        HStack {
                            Text("Próximo")
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

struct OnboardingView5_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView5(showOnboarding: .constant(true))
    }
}
