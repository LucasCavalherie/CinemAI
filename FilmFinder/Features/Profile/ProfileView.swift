import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query(filter: #Predicate<LibraryItem> { $0.isFavorite }, sort: \.recommendedAt, order: .reverse)
    private var favorites: [LibraryItem]

    @Query(filter: #Predicate<LibraryItem> { $0.isWatched }, sort: \.recommendedAt, order: .reverse)
    private var watched: [LibraryItem]

    var body: some View {
        NavigationStack {
            VStack(alignment: .center) {
                Image("FilmFinder_logoPB")
                    .resizable()
                    .frame(width: 54, height: 29)

                Image("perfil")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94)
                    .padding(.top, 20)

                Text("Meu Perfil")
                    .font(.system(size: 20))
                    .fontWidth(.expanded)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                    .foregroundColor(.laranja)

                Text("\(watched.count) assistidos | \(favorites.count) favoritos")
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .foregroundColor(.branco)

                VStack {
                    NavigationLink {
                        LibraryListView(kind: .favorites)
                    } label: {
                        LibraryPreviewRectangle(heading: "Favoritos", items: favorites)
                    }
                    NavigationLink {
                        LibraryListView(kind: .watched)
                    } label: {
                        LibraryPreviewRectangle(heading: "Assistidos", items: watched)
                    }
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cinza1)
        }
    }
}
