import SwiftUI

struct DocumentExportMenu: View {
    let document: Letterspace_CanvasDocument
    @State private var showPDFExport = false
    
    var body: some View {
        Button {
            showPDFExport = true
        } label: {
            Label("Export as PDF", systemImage: "arrow.down.doc")
        }
        .sheet(isPresented: $showPDFExport) {
            PDFExportDialog(document: document)
        }
    }
}

// Menu extension for document menu
extension View {
    func documentExportMenu(document: Letterspace_CanvasDocument) -> some View {
        self.modifier(DocumentExportMenuModifier(document: document))
    }
}

struct DocumentExportMenuModifier: ViewModifier {
    let document: Letterspace_CanvasDocument
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                DocumentExportMenu(document: document)
            }
    }
}

// Preview
struct DocumentExportMenu_Previews: PreviewProvider {
    static var previews: some View {
        Text("Document View")
            .documentExportMenu(document: Letterspace_CanvasDocument(title: "Test Document", subtitle: "Test Subtitle"))
    }
} 