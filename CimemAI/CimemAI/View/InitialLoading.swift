import SwiftUI

struct InicialLoading: View {
    @State var isActive: Bool = false
    @State private var introOpacity = 1.0
    @State private var viewOpacity = 0.0
    
    @AppStorage("showOnboarding") private var showOnboarding = true
    
    
    var body: some View {
        ZStack {
                ZStack {
                    if showOnboarding {
                        OnboardingView(showOnboarding: $showOnboarding).opacity(viewOpacity)
                    } else {
                        MainView().opacity(viewOpacity)
                    }
                    
                    ZStack{
                        LinearGradient(colors: [Color(red: 0.15, green: 0.36, blue: 0.44), Color(red: 0.26, green: 0.57, blue: 0.58)], startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea()
                        
                        Image("filmfinderinicia")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 300, height: 300)
                    }.opacity(introOpacity)
                }
        }
        .onAppear() {
            withAnimation(.easeInOut(duration: 1.3)) {
                introOpacity = 0.0
                viewOpacity = 1.0
            }
        }
    }
}
          

struct InicialLoading_Previews: PreviewProvider {
    static var previews: some View {
        InicialLoading()
    }
}
