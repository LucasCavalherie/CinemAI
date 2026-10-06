import SwiftUI

struct CustomDivider: View {
    let color: Color
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: width)
            .edgesIgnoringSafeArea(.horizontal)
    }
}
