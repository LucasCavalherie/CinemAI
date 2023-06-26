
import SwiftUI

struct ChatGptView: View {
    @State var inputText: String
    @State var response: [String]?
        
    var body: some View {
        VStack {
            if let response = response {
                IMDBView(filmes: response)
            } else {
                Text("Carregando...")
            }
        }.onAppear(perform: loadData)
    }
    
    func loadData() {
        search(message: inputText) { fetchedConteudo in
            DispatchQueue.main.async {
                self.response = fetchedConteudo
            }
        }
    }
    
    func search(message: String, completion: @escaping ([String]) -> Void) {
        let apiKey = Secrets.CHATGPT_API_KEY
        let model = "gpt-3.5-turbo"
        let prompt = Prompt(role: "user", content: formatInputText(message: message))
        
        let requestJson = Request(model: model, messages: [prompt])

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
                    let response = try decoder.decode(ChatGptResponse.self, from: data)
                    var text = response.choices[0].message.content
                    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    text = text.replacingOccurrences(of: "'", with: "")
                    text = text.replacingOccurrences(of: "\"", with: "")
                    print(text)
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
    
    
    func formatInputText(message: String) -> String {
        return "Forneça apenas o nome 4 filmes, onde os espaços são -, no formato: filme1;filme2;filme3 a partir da seguinte descrição: " + message
    }
}


struct ChatGpt_Previews: PreviewProvider {
    static var previews: some View {
        ChatGptView(inputText: "Escreva exatamente o que estiver entre aspas: 'Vingadores Ultimato'")
    }
}
