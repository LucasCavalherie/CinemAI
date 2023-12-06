//
//  CategoriesView.swift
//  CimemAI
//
//  Created by Lucas Cavalherie on 26/06/23.
//

import SwiftUI

struct Category: Identifiable {
    let id = UUID()
    let name : String
    let nameLocalized: LocalizedStringKey
    
    
    init(name: String) {
        self.name = name
        self.nameLocalized = LocalizedStringKey(name)
    }
}

struct CategoriesView: View {
    @Binding var type: String
    
    @State var selectedGenre: [Category] = []
    private func toggleGenreSelection(_ category: Category) {
        if let index = selectedGenre.firstIndex(where: { $0.id == category.id }) {
            selectedGenre.remove(at: index)
        } else {
            selectedGenre.append(category)
        }
    }
    let genre = [
        Category(name: "Drama"),
        Category(name: "Suspense"),
        Category(name: "Romance"),
        Category(name: "Terror"),
        Category(name: "Sci-fi"),
        Category(name: "Ação"),
        Category(name: "Comédia"),
        Category(name: "Fantasia"),
        Category(name: "Anime"),
        Category(name: "Mistério"),
        Category(name: "Animação"),
        Category(name: "Musical"),
        Category(name: "Aventura"),
        Category(name: "Biográfico"),
        Category(name: "Histórico")
    ]
    
    @State var selectedScript: [Category] = []
    private func toggleScriptSelection(_ category: Category) {
        if let index = selectedScript.firstIndex(where: { $0.id == category.id }) {
            selectedScript.remove(at: index)
        } else {
            selectedScript.append(category)
        }
    }
    
    let script = [
        Category(name: "Crime"),
        Category(name: "Esportes"),
        Category(name: "Dança"),
        Category(name: "Policial"),
        Category(name: "Super Herói"),
        Category(name: "Faroeste"),
        Category(name: "Espionagem"),
        Category(name: "Robôs"),
        Category(name: "Guerra"),
        Category(name: "Adolescente"),
        Category(name: "Enigmas"),
        Category(name: "Besteirol"),
        Category(name: "Sobrenatural"),
        Category(name: "Zumbi"),
        Category(name: "Clichê"),
        Category(name: "LGBTQIA+"),
        Category(name: "Carros"),
        Category(name: "Animais")
    ]
    
    @State var selectedMood: [Category] = []
    private func toggleMoodSelection(_ category: Category) {
        if let index = selectedMood.firstIndex(where: { $0.id == category.id }) {
            selectedMood.remove(at: index)
        } else {
            selectedMood.append(category)
        }
    }
    let mood = [
        Category(name: "Apaixonado(a)"),
        Category(name: "Relaxado"),
        Category(name: "Conforto"),
        Category(name: "Chorar igual um bebê"),
        Category(name: "Divertido"),
        Category(name: "Inspirado"),
        Category(name: "Noite de filmes com amigos"),
        Category(name: "Rir até não conseguir mais"),
        Category(name: "Reflexivo"),
        Category(name: "A vida é uma só")
    ]
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var btnBack : some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }){
            BackButton()
    }}
    
    var body: some View {
        VStack (alignment: .center) {
            VStack (alignment: .leading) {
                Text("Genêro:")
                    .font(.system(size: 20))
                    .fontWidth(.expanded)
                
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32), count: 3), spacing: 16) {
                    ForEach(genre) { category in
                        Button {
                            toggleGenreSelection(category)
                        } label: {
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundColor(.clear)
                                .frame(width: 85, height: 26)
                                .overlay(
                                    Text(category.nameLocalized)
                                        .font(.system(size: 13))
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedGenre.contains { $0.id == category.id } ? .white : Color("branco"))
                                )
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedGenre.contains { $0.id == category.id } ? Color("roxo") : Color("branco"), lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedGenre.contains { $0.id == category.id } ? Color("roxo") : Color.clear)
                                )
                        )
                        
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            VStack (alignment: .leading) {
                Text("Tema:")
                    .font(.system(size: 20))
                    .fontWidth(.expanded)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32), count: 3), spacing: 16) {
                    ForEach(script) { category in
                        Button {
                            toggleScriptSelection(category)
                        } label: {
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundColor(.clear)
                                .frame(width: 85, height: 26)
                                .overlay(
                                    Text(category.nameLocalized)
                                        .font(.system(size: 13))
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedScript.contains { $0.id == category.id } ? .white : Color("branco"))

                                        
                                )
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedScript.contains { $0.id == category.id } ? Color("roxo") : Color("branco"), lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedScript.contains { $0.id == category.id } ? Color("roxo") : Color.clear)
                                )
                        )
                        
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            VStack (alignment: .leading) {
                Text("Como você se sente hoje:")
                    .font(.system(size: 20))
                    .fontWidth(.expanded)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32), count: 3), spacing: 16) {
                    ForEach(mood) { category in
                        Button {
                            toggleMoodSelection(category)
                        } label: {
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundColor(.clear)
                                .frame(width: 85, height: 26)
                                .overlay(
                                    Text(category.nameLocalized)
                                        .font(.system(size: 11))
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedMood.contains { $0.id == category.id } ? .white : Color("branco"))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        
                                )
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMood.contains { $0.id == category.id } ? Color("roxo") : Color("branco"), lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedMood.contains { $0.id == category.id } ? Color("roxo") : Color.clear)
                                )
                        )
                        
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            NavigationLink {
                let inputText = "Estou querendo \(type) para me sentir \(selectedMood.map{$0.name }.joined(separator: ", ")), me recomende um que seja de \(selectedGenre.map{$0.name}.joined(separator: ", ")) e com um tema de \(selectedScript.map{$0.name}.joined(separator: ", "))"
                
                ChatGptView(type: type, inputText: inputText)
            } label: {
                HStack {
                    Text("Pesquisar \(type)")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15))
                .fontWeight(.bold)
                .foregroundColor(Color("preto"))
                .frame(width: 200, height: 40, alignment: .center)
                .background(Color("laranja"))
                .cornerRadius(16)
                
            }
        }
    }
    
    func joinedNames(from categories: [Category]) -> String {
        categories.map { NSLocalizedString($0.name, comment: "") }
                  .joined(separator: ", ")
    }
}

struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CategoriesView(type: Binding.constant("Filmes"))
    }
}
