import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct LibraryView: View {
    @EnvironmentObject var libraryService: UserLibraryService
    @State private var showingFileImporter = false
    @State private var showingAddLinkSheet = false
    @State private var newLinkURLString = ""
    @State private var isProcessing = false // To show activity indicator
    @State private var processingMessage = ""
    @State private var isEditingList = false // State for macOS edit mode
    
    // Import processing state variables
    @State private var processedCount = 0
    @State private var errorCount = 0
    @State private var successCount = 0
    @State private var totalFiles = 0
    @State private var errorMessages: [String] = []
    @State private var isHoveringClose = false // Add state for close button hover
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Smart Study Library")
                    .font(.title2).bold()
                Spacer()
                // Close button for the modal/sheet
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark") // Use standard xmark
                        .font(.system(size: 10, weight: .bold)) // Match other modals
                        .foregroundColor(.white) // White icon
                        .frame(width: 22, height: 22) // Standard frame
                        .background(
                            Circle()
                                .fill(isHoveringClose ? Color.red : Color.gray.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in // Add onHover modifier
                    isHoveringClose = hovering
                }
            }
            .padding()
            
            Divider()

            // List of Library Items
            List {
                if libraryService.libraryItems.isEmpty {
                    Text("Your library is empty. Add PDFs or web links to get started.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(libraryService.libraryItems) { item in
                        LibraryItemRow(item: item, isEditing: self.isEditingList) {
                            if let index = libraryService.libraryItems.firstIndex(where: { $0.id == item.id }) {
                                deleteItems(offsets: IndexSet(integer: index))
                            }
                        }
                    }
                }
            }
            .listStyle(.plain) // Use plain style for tighter spacing
            
            // Processing Indicator
            if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(processingMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
            }

            Divider()
            
            // Bottom Toolbar
            HStack {
                Button {
                    showingFileImporter = true
                } label: {
                    Label("Add PDF", systemImage: "doc.badge.plus")
                }
                .disabled(isProcessing)
                
                // Commented out for now - user doesn't want web link functionality
                /*
                Button {
                    newLinkURLString = ""
                    showingAddLinkSheet = true
                } label: {
                    Label("Add Web Link", systemImage: "link.badge.plus")
                }
                .disabled(isProcessing)
                */
                
                Spacer()
                
                // macOS-compatible Edit/Done button
                Button(isEditingList ? "Done" : "Edit") {
                    withAnimation {
                        isEditingList.toggle()
                    }
                }
                .disabled(isProcessing || libraryService.libraryItems.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 300, idealHeight: 450)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result: result)
        }
        .sheet(isPresented: $showingAddLinkSheet) {
            AddLinkSheet(urlString: $newLinkURLString, isProcessing: $isProcessing) {
                handleAddLink()
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        offsets.map { libraryService.libraryItems[$0].id }.forEach {
            libraryService.deleteItem(id: $0)
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            
            // Reset tracking variables
            processedCount = 0
            errorCount = 0
            successCount = 0
            totalFiles = urls.count
            errorMessages.removeAll()
            
            isProcessing = true
            processingMessage = "Processing \(totalFiles) PDF(s)... (0/\(totalFiles))"

            // Process each selected URL
            for url in urls {
                // First check if it's an iCloud document that needs downloading
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemIsDownloadingKey, .ubiquitousItemDownloadingStatusKey])
                    let isDownloading = resourceValues.ubiquitousItemIsDownloading ?? false
                    let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus
                    
                    print("📋 Selected file: \(url.lastPathComponent)")
                    print("   - Is iCloud download in progress: \(isDownloading)")
                    print("   - Download status: \(downloadStatus?.rawValue ?? "unknown")")
                } catch {
                    print("⚠️ Couldn't get iCloud status: \(error.localizedDescription)")
                }
                
                // Ensure we have a valid file URL by resolving bookmark data if needed
                guard url.startAccessingSecurityScopedResource() else {
                    print("⚠️ Cannot access security scoped resource: \(url.lastPathComponent)")
                    
                    // Update counts immediately for failed security access
                    processedCount += 1
                    errorCount += 1
                    errorMessages.append("Failed to access '\(url.lastPathComponent)': Security access denied")
                    
                    // Update UI immediately for this error
                    processingMessage = "Processing \(totalFiles) PDF(s)... (\(processedCount)/\(totalFiles))"
                    continue
                }
                
                // Copy the file to a temporary location to ensure we can access it consistently
                // This is especially important for iCloud files that might be placeholder files
                do {
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = url.lastPathComponent
                    let localURL = tempDir.appendingPathComponent(fileName)
                    
                    // Remove any existing temp file with same name
                    try? FileManager.default.removeItem(at: localURL)
                    
                    // Copy the file to a location we have full control over
                    try FileManager.default.copyItem(at: url, to: localURL)
                    
                    print("📋 Copied to temporary location: \(localURL.path)")
                    
                    // If it's an iCloud file, try to trigger a download in case it's a placeholder
                    try? FileManager.default.startDownloadingUbiquitousItem(at: localURL)
                    
                    // Process the local copy instead of the original URL
                    processSelectedPDF(localURL, originalURL: url, fileName: fileName)
                } catch {
                    print("❌ Failed to copy file: \(error.localizedDescription)")
                    url.stopAccessingSecurityScopedResource()
                    
                    // Update counts immediately for failed file copy
                    processedCount += 1
                    errorCount += 1
                    errorMessages.append("Failed to copy '\(url.lastPathComponent)': \(error.localizedDescription)")
                    
                    // Update UI immediately for this error
                    processingMessage = "Processing \(totalFiles) PDF(s)... (\(processedCount)/\(totalFiles))"
                    continue
                }
            }
            
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
            // Optionally show an alert
        }
    }
    
    // Helper method to process a PDF after we've copied it to a temp location
    private func processSelectedPDF(_ url: URL, originalURL: URL, fileName: String) {
        libraryService.addAndProcessItem(sourceURL: url, type: .pdf) { result in
            // Clean up when done with this URL
            originalURL.stopAccessingSecurityScopedResource()
            
            // Must update state on main thread
            DispatchQueue.main.async {
                self.processedCount += 1
                switch result {
                case .success(let item):
                    self.successCount += 1
                    print("Successfully added and processed PDF: \(item.title)")
                case .failure(let error):
                    self.errorCount += 1
                    let errorMessage = "Failed to process '\(fileName)': \(error.localizedDescription)"
                    self.errorMessages.append(errorMessage)
                    print("❌ \(errorMessage)")
                }
                
                // Update progress message
                self.processingMessage = "Processing \(self.totalFiles) PDF(s)... (\(self.processedCount)/\(self.totalFiles))"
                
                // Check if all files are processed
                if self.processedCount == self.totalFiles {
                    self.isProcessing = false
                    
                    // Only save if we have successful items to save
                    if self.successCount > 0 {
                        self.libraryService.saveItems()
                    }
                    
                    // Set final message
                    if self.errorCount > 0 {
                        self.processingMessage = "Finished with \(self.errorCount) error(s). \(self.successCount > 0 ? "Added \(self.successCount) file(s)." : "")"
                        // Keep the message visible for a few seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.processingMessage = ""
                        }
                        
                        print("Finished processing with \(self.errorCount) error(s):")
                        self.errorMessages.forEach { print("  - \($0)") }
                    } else {
                        self.processingMessage = "Successfully added \(self.successCount) file(s)."
                        // Keep the message visible for a few seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.processingMessage = ""
                        }
                        print("Finished processing all PDFs successfully.")
                    }
                }
            }
        }
    }
    
    private func handleAddLink() {
        guard let url = URL(string: newLinkURLString) else {
            print("Invalid URL string: \(newLinkURLString)")
            // TODO: Show alert: Invalid URL
            return
        }
        
        isProcessing = true
        processingMessage = "Processing \(url.host ?? url.absoluteString)..."
        showingAddLinkSheet = false // Dismiss sheet immediately

        libraryService.addAndProcessItem(sourceURL: url, type: .webLink) { result in
            // Update UI on main thread
            DispatchQueue.main.async {
                isProcessing = false
                processingMessage = ""
                switch result {
                case .success(let item):
                    print("Successfully added and processed link: \(item.title)")
                case .failure(let error):
                    print("Failed to add/process link: \(error.localizedDescription)")
                    // TODO: Show alert to user
                }
            }
        }
    }
}

// Row view for displaying a single library item
struct LibraryItemRow: View {
    let item: UserLibraryItem
    var isEditing: Bool // Flag passed from parent
    let deleteAction: () -> Void // Action to perform on delete
    
    // Access to the library service to get the full path
    @EnvironmentObject var libraryService: UserLibraryService 

    var body: some View {
        HStack {
            Image(systemName: item.type == .pdf ? "doc.text.fill" : "link")
                .foregroundColor(item.type == .pdf ? .red : .blue)
                .frame(width: 20) // Align icons
            VStack(alignment: .leading) {
                HStack {
                    Text(item.title).lineLimit(1)
                    if !item.isEmbeddingComplete {
                        Text("(Processing...)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                // Display only the filename for iCloud-stored PDFs
                Text(item.type == .pdf ? item.title : item.source)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // "Open" button for PDF items (visible when not editing and embedding is complete)
            if item.type == .pdf && item.isEmbeddingComplete && !isEditing {
                Button {
                    openPDF()
                } label: {
                    Image(systemName: "arrow.up.forward.app.fill") // Or "doc.text.viewfinder"
                        .foregroundColor(.accentColor) // Use accent color
                }
                .buttonStyle(.plain)
                .help("Open PDF")
            }
            
            // Show delete button only when editing AND embedding is complete
            if isEditing && item.isEmbeddingComplete {
                Button {
                    deleteAction()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
        .opacity(item.isEmbeddingComplete ? 1.0 : 0.7) // Slightly dim row while processing
        .animation(.default, value: isEditing) // Animate the button appearance
        .animation(.default, value: item.isEmbeddingComplete) // Animate text/opacity change
    }
    
    // Function to open the PDF
    private func openPDF() {
        guard item.type == .pdf, 
              let pdfsDirectory = libraryService.getLibraryPdfsDirectoryURL() else { return } // Use public getter
        
        // The `item.source` for PDFs should now be just the filename
        let fileURL = pdfsDirectory.appendingPathComponent(item.source)
        
        print("Attempting to open PDF at: \(fileURL.path)")
        #if os(macOS)
        NSWorkspace.shared.open(fileURL)
        #elseif os(iOS)
        // On iOS, we can use UIApplication to open the file with the system's default PDF viewer
        // or we could present a document interaction controller
        UIApplication.shared.open(fileURL)
        #endif
    }
}

// Sheet view for adding a web link
struct AddLinkSheet: View {
    @Binding var urlString: String
    @Binding var isProcessing: Bool
    let onAdd: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Add Web Link")
                .font(.headline)
                .padding()
            
            TextField("Enter URL (e.g., https://example.com)", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                
            Spacer()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    onAdd()
                }
                .disabled(urlString.isEmpty || isProcessing)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 350, height: 180)
    }
}

// Preview
struct LibraryView_Previews: PreviewProvider {
    // Create a static instance for the preview
    @StateObject static var mockService = UserLibraryService()
    
    static var previews: some View {
        // Create mock chunks (optional, could be nil or empty)
        let mockPdfChunks = [LibraryChunk(id: UUID(), text: "This is content...")] 
        let mockLinkChunks = [LibraryChunk(id: UUID(), text: "Web page text...")]
        
        // Configure the mock service *before* the view uses it
        mockService.libraryItems = [
            UserLibraryItem(id: UUID(), type: .pdf, title: "Example Document.pdf", source: "file:///Users/Shared/Example Document.pdf", chunks: mockPdfChunks, dateAdded: Date(), isEmbeddingComplete: true),
            UserLibraryItem(id: UUID(), type: .webLink, title: "example.com", source: "https://example.com", chunks: mockLinkChunks, dateAdded: Date(), isEmbeddingComplete: false)
        ]
        
        return LibraryView()
            .environmentObject(mockService) // Inject the static mock instance
    }
} 