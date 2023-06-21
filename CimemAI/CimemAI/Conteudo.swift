//
//  COnteudo.swift
//  CimemAI
//
//  Created by André Wozniack on 21/06/23.
//

import Foundation

struct Conteudo: Identifiable{
    let id = UUID()
    let idImdb: String
    let title: String
    let image: String
    let lancamento: String
    let duracao: String
    let plot: String
    let type : String
}
