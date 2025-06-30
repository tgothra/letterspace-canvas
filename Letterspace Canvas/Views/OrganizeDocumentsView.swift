import SwiftUI

struct OrganizeDocumentsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    @Binding var isPresented: Bool
    @Binding var folders: [Folder]
    @State private var documents: [Letterspace_CanvasDocument] = []
    @State private var expandedFolders: Set<UUID> = []  // Track which folders are expanded
    @State private var closeButtonHovering = false
    @State private var draggingDocument: Letterspace_CanvasDocument?
    @State private var isLoading = true
    @State private var folderDocuments: [UUID: Set<String>] = [:]
    @State private var needsRefresh: Bool = false
    @State private var selectedFolderId: UUID? = nil
    @State private var showingAddFolderSheet = false
    @State private var newFolderName = ""
    @State private var showingRenameFolderSheet = false
    @State private var renamingFolderId: UUID? = nil
    @State private var renameFolderName = ""
    @State private var hoveredFolderId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Organize Documents")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(closeButtonHovering ? Color.red : Color.gray.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    closeButtonHovering = hovering
                }
            }
            .padding(.bottom, 12)
            
            Text("Drag and drop documents into folders to organize them")
                .font(.system(size: 11))
                .italic()
                .foregroundStyle(theme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
            
            if isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else {
                // Main content area with split view
                HStack(spacing: 0) {
                    // Left side: Folder list
                    VStack(alignment: .leading, spacing: 0) {
                        // Folders header with new folder button
                        HStack {
                            Text("Folders")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(theme.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                showingAddFolderSheet = true
                                newFolderName = ""
                            }) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 8)
                        
                        Divider()
                            .padding(.bottom, 8)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                // All Items option (similar to Smart Study Library)
                                ZStack {
                                    // Background highlight for selected "All Items"
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(selectedFolderId == nil ? Color.blue.opacity(0.1) : Color.clear)
                                        .animation(.easeInOut(duration: 0.1), value: selectedFolderId == nil)
                                    
                                    HStack {
                                        Image(systemName: "folder")
                                            .foregroundColor(selectedFolderId == nil ? .blue : theme.secondary)
                                        Text("All Items")
                                            .foregroundColor(selectedFolderId == nil ? theme.primary : theme.secondary)
                                        Spacer()
                                        if selectedFolderId == nil {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                }
                                .contentShape(Rectangle()) // Make entire area clickable
                                .onTapGesture {
                                    selectedFolderId = nil
                                }
                                
                                // User folders
                                ForEach(folders) { folder in
                                    ZStack {
                                        // Background highlight for selected folder
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedFolderId == folder.id ? Color.blue.opacity(0.1) : Color.clear)
                                            .animation(.easeInOut(duration: 0.1), value: selectedFolderId == folder.id)
                                        
                                        HStack {
                                            // Folder content
                                            HStack {
                                                Image(systemName: "folder")
                                                    .foregroundColor(selectedFolderId == folder.id ? .blue : theme.secondary)
                                                Text(folder.name)
                                                    .foregroundColor(selectedFolderId == folder.id ? theme.primary : theme.secondary)
                                                Spacer()
                                                if selectedFolderId == folder.id {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                            
                                            // Three-dot menu that appears on hover
                                            if hoveredFolderId == folder.id {
                                                Menu {
                                                    Button(action: {
                                                        renamingFolderId = folder.id
                                                        renameFolderName = folder.name
                                                        showingRenameFolderSheet = true
                                                    }) {
                                                        Label("Rename", systemImage: "pencil")
                                                    }
                                                    
                                                    Button(role: .destructive, action: {
                                                        deleteFolder(folder)
                                                    }) {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                } label: {
                                                    Image(systemName: "ellipsis.circle")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(theme.secondary)
                                                        .frame(width: 24, height: 24)
                                                }
                                                .menuStyle(.borderlessButton)
                                                .menuIndicator(.hidden)
                                                .fixedSize()
                                                .transition(.opacity)
                                                .zIndex(1) // Ensure menu is above the button
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                    }
                                    .contentShape(Rectangle()) // Make entire area clickable
                                    .onTapGesture {
                                        selectedFolderId = folder.id
                                    }
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            hoveredFolderId = hovering ? folder.id : nil
                                        }
                                    }
                                    .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
                                        guard let provider = providers.first else { return false }
                                        
                                        provider.loadObject(ofClass: NSString.self) { item, _ in
                                            guard let documentId = item as? String,
                                                  let document = documents.first(where: { $0.id == documentId }) else {
                                                return
                                            }
                                            
                                            // Add document to this folder
                                            addDocumentToFolder(document, folder: folder)
                                        }
                                        
                                        return true
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 250)
                    .padding(.trailing, 1)
                    
                    Divider()
                    
                    // Right side: All Documents or Folder Documents list
                    VStack(alignment: .leading, spacing: 0) {
                        Text(selectedFolderId == nil ? "All Documents" : folders.first(where: { $0.id == selectedFolderId })?.name ?? "Documents")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.primary)
                            .padding(.bottom, 8)
                        
                        Divider()
                            .padding(.bottom, 8)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                let filteredDocuments = getFilteredDocuments()
                                
                                ForEach(filteredDocuments) { document in
                                    DocumentRowView(
                                        document: document, 
                                        draggingDocument: $draggingDocument,
                                        onRemove: selectedFolderId != nil ? {
                                            if let folderId = selectedFolderId,
                                               let folder = folders.first(where: { $0.id == folderId }) {
                                                removeDocumentFromFolder(document, folder: folder)
                                            }
                                        } : nil
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 16)
                }
            }
        }
        .padding(24)
        .frame(width: 700, height: 500)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
        .sheet(isPresented: $showingAddFolderSheet) {
            VStack(spacing: 20) {
                Text("Add New Folder")
                    .font(.headline)
                
                TextField("Folder Name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        showingAddFolderSheet = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Create") {
                        addNewFolder()
                        showingAddFolderSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .cornerRadius(12)
            .frame(width: 350, height: 180)
        }
        .sheet(isPresented: $showingRenameFolderSheet) {
            VStack(spacing: 20) {
                Text("Rename Folder")
                    .font(.headline)
                
                TextField("Folder Name", text: $renameFolderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        showingRenameFolderSheet = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Rename") {
                        renameFolder()
                        showingRenameFolderSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(renameFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .cornerRadius(12)
            .frame(width: 350, height: 180)
        }
        .onAppear {
            loadSavedFolders()
            loadDocuments()
            loadFolderDocuments()
        }
        .onChange(of: folderDocuments) { _, _ in
            updateFoldersFromDocuments()
        }
    }
    
    // New function to load saved folders from UserDefaults
    private func loadSavedFolders() {
        print("📂 Loading saved folders from UserDefaults...")
        if let data = UserDefaults.standard.data(forKey: "SavedFolders") {
            let decoder = JSONDecoder()
            if let decodedFolders = try? decoder.decode([Folder].self, from: data) {
                print("📂 Successfully loaded \(decodedFolders.count) folders")
                // Update folders binding with animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    // Only update if we actually have folders to restore
                    if !decodedFolders.isEmpty {
                        folders = decodedFolders
                    }
                }
            } else {
                print("❌ Failed to decode saved folders data")
            }
        } else {
            print("❌ No saved folders found in UserDefaults")
        }
    }
    
    // Get documents based on current folder selection
    private func getFilteredDocuments() -> [Letterspace_CanvasDocument] {
        if let folderId = selectedFolderId,
           let docIds = folderDocuments[folderId] {
            return documents.filter { docIds.contains($0.id) }
        } else {
            return documents
        }
    }
    
    // Whether the folder is being targeted for drop
    @State private var isDropTargeted = false
    
    // Rest of the functions remain unchanged
    private func loadDocuments() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async {
                    self.documents = []
                    self.isLoading = false
                }
                return
            }
            
            let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
            
            do {
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
                
                let fileURLs = try fileManager.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "canvas" }
                
                var loadedDocuments: [Letterspace_CanvasDocument] = []
                
                for url in fileURLs {
                    do {
                        let data = try Data(contentsOf: url)
                        if let document = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                            loadedDocuments.append(document)
                        }
                    } catch {
                        print("Error loading document at \(url): \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    self.documents = loadedDocuments.sorted { $0.title < $1.title }
                    self.isLoading = false
                }
            } catch {
                print("Error loading documents: \(error)")
                DispatchQueue.main.async {
                    self.documents = []
                    self.isLoading = false
                }
            }
        }
    }
    
    // The rest of your existing functions remain the same
    private func loadFolderDocuments() {
        print("📂 Loading folder documents from UserDefaults...")
        if let data = UserDefaults.standard.data(forKey: "FolderDocuments") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([String: Set<String>].self, from: data) {
                print("📂 Successfully decoded folder documents data")
                
                // First, update the folderDocuments dictionary
                var newFolderDocuments: [UUID: Set<String>] = [:]
                for (key, value) in decoded {
                    if let uuid = UUID(uuidString: key) {
                        newFolderDocuments[uuid] = value
                        print("📂 Loaded \(value.count) documents for folder with ID: \(key)")
                    }
                }
                
                // Then, update each folder's documentIds to match folderDocuments
                var updatedFolders = folders
                for i in 0..<updatedFolders.count {
                    let folderId = updatedFolders[i].id
                    if let docs = newFolderDocuments[folderId] {
                        updatedFolders[i].documentIds = docs
                        print("📂 Updated folder '\(updatedFolders[i].name)' with \(docs.count) documents")
                    }
                }
                
                // Update state with animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.folderDocuments = newFolderDocuments
                    self.folders = updatedFolders
                }
                
                // Save the synchronized state
                saveFolders()
                
                print("📂 Folder documents loading complete")
            } else {
                print("❌ Failed to decode folder documents data")
            }
        } else {
            print("❌ No folder documents data found in UserDefaults")
        }
    }
    
    private func saveFolderDocuments() {
        print("💾 Saving folder documents...")
        let encoder = JSONEncoder()
        // Convert UUID keys to Strings for JSON compatibility
        let stringKeys = folderDocuments.reduce(into: [String: Set<String>]()) { result, pair in
            result[pair.key.uuidString] = pair.value
            if let folder = folders.first(where: { $0.id == pair.key }) {
                print("💾 Saving folder '\(folder.name)' with \(pair.value.count) documents")
            }
        }
        if let encoded = try? encoder.encode(stringKeys) {
            UserDefaults.standard.set(encoded, forKey: "FolderDocuments")
            // Remove synchronize() to prevent main thread hangs
            print("💾 Successfully saved folder documents")
            
            // Update folders' documentIds to stay in sync
            var updatedFolders = folders
            for i in 0..<updatedFolders.count {
                let folderId = updatedFolders[i].id
                if let docs = folderDocuments[folderId] {
                    updatedFolders[i].documentIds = docs
                }
            }
            folders = updatedFolders
        }
    }
    
    private func saveFolders() {
        print("💾 Saving folders...")
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: "SavedFolders")
            // Remove synchronize() to prevent main thread hangs
            print("💾 Successfully saved folders")
        }
    }
    
    private func updateFoldersFromDocuments() {
        print("🔄 Updating folders from documents...")
        var updatedFolders = folders
        for (index, folder) in folders.enumerated() {
            var updatedFolder = folder
            if let docs = folderDocuments[folder.id] {
                updatedFolder.documentIds = docs
                print("🔄 Updating folder '\(folder.name)' with \(docs.count) documents")
            } else {
                updatedFolder.documentIds = []
                print("🔄 Clearing documents for folder '\(folder.name)'")
            }
            updatedFolders[index] = updatedFolder
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            folders = updatedFolders
        }
        
        saveFolders()
        saveFolderDocuments()
        
        // Notify main view of the update
        NotificationCenter.default.post(name: NSNotification.Name("FoldersDidUpdate"), object: nil)
        print("🔄 Folder update complete")
    }
    
    private func addDocumentToFolder(_ document: Letterspace_CanvasDocument, folder: Folder) {
        print("📝 Adding document '\(document.title)' to folder '\(folder.name)'")
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // Update folderDocuments state
                var docs = self.folderDocuments[folder.id] ?? Set<String>()
                docs.insert(document.id)
                self.folderDocuments[folder.id] = docs
                print("📝 Updated folderDocuments: Folder '\(folder.name)' now has \(docs.count) documents")
                
                // Create a new array of folders to trigger SwiftUI updates
                var updatedFolders = self.folders
                if let index = updatedFolders.firstIndex(where: { $0.id == folder.id }) {
                    var updatedFolder = updatedFolders[index]
                    updatedFolder.documentIds = docs
                    updatedFolders[index] = updatedFolder
                    print("📝 Updated folder: '\(updatedFolder.name)' now has \(docs.count) documents")
                    
                    // Update folders binding
                    self.folders = updatedFolders
                }
                
                // Save changes
                self.saveFolderDocuments()
                self.saveFolders()
                
                // Force an immediate update to UserDefaults
                // Remove synchronize() to prevent main thread hangs
                
                // Notify main view of the update
                NotificationCenter.default.post(name: NSNotification.Name("FoldersDidUpdate"), object: nil)
                print("📝 Posted FoldersDidUpdate notification")
            }
        }
    }
    
    private func removeDocumentFromFolder(_ document: Letterspace_CanvasDocument, folder: Folder) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // Update folderDocuments state
                var docs = self.folderDocuments[folder.id] ?? Set<String>()
                docs.remove(document.id)
                self.folderDocuments[folder.id] = docs
                
                // Create a new array of folders to trigger SwiftUI updates
                var updatedFolders = self.folders
                if let index = updatedFolders.firstIndex(where: { $0.id == folder.id }) {
                    var updatedFolder = updatedFolders[index]
                    updatedFolder.documentIds = docs
                    updatedFolders[index] = updatedFolder
                    
                    // Update folders binding
                    self.folders = updatedFolders
                }
                
                // Save changes
                self.saveFolderDocuments()
                self.saveFolders()
                
                // Force an immediate update to UserDefaults
                // Remove synchronize() to prevent main thread hangs
                
                // Notify main view of the update
                NotificationCenter.default.post(name: NSNotification.Name("FoldersDidUpdate"), object: nil)
            }
        }
    }
    
    // Function to add a new folder
    private func addNewFolder() {
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newFolder = Folder(id: UUID(), name: trimmedName, documentIds: [])
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            var updatedFolders = folders
            updatedFolders.append(newFolder)
            folders = updatedFolders
            
            // Create an empty document set for this folder
            folderDocuments[newFolder.id] = Set<String>()
            
            // Select the new folder
            selectedFolderId = newFolder.id
        }
        
        // Save the updated folders to UserDefaults
        saveFolders()
        saveFolderDocuments()
        
        // Notify any listeners that folders have been updated
        NotificationCenter.default.post(name: NSNotification.Name("FoldersDidUpdate"), object: nil)
    }
    
    // Function to rename a folder
    private func renameFolder() {
        let trimmedName = renameFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let folderId = renamingFolderId, !trimmedName.isEmpty else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            var updatedFolders = folders
            if let index = updatedFolders.firstIndex(where: { $0.id == folderId }) {
                var updatedFolder = updatedFolders[index]
                updatedFolder.name = trimmedName
                updatedFolders[index] = updatedFolder
                folders = updatedFolders
            }
        }
        
        // Save the updated folders to UserDefaults
        saveFolders()
        
        // Notify any listeners that folders have been updated
        NotificationCenter.default.post(name: NSNotification.Name("FoldersDidUpdate"), object: nil)
    }
    
    // Function to delete a folder
    private func deleteFolder(_ folder: Folder) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Remove folder from folders array
            folders.removeAll { $0.id == folder.id }
            
            // Remove folder's documents mapping
            folderDocuments.removeValue(forKey: folder.id)
            
            // If the deleted folder was selected, select All Items
            if selectedFolderId == folder.id {
                selectedFolderId = nil
            }
        }
        
        // Save the updated folders to UserDefaults
        saveFolders()
        saveFolderDocuments()
        
        // Notify any listeners that folders have been updated
        NotificationCenter.default.post(name: NSNotification.Name("FoldersDidUpdate"), object: nil)
    }
}

// New document row view that matches the Smart Study Library style
struct DocumentRowView: View {
    let document: Letterspace_CanvasDocument
    @Binding var draggingDocument: Letterspace_CanvasDocument?
    var onRemove: (() -> Void)? = nil
    @Environment(\.themeColors) var theme
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundColor(theme.secondary)
                .frame(width: 20)
            
            Text(document.title.isEmpty ? "Untitled" : document.title)
                .font(.system(size: 13))
                .lineLimit(1)
            
            Spacer()
            
            // Only show remove button if we're in a folder view and hovering
            if isHovering, onRemove != nil {
                Button(action: { onRemove?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray.opacity(0.7))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHovering ? theme.primary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .onDrag {
            draggingDocument = document
            return NSItemProvider(object: document.id as NSString)
        }
    }
} 