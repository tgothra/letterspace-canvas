import SwiftUI

#if os(macOS)
import AppKit
#endif

struct DocumentView: View {
    @Binding var document: Letterspace_CanvasDocument
    @State private var selectedBlock: UUID?
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Document content here
                ForEach(document.elements) { element in
                    DocumentElementView(
                        document: $document,
                        element: .constant(element),
                        selectedElement: $selectedBlock
                    )
                }
            }
            .padding(.horizontal, 48)
        }
        .onAppear {
            // Preload all header images in the document
            ImageCache.shared.preloadImages(for: document)
        }
    }
    
    // ... rest of the code remains the same ...
} 