import SwiftUI

struct ProfileFavoriteCard: View {
    
    var contents : [WatchedContent]
    let title : String
    

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
            if contents.count <= 0 {
                HStack{
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 95, height: 143)
                        .cornerRadius(8)
                        .opacity(0)
                    
                }
            } else {
                HStack {
                    ForEach(contents.prefix(3), id: \.id) { content in
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
        return ProfileFavoriteCard(contents: DataManager.shared.favorites, title: "Favoritos")
    }
}
