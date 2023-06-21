

import Foundation
import Combine

@MainActor
class ChatRequestManager: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @Published var responseData: Data?
    @Published var responseError: Error?

    func makeRequest(text: String) {
        let apiKey = "KEY-AQUI"
        let model = "text-davinci-003"
        let prompt = text
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

        URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0.data }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let err):
                    self.responseError = err

                default:
                    break;
                }
            }, receiveValue: { data in
                DispatchQueue.main.async {
                    self.responseData = data
                }
            })
            .store(in: &self.cancellables)
    }
}
