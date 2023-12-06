//
//  OnboardingView3.swift
//  CimemAI
//
//  Created by Júlia Savaris on 04/07/23.
//

import SwiftUI

struct OnboardingView3: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @Binding var showOnboarding : Bool
    
    var body: some View {
        NavigationStack() {
            VStack(alignment: .center) {
                Image("onboardingTop")
                    .padding()
                
                HStack{
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color("roxo-azulado"))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color("roxo-azulado"))
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color("roxo-azulado"))
                    
                    
                }
                .padding(.top, 12)
                
                Spacer()
                
                Image("onboarding3")
                
                VStack{
                    Text("Ou descreva o que está procurando")
                        .font(.system(size: 20))
                        .fontWidth(.expanded)
                        .fontWeight(.bold)
                        .foregroundColor(Color("laranja"))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                    
                    Text("Descreva as características que estiver procurando como um passe de mágica")
                        .font(.system(size: 20))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding()
                
                Spacer()
                
                HStack {
                    Button {
                        self.presentationMode.wrappedValue.dismiss()
                        
                    } label: {
                        
                        HStack {
                            
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(Color("branco"))
                            
                            Text("Voltar")
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(Color("branco"))
                            
                            
                        }
                        .frame(width: 150, height: 60, alignment: .center)
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
                                .foregroundColor(Color("laranja"))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(Color("laranja"))
                            
                            
                            
                        }
                    }
                    .frame(width: 150, height: 60, alignment: .center)
                    // .background(Color(red: 0.15, green: 0.36, blue: 0.44))
                    .cornerRadius(16)
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color("cinza1"))
        }
        .navigationBarBackButtonHidden(true)
    }
}
struct OnboardingView3_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView3(showOnboarding: .constant(true))
    }
}
