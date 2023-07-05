import SwiftUI

struct SerieDetail: View {
    @State var conteudo: SerieData
    @ObservedObject private var dataManager = DataManager.shared
    
    var ratingAsStars: Int {
        return Int((Double(conteudo.rating) ) / 2.0 + 0.5)
    }
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var btnBack : some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }){
            BackButton()
    }}

    
    var body: some View {
        ScrollView{
            VStack(spacing: -25){
                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(conteudo.image)")) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Rectangle()
                            .opacity(0)
                            .frame(width: 390, height: 600)
                    } else {
                        Rectangle()
                            .opacity(0)
                            .frame(width: 390, height: 600)
                        
                    }
                }
                VStack(alignment: .leading, spacing: 19){
                    HStack{
                        VStack(alignment: .leading, spacing: 5){
                            Text(conteudo.title)
                                .font(Font.custom("Poppins-Regular", size: 24))
                                .foregroundColor(Color("Azul_Escuro"))
                                .fontWeight(.semibold)
                                .padding(.top)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack {
                                ForEach(0..<ratingAsStars, id: \.self) { _ in
                                    Text(.init(systemName: "star.fill"))
                                        .foregroundColor(Color("Azul_Quase_Preto"))
                                        .font(.system(size: 14))
                                }
                                ForEach(0..<(5-ratingAsStars), id: \.self) { _ in
                                    Text(.init(systemName: "star"))
                                        .foregroundColor(Color("Azul_Quase_Preto"))
                                        .font(.system(size: 14))
                                }
                            }
                        }
                        Button(action: {
                            conteudo.favorite.toggle()
                            if conteudo.favorite {
                                let watchedContent = WatchedContent(date: Date(), content: .serie(conteudo))
                                dataManager.addFavorite(watchedContent)
                            } else {
                                
                                let watchedContent = WatchedContent(date: Date(), content: .serie(conteudo))
                                dataManager.removeFavorite(watchedContent)
                            }
                            print(dataManager.favorites)
                            dataManager.saveToUserDefaults()
                        }, label: {
                            if !conteudo.favorite {
                                Text(.init(systemName: "heart"))
                                    .font(Font.custom("SF Pro", size: 30))
                                    .foregroundColor(Color("Azul_Quase_Preto"))
                            } else {
                                Text(.init(systemName: "heart.fill"))
                                    .font(Font.custom("SF Pro", size: 30))
                                    .foregroundColor(.red)
                            }
                        })

                        Button(action: {
                            conteudo.watched.toggle()
                            if conteudo.watched {
                                let watchedContent = WatchedContent(date: Date(), content: .serie(conteudo))
                                dataManager.addWatched(watchedContent)
                            } else {
                                let watchedContent = WatchedContent(date: Date(), content: .serie(conteudo))
                                dataManager.removeWatched(watchedContent)
                            }
                            print(dataManager.watched)
                            dataManager.saveToUserDefaults()
                        }, label: {
                            if !conteudo.watched {
                                Image("Olhozin")
                                    .resizable()
                                    .frame(width: 50, height: 32)
                                    .scaledToFit()
                            } else {
                                Image("Olhozin.fill")
                                    .resizable()
                                    .frame(width: 50, height: 32)
                                    .scaledToFit()
                            }
                        })
                    }
                    .padding(.horizontal, 30)
                    HStack(spacing: 10){
                        HStack{
                            Text(.init(systemName: "clock"))
                                .font(Font.custom("SF Pro", size: 14))
                            Text("\(conteudo.duration) temporadas")
                                .font(Font.custom("SF Pro", size: 14))
                                .multilineTextAlignment(.center)
                            
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 10)
                        .background(Rectangle()
                            .foregroundColor(.clear)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .inset(by: 0.5)
                                    .stroke(Color("Azul_Quase_Preto"), lineWidth: 1)
                            ))
                        Text(conteudo.releaseDate)
                            .font(Font.custom("SF Pro", size: 14))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 20)
                            .background(Rectangle()
                                .foregroundColor(.clear)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .inset(by: 0.5)
                                        .stroke(Color("Azul_Quase_Preto"), lineWidth: 1)
                                ))
                        Spacer()
                    }.padding(.leading, 30)
                    Text(conteudo.plot)
                        .font(Font.custom("SF Pro", size: 16))
                        .padding(.horizontal, 30)
                    
                    
                    Spacer()
                }.background(Rectangle()
                    .foregroundColor(Color("Branco"))
                    .cornerRadius(28))
            }
        }
        .edgesIgnoringSafeArea([.top])
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
    }
}

struct SerieDetail_Previews: PreviewProvider {
    static var previews: some View {
        SerieDetail(conteudo: SerieData(idFilme: 19995, title: "Dark", image: "/5LoHuHWA4H8jElFlZDvsmU2n63b.jpg", releaseDate: "2017-12-01", originalTitle: nil, duration: 3, plot: "Quatro famílias iniciam uma desesperada busca por respostas quando uma criança desaparece e um complexo mistério envolvendo três gerações começa a se revelar.", rating: 8.427, favorite: false, watched: false))
    }
}
