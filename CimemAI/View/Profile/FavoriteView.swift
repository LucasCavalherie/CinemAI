import SwiftUI

struct FavoriteViews: View {
    @ObservedObject var dataManager = DataManager.shared
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var btnBack : some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }){
            BackButton()
    }}

    var body: some View {
        NavigationStack{
            ScrollView {
                VStack(alignment:.center) {
                    HStack(alignment: .bottom) {
                        Text("Favoritos")
                            .font(Font.custom("Poppins", size: 30) .weight(.bold))
                            .foregroundColor(Color(red: 0.61, green: 0.13, blue: 0.15))
                            .padding(.leading, 40)
                        
                        Spacer()
                        Image("coração mascotinho")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70)
                            .padding(.top)
                            .padding(.bottom, 6)
                            .padding(.trailing, 43)
                    }
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 323, height: 1)
                        .background(Color(red: 0.61, green: 0.13, blue: 0.15))
                }
                .padding(.bottom, 10)
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible())]) {
                        ForEach(dataManager.favorites) { favoriteItem in
                            switch favoriteItem.content {
                            case .filme(let filmData):
                                if filmData.favorite {
                                    ContentCard(watchedContent: favoriteItem)
                                }
                            case .serie(let serieData):
                                if serieData.favorite {
                                    ContentCard(watchedContent: favoriteItem)
                                }
                            }
                        }
                    }.padding(.vertical, 8)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .navigationBarItems(leading: btnBack)
    }
}

struct FavoriteViews_Previews: PreviewProvider {
    static var previews: some View {
        FavoriteViews()
    }
}
