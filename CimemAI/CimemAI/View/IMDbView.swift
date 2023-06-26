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
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 0)
            .ignoresSafeArea()
        }.onAppear(perform: loadData)
    }
    
    func loadData() {
    
        Task {
            let data = await findAll()
            DispatchQueue.main.async {
                findAllData = data
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
    
    func find(id: String, completion: @escaping (FindData) -> Void) {
        guard let url = URL(string: "https://imdb-api.com/pt/API/Title/\(Secrets.IMDB_API_KEY)/\(id)/Ratings,Wikipedia") else {
            print("URL inválida")
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Erro na requisição: \(error)")
            } else if let data = data {
                let decoder = JSONDecoder()
                do {
                    let response = try decoder.decode(FindResponse.self, from: data)
                    let findData = FindData(
                        idImdb: response.id,
                        title: response.originalTitle ?? response.title,
                        originalTitle: response.originalTitle ?? response.title,
                        image: response.image,
                        releaseDate: response.releaseDate,
                        year: response.year,
                        duracao: response.duration ?? "",
                        plot: response.plot,
                        type: response.type,
                        imDbRating: response.imDbRating,
                        director: response.director,
                        stars: response.stars)
                    completion(findData)
                } catch {
                    print("Erro na decodificação: \(error)")
                }
            }
        }

        task.resume()
    }
    
    func search(message: String, completion: @escaping (SearchData) -> Void) {
        guard let url = URL(string: "https://imdb-api.com/pt/API/Search/\(Secrets.IMDB_API_KEY)/\(message)") else {
            print("URL inválida")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Erro na requisição: \(error)")
            } else if let data = data {
                let decoder = JSONDecoder()
                do {
                    let response = try decoder.decode(SearchResponse.self, from: data)
                    let conteudo = SearchData(idImdb: response.results[0].id)
                    completion(conteudo)
                } catch {
                    print("Erro na decodificação: \(error)")
                }
            }
        }

        task.resume()
    }
    
    func findFilmes(message: String) async -> FindData? {
        guard let urlSearch = URL(string: "https://imdb-api.com/pt/API/Search/\(Secrets.IMDB_API_KEY)/\(message)") else {
            print("URL inválida")
            return nil
        }
        
        guard let (data, _) = try? await URLSession.shared.data(from: urlSearch) else {
            print("deu pau")
            return nil
        }
        
        
        let decoder = JSONDecoder()
        guard let response = try? decoder.decode(SearchResponse.self, from: data) else {
            print("deu pau")
            return nil
        }
        
        let id = response.results[0].id
        
        
        guard let urlFind = URL(string: "https://imdb-api.com/pt/API/Title/\(Secrets.IMDB_API_KEY)/\(id)/Ratings,Wikipedia") else {
            print("URL inválida")
            return nil
        }
        
        guard let (data, _) = try? await URLSession.shared.data(from: urlFind) else {
            print("deu pau")
            return nil
        }
        
        guard let response = try? decoder.decode(FindResponse.self, from: data) else {
            print("deu pau")
            return nil
        }
        
        let conteudo = FindData(
            idImdb: response.id,
            title: response.title,
            originalTitle: response.originalTitle ?? response.title,
            image: response.image,
            releaseDate: response.releaseDate,
            year: response.year,
            duracao: response.duration ?? "",
            plot: response.plot,
            type: response.type,
            imDbRating: response.imDbRating,
            director: response.director,
            stars: response.stars
        )
        
        return conteudo
    }
}

struct IMDBView_Previews: PreviewProvider {
    static var previews: some View {
        IMDBView(filmes: ["Vingadores", "JurassicPark", "poderosochefão"])
    }
}
