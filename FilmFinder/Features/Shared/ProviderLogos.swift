import SwiftUI

struct ProviderLogoView: View {
    let provider: StreamingProvider
    var size: CGFloat = 28

    var body: some View {
        AsyncImage(url: TMDBImage.logo(provider.logoPath)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Color.cinza2
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .accessibilityLabel(provider.name)
    }
}

struct ProviderLogosRow: View {
    let providers: [StreamingProvider]
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 6) {
            ForEach(providers) { provider in
                ProviderLogoView(provider: provider, size: size)
            }
        }
    }
}
