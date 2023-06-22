import Foundation
import SwiftUI

struct IMDbCard: View {
    let title : String
    let url : String
    let rating : String
    
    var ratingAsStars: Int {
        return Int((Double(rating) ?? 0) / 2.0 + 0.5)
    }

    var body: some View {
        ZStack{
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 290, height: 416)
                .background(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0), location: 0.00),
                            Gradient.Stop(color: .black, location: 0.98),
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                )
                .cornerRadius(13).opacity(0.3)
                .background(Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 290, height: 416)
                    .background(
                        AsyncImage(url: URL(string: url), scale: 4.7)
                            .frame(width: 290, height: 416)
                            .clipped()
                    ).cornerRadius(17))
            VStack(alignment: .leading){
                Spacer()
                Text(title)
                  .font(
                    Font.custom("Poppins-Regular", size: 23)
                        .weight(.bold)
                  )
                  .foregroundColor(.white)

                
                HStack {
                    ForEach(0..<ratingAsStars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.white)
                    }
                    ForEach(0..<(5-ratingAsStars), id: \.self) { _ in
                        Image(systemName: "star")
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom)
                  
            }.frame(width: 290, height: 416)
                
        }
    }
}

struct IMDbCard_Previews: PreviewProvider {
    static var previews: some View {
        IMDbCard(title: "O Poderoso Chefão" ,url: "https://m.media-amazon.com/images/M/MV5BM2MyNjYxNmUtYTAwNi00MTYxLWJmNWYtYzZlODY3ZTk3OTFlXkEyXkFqcGdeQXVyNzkwMjQ5NzM@._V1_Ratio0.7027_AL_.jpg", rating: "9.8")
    }
}
