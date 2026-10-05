import SwiftUI

struct LibraryRow: View {
    let entry: LibraryEntry

    var body: some View {
        NavigationLink {
            TitleDetail(title: entry.title)
        } label: {
            HStack(spacing: 12) {
                PosterImage(path: entry.title.posterPath)
                    .frame(width: 70, height: 105)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title.title)
                        .font(.system(size: 16, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.branco)
                    HStack(spacing: 8) {
                        if let year = entry.title.year {
                            Text(String(year))
                        }
                        Label(String(format: "%.1f", entry.title.rating), systemImage: "star.fill")
                            .foregroundColor(.laranja)
                        if let genre = entry.title.genres.first {
                            Text(genre)
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.branco)
                    Text(entry.date, style: .date)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
                LibraryBadges(entry: entry)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Selos de favorito/assistido, usados na linha e na célula da grade.
struct LibraryBadges: View {
    let entry: LibraryEntry

    var body: some View {
        HStack(spacing: 4) {
            if entry.isFavorite {
                Image(systemName: "heart.fill").foregroundColor(.rosa)
            }
            if entry.isWatched {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.laranja)
            }
        }
        .font(.system(size: 14))
    }
}
