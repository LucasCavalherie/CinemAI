//
//  OnboardingView3.swift
//  CimemAI
//
//  Created by Júlia Savaris on 04/07/23.
//

import SwiftUI

struct OnboardingView3: View {
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
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    
                }
                .padding(.top, 12)
                
                Spacer()
                
                Text("Modo Seleção")
                    .font(Font.custom("Poppins", size: 32) .weight(.bold))
                    .foregroundColor(Color("Arenito"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 1)
                
                Text("Selecione as categorias que \nvocê mais gostar para gerar indicações de filmes!")
                    .font(.system(size: 22))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Image("pipoco_selecionando")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320, height: 340)
                    .padding(.bottom)
                
                Text("Escolha entre opções de gêneros, aspectos da história e duração.\n")
                    .font(.system(size: 18))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
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
                        OnboardingView4()
                        
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
struct OnboardingView3_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView3()
    }
}
