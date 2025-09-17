//
//  DigitalClockApp.swift
//  DigitalClock
//
//  Created by Martin Krčma on 17.09.2025.
//

import SwiftUI

@main
struct DigitalClockApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
