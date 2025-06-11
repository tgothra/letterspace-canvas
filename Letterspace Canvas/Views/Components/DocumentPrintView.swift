#if os(macOS)
import SwiftUI
import AppKit
import PDFKit

// DocumentPrintView for printing functionality
struct DocumentPrintView: View {
    let document: Letterspace_CanvasDocument
    let showHeaderImage: Bool
    let showDocumentTitle: Bool
    let showPageNumbers: Bool
    @State private var pdfDocument: PDFDocument?
    
    var body: some View {
        Group {
            if let pdf = pdfDocument {
                PDFPrintPreview(document: pdf)
            } else {
                // Show loading placeholder until PDF is generated
                Text("Preparing document for printing...")
                    .onAppear {
                        // Generate PDF data on appear
                        if let pdfData = PDFDocumentGenerator.generatePDFData(
                            for: document,
                            showHeaderImage: showHeaderImage,
                            showDocumentTitle: showDocumentTitle,
                            showPageNumbers: showPageNumbers,
                            fontScale: 1.0,
                            includeVerseText: false
                        ) {
                            // Create PDF document
                            self.pdfDocument = PDFDocument(data: pdfData)
                        }
                    }
            }
        }
    }
}

// Simple SwiftUI wrapper for PDFView (renamed to avoid conflicts)
struct PDFPrintPreview: NSViewRepresentable {
    var document: PDFDocument
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        // Remove border display
        pdfView.displaysPageBreaks = false
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.document = document
        
        // If we have a document, adjust the view's frame to match the PDF page size
        if let page = document.page(at: 0) {
            let bounds = page.bounds(for: .mediaBox)
            pdfView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        }
    }
}
#endif
