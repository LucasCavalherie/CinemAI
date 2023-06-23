//
//  ContentView.swift
//  CimemAI
//
//  Created by André Wozniack on 20/06/23.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var conteudo: Conteudo?

    var body: some View {
        VStack {
            if let conteudo = conteudo {
                AsyncImage(url: URL(string: conteudo.image), scale: 5)
                Text("Título: \(conteudo.title)")
                Text("Duração: \(conteudo.duracao)")
            } else {
                Text("Carregando...")
            }
        }.onAppear(perform: loadData)
    }
    
    func loadData() {
        fetchData { fetchedConteudo in
            DispatchQueue.main.async {
                self.conteudo = fetchedConteudo
            }
        }
    }
    
    func fetchData(completion: @escaping (Conteudo) -> Void) {
        guard let url = URL(string: "https://imdb-api.com/pt/API/Title/\(Secrets.IMDB_API_KEY)/tt0861739/Ratings,Wikipedia") else {
            print("URL inválida")
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Erro na requisição: \(error)")
            } else if let data = data {
                let decoder = JSONDecoder()
                do {
                    let response = try decoder.decode(Response.self, from: data)
                    let conteudo = Conteudo(idImdb: response.id,
                        title: response.title,
                        originalTitle: response.originalTitle ?? "",
                        image: response.image,
                        releaseDate: response.releaseDate,
                        year: response.year,
                        duracao: response.duration ?? "",
                        plot: response.plot,
                        type: response.type,
                        imDbRating: response.imDbRating,
                        director: response.director,
                        stars: response.stars)
                        completion(conteudo)
                } catch {
                    print("Erro na decodificação: \(error)")
                }
            }
        }

        task.resume()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
