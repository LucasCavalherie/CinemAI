import SwiftUI

struct ChatGptView: View {
    var type: String
    @State var inputText: String
    @State var response: [String]?
    @ObservedObject var dataMananger = DataManager.shared
        
    var body: some View {
        VStack {
            if let response = response {
                if type == "Filmes" {
                    FilmView(contents: response, type: type)
                } else if type == "Séries" {
                    SerieView(contents: response, type: type)
                }
            } else {

                VStack {
                    VStack {
                        Text("Encontrando as opções mais")
                            .foregroundColor(Color("branco"))
                            .fontWidth(.expanded)
                            .font(.title)
                        
                        + Text(" compatíveis ")
                            .foregroundColor(Color("laranja"))
                            .fontWidth(.expanded)
                            .font(.title)
                        
                        + Text("com você")
                            .foregroundColor(Color("branco"))
                            .fontWidth(.expanded)
                            .font(.title)
                    }
                    .fontWeight(.bold)
                    .padding(.horizontal, 32)
                    
                    
                    LottieView(name: "pipocascertasmesmo", loopMode: .loop, animationSpeed: 2)
                            .frame(width: 250, height: 112.0)
                            .scaleEffect(0.8)
                            .padding(.bottom, 60)
                }
                
            }
        }
        .onAppear(perform: loadData)
        .navigationBarBackButtonHidden(true)
    }
    func loadData() {
        print(inputText)
        if response != nil {
            return
        }
        search(message: inputText) { fetchedConteudo in
            DispatchQueue.main.async {
                self.response = fetchedConteudo
            }
        }
    }

    func search(message: String, completion: @escaping ([String]) -> Void) {
        let apiKey = Secrets.CHATGPT_API_KEY
        let model = "gpt-3.5-turbo"
        let promptUser = Prompt(role: "user", content: message)
        let promptSys = Prompt(role: "system", content: "Você é um sistema que indica \(type). O usuário ira passar um descrição e você indicara SOMENTE os nomes de \(type)s. Você indicara 9 \(type)s. Devera responder no seguinte formato: nome1;nome2;nome3;nome4;nome5;nome6;nome7;nome8;nome9. Não é necessário nenhum texto adicional ou mensagem explicando, retorne SOMENTE os NOMES")
        var alreadyRecomended : String = ""
        
        dataMananger.allContent.forEach() { movieWatched in
            switch movieWatched.content {
            case .filme(let film):
                if type == "Filmes" {
                    alreadyRecomended = alreadyRecomended + film.title + ", "
                }
                
            case .serie(let serie):
                if type == "Séries" {
                    alreadyRecomended = alreadyRecomended + serie.title + ", "
                }
            }
        }
        
        var prompts = [promptSys,promptUser]
        if alreadyRecomended != "" {
            let filterMovies = Prompt(role: "system", content: "Existem alguns \(type) que já foram recomendados que são esses: \(alreadyRecomended). Não recomende esses, recomende outros.")
            prompts = [promptSys,filterMovies,promptUser]
        }
        
//        print(prompts)
        
        let requestJson = Request(model: model, messages: prompts)
        let encoder = JSONEncoder()
        let jsonData = try? encoder.encode(requestJson)
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Erro na requisição: \(error)")
            } else if let data = data {
                let decoder = JSONDecoder()
                do {
                    _ = try JSONSerialization.jsonObject(with: data, options: [])
//                    print(jsonObject)
                    
                    let response = try decoder.decode(ChatGptResponse.self, from: data)
                    var text = response.choices[0].message.content
                    text = text.trimmingCharacters(in: .newlines)
                    text = text.replacingOccurrences(of: " ", with: "-")
                    text = text.replacingOccurrences(of: ":", with: "")
                    text = text.replacingOccurrences(of: "'", with: "")
                    text = text.replacingOccurrences(of: "\"", with: "")
                    let filmes = text
                        .split(separator: ";")
                        .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    completion(filmes)
                } catch {
                    print("Erro na decodificação: \(error)")
                }
            }
        }
        task.resume()
    }
}


struct ChatGpt_Previews: PreviewProvider {
    static var previews: some View {
        ChatGptView(type: "Filmes", inputText: "Uma filme com musica e romance cliche")
    }
}
