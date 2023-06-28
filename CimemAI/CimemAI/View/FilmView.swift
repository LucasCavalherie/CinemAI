import SwiftUI
import CoreData

struct FilmView: View {
    var contents : [String]
    var type : String
    @State var load : Bool = false

    @State var findAllData: [FilmData] = []
    
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
                            .foregroundColor(.black)
                            .frame(width: 290, height: 110, alignment: .topLeading)
                        
                        ScrollView(.horizontal, showsIndicators: false){
                            HStack(spacing: 20){
                                ForEach(findAllData) { data in
                                    NavigationLink {
                                        IMDbDetail(conteudo: data)
                                    } label: {
                                        IMDbCard(conteudo: data)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Não achou nada")
                    }
                } else {
                    Text("Carregando...")
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 0)
            .ignoresSafeArea()
        }.onAppear(perform: loadData)
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
            
            for content in contents {
                group.addTask {
                    return await self.findFilmes(message: content)
                }
            }
            
            for await filme in group {
                if let filme = filme {
                    datas.append(filme)
                }
            }
            
            return datas
        })
    }
    
    func findFilmes(message: String) async -> FindData? {
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
            saved: false,
            watched: false
            
        )
        return conteudo
    }
    
}

struct IMDBView_Previews: PreviewProvider {
    static var previews: some View {
        FilmView(contents: ["Forest-Gump", "Vingadores", "Top-Gun"], type: "filme")
    }
}
