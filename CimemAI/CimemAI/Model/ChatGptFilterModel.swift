
import SwiftUI

// Classe observável para armazenar o estado e os valores selecionados
class ChatGptFilterModel: ObservableObject {
    @Published var tipo: String = ""
    @Published var filtros: [String] = [""]
}
