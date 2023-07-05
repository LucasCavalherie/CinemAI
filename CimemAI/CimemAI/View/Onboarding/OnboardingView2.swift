//
//  OnboardingView2.swift
//  CimemAI
//
//  Created by Júlia Savaris on 03/07/23.
//

import SwiftUI

struct OnboardingView2: View {
    @Binding var showOnboarding : Bool
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        NavigationStack() {
            VStack(alignment: .center) {
                HStack{
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
                
                Text("Modo descrição")
                    .font(Font.custom("Poppins", size: 32) .weight(.bold))
                    .foregroundColor(Color(red: 0, green: 0.37, blue: 0.45))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 1)
                
                Text("Escreva como se você fosse \npedir sugestões a um amigo!")
                    .font(.system(size: 22))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Image("pipoco_falando2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320)
                    .padding(.bottom)
                
                Text("Descreva gêneros, duração, características do roteiro, diretores, atores participantes e muito mais!")
                    .font(.system(size: 18))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
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
                        OnboardingView3(showOnboarding: $showOnboarding)
                        
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
                        .frame(width: 150, height: 60, alignment: .center)
                        // .background(Color(red: 0.15, green: 0.36, blue: 0.44))
                        .cornerRadius(16)
                        .padding(.vertical, 8)
                        
                    }
                }
                
            }
            
            
        }
        .navigationBarBackButtonHidden(true)
        
        
    }
}
    

struct OnboardingView2_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView2(showOnboarding: .constant(true))
    }
}
