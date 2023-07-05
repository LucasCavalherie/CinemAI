import SwiftUI

struct ProfileView: View {
    
    @ObservedObject var dataManager = DataManager.shared
    
    var body: some View {
        NavigationStack{
            VStack(alignment: .center){
                
                Image("perfil")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128)
                    .padding(.top, 40)
                
                Text("Meu Perfil")
                    .font(Font.custom("Poppins-regular", size: 25))
                    .fontWeight(.bold)
                    .padding(.bottom, 30)
                    .foregroundColor(Color(red: 0.22, green: 0.48, blue: 0.53))
                
                NavigationLink(destination: {
                    FavoriteViews()
                }, label: {
                    ProfileFavoriteCard(contents: dataManager.favorites)
                })
                .background( Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 350, height: 230)
                    .background(Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.3))
                    .cornerRadius(16))
                
                .padding(.bottom, 40)
                NavigationLink(destination: {
                    WatchedView()
                }, label: {
                    ProfileFavoriteCard(contents: dataManager.watched)
                })
                .background( Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 350, height: 230)
                    .background(Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.3))
                    .cornerRadius(16))
                .padding(.bottom, 40)
                
            }
            
            .padding(.vertical)
            Spacer()
        }
    }
    
}


struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
