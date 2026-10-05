import SwiftData
import SwiftUI

struct ResultsView: View {
    let mediaType: MediaType
    let query: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var model: ResultsModel?
    @State private var currentIndex = 0
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingStateView()
            }
        }
        .task {
            if model == nil {
                model = ResultsModel(
                    mediaType: mediaType,
                    query: query,
                    service: environment.service,
                    store: LibraryStore(context: modelContext),
                    onQuota: { environment.account.update(quota: $0) }
                )
            }
            // `load()` só age em `.idle`: reexecuta com segurança se a task foi cancelada ao navegar.
            await model?.load()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { BackButton() }
            }
        }
    }

    @ViewBuilder
    private func content(_ model: ResultsModel) -> some View {
        switch model.phase {
        case .idle, .loading:
            LoadingStateView()
        case .empty:
            ErrorStateView(kind: .noResults)
        case .failed(let error):
            ErrorStateView(kind: ErrorKind(error)) {
                Task { await model.retry() }
            }
        case .loaded:
            carousel(model)
        }
    }

    private func carousel(_ model: ResultsModel) -> some View {
        let titles = model.visible
        let index = min(currentIndex, max(titles.count - 1, 0))

        return VStack(alignment: .leading, spacing: 16) {
            heading
                .font(.system(size: 24))
                .fontWidth(.expanded)

            ZStack {
                ForEach(Array(titles.enumerated()), id: \.element.id) { position, title in
                    TitleCard(title: title)
                        .scaleEffect(0.9)
                        .opacity(index == position ? 1.0 : 0.5)
                        .scaleEffect(index == position ? 1.2 : 0.8)
                        .offset(x: CGFloat(position - index) * 260 + dragOffset, y: 0)
                }
            }
            .frame(maxWidth: .infinity)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in state = value.translation.width }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        withAnimation {
                            if value.translation.width > threshold {
                                currentIndex = max(0, index - 1)
                            } else if value.translation.width < -threshold {
                                currentIndex = min(titles.count - 1, index + 1)
                            }
                        }
                    }
            )
            .padding()
            .padding(.leading)

            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        guard titles.indices.contains(index) else { return }
                        Task { await model.swap(titles[index]) }
                    } label: {
                        Group {
                            if model.isSwapping {
                                ProgressView().tint(.branco)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                        .foregroundStyle(Color.branco)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 14).foregroundStyle(Color.laranja))
                    }
                    .disabled(model.isSwapping)
                    .accessibilityLabel("Trocar por outra opção")
                    Spacer()
                }

                if let error = model.swapError {
                    Text(ErrorKind(error).title)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 30)
    }

    private var heading: Text {
        let lead: LocalizedStringKey = mediaType == .movie ? "Estes são os filmes " : "Estas são as séries "
        return Text(lead).foregroundColor(.white).fontWeight(.semibold)
            + Text("mais compatíveis ").foregroundColor(.laranja).bold()
            + Text("com você agora:").foregroundColor(.white).fontWeight(.semibold)
    }
}
