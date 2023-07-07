import SwiftUI
import CoreData

struct FilmView: View {
    var contents : [String]
    var type : String
    @State var load : Bool = false
    @ObservedObject var dataMananger = DataManager.shared

    @State var findAllData: [FilmData] = []
    @State var otherData: [FilmData] = []
    
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
                        Text("Estes são os três filmes mais compatíveis com você hoje:")
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
                                        FilmDetail(conteudo: data)
                                    } label: {
                                        ZStack (alignment: .topTrailing) {
                                            FilmCard(conteudo: data)
                                            if otherData.count >= 1 {
                                                Button {
                                                    changeMovie(oldMovie: data)
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
    
    func changeMovie(oldMovie: FilmData){
        if let index = findAllData.firstIndex(where: { $0.id == oldMovie.id }) {
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
    
    func findAll () async -> [FilmData] {
        return await withTaskGroup(of: FilmData?.self, body: { group in
            var datas = [FilmData]()
            var count = 0
            
            for content in contents {
                group.addTask {
                    return await self.findFilmes(message: content)
                }
            }
            
            for await filme in group {
                if let filme = filme {
                    let repetido = dataMananger.checkContentsAlreadyInToWatched(content: WatchedContent(date: Date(), content: .filme(filme)))
                    dataMananger.addContent(WatchedContent(date: Date(), content: .filme(filme)))
                    if !repetido {
                        if count < 3 {
                            datas.append(filme)
                            
                        } else {
                            otherData.append(filme)
                        }
                        count = count + 1
                    }
                }
            }
            
            return datas
        })
    }
    
    func findFilmes(message: String) async -> FilmData? {
        let mensagem = message.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? message
        var request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/search/movie?query=\(mensagem)&include_adult=false&language=pt-BR&page=1")!,timeoutInterval: Double.infinity)
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
        
        var urlFind = URLRequest(url: URL(string: "https://api.themoviedb.org/3/movie/\(id)?language=pt-BR")!,timeoutInterval: Double.infinity)
        urlFind.addValue("Bearer \(Secrets.TMDB_API_KEY)", forHTTPHeaderField: "Authorization")
        urlFind.httpMethod = "GET"
        
        guard let (data, _) = try? await URLSession.shared.data(for: urlFind) else {
            print("deu pau de novo")
            return nil
        }
        
        guard let response = try? decoder.decode(FindResponse.self, from: data) else {
            print("deu pau na response")
            return nil
        }
        
        let conteudo = FilmData(
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

struct IMDBView_Previews: PreviewProvider {
    static var previews: some View {
        FilmView(contents: ["Forest-Gump", "Vingadores", "Top-Gun", "Procurando Nemo"], type: "filme")
    }
}
