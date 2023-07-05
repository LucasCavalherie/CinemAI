import SwiftUI

struct HistoryView: View {
    
    @ObservedObject private var dataManager = DataManager.shared
    
    var body: some View {
        NavigationStack{
            VStack{
                Button {
                    let domain = Bundle.main.bundleIdentifier!
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    UserDefaults.standard.synchronize()
                    print(dataManager.allContent)
                    
                } label: {
                    Text("RESET")
                }
                ScrollView{
                    LazyVGrid(columns: [GridItem(.flexible())]) {
                        ForEach(dataManager.allContent) { history in
                            ContentCard(watchedContent: history)
                        }.padding(.vertical, 8)
                    }
                }
            }
        }
    }
}


struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
