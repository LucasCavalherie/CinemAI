import SwiftUI

struct LibraryRow: View {
    let title: Title
    let date: Date

    var body: some View {
        NavigationLink {
            TitleDetail(title: title)
        } label: {
            HStack {
                PosterImage(path: title.posterPath)
                    .frame(width: 70, height: 105)
                    .clipped()
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title.title)
                        .font(.system(size: 16))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.branco)
                    if let year = title.year {
                        Text(String(year))
                            .font(.system(size: 13))
                            .foregroundColor(.branco)
                    }
                    Text(date, style: .date)
                        .font(.system(size: 10))
                        .foregroundColor(Color(uiColor: .gray))
                }
                .padding()
                Spacer()
            }
            .padding(.leading)
            .frame(maxWidth: .infinity)
        }
    }
}
