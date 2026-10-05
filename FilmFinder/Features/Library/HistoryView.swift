import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            LibraryListView(kind: .history, showsBackButton: false)
        }
    }
}
