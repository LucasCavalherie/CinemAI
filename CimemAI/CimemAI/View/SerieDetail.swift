import SwiftUI

struct SerieDetail: View {
    @State var conteudo: SerieData
    @State private var favoriteSeries = DataManager.shared.getSeriesFromFavorites()
    
    var ratingAsStars: Int {
        return Int((Double(conteudo.rating) ) / 2.0 + 0.5)
    }
    
    var body: some View {
        ScrollView{
            VStack(spacing: -25){
                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original\(conteudo.image)")) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Color.red
                    } else {
                        Color.blue
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
                            conteudo.favorite!.toggle()
                            if conteudo.favorite! {
                                DataManager.shared.saveSerieToFavorites(serie: conteudo)
                            } else {
                                DataManager.shared.removeSerieFromFavorites(serie: conteudo)
                            }
                            print(DataManager.shared.getFilmesFromFavorites())
                        }, label: {
                            if !conteudo.favorite! {
                                Text(.init(systemName: "heart"))
                                    .font(Font.custom("SF Pro", size: 30))
                                    .foregroundColor(Color("Azul_Quase_Preto"))
                            } else {
                                Text(.init(systemName: "heart.fill"))
                                    .font(Font.custom("SF Pro", size: 30))
                                    .foregroundColor(.red)
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
        .ignoresSafeArea()
        .onAppear(perform: checkIsFavorite)  // chame a função aqui
    }
    
    func checkIsFavorite() {
        if let favoriteSerie = favoriteSeries.first(where: { $0.id == conteudo.id }) {
            conteudo = favoriteSerie
        }
    }
}

struct SerieDetail_Previews: PreviewProvider {
    static var previews: some View {
        SerieDetail(conteudo: SerieData(idFilme: 19995, title: "Dark", image: "/5LoHuHWA4H8jElFlZDvsmU2n63b.jpg", releaseDate: "2017-12-01", originalTitle: nil, duration: 3, plot: "Quatro famílias iniciam uma desesperada busca por respostas quando uma criança desaparece e um complexo mistério envolvendo três gerações começa a se revelar.", rating: 8.427, favorite: false))
    }
}
