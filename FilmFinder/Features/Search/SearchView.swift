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

private enum SearchMethod: Hashable {
    case description
    case categories
}

struct SearchView: View {
    @State private var message = ""
    @State private var selectedType: MediaType = .movie
    @State private var selectedMethod: SearchMethod = .description
    @FocusState private var isEditing: Bool
    @Environment(AppEnvironment.self) private var environment

    private var trimmedMessage: String {
        String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
    }

    var body: some View {
        NavigationStack {
            VStack {
                Image("FilmFinder_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 35)
                    .padding(5)

                if let quota = environment.account.quota {
                    Text("\(quota.remaining) buscas restantes hoje")
                        .font(.system(size: 13))
                        .foregroundColor(quota.remaining == 0 ? .red : Color("branco").opacity(0.7))
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading) {
                        Text("Selecione o tipo de conteúdo que você está procurando:")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .fontWidth(.expanded)
                            .foregroundColor(Color("branco"))

                        Picker("Appearance", selection: $selectedType) {
                            ForEach(MediaType.allCases, id: \.self) { type in
                                Text(type.pluralName).tag(type)
                            }
                        }
                        .colorMultiply(selectedType == .movie ? Color("laranja") : .purple)
                        .pickerStyle(.segmented)

                        Text("Escolha um método de busca:")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .fontWidth(.expanded)
                            .foregroundColor(Color("branco"))

                        Picker("Appearance", selection: $selectedMethod) {
                            Text("Descrição").tag(SearchMethod.description)
                            Text("Selecionar categorias").tag(SearchMethod.categories)
                        }
                        .colorMultiply(selectedMethod == .description ? Color("laranja") : .purple)
                        .pickerStyle(.segmented)
                    }
                    .padding()

                    VStack(alignment: .center) {
                        if selectedMethod == .description {
                            TextField("", text: $message, axis: .vertical)
                                .placeholder(when: message.isEmpty) {
                                    VStack(alignment: .leading) {
                                        Text("Descreva o tipo de filme que você está a fim de assistir agora")
                                    }
                                    .foregroundColor(.white)
                                }
                                .lineLimit(5...10)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .focused($isEditing)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(width: 300, height: 300, alignment: .topLeading)
                                .background(Color("cinza2"))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.cinza1, lineWidth: 1)
                                )

                            NavigationLink {
                                ResultsView(mediaType: selectedType, query: trimmedMessage)
                            } label: {
                                HStack {
                                    Text("Pesquisar \(selectedType.pluralNameString)")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 15))
                                .fontWeight(.bold)
                                .foregroundColor(Color("preto"))
                                .frame(width: 200, height: 40, alignment: .center)
                                .background(Color("laranja").opacity(trimmedMessage.isEmpty ? 0.4 : 1))
                                .cornerRadius(16)
                            }
                            .disabled(trimmedMessage.isEmpty)
                        } else {
                            CategoriesView(type: $selectedType)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
            .background(Color("cinza1"))
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { isEditing = false }
                }
            }
            .task { await environment.account.refresh() }
        }
    }
}

#Preview {
    SearchView()
        .environment(AppEnvironment.live())
}
