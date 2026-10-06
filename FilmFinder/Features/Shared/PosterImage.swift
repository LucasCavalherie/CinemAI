import SwiftUI

struct PosterImage: View {
    let path: String?

    var body: some View {
        if let url = TMDBImage.poster(path) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                default:
                    ZStack {
                        Color.cinza2
                        ProgressView()
                    }
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.cinza2
            Image("error")
                .resizable()
                .scaledToFit()
                .padding(24)
        }
    }
}
