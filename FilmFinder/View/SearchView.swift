import SwiftUI

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct SearchView: View {
    var type: String
    @State var message = ""
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var btnBack : some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }){
            BackButton()
    }}
    
    @State private var selectedSearch = "Descrição"
    let searchs = ["Descrição", "Selecionar categorias"]
    
    @State private var selectedType = "Filmes"
    let types = ["Filmes", "Séries"]
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView (showsIndicators: false) {
                    VStack (alignment: .leading){
                        Text("Selecione o tipo de conteúdo que você está procurando:")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .fontWidth(.expanded)
                            .foregroundColor(Color("branco"))
                        
                        Picker("Appearance", selection: $selectedType) {
                            Text("Filmes").tag("Filmes")
                            Text("Series").tag("Series")
                        }
                        .colorMultiply(selectedType == "Filmes" ? Color("laranja") : .purple)
                        .pickerStyle(.segmented)
                        
                        Text("Escolha um método de busca:")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .fontWidth(.expanded)
                            .foregroundColor(Color("branco"))
                        
                        Picker("Appearance", selection: $selectedSearch) {
                            Text("Descrição").tag("Descrição")
                            Text("Selecionar categorias").tag("Selecionar categorias")
                        }
                        .colorMultiply(selectedSearch == "Descrição" ? Color("laranja") : .purple)
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    
                    VStack (alignment: .center) {
                        
                        if selectedSearch == "Descrição" {
                            TextField("", text: $message, axis: .vertical)
                                .placeholder(when: message.isEmpty) {
                                    VStack (alignment: .leading) {
                                        Text("Descreva o tipo de filme que você está a fim de assistir agora")
                                    }
                                    .foregroundColor(.white)
                                }
                                .lineLimit(5...10)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(width: 300, height: 300, alignment: .topLeading)
                                .background(Color("cinza2"))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color("Azul_Quase_Preto"), lineWidth: 1)
                                )
                            
                                NavigationLink {
                                    ChatGptView(type: selectedType, inputText: message)
                                } label: {
                                    HStack {
                                        Text("Pesquisar \(selectedType)")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.system(size: 15))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("preto"))
                                    .frame(width: 200, height: 40, alignment: .center)
                                    .background(Color("laranja"))
                                    .cornerRadius(16)
                                    
                                }
                        } else {
                            CategoriesView(type: $selectedType)
                        }
                        
                        
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
            .background(Color("cinza1"))
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(type: "Filmes")
    }
}
