//
//  CimemAIApp.swift
//  CimemAI
//
//  Created by André Wozniack on 20/06/23.
//

import SwiftUI

@main
struct CimemAIApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
