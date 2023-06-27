//
//  ContentView.swift
//  CimemAI
//
//  Created by André Wozniack on 20/06/23.
//

import SwiftUI
import CoreData

struct IMDBView: View {
    var filmes : [String]
    @State var findData: FindData?
    @State var findAllData: [FindData] = []
    
    var body: some View {
        NavigationStack{
            VStack(alignment: .leading, spacing: 16) {
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
    
    func findAll () async -> [FindData] {
        return await withTaskGroup(of: FindData?.self, body: { group in
            var datas = [FindData]()
            
            for filme in filmes {
                group.addTask {
                    return await self.findFilmes(message: filme)
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
        var mensagem = message.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? message
        var request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/search/multi?query=\(mensagem)&include_adult=false&language=pt-BR&page=1")!,timeoutInterval: Double.infinity)
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
        
        let conteudo = FindData(
            idFilme: response.id,
            title: response.title,
            image: response.image,
            releaseDate: response.releaseDate,
            originalTitle: response.releaseDate,
            duration: response.duration,
            plot: response.plot,
            rating: response.rating
        )
        return conteudo
    }
}

struct IMDBView_Previews: PreviewProvider {
    static var previews: some View {
        IMDBView(filmes: ["Vingadores", "Jurassic-aasdaPark", "poderoso-chefao"])
    }
}
