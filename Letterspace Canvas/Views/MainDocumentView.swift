import SwiftUI

struct MainDocumentView: View {
    @Binding var document: Letterspace_CanvasDocument
    @State private var activeToolbarId: UUID?
    
    var body: some View {
        MainLayout(document: $document)
            .environment(\.sharedToolbarState, $activeToolbarId)
    }
} 