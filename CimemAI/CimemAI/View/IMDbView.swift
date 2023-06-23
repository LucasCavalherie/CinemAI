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
    @State var searchData: SearchData?
    
    var body: some View {
        VStack {
            if let findData = findData {
                IMDbCard(title: findData.title,url: findData.image, rating: findData.duracao)
            } else {
                Text("Carregando...")
            }
        }.onAppear(perform: loadData)
    }
    
    func loadData() {
        search(message: filmes[0]) { fetchedConteudo in
            DispatchQueue.main.async {
                self.searchData = fetchedConteudo
                if let searchData = searchData {
                    find(id: searchData.idImdb) { fetchedConteudo in
                        DispatchQueue.main.async {
                            self.findData = fetchedConteudo
                        }
                    }
                }
            }
        }
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
                    let conteudo = FindData(
                        idImdb: response.id,
                        title: response.originalTitle ?? response.title,
                        originalTitle: response.originalTitle ?? response.title,
                        image: response.image,
                        releaseDate: response.releaseDate,
                        duracao: response.duration ?? "0",
                        plot: response.plot,
                        type: response.type
                    )
                    completion(conteudo)
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
    
}

struct IMDBView_Previews: PreviewProvider {
    static var previews: some View {
        IMDBView(filmes: ["Vingadores"])
    }
}
