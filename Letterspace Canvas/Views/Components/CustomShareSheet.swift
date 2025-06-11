#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import AppKit


struct CustomShareSheet: View {
    let document: Letterspace_CanvasDocument
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    @State private var exportProgress: Double?
    @State private var exportError: String?
    
    // PDF export options
    @State private var showHeaderImage = true
    @State private var showDocumentTitle = true
    @State private var showPageNumbers = false
    @State private var fontScale: FontScale = .medium
    
    // Font scale enum
    enum FontScale: String, CaseIterable, Identifiable {
        case small = "S"
        case medium = "M"
        case large = "L"
        case extraLarge = "XL"
        
        var id: String { rawValue }
        
        var scaleFactor: CGFloat {
            switch self {
                case .small: return 0.71
                case .medium: return 0.80
                case .large: return 1.0
                case .extraLarge: return 1.1
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Export PDF")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                // Close button
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            HStack(alignment: .top, spacing: 0) {
                // Left side - Options
                VStack(alignment: .leading, spacing: 16) {
                    // Toggle options with fixed-width container for toggles
                    VStack(alignment: .leading, spacing: 12) {
                        // Document Title Toggle
                        HStack {
                            Text("Hide Document Title")
                                .font(.system(size: 13))
                            
                            Spacer()
                            
                            // Fixed-width container for toggle
                            ZStack(alignment: .trailing) {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 50, height: 22)
                                
                                Toggle("", isOn: Binding(
                                    get: { !showDocumentTitle },
                                    set: { showDocumentTitle = !$0 }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }
                        }
                        
                        // Header Image Toggle
                        HStack {
                            Text("Hide Header Image")
                                .font(.system(size: 13))
                            
                            Spacer()
                            
                            // Fixed-width container for toggle
                            ZStack(alignment: .trailing) {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 50, height: 22)
                                
                                Toggle("", isOn: Binding(
                                    get: { !showHeaderImage },
                                    set: { showHeaderImage = !$0 }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }
                        }
                        
                        // Page Numbers Toggle
                        HStack {
                            Text("Show Page Numbers")
                                .font(.system(size: 13))
                            
                            Spacer()
                            
                            // Fixed-width container for toggle
                            ZStack(alignment: .trailing) {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 50, height: 22)
                                
                                Toggle("", isOn: $showPageNumbers)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                        }
                        
                        // New Font Size Selector
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Text Size")
                                .font(.system(size: 13))
                                .padding(.top, 6)
                            
                            Picker("Text Size", selection: $fontScale) {
                                ForEach(FontScale.allCases) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 8) {
                        Button(action: exportAsPDF) {
                            HStack {
                                Spacer()
                                if let progress = exportProgress {
                                    ProgressView(value: progress, total: 1.0)
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.7)
                                        .padding(.trailing, 8)
                                }
                                Text("Save As...")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundStyle(Color.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // Call printDocument directly
                            printDocument()
                            // Dismiss the sheet after the print dialog is handled
                            isPresented = false
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "printer")
                                    .font(.system(size: 13))
                                    .padding(.trailing, 4)
                                Text("Print")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .background(colorScheme == .dark ? Color(.sRGB, white: 0.3) : Color(.sRGB, white: 0.9))
                            .foregroundStyle(theme.primary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if let error = exportError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.red)
                            .padding(.top, 8)
                    }
                }
                .padding(16)
                .frame(width: 220)
                
                Divider()
                
                // Right side - Document Preview
                ScrollView {
                    VStack(spacing: 0) {
                        // Document preview
                        SimplifiedDocumentPreview(
                            document: document,
                            showHeaderImage: showHeaderImage,
                            showDocumentTitle: showDocumentTitle,
                            showPageNumbers: showPageNumbers,
                            fontScale: fontScale.scaleFactor
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: 450, height: 500)
            }
            .frame(width: 670, height: 500)
        }
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : Color(.sRGB, white: 0.97))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private func exportAsPDF() {
        // Start progress indicator
        exportProgress = 0.1
        exportError = nil
        
        // Create a save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.pdf]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save PDF"
        savePanel.message = "Choose a location to save the PDF"
        savePanel.nameFieldStringValue = "\(document.title).pdf"
        
        // Show the save panel
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                // Update progress
                exportProgress = 0.3
                
                // Generate PDF data
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        // Create PDF data with the selected options
                        let pdfData = generatePDF(
                            document: document,
                            showHeaderImage: showHeaderImage,
                            showDocumentTitle: showDocumentTitle,
                            showPageNumbers: showPageNumbers,
                            fontScale: fontScale.scaleFactor
                        )
                        
                        // Update progress
                        DispatchQueue.main.async {
                            exportProgress = 0.7
                        }
                        
                        // Write to file
                        try pdfData.write(to: url)
                        
                        // Complete
                        DispatchQueue.main.async {
                            exportProgress = 1.0
                            
                            // Reset after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                exportProgress = nil
                                isPresented = false
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            exportProgress = nil
                            exportError = "Error exporting PDF: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                // User cancelled
                DispatchQueue.main.async {
                    exportProgress = nil
                }
            }
        }
    }
    
    // Generate PDF from document
    private func generatePDF(document: Letterspace_CanvasDocument, showHeaderImage: Bool, showDocumentTitle: Bool, showPageNumbers: Bool, fontScale: CGFloat) -> Data {
        // Use our shared PDFDocumentGenerator utility
        if let pdfData = PDFDocumentGenerator.generatePDFData(
            for: document,
            showHeaderImage: showHeaderImage,
            showDocumentTitle: showDocumentTitle,
            showPageNumbers: showPageNumbers,
            fontScale: fontScale,
            includeVerseText: false
        ) {
            return pdfData
        }
        
        // Return empty data if generation failed
        return Data()
    }
    
    private func printDocument() {
        // Generate PDF data
        if let pdfData = PDFDocumentGenerator.generatePDFData(
            for: document,
            showHeaderImage: showHeaderImage,
            showDocumentTitle: showDocumentTitle,
            showPageNumbers: showPageNumbers,
            fontScale: fontScale.scaleFactor,
            includeVerseText: false
        ) {
            // Create a temporary file for the PDF
            let temporaryDirectory = FileManager.default.temporaryDirectory
            let tempFileName = "temp_print_\(UUID().uuidString).pdf"
            let tempFileURL = temporaryDirectory.appendingPathComponent(tempFileName)
            
            do {
                // Write PDF data to the temporary file
                try pdfData.write(to: tempFileURL)
                
                // Open the PDF file in Preview app which has better printing control
                NSWorkspace.shared.open(tempFileURL)
                
                // Schedule the temporary file for deletion after a reasonable time
                DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5 minutes
                    try? FileManager.default.removeItem(at: tempFileURL)
                }
            } catch {
                print("Error writing temporary PDF: \(error.localizedDescription)")
            }
        } else {
            print("Error: Failed to generate PDF for printing")
        }
    }
    
    // Helper function to load header image
    private func loadHeaderImage(from fileName: String) -> NSImage? {
        guard !fileName.isEmpty else { return nil }
        
        // Try to load from document directory first
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: fileURL.path),
           let image = NSImage(contentsOf: fileURL) {
            return image
        }
        
        // Try to load from bundle as fallback
        return NSImage(named: fileName)
    }
}
#endif
