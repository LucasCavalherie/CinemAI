//
//  CimemAIApp.swift
//  CimemAI
//
//  Created by André Wozniack on 20/06/23.
//

import SwiftUI
import Foundation

@main
struct CimemAIApp: App {
    
    init() {
        for family in UIFont.familyNames {
            print(family)
            for font in UIFont.fontNames(forFamilyName: family) {
                print(" \(font)")
            }
                    
        }
    }
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
