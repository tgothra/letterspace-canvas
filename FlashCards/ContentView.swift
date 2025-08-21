//
//  ContentView.swift
//  FlashCards
//
//  Created by Balaji Venkatesh on 27/01/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var dragProperties: DragProperties = .init()
    var body: some View {
        NavigationStack {
            Home()
                .navigationTitle("Flash Cards")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
        /// I want always dark mode
        .preferredColorScheme(.dark)
        .overlay(alignment: .topLeading) {
            if let previewImage = dragProperties.previewImage, dragProperties.show {
                Image(uiImage: previewImage)
                    .opacity(0.8)
                    .offset(
                        x: dragProperties.initialViewLocation.x,
                        y: dragProperties.initialViewLocation.y
                    )
                    .offset(dragProperties.offset)
                    .ignoresSafeArea()
            }
        }
        .environmentObject(dragProperties)
    }
}

#Preview {
    ContentView()
}
