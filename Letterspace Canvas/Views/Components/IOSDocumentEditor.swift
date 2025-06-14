#if os(iOS)
import SwiftUI
import Combine

struct IOSDocumentEditor: View {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool
    @State private var textContent: String = ""
    @State private var fileMonitor: DocumentFileMonitor?
    @State private var lastKnownModifiedDate: Date = Date()
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Main text editing area
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Text editor
                        TextEditor(text: $textContent)
                            .font(.system(size: 16, weight: .regular))
                            .lineSpacing(4)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .focused($isFocused)
                            .scrollContentBackground(.hidden) // Hide default background
                            .background(Color.clear)
                            .frame(minHeight: geometry.size.height) // Fill entire available height
                            .padding(.horizontal, 24)
                            .padding(.top, 16) // Only top padding to avoid bottom gap
                            .onChange(of: textContent) { _, newValue in
                                // Update document content when text changes
                                updateDocumentContent(newValue)
                            }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.08) : Color(.sRGB, white: 0.98))
        )
        .onAppear {
            loadDocumentContent()
            // Temporarily disable file monitoring to prevent SIGTERM issues
            // startFileMonitoring()
            startPeriodicRefresh()
        }
        .onDisappear {
            // stopFileMonitoring()
            stopPeriodicRefresh()
        }
        .onChange(of: document.id) { _, _ in
            // Reload content when document changes (e.g., via iCloud sync)
            loadDocumentContent()
            // stopFileMonitoring()
            stopPeriodicRefresh()
            // startFileMonitoring()
            startPeriodicRefresh()
        }
        .onChange(of: document.modifiedAt) { _, _ in
            // Reload content when document is modified externally (e.g., from macOS)
            if document.modifiedAt != lastKnownModifiedDate {
                print("🔄 External document change detected, reloading content...")
                loadDocumentContent()
                lastKnownModifiedDate = document.modifiedAt
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh when app becomes active (user switches back from macOS)
            checkForExternalChanges()
        }
        .onTapGesture {
            // Focus the text editor when tapped
            isFocused = true
        }
    }
    
    private func loadDocumentContent() {
        // Load content from the unified textBlock element (same as macOS)
        if let textElement = document.elements.first(where: { $0.type == .textBlock }) {
            // Use the string content from the textBlock element
            textContent = textElement.content
            print("📖 iOS: Loaded document content (\(textElement.content.count) characters) from textBlock element")
        } else if !document.elements.isEmpty {
            // Fallback: if no textBlock exists but there are other elements, 
            // combine all element content for editing
            let combinedContent = document.elements.map { $0.content }.joined(separator: "\n\n")
            textContent = combinedContent
            print("📖 iOS: Loaded combined content from \(document.elements.count) elements (\(combinedContent.count) characters)")
            
            // Create a textBlock element with the combined content for future editing
            let textElement = DocumentElement(type: .textBlock, content: combinedContent)
            document.elements.append(textElement)
            document.save()
        } else {
            // If no content exists, create placeholder content
            textContent = "Start typing your document here...\n\nThis text editor is synchronized with the macOS version."
            print("📖 iOS: Created new document with placeholder content")
        }
    }
    
    private func updateDocumentContent(_ newContent: String) {
        // Update the unified textBlock element (same approach as macOS)
        if let index = document.elements.firstIndex(where: { $0.type == .textBlock }) {
            // Update existing textBlock element directly on the binding
            document.elements[index].content = newContent
            // For iOS, we don't handle attributedContent/rtfData but we preserve the structure
        } else {
            // Create new textBlock element
            let element = DocumentElement(type: .textBlock, content: newContent)
            document.elements.append(element)
        }
        
        // Update modification time
        document.modifiedAt = Date()
        
        // Update the canvasDocument content for consistency
        document.updateCanvasDocument()
        
        // Save the document immediately
        document.save()
        
        print("📝 iOS: Updated document content (\(newContent.count) characters) and saved to iCloud Documents")
    }
    
    private func startFileMonitoring() {
        stopFileMonitoring() // Stop any existing monitoring
        
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("❌ Cannot start file monitoring: no app directory")
            return
        }
        
        let fileURL = appDirectory.appendingPathComponent("\(document.id).canvas")
        
        // Only start monitoring if the file actually exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            fileMonitor = DocumentFileMonitor(fileURL: fileURL) { 
                DispatchQueue.main.async {
                    self.reloadDocumentFromDisk()
                }
            }
            print("🔍 Started file monitoring for: \(fileURL.lastPathComponent)")
        } else {
            print("⚠️ Document file does not exist yet, skipping file monitoring")
        }
        
        // Skip Images directory monitoring for now to reduce system load
        // This was causing SIGTERM issues with iCloud Documents
        print("📡 File monitoring setup complete")
    }
    
    private func stopFileMonitoring() {
        fileMonitor?.stopMonitoring()
        fileMonitor = nil
        print("🛑 Stopped file monitoring")
    }
    
    private func checkForExternalChanges() {
        print("🔄 Checking for external changes...")
        reloadDocumentFromDisk()
    }
    
    private func startPeriodicRefresh() {
        // Reduce frequency from 3 seconds to 10 seconds to be less aggressive
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            checkForExternalChanges()
        }
        print("⏰ Started periodic refresh timer (10s intervals)")
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("⏰ Stopped periodic refresh timer")
    }
    
    private func reloadDocumentFromDisk() {
        // Add safety check to prevent excessive reloading
        let currentTime = Date().timeIntervalSince1970
        let lastReloadKey = "LastDocumentReload_\(document.id)"
        let lastReloadTime = UserDefaults.standard.double(forKey: lastReloadKey)
        
        // Throttle reloads to maximum once per 2 seconds
        if currentTime - lastReloadTime < 2.0 {
            print("📝 Throttling document reload - too frequent")
            return
        }
        
        UserDefaults.standard.set(currentTime, forKey: lastReloadKey)
        
        // Load the latest version from disk with error handling
        guard let updatedDocument = Letterspace_CanvasDocument.load(id: document.id) else {
            print("⚠️ Could not reload document from disk")
            return
        }
        
        // Check if the content actually changed to avoid unnecessary updates
        let currentContentHash = document.elements.map { $0.content }.joined().hash
        let newContentHash = updatedDocument.elements.map { $0.content }.joined().hash
        
        if currentContentHash != newContentHash {
            print("🔄 Document content changed externally, updating...")
            document = updatedDocument
            loadDocumentContent()
            lastKnownModifiedDate = updatedDocument.modifiedAt
        } else {
            print("📝 Document unchanged, no update needed")
        }
    }
}

// MARK: - File Monitoring System
class DocumentFileMonitor {
    private let fileURL: URL
    private let onChange: () -> Void
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var isMonitoring = false
    
    init(fileURL: URL, onChange: @escaping () -> Void) {
        self.fileURL = fileURL
        self.onChange = onChange
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        // Ensure we're not already monitoring
        guard !isMonitoring else { return }
        
        // Check if file exists before attempting to monitor
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📡 File does not exist, skipping monitoring: \(fileURL.lastPathComponent)")
            return
        }
        
        // Open file descriptor with error handling
        fileDescriptor = open(fileURL.path, O_EVTONLY | O_NONBLOCK)
        guard fileDescriptor >= 0 else {
            print("❌ Failed to open file descriptor for monitoring: \(fileURL.path) (errno: \(errno))")
            return
        }
        
        // Create dispatch source with error handling
        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        guard let dispatchSource = dispatchSource else {
            print("❌ Failed to create dispatch source for monitoring")
            close(fileDescriptor)
            fileDescriptor = -1
            return
        }
        
        dispatchSource.setEventHandler { [weak self] in
            // Use weak self to prevent retain cycles
            guard let self = self else { return }
            
            // Throttle events to prevent excessive callbacks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.onChange()
            }
        }
        
        dispatchSource.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
            self.isMonitoring = false
        }
        
        dispatchSource.resume()
        isMonitoring = true
        print("📡 File monitoring started for: \(fileURL.lastPathComponent)")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        dispatchSource?.cancel()
        dispatchSource = nil
        
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        
        isMonitoring = false
        print("📡 File monitoring stopped")
    }
}

// Preview for development
#Preview {
    IOSDocumentEditor(document: .constant(Letterspace_CanvasDocument()))
        .padding()
}
#endif 