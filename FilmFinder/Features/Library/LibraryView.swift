import SwiftData
import SwiftUI

struct LibraryView: View {
    private enum Layout: String {
        case list
        case grid
    }

    private struct UndoState: Identifiable {
        let id = UUID()
        let message: LocalizedStringKey
        let perform: () -> Void
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.selectTab) private var selectTab
    @Query(
        filter: #Predicate<LibraryItem> { $0.isFavorite || $0.isWatched || $0.inHistory },
        sort: \.recommendedAt,
        order: .reverse
    )
    private var items: [LibraryItem]

    @State private var segment: LibrarySegment = .favorites
    @State private var query = ""
    @State private var mediaType: MediaType?
    @State private var undo: UndoState?
    @State private var confirmingClear = false
    @AppStorage("library.layout") private var layoutRaw = Layout.list.rawValue

    private var layout: Layout { Layout(rawValue: layoutRaw) ?? .list }

    var body: some View {
        let entries = LibraryFilter.entries(from: items)
        let visible = LibraryFilter(segment: segment, query: query, mediaType: mediaType).apply(to: entries)

        NavigationStack {
            VStack(spacing: 12) {
                header(entries)
                content(visible)
            }
            .background(Color.cinza1)
            .navigationTitle("Biblioteca")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Buscar na biblioteca")
            .toolbar { toolbar }
            .overlay(alignment: .bottom) { toast }
            .confirmationDialog("Limpar histórico?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Limpar histórico", role: .destructive) {
                    LibraryStore(context: modelContext).clearHistory()
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    // MARK: - Cabeçalho

    private func header(_ entries: [LibraryEntry]) -> some View {
        VStack(spacing: 10) {
            Text("\(LibraryFilter.count(.watched, in: entries)) assistidos · \(LibraryFilter.count(.favorites, in: entries)) favoritos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("Segmento", selection: $segment) {
                ForEach(LibrarySegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                layoutRaw = (layout == .list ? Layout.grid : Layout.list).rawValue
            } label: {
                Image(systemName: layout == .list ? "square.grid.2x2" : "list.bullet")
            }
            .accessibilityLabel(layout == .list ? "Grade" : "Lista")

            Menu {
                Picker("Tipo", selection: $mediaType) {
                    Text("Todos").tag(MediaType?.none)
                    ForEach(MediaType.allCases, id: \.self) { type in
                        Text(type.pluralName).tag(MediaType?.some(type))
                    }
                }
                if segment == .history {
                    Divider()
                    Button("Limpar histórico", role: .destructive) { confirmingClear = true }
                }
            } label: {
                Image(systemName: mediaType == nil ? "ellipsis.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }

    // MARK: - Conteúdo

    @ViewBuilder
    private func content(_ visible: [LibraryEntry]) -> some View {
        if visible.isEmpty {
            emptyState
        } else if layout == .grid {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], spacing: 16) {
                    ForEach(visible) { entry in
                        LibraryGridCell(entry: entry)
                            .contextMenu {
                                toggles(for: entry)
                                removeButton(for: entry)
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
            }
        } else {
            List(visible) { entry in
                LibraryRow(entry: entry)
                    .listRowBackground(Color.cinza1)
                    .swipeActions(edge: .leading) { toggles(for: entry) }
                    .swipeActions(edge: .trailing) { removeButton(for: entry) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty || mediaType != nil {
            ContentUnavailableView(
                "Nenhum resultado",
                systemImage: "magnifyingglass",
                description: Text("Tente outro termo ou filtro.")
            )
        } else {
            ContentUnavailableView {
                Label(segment.emptyTitle, systemImage: segment.emptyIcon)
            } description: {
                Text(segment.emptyMessage)
            } actions: {
                Button("Ir para Recomendações") { selectTab(.recommendations) }
                    .buttonStyle(.borderedProminent)
                    .tint(.laranja)
            }
        }
    }

    // MARK: - Ações

    @ViewBuilder
    private func toggles(for entry: LibraryEntry) -> some View {
        Button { toggleFavorite(entry) } label: {
            Label(entry.isFavorite ? "Desfavoritar" : "Favoritar", systemImage: entry.isFavorite ? "heart.slash" : "heart")
        }
        .tint(.rosa)
        Button { toggleWatched(entry) } label: {
            Label(entry.isWatched ? "Não assistido" : "Assistido", systemImage: entry.isWatched ? "eye.slash" : "eye")
        }
        .tint(.roxo)
    }

    private func removeButton(for entry: LibraryEntry) -> some View {
        Button(role: .destructive) { remove(entry) } label: {
            Label("Remover", systemImage: "trash")
        }
    }

    private func toggleFavorite(_ entry: LibraryEntry) {
        withAnimation { LibraryStore(context: modelContext).setFavorite(entry.title, !entry.isFavorite) }
    }

    private func toggleWatched(_ entry: LibraryEntry) {
        withAnimation { LibraryStore(context: modelContext).setWatched(entry.title, !entry.isWatched) }
    }

    private func remove(_ entry: LibraryEntry) {
        let store = LibraryStore(context: modelContext)
        guard let before = store.flags(for: entry.title) else { return }
        let removedFrom = segment
        withAnimation { store.remove(entry.title, from: removedFrom) }
        showUndo(removedFrom.removedMessage) {
            withAnimation { LibraryStore(context: modelContext).restore(before, for: entry.title) }
        }
    }

    // MARK: - Desfazer

    @ViewBuilder
    private var toast: some View {
        if let undo {
            UndoToast(message: undo.message) {
                undo.perform()
                withAnimation { self.undo = nil }
            }
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func showUndo(_ message: LocalizedStringKey, perform: @escaping () -> Void) {
        let state = UndoState(message: message, perform: perform)
        withAnimation { undo = state }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if undo?.id == state.id {
                withAnimation { undo = nil }
            }
        }
    }
}
