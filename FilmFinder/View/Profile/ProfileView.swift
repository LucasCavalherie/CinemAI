import SwiftUI

struct ProfileView: View {
    
    @ObservedObject var dataManager = DataManager.shared
    
    var body: some View {
        NavigationStack{
            VStack(alignment: .center){
                Image("FilmFinder_logoPB")
                    .resizable()
                    .frame(width: 54, height: 29)
                
                Image("perfil")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94)
                    .padding(.top, 20)
                
                Text("Meu Perfil")
                    .font(.system(size: 20))
                    .fontWidth(.expanded)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                    .foregroundColor(.laranja)
                HStack{
                    Text("\(dataManager.watched.count) Filmes Assistidos |") +
                    Text(" \(dataManager.favorites.count) Filmes Favoritos")
                }
                .font(.system(size: 15))
                .fontWeight(.medium)
                .foregroundColor(.branco)
                
                VStack{
                    NavigationLink {
                        FavoriteViews()
                    } label: {
                        FavoriteRectangle()
                        
                    }
                    NavigationLink {
                        WatchedView()
                    } label: {
                        WatchedRectangle()
                        
                    }
                    
                }
                
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cinza1)
        }
        
    }
    
    
}


struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
