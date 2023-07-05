//
//  OnboardingView4.swift
//  CimemAI
//
//  Created by Júlia Savaris on 04/07/23.
//

import SwiftUI

struct OnboardingView4: View {
    @Binding var showOnboarding : Bool
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
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
                    
                }
                .padding(.top, 12)
                
                Spacer()
                
                Text("Histórico e Perfil")
                    .font(Font.custom("Poppins", size: 32) .weight(.bold))
                    .foregroundColor(Color("Azul"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 1)
                
                Text("Navegue pela barra inferior para acessar o Histórico de Recomendações e o seu Perfil")
                    .font(.system(size: 22))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Veja também sua lista de assistidos e favoritos na aba perfil!\n")
                    .font(.system(size: 18))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 1)
                
                Image("pipoco_selecionando")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320, height: 340)
                    .padding(.bottom)
                
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
                    
                    Button {
                        showOnboarding = false
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

struct OnboardingView4_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView4(showOnboarding: .constant(true))
    }
}
