import SwiftUI

struct ProfileListCard: View {
    let title : String
    let contents: [WatchedContent]

        init(title: String, contents: [WatchedContent]) {
            self.title = title
            assert(contents.count <= 3, "ProfileListCard expects exactly three WatchedContent items")
            self.contents = contents
        }

    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .font(Font.custom("Poppins-regular", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0, green: 0.07, blue: 0.1))
                Spacer()
                Image(systemName: "arrow.right")
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0, green: 0.07, blue: 0.1))
                
            }
            .padding(.horizontal, 36)
            HStack {
                ForEach(contents, id: \.id) { content in
                    switch content.content {
                    case .filme(let film):
                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(film.image)")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                            default:
                                Rectangle().fill(Color.gray)
                            }
                        }
                        .frame(width: 95, height: 143)
                        .cornerRadius(8)
                        
                    case .serie(let serie):
                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(serie.image)")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                            default:
                                Rectangle().fill(Color.gray)
                            }
                        }
                        .frame(width: 95, height: 143)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .background( Rectangle()
            .foregroundColor(.clear)
            .frame(width: 350, height: 230)
            .background(Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.3))
            .cornerRadius(16))
    }
}

struct ProfileListCard_Previews: PreviewProvider {
    static var previews: some View {
        let sampleContents = Array(DataManager.shared.getContentsFromFavorites().prefix(3))
        return ProfileListCard(title: "Favoritos", contents: sampleContents)
    }
}
