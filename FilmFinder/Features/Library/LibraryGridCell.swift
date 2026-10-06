import SwiftUI

struct LibraryGridCell: View {
    let entry: LibraryEntry

    var body: some View {
        NavigationLink {
            TitleDetail(title: entry.title)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay { PosterImage(path: entry.title.posterPath) }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        LibraryBadges(entry: entry)
                            .padding(6)
                            .shadow(color: .preto, radius: 3)
                    }
                Text(entry.title.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.branco)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let year = entry.title.year {
                    Text(String(year))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
