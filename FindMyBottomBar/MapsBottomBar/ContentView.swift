//
//  ContentView.swift
//  MapsBottomBar
//
//  Created by Balaji Venkatesh on 22/06/25.
//

import SwiftUI
import MapKit

/// Apple Park Coordinates
extension MKCoordinateRegion {
    static let applePark = MKCoordinateRegion(center: .init(latitude: 37.3346, longitude: -122.0090), latitudinalMeters: 1000, longitudinalMeters: 1000)
}

struct ContentView: View {
    @State private var showBottomBar: Bool = true
    var body: some View {
        Map(initialPosition: .region(.applePark))
            .sheet(isPresented: $showBottomBar) {
                BottomBarView()
                    .presentationDetents([.height(isiOS26 ? 80 : 130), .fraction(0.6), .large])
                    .presentationBackgroundInteraction(.enabled)
            }
    }
}

#Preview {
    ContentView()
}
