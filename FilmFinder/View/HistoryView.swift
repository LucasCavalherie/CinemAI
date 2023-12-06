import SwiftUI

extension Color {
    static let customOrange = Color.orange // Substitua por seu valor de cor RGB exato se necessário
}

struct HistoryView: View {
    
    @ObservedObject private var dataManager = DataManager.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                // Logo no topo
                Image("FilmFinder_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25)
                    .padding(5)
                HistoryHeader()
                List {
                    ForEach(dataManager.history) { history in
                        ContentCard(watchedContent: history)
                            .listRowBackground(Color.cinza1)
                    }
                    .onDelete(perform: deleteItems)
                }
                

                .listStyle(.plain)
                .navigationTitle("")
                .navigationBarHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                            .foregroundColor(.laranja)
                    }
                }
                
            }
            .background(Color.cinza1)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                let content = dataManager.history[index]
                dataManager.removeFromHistory(content)
            }
        }
    }
}

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

struct HistoryHeader: View {
    var body: some View {
        VStack{
            HStack {
                Text("Histórico")
                    .fontWidth(.expanded)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.laranja)
                
                Spacer()
                
                EditButton()
                    .foregroundColor(.laranja)
            }
            CustomDivider(color: .laranja, width: 2)
        }
        .padding()
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
