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
                HStack{
                    Image(systemName: "circle.fill")
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
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(uiColor: .systemGray))
                    
                }
                .padding(.top, 12)
                
                Spacer()
                
                Image("bichinhos")
                    .resizable()
                    .scaledToFit()
                
                Text("Sem travar na hora de\n escolher o que assistir!")
                    .font(Font.custom("Poppins-Regular", size: 28) .weight(.bold))
                    .foregroundColor(Color(red: 0.61, green: 0.13, blue: 0.15))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
                
                Text("Encontre os filmes ou séries que mais \ncombinam com você, de forma \ncustomizada e rápida!")
                    .font(.system(size: 19))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                NavigationLink {
                    OnboardingView2(showOnboarding: $showOnboarding)
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
                //  .background(Color(red: 0.15, green: 0.36, blue: 0.44))
                .cornerRadius(16)
                .padding(.vertical, 8)
                
                
            }
            
            
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(showOnboarding: .constant(true))
    }
}
