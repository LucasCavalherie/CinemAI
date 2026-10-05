import SwiftUI

struct LibraryPreviewRectangle: View {
    let heading: LocalizedStringKey
    let items: [LibraryItem]

    var body: some View {
        VStack {
            Text(heading)
                .font(.system(size: 15))
                .fontWeight(.bold)
                .fontWidth(.expanded)
                .foregroundStyle(Color.laranja)
                .padding(.top)
            CustomDivider(color: .laranja, width: 2)
                .padding(.horizontal)

            HStack {
                if items.isEmpty {
                    Color.clear.frame(width: 95, height: 142)
                } else {
                    ForEach(items.prefix(3)) { item in
                        PosterImage(path: item.snapshot?.posterPath)
                            .frame(width: 95, height: 142)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
            }
        }
        .frame(width: 341, height: 207.3125)
        .background(Color(red: 0.2, green: 0.2, blue: 0.2), in: RoundedRectangle(cornerRadius: 15.5))
    }
}
