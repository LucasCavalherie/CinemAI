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
    @State private var selectedCategories: [Category] = []
    let categories = [
        Category(name: "Drama"),
        Category(name: "Romance"),
        Category(name: "Suspense"),
        Category(name: "Terror"),
        Category(name: "Ficção científica"),
        Category(name: "Ação"),
        Category(name: "Crime"),
        Category(name: "Família"),
        Category(name: "Guerra"),
        Category(name: "Comédia"),
        Category(name: "Animação"),
        Category(name: "Musical"),
        Category(name: "Fantasia"),
        Category(name: "Aventura"),
        Category(name: "História")
    ]
    
    var body: some View {
        NavigationStack {
            VStack (alignment: .center) {
                Text("Selecione o que você quer ver hoje:")
                    .font(.system(size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.17, green: 0.17, blue: 0.17))
                    .padding(.bottom)
                
                LazyVGrid (columns: [GridItem(), GridItem(), GridItem()]) {
                    ForEach(categories) { category in
                        Button {
                            toggleCategorySelection(category)
                        } label: {
                            Text(category.name)
                                .font(.system(size: 16))
                                .fontWeight(.bold)
                                .foregroundColor(selectedCategories.contains { $0.id == category.id } ? .white : .black)
                        }
                        .frame(width: 80, height: 60, alignment: .center)
                        .padding(.horizontal, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange, lineWidth: 3)
                        )
                        .background(RoundedRectangle(cornerRadius: 20).fill(selectedCategories.contains { $0.id == category.id } ? Color.orange : Color.white))
                    }
                }
                .padding(.horizontal)
                
                NavigationLink {
                    let inputText = " me diga \(type) que sejam \(selectedCategories.map{$0.name}.joined(separator: ", "))"
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
            .padding()
        }
    }

    private func toggleCategorySelection(_ category: Category) {
        if let index = selectedCategories.firstIndex(where: { $0.id == category.id }) {
            selectedCategories.remove(at: index)
        } else {
            selectedCategories.append(category)
        }
    }
}

struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CategoriesView(type: "filmes")
    }
}
