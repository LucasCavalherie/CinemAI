import SwiftUI

struct SerieView: View {
    var contents : [String]
    var type : String
    @State var findData: SerieData?
    @State var findAllData: [SerieData] = []

    
    var body: some View {
        NavigationStack{
            VStack(alignment: .leading, spacing: 16) {
                if findAllData.count > 0 {
                    Text("Estes são as séries mais compatíveis com você hoje:")
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
                                    SerieDetail(conteudo: data)
                                } label: {
                                    SerieCard(conteudo: data)
                                }
                            }
                        }
                    }
                } else {
                    Text("Não achou nada")
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
            }
        }
    }

    
    func findAll () async -> [SerieData] {
        return await withTaskGroup(of: SerieData?.self, body: { group in
            var datas = [SerieData]()
            
            for content in contents {
                group.addTask {
                    return await self.findSeries(message: content)
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
    
    func findSeries(message: String) async -> SerieData? {
        print(message)
        let mensagem = message.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? message
        var request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/search/tv?query=\(mensagem)&include_adult=false&language=pt-BR&page=1")!,timeoutInterval: Double.infinity)
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
            saved: false,
            watched: false
        )
        return conteudo
    }
    
}

struct SerieView_Previews: PreviewProvider {
    static var previews: some View {
        SerieView(contents: ["dark", "black-Mirror", "suits"], type: "série")
    }
}
