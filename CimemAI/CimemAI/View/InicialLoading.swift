//
//  InicialLoading.swift
//  CimemAI
//
//  Created by Júlia Savaris on 28/06/23.
//

import SwiftUI

struct InicialLoading: View {
    @State var isActive: Bool = false
    
    var body: some View {
        ZStack {
            if self.isActive {
                TypeView()
            } else {
                
                
                ZStack {
                    LinearGradient(colors: [Color(red: 0.15, green: 0.36, blue: 0.44), Color(red: 0.26, green: 0.57, blue: 0.58)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                    
                    Image("filmfinderinicia")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                }
                            
             
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}
          

struct InicialLoading_Previews: PreviewProvider {
    static var previews: some View {
        InicialLoading()
    }
}
