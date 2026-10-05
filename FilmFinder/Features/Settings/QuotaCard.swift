import SwiftUI

struct QuotaCard: View {
    let quota: Quota?
    let isSignedIn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Buscas de hoje", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.laranja)
                Spacer()
                if let quota {
                    Text("\(quota.remaining) restantes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let quota {
                ProgressView(value: quota.usedFraction)
                    .tint(.laranja)
                Text("Renova \(quota.resetsAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            Divider()

            Label(
                isSignedIn ? "Conectado com a Apple" : "Sem conta conectada",
                systemImage: isSignedIn ? "checkmark.seal.fill" : "person.crop.circle.badge.questionmark"
            )
            .font(.subheadline)
            .foregroundColor(isSignedIn ? .laranja : .secondary)
        }
        .padding()
        .background(Color.cinza2, in: RoundedRectangle(cornerRadius: 16))
    }
}
