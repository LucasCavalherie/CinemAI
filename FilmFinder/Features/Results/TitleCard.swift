import SwiftUI

struct TitleCard: View {
    let title: Title

    private let width: CGFloat = 265
    private let height: CGFloat = 400

    var body: some View {
        ZStack {
            PosterImage(path: title.posterPath)
                .frame(width: width, height: height)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.35),
                            .init(color: Color(red: 0.29, green: 0.01, blue: 0.46), location: 0.98),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 17))

            VStack {
                HStack {
                    Spacer()
                    NavigationLink {
                        TitleDetail(title: title)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .font(.system(size: 25, weight: .bold))
                            .shadow(color: .preto, radius: 5)
                    }
                }
                .padding()

                Spacer()

                Text(title.title)
                    .font(.system(size: 20))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                StarsView(stars: title.stars)
                    .padding(.bottom, 8)

                if !title.reason.isEmpty {
                    Text(title.reason)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                let highlighted = title.providers.highlighted()
                if !highlighted.isEmpty {
                    HStack(spacing: 8) {
                        Text("Disponível em")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                        ProviderLogosRow(providers: highlighted, size: 24)
                    }
                    .padding(.bottom, 16)
                } else {
                    Spacer().frame(height: 16)
                }
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
    }
}
