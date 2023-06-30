import SwiftUI

struct MainView: View {
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HistoryView()
                .tabItem {
                    Label("Histórico", systemImage: "clock.arrow.circlepath")
                }
                .tag(0)
            
            TypeView()
                .tabItem {
                    Label("Recomendações", systemImage: "popcorn.circle.fill")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.circle.fill")
                }
                .tag(2)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
