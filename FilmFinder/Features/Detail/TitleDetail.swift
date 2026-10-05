import SwiftData
import SwiftUI

struct TitleDetail: View {
    let title: Title

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [LibraryItem]

    init(title: Title) {
        self.title = title
        let key = title.id
        _items = Query(filter: #Predicate<LibraryItem> { $0.libraryKey == key })
    }

    private var item: LibraryItem? { items.first }
    private var isFavorite: Bool { item?.isFavorite ?? false }
    private var isWatched: Bool { item?.isWatched ?? false }
    private var store: LibraryStore { LibraryStore(context: modelContext) }

    var body: some View {
        ScrollView {
            VStack(spacing: -25) {
                PosterImage(path: title.posterPath)
                    .frame(maxWidth: .infinity)
                    .frame(height: 560)
                    .clipped()

                VStack(alignment: .leading, spacing: 19) {
                    header
                    chips
                    if !title.genres.isEmpty { genres }
                    if !title.reason.isEmpty { reason }
                    Text(title.overview)
                        .font(.system(size: 16))
                        .padding(.horizontal, 30)
                    StreamingSection(providers: title.providers)
                        .padding(.horizontal, 30)
                    Spacer(minLength: 24)
                }
                .padding(.top, 8)
                .background(Color.preto, in: RoundedRectangle(cornerRadius: 28))
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { BackButton() }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title.title)
                    .font(.system(size: 24))
                    .foregroundColor(.branco)
                    .fontWeight(.semibold)
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StarsView(stars: title.stars, color: .laranja)
            }

            Button {
                store.setFavorite(title, !isFavorite)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 23))
                    .foregroundColor(isFavorite ? .laranja : .branco)
            }
            .accessibilityLabel(isFavorite ? "Remover dos favoritos" : "Favoritar")

            Button {
                store.setWatched(title, !isWatched)
            } label: {
                Image(isWatched ? "Olhozin" : "Olhozin.fill")
                    .resizable()
                    .frame(width: 40, height: 25)
                    .scaledToFit()
            }
            .accessibilityLabel(isWatched ? "Desmarcar como assistido" : "Marcar como assistido")
        }
        .padding(.horizontal, 30)
    }

    private var chips: some View {
        HStack(spacing: 10) {
            if let minutes = title.runtimeMinutes {
                chip { Label("\(minutes) min", systemImage: "clock") }
            }
            if let seasons = title.seasons {
                chip { Text("\(seasons) temporadas") }
            }
            if let year = title.year {
                chip { Text(String(year)) }
            }
            Spacer()
        }
        .padding(.leading, 30)
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(size: 14))
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .overlay(RoundedRectangle(cornerRadius: 10).inset(by: 0.5).stroke(Color.branco, lineWidth: 1))
    }

    private var genres: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(title.genres, id: \.self) { genre in
                    Text(genre)
                        .font(.system(size: 13))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.roxo.opacity(0.5), in: Capsule())
                }
            }
            .padding(.horizontal, 30)
        }
    }

    private var reason: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Por que combina")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title.reason)
                .font(.system(size: 16))
                .foregroundColor(.laranja)
        }
        .padding(.horizontal, 30)
    }
}
