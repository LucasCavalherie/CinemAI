import SwiftUI

struct HistoryView: View {
    @State private var history = DataManager.shared.getWatchedContent()
    
    var body: some View {
        NavigationStack{
            VStack{
                Button {
                    let domain = Bundle.main.bundleIdentifier!
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    UserDefaults.standard.synchronize()
                    print(DataManager.shared.getWatchedContent())

                } label: {
                    Text("RESET")
                }
                ScrollView{
                    LazyVGrid(columns: [GridItem(.flexible())]) {
                        ForEach(history) { history in
                            ContentCard(watchedContent: history)
                        }.padding(.vertical, 8)
                    }
                }
                
            }
        }.onAppear(perform: reload)
    }
    
    func reload(){
        self.history = DataManager.shared.getWatchedContent()
        print(history)
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
