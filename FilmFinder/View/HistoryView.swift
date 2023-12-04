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
                Image("FilmFinder_logo") // Assegure-se que o nome da imagem está correto
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25) // Ajuste o tamanho conforme necessário
                    .padding(5)
                HistoryHeader()
                List {
                    ForEach(dataManager.history) { history in
                        ContentCard(watchedContent: history)
                    }
                    .onDelete(perform: deleteItems)
                }
                .frame(width: .infinity)
                .listStyle(.plain) // Utilize o estilo plain para evitar linhas adicionais e padding da List padrão
                .navigationTitle("")
                .navigationBarHidden(true) // Esconde a barra de navegação padrão para customizar
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                            .foregroundColor(.laranja)
                    }
                }
            }
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
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.laranja)
                
                Spacer()
                
                EditButton()
                    .foregroundColor(.laranja)
            }
            CustomDivider(color: .laranja, width: 2)
                .frame(width: .infinity) // O tamanho pode ser ajustado conforme necessário
        }
        .padding()
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
