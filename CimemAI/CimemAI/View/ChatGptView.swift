
import SwiftUI

struct ChatGptView: View {
    @ObservedObject var apiRequestManager = ChatRequestManager()
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 25) {

            if let data = apiRequestManager.responseData {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let choices = json["choices"] as? [[String: Any]] {
                        if let text = choices[0]["text"] as? String {
                            Text(text)
                        }
                    }
                }
            }
            
            TextField("Pergunte", text: $inputText)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 10.0).strokeBorder(Color.gray, style: StrokeStyle(lineWidth: 1.5)))
            Button(action: {
                self.apiRequestManager.makeRequest(text: inputText)
             }) {
                 Text("Busque o seu filme")
                     .frame(minWidth: 0, maxWidth: .infinity)
                     .font(.system(size: 18))
                     .fontWeight(.bold)
                     .padding()
                     .foregroundColor(.white)
                     .overlay(
                         RoundedRectangle(cornerRadius: 20)
                             .stroke(Color.white, lineWidth: 1)
                 )
             }
             .background(Color.orange)
             .cornerRadius(20)

            
        }
        .padding()
    }
}


struct ChatGpt_Previews: PreviewProvider {
    static var previews: some View {
        ChatGptView()
    }
}
