import Foundation
import SwiftData
@testable import FilmFinder

/// Container em memória; o `container` precisa ficar vivo enquanto o `store` é usado.
@MainActor
struct LibraryHarness {
    let container: ModelContainer
    let store: LibraryStore

    init() throws {
        container = try ModelContainer(
            for: LibraryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = LibraryStore(context: container.mainContext)
    }

    var items: [LibraryItem] {
        (try? container.mainContext.fetch(FetchDescriptor<LibraryItem>())) ?? []
    }

    func item(_ id: String) -> LibraryItem? {
        items.first { $0.libraryKey == id }
    }
}
