import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// Add this struct to store deletion date
fileprivate struct DeletedDocument: Codable {
    let document: Letterspace_CanvasDocument
    let deletedAt: Date
    
    var daysSinceDeleted: Int {
        Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
    }
}

fileprivate struct DeletedDocumentRow: View {
    let document: DeletedDocument
    let isSelected: Bool
    let onRestore: () -> Void
    let onDelete: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    private let maxDaysInTrash = 30
    
    var body: some View {
        HStack(spacing: 12) {
            // Document icon
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(theme.secondary)
                .frame(width: 24, height: 24)
                .background(theme.secondary.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.document.title.isEmpty ? "Untitled" : document.document.title)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.primary)
                
                HStack(spacing: 4) {
                    Text("Deleted \(formatDate(document.deletedAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondary)
                    
                    if document.daysSinceDeleted > 0 {
                        Text("• \(maxDaysInTrash - document.daysSinceDeleted) days remaining")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onRestore) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.blue)
                        .frame(width: 24, height: 24)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.red)
                        .frame(width: 24, height: 24)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? theme.secondary.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? color : color.opacity(0.9))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct RecentlyDeletedView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    @State private var deletedDocuments: [DeletedDocument] = []
    @State private var selectedDocuments: Set<String> = []
    @State private var lastSelectedIndex: Int? = nil
    @State private var isLoading = true
    @Binding var isPresented: Bool
    @State private var isHoveringClose = false
    @State private var appearanceOpacity = 0.0
    @State private var showDeleteAllAlert = false
    
    private let maxDaysInTrash = 30
    
    var body: some View {
        ZStack {
            // Dismiss layer
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                        isPresented = false
                    }
                }
            
            // Modal content
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    HStack {
                        Text("Recently Deleted")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.primary)
                        Spacer()
                        
                        if !deletedDocuments.isEmpty {
                            Button(action: deleteAllPermanently) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .frame(width: 24, height: 24)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(Circle())
                                    Text("Delete All Permanently")
                                        .font(.system(size: 12))
                                }
                                .foregroundStyle(Color.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                        }
                        
                        Button(action: { 
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(
                                    Circle()
                                        .fill(isHoveringClose ? Color.red : Color.gray.opacity(0.5))
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            isHoveringClose = hovering
                        }
                    }
                    
                    Text("Documents will be permanently deleted after 30 days")
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 16)
                
                if isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if deletedDocuments.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.secondary)
                        Text("No Recently Deleted Documents")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Document List
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(deletedDocuments.enumerated()), id: \.element.document.id) { index, deletedDoc in
                                DeletedDocumentRow(
                                    document: deletedDoc,
                                    isSelected: selectedDocuments.contains(deletedDoc.document.id),
                                    onRestore: { restoreDocument(deletedDoc) },
                                    onDelete: { deletePermanently(deletedDoc) }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture(count: 1) { location in
                                    #if os(macOS)
                                    let event = NSApp.currentEvent
                                    let isCommandPressed = event?.modifierFlags.contains(.command) == true
                                    let isShiftPressed = event?.modifierFlags.contains(.shift) == true
                                    
                                    if isCommandPressed {
                                        // Command+click: Toggle selection
                                        if selectedDocuments.contains(deletedDoc.document.id) {
                                            selectedDocuments.remove(deletedDoc.document.id)
                                        } else {
                                            selectedDocuments.insert(deletedDoc.document.id)
                                        }
                                        lastSelectedIndex = index
                                    } else if isShiftPressed {
                                        // Shift+click: Range selection
                                        if let lastIndex = lastSelectedIndex {
                                            let range = lastIndex < index ? 
                                                lastIndex...index : 
                                                index...lastIndex
                                            
                                            for i in range {
                                                selectedDocuments.insert(deletedDocuments[i].document.id)
                                            }
                                        } else {
                                            // If no previous selection, just select this one
                                            selectedDocuments = [deletedDoc.document.id]
                                        }
                                        lastSelectedIndex = index
                                    } else {
                                        // Normal click: Single selection
                                        selectedDocuments = [deletedDoc.document.id]
                                        lastSelectedIndex = index
                                    }
                                    #elseif os(iOS)
                                    // On iOS, just do single selection (no modifier keys)
                                    selectedDocuments = [deletedDoc.document.id]
                                    lastSelectedIndex = index
                                    #endif
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: .infinity)
                    
                    Divider()
                        .padding(.vertical, 16)
                    
                    // Footer with actions
                    HStack {
                        Text("\(selectedDocuments.count) selected")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                            .opacity(selectedDocuments.isEmpty ? 0 : 1)
                        
                        Spacer()
                        
                        if !selectedDocuments.isEmpty {
                            HStack(spacing: 8) {
                                ActionButton(
                                    title: "Restore Selected",
                                    color: .blue,
                                    action: restoreSelectedDocuments
                                )
                                
                                ActionButton(
                                    title: "Delete Permanently",
                                    color: .red,
                                    action: deleteSelectedPermanently
                                )
                            }
                        }
                    }
                }
            }
            .padding(24)
            .applyIf(!({
                #if os(iOS)
                UIDevice.current.userInterfaceIdiom == .phone
                #else
                false
                #endif
            }()), {
                $0.frame(width: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 340 : 500  // Smaller for iPhone, larger for iPad
                    #else
                    return 500 // macOS default
                    #endif
                }(), height: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 600 : 700  // Constrain height for iPhone
                    #else
                    return 600 // macOS default
                    #endif
                }())
                .background({
                    #if os(macOS)
                    colorScheme == .dark ? Color(.controlBackgroundColor) : Color.white
                    #elseif os(iOS)
                    colorScheme == .dark ? Color(.systemBackground) : Color.white
                    #endif
                }())
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.secondary.opacity(0.1), lineWidth: 1)
                )
            })
            .opacity(appearanceOpacity)
            .scaleEffect(appearanceOpacity * 0.05 + 0.95, anchor: .center)
        }
        .onAppear {
            // Start loading documents immediately
            Task {
                await loadDeletedDocuments()
            }
            
            // Smoother appearance animation
            withAnimation(
                .spring(
                    response: 0.5,    // Slightly slower
                    dampingFraction: 0.9,  // More damping for smoother motion
                    blendDuration: 0.5    // Longer blend for smoother transitions
                )
            ) {
                appearanceOpacity = 1.0
            }
        }
        .onDisappear {
            withAnimation(
                .spring(
                    response: 0.5,
                    dampingFraction: 0.9,
                    blendDuration: 0.5
                )
            ) {
                appearanceOpacity = 0.0
            }
        }
        #if os(iOS)
        .alert("Delete All Documents Permanently", isPresented: $showDeleteAllAlert) {
            Button("Delete All", role: .destructive) {
                performDeleteAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to permanently delete all documents in the trash? This action cannot be undone.")
        }
        #endif
    }
    
    private func loadDeletedDocuments() async {
        isLoading = true
        
        await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            // Use the same directory resolution as the rest of the app (iCloud-aware)
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("🗑️ ERROR: Could not determine app documents directory")
            return
        }
            let trashURL = appDirectory.appendingPathComponent(".trash", isDirectory: true)
            
            // Create trash directory if needed
            do {
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
                try fileManager.createDirectory(at: trashURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating trash directory: \(error)")
                await MainActor.run {
                    self.deletedDocuments = []
                    self.isLoading = false
                }
                return
            }
            
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: [.contentModificationDateKey])
                    .filter { $0.pathExtension == "canvas" }
                
                // Create an actor to safely collect results
                actor DocumentCollector {
                    private var loadedDocuments: [DeletedDocument] = []
                    private var documentsToDelete: [URL] = []
                    
                    func addDocument(_ doc: DeletedDocument) {
                        loadedDocuments.append(doc)
                    }
                    
                    func addDocumentToDelete(_ url: URL) {
                        documentsToDelete.append(url)
                    }
                    
                    func getLoadedDocuments() -> [DeletedDocument] {
                        loadedDocuments
                    }
                    
                    func getDocumentsToDelete() -> [URL] {
                        documentsToDelete
                    }
                }
                
                let collector = DocumentCollector()
                
                // Process documents in parallel
                await withTaskGroup(of: (DeletedDocument?, URL?).self) { group in
                    for url in fileURLs {
                        group.addTask {
                            do {
                                let data = try Data(contentsOf: url)
                                let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                                let attrs = try fileManager.attributesOfItem(atPath: url.path)
                                let deletionDate = attrs[.modificationDate] as? Date ?? Date()
                                
                                let deletedDoc = DeletedDocument(document: doc, deletedAt: deletionDate)
                                
                                if deletedDoc.daysSinceDeleted >= maxDaysInTrash {
                                    return (nil, url)
                                } else {
                                    return (deletedDoc, nil)
                                }
                            } catch {
                                print("Error loading deleted document at \(url): \(error)")
                                return (nil, nil)
                            }
                        }
                    }
                    
                    // Collect results safely using the actor
                    for await result in group {
                        if let doc = result.0 {
                            await collector.addDocument(doc)
                        }
                        if let url = result.1 {
                            await collector.addDocumentToDelete(url)
                        }
                    }
                }
                
                // Delete old documents in parallel
                let documentsToDelete = await collector.getDocumentsToDelete()
                await withTaskGroup(of: Void.self) { group in
                    for url in documentsToDelete {
                        group.addTask {
                            do {
                                try fileManager.removeItem(at: url)
                            } catch {
                                print("Error auto-deleting old document: \(error)")
                            }
                        }
                    }
                    await group.waitForAll()
                }
                
                // Get final results from collector
                let loadedDocuments = await collector.getLoadedDocuments()
                
                await MainActor.run {
                    self.deletedDocuments = loadedDocuments.sorted { $0.deletedAt > $1.deletedAt }
                    self.isLoading = false
                }
            } catch {
                print("Error loading deleted documents: \(error)")
                await MainActor.run {
                    self.deletedDocuments = []
                    self.isLoading = false
                }
            }
        }.value
    }
    
    private func restoreDocument(_ deletedDoc: DeletedDocument) {
        let fileManager = FileManager.default
        // Use the same directory resolution as the rest of the app (iCloud-aware)
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("🗑️ ERROR: Could not determine app documents directory")
            return
        }
        let trashURL = appDirectory.appendingPathComponent(".trash", isDirectory: true)
        
        let sourceURL = trashURL.appendingPathComponent("\(deletedDoc.document.id).canvas")
        let destinationURL = appDirectory.appendingPathComponent("\(deletedDoc.document.id).canvas")
        
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            
            // Remove from deleted documents list
            deletedDocuments.removeAll { $0.document.id == deletedDoc.document.id }
            selectedDocuments.remove(deletedDoc.document.id)
            
            // Notify that documents have been updated
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        } catch {
            print("Error restoring document: \(error)")
        }
    }
    
    private func restoreSelectedDocuments() {
        for documentId in selectedDocuments {
            if let deletedDoc = deletedDocuments.first(where: { $0.document.id == documentId }) {
                restoreDocument(deletedDoc)
            }
        }
    }
    
    private func deleteSelectedPermanently() {
        let fileManager = FileManager.default
        guard let documentsURL = Letterspace_CanvasDocument.getDocumentsDirectory() else {
            print("🗑️ ERROR: Could not determine documents directory")
            return
        }
        let trashURL = documentsURL.appendingPathComponent(".trash", isDirectory: true)
        
        for documentId in selectedDocuments {
            let fileURL = trashURL.appendingPathComponent("\(documentId).canvas")
            
            do {
                try fileManager.removeItem(at: fileURL)
                deletedDocuments.removeAll { $0.document.id == documentId }
            } catch {
                print("Error permanently deleting document: \(error)")
            }
        }
        
        selectedDocuments.removeAll()
    }
    
    private func deleteAllPermanently() {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Delete All Documents Permanently"
        alert.informativeText = "Are you sure you want to permanently delete all documents in the trash? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            performDeleteAll()
        }
        #elseif os(iOS)
        // On iOS, we'll use a SwiftUI alert state
        showDeleteAllAlert = true
        #endif
    }
    
    private func performDeleteAll() {
        let fileManager = FileManager.default
        // Use the same directory resolution as the rest of the app (iCloud-aware)
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("🗑️ ERROR: Could not determine app documents directory")
            return
        }
        let trashURL = appDirectory.appendingPathComponent(".trash", isDirectory: true)
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            for url in fileURLs {
                try fileManager.removeItem(at: url)
            }
            
            deletedDocuments.removeAll()
            selectedDocuments.removeAll()
        } catch {
            print("Error deleting all documents: \(error)")
        }
    }
    
    private func deletePermanently(_ deletedDoc: DeletedDocument) {
        let fileManager = FileManager.default
        guard let documentsURL = Letterspace_CanvasDocument.getDocumentsDirectory() else {
            print("🗑️ ERROR: Could not determine documents directory")
            return
        }
        let trashURL = documentsURL.appendingPathComponent("Letterspace Canvas/.trash")
        let fileURL = trashURL.appendingPathComponent("\(deletedDoc.document.id).canvas")
        
        do {
            try fileManager.removeItem(at: fileURL)
            deletedDocuments.removeAll { $0.document.id == deletedDoc.document.id }
            selectedDocuments.remove(deletedDoc.document.id)
        } catch {
            print("Error permanently deleting document: \(error)")
        }
    }
} 