import SwiftUI

struct SerieDetail: View {
    let conteudo: SerieData
    
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
                        Color.red
                    } else {
                        Color.blue
                    }
                }
                VStack(alignment: .leading, spacing: 19){
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
                                    .foregroundColor(.black)
                                    .font(.system(size: 14))
                            }
                            ForEach(0..<(5-ratingAsStars), id: \.self) { _ in
                                Text(.init(systemName: "star"))
                                    .foregroundColor(.black)
                                    .font(.system(size: 14))
                            }
                        }
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
                                    .stroke(Color(red: 0, green: 0.07, blue: 0.1), lineWidth: 1)
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
                                        .stroke(Color(red: 0, green: 0.07, blue: 0.1), lineWidth: 1)
                                ))
                            
                        Spacer()
                    }.padding(.leading, 30)
                    Text(conteudo.plot)
                        .font(Font.custom("SF Pro", size: 16))
                        .padding(.horizontal, 30)
                    
                    
                Spacer()
                }.background(Rectangle()
                    .foregroundColor(.white)
                    .cornerRadius(28))
            }
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
    }
}

struct SerieDetail_Previews: PreviewProvider {
    static var previews: some View {
        SerieDetail(conteudo: SerieData(idFilme: 19995, title: "Dark", image: "/5LoHuHWA4H8jElFlZDvsmU2n63b.jpg", releaseDate: "2017-12-01", originalTitle: nil, duration: 3, plot: "Quatro famílias iniciam uma desesperada busca por respostas quando uma criança desaparece e um complexo mistério envolvendo três gerações começa a se revelar.", rating: 8.427))
    }
}
