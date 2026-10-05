import SwiftUI

struct StarsView: View {
    let stars: Int
    var color: Color = .white
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) / 5")
    }
}
