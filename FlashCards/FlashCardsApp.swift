//
//  FlashCardsApp.swift
//  FlashCards
//
//  Created by Balaji Venkatesh on 27/01/25.
//

import SwiftUI

@main
struct FlashCardsApp: App {
    let persistenceController = PersistenceController.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
