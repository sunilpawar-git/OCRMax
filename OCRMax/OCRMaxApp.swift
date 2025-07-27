//
//  OCRMaxApp.swift
//  OCRMax
//
//  Created by Sunil Pawar on 27/07/25.
//

import SwiftUI

@main
struct OCRMaxApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
