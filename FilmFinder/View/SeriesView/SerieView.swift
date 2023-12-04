import SwiftUI

struct SerieView: View {
    var contents : [String]
    var type : String
    @State var findData: SerieData?
    @State var findAllData: [SerieData] = []
    @State var otherData: [SerieData] = []
    @State var load : Bool = false
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
            VStack(alignment: .leading, spacing: 16) {
                if load {
                    if findAllData.count > 0 {
                        Text("Estes são as séries mais compatíveis com você hoje:")
                            .font(
                                Font.custom("Poppins", size: 24)
                                    .weight(.bold)
                            )
                            .foregroundColor(Color("Azul_Quase_Preto"))
                            .frame(width: 290, height: 110, alignment: .topLeading)
                        
                        ScrollView(.horizontal, showsIndicators: false){
                            HStack(spacing: 20){
                                ForEach(findAllData) { data in
                                    NavigationLink {
                                        SerieDetail(conteudo: data)
                                    } label: {
                                        ZStack (alignment: .topTrailing) {
                                            SerieCard(conteudo: data)
                                            if otherData.count >= 1 {
                                                Button {
                                                    changeSerie(oldSerie: data)
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "arrow.clockwise")
                                                            .font(.system(size: 20))
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white)
                                                    }
                                                    .padding(8)
                                                    .background(.gray)
                                                    .opacity(0.7)
                                                    .cornerRadius(10)
                                                    .padding()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        ErrorView()
                    }
                } else {
                    LottieView(name: "pipocascertasmesmo", loopMode: .loop, animationSpeed: 2)
                            .frame(width: 250, height: 112.0)
                            .scaleEffect(0.8)
                            .padding(.bottom, 60)
                }
                
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 0)
            .ignoresSafeArea()
        }
        .onAppear(perform: loadData)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
    }
    
    func changeSerie(oldSerie: SerieData){
        if let index = findAllData.firstIndex(where: { $0.id == oldSerie.id }) {
            findAllData.remove(at: index)
        }
        if otherData.count > 0 {
            findAllData.append(otherData.first!)
            otherData.removeFirst()
        }
        
    }
    
    func loadData() {
        if findAllData.count == 0 {
            Task {
                let data = await findAll()
                DispatchQueue.main.async {
                    findAllData = data
                }
                load = true
            }
        }
    }

    
    func findAll () async -> [SerieData] {
        return await withTaskGroup(of: SerieData?.self, body: { group in
            var datas = [SerieData]()
            var count = 0
            
            for content in contents {
                group.addTask {
                    return await self.findSeries(message: content)
                }
            }
            
            for await serie in group {
                if let serie = serie {
                    let repetido = DataManager.shared.checkContentsAlreadyInToWatched(content: WatchedContent(date: Date(), content: .serie(serie)))
                    if !repetido {
                        if count < 3 {
                            datas.append(serie)
                            dataManager.addContent(WatchedContent(date: Date(), content: .serie(serie)))
                        } else {
                            otherData.append(serie)
                        }
                        count = count + 1
                    }
                }
            }
            
            return datas
        })
    }
    
    func findSeries(message: String) async -> SerieData? {
        let idioma = Locale.current.language.languageCode
        var len = ""
        switch idioma {
        case "en":
            len = "en-US"
        case "pt":
            len = "pt-BR"
        case "fr":
            len = "fr-FR"
        case .none:
            len = "en-US"
        case .some(_):
            len = "en-US"
        }
        let mensagem = message.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? message
        var request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/search/tv?query=\(mensagem)&include_adult=false&language=\(len)&page=1")!,timeoutInterval: Double.infinity)
        request.addValue("Bearer \(Secrets.TMDB_API_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "accept")
    
        request.httpMethod = "GET"
        
        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            print("deu pau 1")
            return nil
        }
        
        
        let decoder = JSONDecoder()
        guard let response = try? decoder.decode(SearchResponse.self, from: data) else {
            print("deu pau")
            return nil
        }
        
        guard response.results.count > 0 else {
            print("Reponse.count == 0")
            return nil
        }
        let id = response.results[0].id
        
        var urlFind = URLRequest(url: URL(string: "https://api.themoviedb.org/3/tv/\(id)?language=pt-BR")!,timeoutInterval: Double.infinity)
        urlFind.addValue("Bearer \(Secrets.TMDB_API_KEY)", forHTTPHeaderField: "Authorization")
        urlFind.httpMethod = "GET"
        
        guard let (data, _) = try? await URLSession.shared.data(for: urlFind) else {
            print("deu pau de novo")
            return nil
        }
        
        guard let response = try? decoder.decode(SerieFindResponse.self, from: data) else {
            print("deu pau na response")
            return nil
        }
        
        let conteudo = SerieData(
            idFilme: response.id,
            title: response.title,
            image: response.image,
            releaseDate: response.releaseDate,
            originalTitle: response.releaseDate,
            duration: response.duration,
            plot: response.plot,
            rating: response.rating,
            favorite: false,
            watched: false
        )
        return conteudo
    }
    
}

struct SerieView_Previews: PreviewProvider {
    static var previews: some View {
        SerieView(contents: ["dark", "black-Mirror", "suits", "stranger things"], type: "série")
    }
}
