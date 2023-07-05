//
//  CategoriesView.swift
//  CimemAI
//
//  Created by Lucas Cavalherie on 26/06/23.
//

import SwiftUI

struct Category: Identifiable {
    let id = UUID()
    let name: String
}

struct CategoriesView: View {
    var type: String
    
    @State private var selectedGenre: [Category] = []
    private func toggleGenreSelection(_ category: Category) {
        if let index = selectedGenre.firstIndex(where: { $0.id == category.id }) {
            selectedGenre.remove(at: index)
        } else {
            selectedGenre.append(category)
        }
    }
    let genre = [
        Category(name: "Drama"),
        Category(name: "Romance"),
        Category(name: "Suspense"),
        Category(name: "Terror"),
        Category(name: "Sci-fi"),
        Category(name: "Ação"),
        Category(name: "Crime"),
        Category(name: "Família"),
        Category(name: "Guerra"),
        Category(name: "Comédia"),
        Category(name: "Animação"),
        Category(name: "Musical"),
        Category(name: "Fantasia"),
        Category(name: "Aventura"),
        Category(name: "História"),
        Category(name: "Brasileiro"),
        Category(name: "Anime")
    ]
    
    @State private var selectedScript: [Category] = []
    private func toggleScriptSelection(_ category: Category) {
        if let index = selectedScript.firstIndex(where: { $0.id == category.id }) {
            selectedScript.remove(at: index)
        } else {
            selectedScript.append(category)
        }
    }
    let script = [
        Category(name: "Espionagem"),
        Category(name: "Dança"),
        Category(name: "Policial"),
        Category(name: "Carros"),
        Category(name: "Robôs"),
        Category(name: "Animais"),
        Category(name: "Super Herói"),
        Category(name: "Faroeste"),
        Category(name: "Besteirol"),
    ]
    
    @State private var selectedMood: [Category] = []
    private func toggleMoodSelection(_ category: Category) {
        if let index = selectedMood.firstIndex(where: { $0.id == category.id }) {
            selectedMood.remove(at: index)
        } else {
            selectedMood.append(category)
        }
    }
    let mood = [
        Category(name: "Triste"),
        Category(name: "Feliz"),
        Category(name: "Quero rir"),
        Category(name: "Inspirador"),
        Category(name: "Mistério"),
        Category(name: "Relaxante"),
        Category(name: "Profundo"),
    ]
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    var btnBack : some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }){
            BackButton()
    }}
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack (alignment: .center) {
                    Text("Selecione o que você quer ver hoje:")
                        .font(.system(size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(Color("Azul_Quase_Preto"))
                        .padding(.bottom)
                    
                    
                    VStack (alignment: .leading) {
                        Text("Genêro:")
                            .font(.system(size: 20))
                            .fontWeight(.bold)
                        FlexStack {
                            ForEach(genre) { category in
                                Button {
                                    toggleGenreSelection(category)
                                } label: {
                                    Text(category.name)
                                        .font(.system(size: 16))
                                        .fontWeight(.bold)
                                        .foregroundColor(selectedGenre.contains { $0.id == category.id } ? .white : Color("Azul_Quase_Preto"))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color("Arenito"), lineWidth: 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedGenre.contains { $0.id == category.id } ? Color("Arenito") : Color.white.opacity(0))
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
                            .fontWeight(.bold)
                        FlexStack {
                            ForEach(script) { category in
                                Button {
                                    toggleScriptSelection(category)
                                } label: {
                                    Text(category.name)
                                        .font(.system(size: 16))
                                        .fontWeight(.bold)
                                        .foregroundColor(selectedScript.contains { $0.id == category.id } ? .white : Color("Azul_Quase_Preto"))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color("Menta"), lineWidth: 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedScript.contains { $0.id == category.id } ? Color("Menta") : Color.white.opacity(0))
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
                            .fontWeight(.bold)
                        FlexStack {
                            ForEach(mood) { category in
                                Button {
                                    toggleMoodSelection(category)
                                } label: {
                                    Text(category.name)
                                        .font(.system(size: 16))
                                        .fontWeight(.bold)
                                        .foregroundColor(selectedMood.contains { $0.id == category.id } ? .white : Color("Azul_Quase_Preto"))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color("Areia"), lineWidth: 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedMood.contains { $0.id == category.id } ? Color("Areia") : Color.white.opacity(0))
                                        )
                                )
                                
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                    NavigationLink {
                        let inputText = "Estou querendo \(type) para me sentir \(selectedMood.map{$0.name}.joined(separator: ", ")), me recomende um que seja de \(selectedGenre.map{$0.name}.joined(separator: ", ")) e com um tema de \(selectedScript.map{$0.name}.joined(separator: ", ")) "
                        ChatGptView(type: type, inputText: inputText)
                    } label: {
                        Text("Pesquisar")
                            .font(.system(size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(width: 300, height: 60, alignment: .center)
                    .background(Color(red: 0.15, green: 0.36, blue: 0.44))
                    .cornerRadius(16)
                    .padding(.vertical, 8)
                }
            }
            .padding()
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: btnBack)
        }
    }
}

struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CategoriesView(type: "filmes")
    }
}
