import SwiftUI

struct UndoToast: View {
    let message: LocalizedStringKey
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.branco)
            Spacer()
            Button("Desfazer", action: onUndo)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.laranja)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cinza2, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }
}
