import SwiftUI
import PDFKit
import UniformTypeIdentifiers
#if os(macOS)
import AppKit

struct PDFExportDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let document: Letterspace_CanvasDocument
    @State private var showDocumentTitle: Bool = true
    @State private var showHeaderImage: Bool = true
    @State private var showPageNumbers: Bool = false
    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var showExportSuccess: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Text("Export PDF")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2)),
                alignment: .bottom
            )
            
            // Main content with sidebar and preview
            HStack(alignment: .top, spacing: 0) {
                // Sidebar with options - using our new implementation
                PDFExportSidebar_New(
                    showDocumentTitle: $showDocumentTitle, 
                    showHeaderImage: $showHeaderImage, 
                    showPageNumbers: $showPageNumbers
                )
                .frame(width: 250)
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(Color.gray.opacity(0.2)),
                    alignment: .trailing
                )
                
                // PDF Preview on right side
                VStack {
                    // PDF Preview
                    SimplifiedDocumentPreview(
                        document: document,
                        showHeaderImage: showHeaderImage,
                        showDocumentTitle: showDocumentTitle,
                        showPageNumbers: showPageNumbers,
                        fontScale: 1.0
                    )
                    .padding()
                    
                    Spacer()
                }
                .frame(minWidth: 400)
            }
            
            // Footer with buttons
            VStack(spacing: 16) {
                // Divider
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2))
                
                // Buttons
                HStack {
                    Spacer()
                    
                    // Save As... button
                    Button {
                        saveAsPDF()
                    } label: {
                        Text("Save As...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 150, height: 40)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Print button
                    Button {
                        printPDF()
                    } label: {
                        HStack {
                            Image(systemName: "printer")
                            Text("Print")
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(width: 150, height: 40)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 10)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 900, height: 700)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color.white)
        .overlay(
            Group {
                if isExporting {
                    Color.black.opacity(0.5)
                        .overlay(
                            VStack(spacing: 16) {
                                ProgressView(value: exportProgress, total: 1.0)
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5)
                                
                                Text("Generating PDF...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding(30)
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(12)
                        )
                }
            }
        )
        .alert("PDF Exported Successfully", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) { }
        }
    }
    
    // Function to save PDF to disk
    private func saveAsPDF() {
        isExporting = true
        
        // Generate the PDF data
        guard let pdfData = PDFDocumentGenerator.generatePDFData(
            for: document,
            showHeaderImage: showHeaderImage,
            showDocumentTitle: showDocumentTitle,
            showPageNumbers: showPageNumbers,
            fontScale: 1.0,
            includeVerseText: false
        ) else {
            isExporting = false
            return
        }
        
        // Create a panel to choose save location
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.pdf]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = false
        savePanel.title = "Save PDF"
        
        // Set default filename
        let docTitle = document.title.isEmpty ? "Untitled Document" : document.title
        savePanel.nameFieldStringValue = "\(docTitle).pdf"
        
        // Show save panel
        savePanel.beginSheetModal(for: NSApp.keyWindow!) { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try pdfData.write(to: url)
                    exportProgress = 1.0
                    
                    // Show success alert after a slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isExporting = false
                        showExportSuccess = true
                    }
                } catch {
                    print("Error saving PDF: \(error.localizedDescription)")
                    isExporting = false
                }
            } else {
                isExporting = false
            }
        }
    }
    
    // Function to print PDF
    private func printPDF() {
        // Generate the PDF data
        guard let pdfData = PDFDocumentGenerator.generatePDFData(
            for: document,
            showHeaderImage: showHeaderImage,
            showDocumentTitle: showDocumentTitle,
            showPageNumbers: showPageNumbers,
            fontScale: 1.0,
            includeVerseText: false
        ) else {
            return
        }
        
        // Create a PDF document from the data
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            print("Failed to create PDF document for printing")
            return
        }
        
        // Create a print info
        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        
        // Create a PDFView directly (not using SwiftUI wrapper)
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        
        // Create a print operation with the native NSView
        let printOperation = NSPrintOperation(view: pdfView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        
        // Run the print operation
        printOperation.run()
    }
}

// Preview for development
struct PDFExportDialog_Previews: PreviewProvider {
    static var previews: some View {
        PDFExportDialog(document: Letterspace_CanvasDocument(title: "Sample Document", subtitle: "Sample Subtitle"))
    }
}

#elseif os(iOS)

// iOS version - simplified PDF export
struct PDFExportDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let document: Letterspace_CanvasDocument
    @State private var showExportSuccess: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Export PDF")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("PDF Export")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("PDF export is currently available on macOS only")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 150, height: 40)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 400, height: 300)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color.white)
    }
}

// Preview for development
struct PDFExportDialog_Previews: PreviewProvider {
    static var previews: some View {
        PDFExportDialog(document: Letterspace_CanvasDocument(title: "Sample Document", subtitle: "Sample Subtitle"))
    }
}

#endif 