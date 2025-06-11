//
//  ContentView.swift
//  Letterspace Canvas
//
//  Created by Timothy Gothra on 11/26/24.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: Letterspace_CanvasDocument
    @State private var activeToolbarId: UUID?
    
    var body: some View {
        MainLayout(document: $document, activeToolbarId: $activeToolbarId)
    }
}

#Preview {
    ContentView(document: .constant(Letterspace_CanvasDocument()))
}
