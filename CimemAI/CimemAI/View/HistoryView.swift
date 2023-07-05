import SwiftUI

struct HistoryView: View {
    
    @ObservedObject private var dataManager = DataManager.shared
    
    var body: some View {
        NavigationStack{
            VStack{
                ScrollView{
                    Button(action: {
                        clearUserDefaults()
                    }) {
                        Text("Limpar UserDefaults")
                    }

                    LazyVGrid(columns: [GridItem(.flexible())]) {
                        ForEach(dataManager.allContent) { history in
                            ContentCard(watchedContent: history)
                        }.padding(.vertical, 8)
                    }
                }
            }
        }
    }
    func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "favorites")
        UserDefaults.standard.removeObject(forKey: "watched")
        UserDefaults.standard.removeObject(forKey: "allContent")
        UserDefaults.standard.synchronize()
        print(dataManager.allContent)
    }

}



struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
