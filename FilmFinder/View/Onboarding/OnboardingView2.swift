//
//  OnboardingView2.swift
//  CimemAI
//
//  Created by Júlia Savaris on 03/07/23.
//

import SwiftUI

struct OnboardingView2: View {
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
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color("roxo-azulado"))
                    Image(systemName: "circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color("roxo-azulado"))
                    
                }
                .padding(.top, 12)
                
                Spacer()
                
                Image("onboarding2")
                
                VStack{
                    Text("Pesquise com nossas sugestões")
                        .font(.system(size: 20))
                        .fontWidth(.expanded)
                        .fontWeight(.bold)
                        .foregroundColor(Color("laranja"))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                    
                    Text("Selecione nas nossas categorias o que está procurando ")
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
                    
                    NavigationLink {
                        OnboardingView3(showOnboarding: $showOnboarding)
                        
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
                        .frame(width: 150, height: 60, alignment: .center)
                        .cornerRadius(16)
                        .padding(.vertical, 8)
                        
                    }
                }
                
            }
            .frame(maxWidth: .infinity)
            .background(Color("cinza1"))
            
            
        }
        .navigationBarBackButtonHidden(true)
        
        
    }
}
    

struct OnboardingView2_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView2(showOnboarding: .constant(true))
    }
}
