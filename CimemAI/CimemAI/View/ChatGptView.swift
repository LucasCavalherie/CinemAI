
import SwiftUI

struct ChatGptView: View {
    @State var inputText: String
    @State var response: String?
        
    var body: some View {
        VStack {
            if let response = response {
                IMDBView(messageChatGpt: response)
            } else {
                Text("Carregando...")
            }
        }.onAppear(perform: loadData)
    }
    
    func loadData() {
        search(message: inputText) { fetchedConteudo in
            DispatchQueue.main.async {
                self.response = fetchedConteudo
                print(self.response)
            }
        }
    }
    
    func search(message: String, completion: @escaping (String) -> Void) {
        let apiKey = Secrets.CHATGPT_API_KEY
        let model = "text-davinci-003"
        let prompt = message
        let maxTokens = 150

        let requestBody : [String : Any] = [
            "model": model,
            "prompt": prompt,
            "max_tokens": maxTokens
        ]

        let jsonData = try? JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/completions")!)
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
                    var text = response.choices[0].text
                    text = text.filter{!$0.isWhitespace}
                    text = text.replacingOccurrences(of: "'", with: "")
                    text = text.replacingOccurrences(of: "\"", with: "")
                    
                    print(text)
                    completion(text)
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
        ChatGptView(inputText: "Escreva exatamente o que estiver entre aspas: 'Vingadores Ultimato'")
    }
}
