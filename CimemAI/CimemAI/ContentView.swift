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
                Text("Título: \(conteudo.title)")
                Text("ID do IMDB: \(conteudo.idImdb)")
                Text("Duração: \(conteudo.duracao)")
                // Adicione mais campos conforme necessário
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
        guard let url = URL(string: "https://imdb-api.com/pt/API/Title/k_cj8fffs5/tt0386676/Ratings,Wikipedia") else {
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
                                            image: response.image,
                                            lancamento: response.fullTitle!,
                                            duracao: response.duration ?? "0",
                                            plot: response.plot,
                                            type: response.type)
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
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
