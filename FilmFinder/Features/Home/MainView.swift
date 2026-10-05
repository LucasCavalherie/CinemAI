import SwiftUI

enum AppTab: Hashable {
    case recommendations
    case library
    case settings
}

extension EnvironmentValues {
    /// Permite a telas internas (ex.: estado vazio da Biblioteca) trocarem de aba.
    @Entry var selectTab: @MainActor (AppTab) -> Void = { _ in }
}

struct MainView: View {
    @State private var selectedTab: AppTab = .recommendations

    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .tabItem {
                    Label("Recomendações", systemImage: "magnifyingglass.circle.fill")
                }
                .tag(AppTab.recommendations)

            LibraryView()
                .tabItem {
                    Label("Biblioteca", systemImage: "books.vertical.fill")
                }
                .tag(AppTab.library)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .accentColor(Color.laranja)
        .environment(\.selectTab) { selectedTab = $0 }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
