//
//  Letterspace_CanvasApp.swift
//  Letterspace Canvas
//
//  Created by Timothy Gothra on 11/26/24.
//

import SwiftUI

@main
struct Letterspace_CanvasApp: App {
    @State private var document = Letterspace_CanvasDocument()
    
    init() {
        Font.registerInterTightFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(document: $document)
                .frame(minWidth: 1200, minHeight: 800)
                .frame(idealWidth: 1440, idealHeight: 900)
                .withTheme()
                .ignoresSafeArea()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1440, height: 900)
    }
}
