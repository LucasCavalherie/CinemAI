import SwiftData
import SwiftUI

struct LibraryListView: View {
    enum Kind {
        case history
        case favorites
        case watched

        var heading: LocalizedStringKey {
            switch self {
            case .history: "Histórico"
            case .favorites: "Favoritos"
            case .watched: "Assistidos"
            }
        }
    }

    let kind: Kind
    let showsBackButton: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [LibraryItem]

    init(kind: Kind, showsBackButton: Bool = true) {
        self.kind = kind
        self.showsBackButton = showsBackButton
        switch kind {
        case .history:
            _items = Query(filter: #Predicate<LibraryItem> { $0.inHistory }, sort: \.recommendedAt, order: .reverse)
        case .favorites:
            _items = Query(filter: #Predicate<LibraryItem> { $0.isFavorite }, sort: \.recommendedAt, order: .reverse)
        case .watched:
            _items = Query(filter: #Predicate<LibraryItem> { $0.isWatched }, sort: \.recommendedAt, order: .reverse)
        }
    }

    var body: some View {
        VStack {
            Image("FilmFinder_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 25)
                .padding(5)

            VStack {
                HStack {
                    Text(kind.heading)
                        .fontWidth(.expanded)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.laranja)
                    Spacer()
                    EditButton()
                        .foregroundColor(.laranja)
                }
                CustomDivider(color: .laranja, width: 2)
            }
            .padding()

            List {
                ForEach(items) { item in
                    if let title = item.snapshot {
                        LibraryRow(title: title, date: item.recommendedAt)
                            .listRowBackground(Color.cinza1)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
        }
        .background(Color.cinza1)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if showsBackButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { BackButton() }
                }
            }
        }
        .toolbar(showsBackButton ? .automatic : .hidden, for: .navigationBar)
    }

    private func delete(at offsets: IndexSet) {
        let store = LibraryStore(context: modelContext)
        let titles = offsets.compactMap { items[$0].snapshot }
        withAnimation {
            for title in titles {
                switch kind {
                case .history: store.removeFromHistory(title)
                case .favorites: store.setFavorite(title, false)
                case .watched: store.setWatched(title, false)
                }
            }
        }
    }
}
