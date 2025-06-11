import SwiftUI

#if os(macOS)
import AppKit
// typealias PlatformSpecificImage = NSImage // Removed
#elseif os(iOS)
import UIKit
// typealias PlatformSpecificImage = UIImage // Removed
#endif

struct PlatformImageView: View {
    #if os(macOS)
    let platformImage: NSImage
    #elseif os(iOS)
    let platformImage: UIImage
    #else
    // Define a default or placeholder type if needed for other platforms
    // For now, let's assume it won't compile on other platforms without further changes
    #endif
    let label: Text

    #if os(macOS)
    init(platformImage: NSImage, label: String = "") {
        self.platformImage = platformImage
        self.label = Text(label)
    }
    #elseif os(iOS)
    init(platformImage: UIImage, label: String = "") {
        self.platformImage = platformImage
        self.label = Text(label)
    }
    #else
    // init for other platforms if needed
    #endif

    var body: some View {
        #if os(macOS)
        Image(nsImage: platformImage)
            .resizable()
        #elseif os(iOS)
        Image(uiImage: platformImage)
            .resizable()
        #else
        // Fallback for other platforms or if specific image type isn't available
        label // Or some placeholder
        #endif
    }
}

// Helper for creating from asset names, assuming they are correctly set up
// for both platforms in Assets.xcassets
struct PlatformImageFromName: View {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    var body: some View {
        #if os(macOS)
        if let nsImage = NSImage(named: name) {
            Image(nsImage: nsImage)
                .resizable()
        } else {
            Image(systemName: "photo") // Placeholder
                .resizable()
        }
        #elseif os(iOS)
        if let uiImage = UIImage(named: name) {
            Image(uiImage: uiImage)
                .resizable()
        } else {
            Image(systemName: "photo") // Placeholder
                .resizable()
        }
        #else
        Image(systemName: "photo") // Placeholder
            .resizable()
        #endif
    }
} 