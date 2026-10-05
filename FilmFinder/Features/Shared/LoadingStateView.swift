import SwiftUI

struct LoadingStateView: View {
    var body: some View {
        VStack {
            (Text("Encontrando as opções mais")
                .foregroundColor(Color("branco"))
                + Text(" compatíveis ")
                .foregroundColor(Color("laranja"))
                + Text("com você")
                .foregroundColor(Color("branco")))
                .fontWidth(.expanded)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            LottieView(name: "pipocascertasmesmo", loopMode: .loop, animationSpeed: 2)
                .frame(width: 250, height: 112)
                .scaleEffect(0.8)
                .padding(.bottom, 60)
        }
    }
}
