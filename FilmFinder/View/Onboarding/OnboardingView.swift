//
//  OnboardingView.swift
//  CimemAI
//
//  Created by Júlia Savaris on 03/07/23.
//

import SwiftUI

struct OnboardingView: View {
    
    @Binding var showOnboarding : Bool
    
    var body: some View {
        NavigationStack() {
            VStack(alignment: .center) {
                Image("onboardingTop")
                    .padding()
                
                HStack{
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color("roxo-azulado"))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color("roxo-azulado"))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color("roxo-azulado"))
                }
                .padding(.top, 12)
                
                Spacer()
                
                Image("onboarding1")
                
                VStack{
                    Text("Sem travar na hora de escolher o que assistir")
                        .font(.system(size: 20))
                        .fontWidth(.expanded)
                        .fontWeight(.bold)
                        .foregroundColor(Color("laranja"))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                    
                    Text("Encontre um filme ou série baseado na sua preferência, de forma rápida e simples!")
                        .font(.system(size: 20))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding()
                
                Spacer()
                NavigationLink {
                    OnboardingView2(showOnboarding: $showOnboarding)
                } label: {
                    
                    HStack {
                        Text("Próximo")
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
                .cornerRadius(16)
                .padding(.vertical, 8)
                
                
            }
            .frame(maxWidth: .infinity)
            .background(Color("cinza1"))
            
            
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(showOnboarding: .constant(true))
    }
}
