import SwiftUI

struct ChatGptView: View {
    var type: String
    @State var inputText: String
    @State var response: [String]?
    @State var filterMovies = DataManager.shared.getFilmesFromFavorites()
    @State var filterSeries = DataManager.shared.getSeriesFromFavorites()
        
    var body: some View {
        VStack {
            if let response = response {
                if type == "filme" {
                    FilmView(contents: response, type: type)
                } else if type == "série" {
                    SerieView(contents: response, type: type)
                }
            } else {
                Text("Carregando as \nmelhores escolhas...")
                    .fontWeight(.heavy)
                    .font(.title)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)

                LottieView(name: "pipocascertasmesmo", loopMode: .loop, animationSpeed: 2)
                        .frame(width: 250, height: 112.0)
                        .scaleEffect(0.8)
                        .padding(.bottom, 60)
            }
        }
        .onAppear(perform: loadData)
        .navigationBarBackButtonHidden(true)
    }
    func loadData() {
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
        
        let promptSys = Prompt(role: "system", content: "Você é um sistema que indica somente os nomes de \(type) a partir de uma descrição do usuário sem a necessidade de qualquer outro tipo de texto ou explicação antes ou depois dos nomes indicados. Voce sempre retorna somente os 9 nomes de \(type) no seguinte formato: nome1;nome2;nome3. Não faça nenhum comentário. Voce retornara apenas os nomes dos \(type) no formato indicado.")
        
        var alreadyRecomended : String = ""
        
        if type == "filme" {
            filterMovies.forEach() { movieWatched in
                print(movieWatched.title)
                alreadyRecomended = alreadyRecomended + movieWatched.title + ", "
            }
        } else if type == "série" {
            filterSeries.forEach() { serieWatched in
                alreadyRecomended = alreadyRecomended + serieWatched.title + ", "
            }
        }
        
        var prompts = [promptSys,promptUser]
        if alreadyRecomended != "" {
            let filterMovies = Prompt(role: "system", content: "Existem alguns \(type) que já foram recomendados que são esses: \(alreadyRecomended). Não recomende esses \(type), recomende outros.")
            prompts = [promptSys,filterMovies,promptUser]
        }
        
        print(prompts)
        
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
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    print(jsonObject)
                    
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
        ChatGptView(type: "filme", inputText: "Uma filme com musica e romance cliche")
    }
}
