import SwiftUI

struct InicialLoading: View {
    @State var isActive: Bool = false
    @State private var introOpacity = 1.0
    @State private var logoOpacity = 0.0
    @State private var sloganOpacity = 0.0
    @State private var viewOpacity = 0.0
    
    @AppStorage("showOnboarding") private var showOnboarding = true

    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding).opacity(viewOpacity)
            } else {
                MainView().opacity(viewOpacity)
            }
            
            // Background
            LinearGradient(
                stops: [
                    Gradient.Stop(color: Color(red: 0.11, green: 0.11, blue: 0.12), location: 0.00),
                    Gradient.Stop(color: Color(red: 0.21, green: 0.21, blue: 0.21), location: 1.00),
                ],
                startPoint: UnitPoint(x: 0.21, y: 0.74),
                endPoint: UnitPoint(x: 0.88, y: -0.15)
            )
            .opacity(introOpacity)
            .ignoresSafeArea()
            
            // Logo
            Image("FilmFinder_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .opacity(logoOpacity)
            
            // Slogan
            Text("The right path to your perfect movie match")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .frame(width: 309, height: 60, alignment: .center)
                .padding(.top, 200)
                .opacity(sloganOpacity)
        }
        .onAppear() {
            withAnimation(.easeInOut(duration: 1.3)) {
                introOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation {
                    logoOpacity = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation {
                    sloganOpacity = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
                withAnimation(.easeInOut(duration: 1.2)) {
                    introOpacity = 0.0
                    logoOpacity = 0.0
                    sloganOpacity = 0.0
                    viewOpacity = 1.0
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
