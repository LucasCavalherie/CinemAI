import SwiftUI

struct WatchedView: View {
    @ObservedObject var dataManager = DataManager.shared
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var btnBack : some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }){
            BackButton()
    }}
    
    var body: some View {
        NavigationStack {
            VStack {
                // Logo no topo
                Image("FilmFinder_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25)
                    .padding(5)
                
                WatchedReader()
                
                List {
                    ForEach(dataManager.watched) { history in
                        ContentCard(watchedContent: history)
                            .listRowBackground(Color.cinza1)
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.plain)
                .navigationTitle("")
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: btnBack)
            .background(Color.cinza1)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                let content = dataManager.watched[index]
                dataManager.removeWatched(content)
            }
        }
    }
}

struct WatchedReader: View {
    var body: some View {
        VStack{
            HStack {
                Text("Assistidos")
                    .fontWidth(.expanded)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.laranja)
                
                Spacer()
                
                EditButton()
                    .foregroundColor(.laranja)
            }
            CustomDivider(color: .laranja, width: 2)
                .frame(width: .infinity)
        }
        .padding()
    }

}


struct WatchedViews_Previews: PreviewProvider {
    static var previews: some View {
        WatchedView()
    }
}
