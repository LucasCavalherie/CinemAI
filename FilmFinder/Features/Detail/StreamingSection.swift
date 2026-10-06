import SwiftUI

struct StreamingSection: View {
    let providers: Providers

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Onde assistir")
                .font(.system(size: 18, weight: .semibold))
                .fontWidth(.expanded)
                .foregroundColor(.branco)

            if providers.isEmpty {
                Text("Não disponível em streaming na sua região")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                group("Assinatura", providers.flatrate)
                group("Grátis", providers.free)
                group("Aluguel", providers.rent)
                group("Compra", providers.buy)

                if let link = providers.link {
                    Link(destination: link) {
                        HStack {
                            Text("Ver onde assistir")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.preto)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.laranja)
                        .cornerRadius(14)
                    }
                }
            }

            Text("Dados de streaming: JustWatch")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func group(_ heading: LocalizedStringKey, _ list: [StreamingProvider]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(heading)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(list) { provider in
                            VStack(spacing: 4) {
                                ProviderLogoView(provider: provider, size: 44)
                                Text(provider.name)
                                    .font(.system(size: 10))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 60)
                            }
                        }
                    }
                }
            }
        }
    }
}
