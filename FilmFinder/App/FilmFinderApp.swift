import SwiftData
import SwiftUI

@main
struct FilmFinderApp: App {
    @State private var environment = AppEnvironment.live()
    private let container: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: LibraryItem.self)
        } catch {
            fatalError("Could not create the library database: \(error)")
        }
        self.container = container
        LegacyImporter(defaults: .standard, store: LibraryStore(context: container.mainContext)).runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            InicialLoading()
                .preferredColorScheme(.dark)
                .environment(environment)
                .modelContainer(container)
                .task { await environment.warmUp() }
        }
    }
}
