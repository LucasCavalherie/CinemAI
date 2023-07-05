import SwiftUI

struct FilmDetail: View {
    @State var conteudo: FilmData
    
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
                        Image("pipocotriste")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipped()
                            .frame(width: 390, height: 600)
                    } else {
                        Image("pipoco")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipped()
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
                                let watchedContent = WatchedContent(date: Date(), content: .filme(conteudo))
                                DataManager.shared.saveContentToFavorites(content: watchedContent)
                            } else {
                                let watchedContent = WatchedContent(date: Date(), content: .filme(conteudo))
                                DataManager.shared.removeContentFromFavorites(content: watchedContent)
                            }
                            print(DataManager.shared.getContentsFromFavorites())
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
                                DataManager.shared.saveContentToWatched(content: WatchedContent(date: Date(), content: .filme(conteudo)))
                            } else {
                                DataManager.shared.removeContentFromWatched(content: WatchedContent(date: Date(), content: .filme(conteudo)))
                            }
                            print(DataManager.shared.getContentsFromWatched())
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
                            Text("\(conteudo.duration) min")
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


struct FilmDetail_Previews: PreviewProvider {
    static var previews: some View {
        FilmDetail(conteudo: FilmData(idFilme: 19995, title: "Avatar", image: "/iNMP8uzV2Ing6ZCw0IICgEFVNfC.jpg", releaseDate: "2009-12-15", originalTitle: nil, duration: 162, plot: "Apesar de confinado a uma cadeira de rodas, Jake Sully, um ex-marine, continua a ser um combatente. Assim, é recrutado para uma missão a Pandora, um corpo celeste que orbita um enorme planeta gasoso, para explorar um mineral alternativo chamado Unobtainium, usado na Terra como recurso energético. Porém, devido ao facto de a atmosfera de Pandora ser altamente tóxica para os humanos, é usado um programa de avatares híbridos, que possibilita a transferência da mente de qualquer humano para um corpo nativo.", rating: 7.571, favorite: false, watched: false))
    }
}
