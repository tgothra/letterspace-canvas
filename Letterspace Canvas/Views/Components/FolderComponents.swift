import SwiftUI

struct FoldersPopupContent: View {
    @Environment(\.themeColors) var theme
    @State private var hoveredFolder: String?
    @State var currentFolder: Folder?
    @State private var documents: [Letterspace_CanvasDocument] = []
    @Binding var activePopup: ActivePopup
    @Binding var folders: [Folder]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @FocusState private var focusedFolderId: UUID?
    @State private var showFolderNamePopup = false
    @State private var newFolderName = ""
    @State private var isRenaming = false
    @State private var folderToRename: Folder?
    @FocusState private var isNameFieldFocused: Bool
    @State private var showDocumentSelection = false
    @State private var selectedDocuments: Set<String> = []
    @State private var searchText = ""
    var onAddFolder: (Folder, UUID?) -> Void
    var showHeader: Bool = true // Add parameter to control header visibility
    
    private var sortedFolders: [Folder] {
        folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var isOrganizeDocumentsActive: Bool {
        activePopup == .organizeDocuments
    }
    
    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            // Header - Only show on iPad and when showHeader is true
            if showHeader && UIDevice.current.userInterfaceIdiom == .pad {
                HStack {
                    Text("Folders")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .padding(.bottom, 12)
                .background(theme.surface)
                
                Divider()
                    .foregroundStyle(theme.secondary.opacity(0.2))
            }
            #endif

                        // Breathing room after separator
                    Spacer()
                .frame(height: 3) // Reduced from 6 to 3 for tighter spacing
                    
            if currentFolder == nil {
                HStack(spacing: 8) {
                    // "New Folder" button - only button on main modal
                    Button(action: {
                        addNewFolder()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16, weight: .medium))
                            Text("New Folder")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(hoveredFolder == "newFolder" ? theme.accent : theme.secondary)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(theme.secondary.opacity(hoveredFolder == "newFolder" ? 0 : 0.1))
                        .background(theme.accent.opacity(hoveredFolder == "newFolder" ? 0.1 : 0))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isOrganizeDocumentsActive)
                    .onHover { isHovered in
                        if !isOrganizeDocumentsActive {
                            hoveredFolder = isHovered ? "newFolder" : nil
                        }
                    }
                }
                .padding(.horizontal, {
                    #if os(macOS)
                    return 12 // Tighter horizontal padding for macOS
                    #else
                    return 16 // More spacious padding for iPad
                    #endif
                }())
                .padding(.vertical, {
                    #if os(macOS)
                    return 6 // Smaller vertical padding for macOS
                    #else
                    return 8 // More padding for iPad
                    #endif
                }())
                
                // Breathing room after organize/new folder buttons
                Spacer()
                    .frame(height: 6)
            }
            
            // Content layout - different structure for iPhone vs other platforms
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            if isPhone {
                // iPhone: VStack with scrollable content and sticky footer
                VStack(spacing: 0) {
                    // Scrollable content area
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            folderContent
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Sticky footer (only show when not in a folder)
                    if currentFolder == nil {
                        stickyFooter
                    }
                }
            } else {
                // iPad: Original layout with footer below scroll
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            folderContent
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if currentFolder == nil {
                        stickyFooter
                    }
                }
            }
            #else
            // macOS: Original layout with footer below scroll
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        folderContent
                    }
                    .padding(.vertical, 8)
                }
                .frame(minHeight: 200) // Ensure minimum height for folder list visibility
                
                if currentFolder == nil {
                    stickyFooter
                }
            }
            #endif
        }
        .frame(maxHeight: .infinity)
        .blur(radius: showFolderNamePopup ? 4 : 0) // Blur main content when popup is shown
        .animation(.easeInOut(duration: 0.2), value: showFolderNamePopup)
        .onAppear {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: Defer heavy document loading to avoid blocking sheet presentation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    loadDocuments()
                }
            } else {
                // iPad: Load documents normally
                loadDocuments()
            }
            #else
            // macOS: Load documents normally
            loadDocuments()
            #endif
        }
        .onChange(of: currentFolder) { _, _ in loadDocuments() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CurrentFolderDidUpdate"))) { notification in
            if let updatedFolder = notification.userInfo?["folder"] as? Folder {
                currentFolder = updatedFolder
            }
        }
        .gesture(
            // Swipe right to go back when inside a folder
            DragGesture()
                .onEnded { value in
                    // Only trigger if we're inside a folder and swiping right significantly
                    if currentFolder != nil && 
                       value.translation.width > 100 && 
                       abs(value.translation.height) < 50 {
                        // Haptic feedback for navigation
                        #if os(iOS)
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        #endif
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            currentFolder = nil
                        }
                    }
                }
        )
        .overlay {
            if showFolderNamePopup {
                folderNamePopup
            }
        }
        .sheet(isPresented: $showDocumentSelection) {
            documentSelectionSheet
        }
    }
    
    // Folder naming popup
    private var folderNamePopup: some View {
        ZStack {
            // Transparent background overlay (no dark tint)
            Color.clear
                .ignoresSafeArea()
                .onTapGesture {
                    showFolderNamePopup = false
                    newFolderName = ""
                }
            
            // Popup content positioned higher
            VStack(spacing: 20) {
                Text(isRenaming ? "Rename Folder" : "New Folder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                TextField(isRenaming ? "Folder name" : "Folder name", text: $newFolderName)
                    .font(.system(size: 16))
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        createOrRenameFolder()
                    }
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showFolderNamePopup = false
                        newFolderName = ""
                        isRenaming = false
                        folderToRename = nil
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(theme.secondary)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(theme.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .contentShape(Rectangle()) // Better tap area
                    .buttonStyle(.plain)
                    
                    Button(isRenaming ? "Confirm" : "Create") {
                        createOrRenameFolder()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.secondary : theme.accent)
                    .cornerRadius(8)
                    .contentShape(Rectangle()) // Better tap area
                    .buttonStyle(.plain)
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
            .frame(width: 300)
            .background(theme.surface)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .offset(y: -100) // Move popup higher to avoid keyboard
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFieldFocused = true
            }
        }
    }
    
    // Document selection sheet
    private var documentSelectionSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(theme.secondary)
                    TextField("Search documents...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.secondary.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Documents list
                List {
                    ForEach(filteredDocuments) { doc in
                        DocumentSelectionRow(
                            document: doc,
                            isSelected: selectedDocuments.contains(doc.id),
                            theme: theme
                        ) {
                            toggleDocumentSelection(doc.id)
                        }
                    }
                }
                .listStyle(.plain)
                
                // Bottom action bar
                HStack {
                    Button("Cancel") {
                        showDocumentSelection = false
                        selectedDocuments.removeAll()
                    }
                    .foregroundColor(theme.secondary)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(theme.secondary.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button("Add \(selectedDocuments.count) Documents") {
                        addSelectedDocumentsToFolder()
                    }
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(selectedDocuments.isEmpty ? theme.secondary : theme.accent)
                    .cornerRadius(8)
                    .disabled(selectedDocuments.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 8)
                .background(theme.surface)
            }
            .navigationTitle("Add Documents")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
    
    private var filteredDocuments: [Letterspace_CanvasDocument] {
        if searchText.isEmpty {
            return documents
        } else {
            return documents.filter { doc in
                doc.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func toggleDocumentSelection(_ documentId: String) {
        if selectedDocuments.contains(documentId) {
            selectedDocuments.remove(documentId)
        } else {
            selectedDocuments.insert(documentId)
        }
    }
    
    private func addSelectedDocumentsToFolder() {
        guard let currentFolder = currentFolder else { return }
        
        if let folderIndex = folders.firstIndex(where: { $0.id == currentFolder.id }) {
            // Add selected documents to the folder
            for documentId in selectedDocuments {
                folders[folderIndex].documentIds.insert(documentId)
            }
            
            // Update current folder reference
            self.currentFolder = folders[folderIndex]
            
            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(folders) {
                UserDefaults.standard.set(encoded, forKey: "SavedFolders")
            }
            
            print("📂 Added \(selectedDocuments.count) documents to folder '\(currentFolder.name)'")
        }
        
        // Close the sheet and reset selection
        showDocumentSelection = false
        selectedDocuments.removeAll()
    }
    
    private func addNewFolder(parentId: UUID? = nil) {
        newFolderName = ""
        isRenaming = false
        folderToRename = nil
        showFolderNamePopup = true
    }
    
    private func startRenameFolder(_ folder: Folder) {
        newFolderName = folder.name
        isRenaming = true
        folderToRename = folder
        showFolderNamePopup = true
    }
    
    private func createOrRenameFolder() {
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name is not empty
        guard !trimmedName.isEmpty else {
            return // Don't create/rename if name is blank
        }
        
        if isRenaming, let folderToRename = folderToRename {
            // Rename existing folder
            if let index = folders.firstIndex(where: { $0.id == folderToRename.id }) {
                folders[index].name = trimmedName
                
                // Update current folder if we're renaming the current one
                if currentFolder?.id == folderToRename.id {
                    currentFolder?.name = trimmedName
                }
                
                // Save to UserDefaults
                if let encoded = try? JSONEncoder().encode(folders) {
                    UserDefaults.standard.set(encoded, forKey: "SavedFolders")
                }
            }
        } else {
            // Create new folder
            let newFolder = Folder(
                id: UUID(),
                name: trimmedName,
                isEditing: false,
                subfolders: [],
                parentId: nil,
                documentIds: Set<String>()
            )
            onAddFolder(newFolder, nil)
            
            // Automatically navigate into the new folder
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                currentFolder = newFolder
            }
        }
        
        // Close popup and reset
        showFolderNamePopup = false
        newFolderName = ""
        isRenaming = false
        folderToRename = nil
    }
    
    private func deleteFolder(_ folder: Folder) {
        print("🗑️ deleteFolder called for: \(folder.name)")
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            print("🗑️ Found folder at index \(index), removing...")
            folders.remove(at: index)
            print("🗑️ Folder removed. Remaining folders: \(folders.count)")
            
            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(folders) {
                UserDefaults.standard.set(encoded, forKey: "SavedFolders")
                print("🗑️ Saved updated folders to UserDefaults")
            }
        } else {
            print("🗑️ ERROR: Could not find folder to delete")
        }
    }
    
    private func removeDocumentFromFolder(_ document: Letterspace_CanvasDocument, from folder: Folder) {
        print("🗑️ removeDocumentFromFolder called for: \(document.title) from \(folder.name)")
        if let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) {
            print("🗑️ Found folder at index \(folderIndex)")
            folders[folderIndex].documentIds.remove(document.id)
            print("🗑️ Document removed from folder. Documents in folder: \(folders[folderIndex].documentIds.count)")
            
            // Also update currentFolder if it's the same folder
            if currentFolder?.id == folder.id {
                currentFolder = folders[folderIndex]
                print("🗑️ Updated current folder")
            }
            
            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(folders) {
                UserDefaults.standard.set(encoded, forKey: "SavedFolders")
                print("🗑️ Saved updated folders to UserDefaults")
            }
            
            print("📂 Removed document '\(document.title)' from folder '\(folder.name)'")
        } else {
            print("🗑️ ERROR: Could not find folder to remove document from")
        }
    }
    
    private func loadDocuments() {
        print("📂 Loading documents...")
        
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("❌ Could not access documents directory")
            return
        }
        
        print("📂 Loading from directory: \(appDirectory.path)")
        
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try fileManager.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📂 Found \(fileURLs.count) canvas files")
            
            var loadedDocuments: [Letterspace_CanvasDocument] = []
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    if let document = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                        loadedDocuments.append(document)
                        print("📂 Loaded document: \(document.title) (ID: \(document.id))")
                    }
                } catch {
                    print("❌ Error loading document at \(url): \(error)")
                }
            }
            
            documents = loadedDocuments.sorted { $0.title < $1.title }
            print("📂 Loaded \(documents.count) documents total")
            
        } catch {
            print("❌ Error accessing documents directory: \(error)")
        }
    }
    
    // Computed property for the main folder content
    private var folderContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Debug: Log the current state
            let _ = print("📁 DEBUG: sortedFolders count: \(sortedFolders.count)")
            let _ = print("📁 DEBUG: folders array: \(folders.map { $0.name })")
            let _ = print("📁 DEBUG: currentFolder: \(currentFolder?.name ?? "nil")")
            
            // Navigation header
            if let currentFolder = currentFolder {
                HStack(spacing: 8) {
                    // Back button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            self.currentFolder = nil
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.primary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(theme.primary.opacity(hoveredFolder == "back" ? 0.1 : 0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isOrganizeDocumentsActive)
                    .onHover { isHovered in
                        if !isOrganizeDocumentsActive {
                            hoveredFolder = isHovered ? "back" : nil
                        }
                    }
                    
                    Spacer()
                    
                    // Centered folder name
                    Text(currentFolder.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.primary)
                        .frame(height: 44)
                        .padding(.horizontal, 16)
                        .background(theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.primary.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .onTapGesture {
                            startRenameFolder(currentFolder)
                        }
                    
                    Spacer()
                
                // Add Doc button (icon only)
                Button(action: {
                    showDocumentSelection = true
                    selectedDocuments.removeAll()
                    searchText = ""
                }) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(hoveredFolder == "organize_inner" ? theme.accent : theme.secondary)
                        .frame(width: 44, height: 44)
                        .background(theme.secondary.opacity(hoveredFolder == "organize_inner" ? 0 : 0.1))
                        .background(theme.accent.opacity(hoveredFolder == "organize_inner" ? 0.1 : 0))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isOrganizeDocumentsActive)
                .onHover { isHovered in
                    if !isOrganizeDocumentsActive {
                        hoveredFolder = isHovered ? "organize_inner" : nil
                    }
                }
            }
            .padding(.horizontal, 12)
            }
    
            // Content area
            LazyVStack(spacing: 8) {
                if let currentFolder = currentFolder {
                    let folderDocs = documents.filter { currentFolder.documentIds.contains($0.id) }
                    let displayedFolders = currentFolder.subfolders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    
                    if displayedFolders.isEmpty && folderDocs.isEmpty {
                        Text("This folder is empty")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.secondary)
                            .padding()
                    } else {
                        ForEach(displayedFolders) { folder in
                            SimpleFolderRow(folder: folder, hoveredFolder: $hoveredFolder, folders: $folders, currentFolder: $currentFolder, isOrganizeDocumentsActive: isOrganizeDocumentsActive, theme: theme, onRename: startRenameFolder, onDelete: deleteFolder)
                        }
                        ForEach(folderDocs) { doc in
                            FolderDocumentRow(
                                document: doc,
                                currentFolder: currentFolder,
                                theme: theme,
                                isOrganizeDocumentsActive: isOrganizeDocumentsActive,
                                onRemove: { removeDocumentFromFolder(doc, from: currentFolder) },
                                onOpen: { loadAndOpenDocument(id: doc.id) }
                            )
                        }
                    }
                } else {
                    // Root folder view
                    ForEach(sortedFolders) { folder in
                        SimpleFolderRow(folder: folder, hoveredFolder: $hoveredFolder, folders: $folders, currentFolder: $currentFolder, isOrganizeDocumentsActive: isOrganizeDocumentsActive, theme: theme, onRename: startRenameFolder, onDelete: deleteFolder)
                    }
                }
            }
            .padding(.horizontal, {
                #if os(macOS)
                return 10 // Tighter horizontal padding for macOS
                #else
                return 12 // More spacious padding for iPad
                #endif
            }())
        }
    }
    
    // Computed property for the sticky footer
    private var stickyFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .foregroundStyle(theme.secondary.opacity(0.2))
                .padding(.horizontal, -20) // Extend divider to full width
            
            // Center the tooltip evenly between separator and bottom edge with reasonable spacing
            Spacer()
                .frame(height: 20) // Increased from 16 to 20 for more breathing room
            
            // Rounded content area with proper background
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.secondary)
                    
                    Text("Deleting folders doesn't delete their documents")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(theme.secondary.opacity(0.08)) // Restore the rounded background
            .cornerRadius(12) // Restore the rounded corners
            .padding(.horizontal, 12) // Add margin from edges
            
            Spacer()
                .frame(height: 2) // Reduced from 4 to 2 for even less space from bottom
        }
        // Remove the container background that's causing the unwanted footer background
    }
}

struct FolderActionButtons: View {
    @Environment(\.themeColors) var theme
    @Binding var hoveredFolder: String?
    var onOrganize: () -> Void
    var onNewFolder: () -> Void

    var body: some View {
                                                            HStack(spacing: 8) {
            Button(action: onOrganize) {
                                                                    HStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 10))
                    Text("Organize")
                                                                            .font(.system(size: 11))
                                                                    }
                .foregroundStyle(hoveredFolder == "organize" ? theme.accent : theme.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .background(theme.secondary.opacity(hoveredFolder == "organize" ? 0 : 0.1))
                .background(theme.accent.opacity(hoveredFolder == "organize" ? 0.1 : 0))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .onHover { isHovered in hoveredFolder = isHovered ? "organize" : nil }
            
            Button(action: onNewFolder) {
                                                                    HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 10))
                    Text("New Folder")
                                                                            .font(.system(size: 11))
                                                                    }
                .foregroundStyle(hoveredFolder == "newFolder" ? theme.accent : theme.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .background(theme.secondary.opacity(hoveredFolder == "newFolder" ? 0 : 0.1))
                .background(theme.accent.opacity(hoveredFolder == "newFolder" ? 0.1 : 0))
                .cornerRadius(4)
                                            }
                                            .buttonStyle(.plain)
            .onHover { isHovered in hoveredFolder = isHovered ? "newFolder" : nil }
        }
    }
}

struct FolderNavigationView: View {
    @Environment(\.themeColors) var theme
    let currentFolder: Folder
    @Binding var hoveredFolder: String?
    var onBack: () -> Void
    var onOrganize: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .onHover { isHovered in hoveredFolder = isHovered ? "back" : nil }
            
            Text(currentFolder.name)
                .font(.system(size: 13, weight: .medium))
            
                                                Spacer()
            
            Button(action: onOrganize) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc.fill").font(.system(size: 10))
                    Text("Organize").font(.system(size: 11))
            }
                                        }
                                        .buttonStyle(.plain)
            .onHover { isHovered in hoveredFolder = isHovered ? "organize" : nil }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct SimpleFolderRow: View {
    let folder: Folder
    @Binding var hoveredFolder: String?
    @Binding var folders: [Folder]
    @Binding var currentFolder: Folder?
    let isOrganizeDocumentsActive: Bool
    let theme: ThemeColors
    let onRename: (Folder) -> Void
    let onDelete: (Folder) -> Void
    @State private var swipeOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Main folder content
            Button(action: {
                if !isOrganizeDocumentsActive && swipeOffset == 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                            currentFolder = folders[index]
                        }
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 17))
                        .foregroundStyle(theme.primary)
                    Text(folder.name)
                        .font(.system(size: 16))
                        .foregroundStyle(theme.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(hoveredFolder == folder.id.uuidString ? theme.secondary.opacity(0.1) : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .offset(x: swipeOffset)
            .onHover { isHovered in
                if swipeOffset == 0 {
                    hoveredFolder = isHovered ? folder.id.uuidString : nil
                }
            }
            .contextMenu {
                Button("Rename") {
                    onRename(folder)
                }
                Button("Delete", role: .destructive) {
                    onDelete(folder)
                }
            }
            .zIndex(1)
            
            // Delete button that appears on swipe
            HStack {
                Spacer()
                Button(action: {
                    print("🗑️ Folder delete button tapped for: \(folder.name)")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onDelete(folder)
                        swipeOffset = 0
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 36)
                        .background(Color.red)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .opacity(swipeOffset < -10 ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: swipeOffset)
            .zIndex(swipeOffset < -10 ? 2 : 0)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if value.translation.width < 0 && !isOrganizeDocumentsActive {
                        swipeOffset = max(value.translation.width, -80)
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if value.translation.width < -40 {
                            swipeOffset = -60
                        } else {
                            swipeOffset = 0
                        }
                    }
                }
        )
        .onChange(of: isOrganizeDocumentsActive) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    swipeOffset = 0
                }
            }
        }
    }
}

struct FolderDocumentRow: View {
    let document: Letterspace_CanvasDocument
    let currentFolder: Folder
    let theme: ThemeColors
    let isOrganizeDocumentsActive: Bool
    let onRemove: () -> Void
    let onOpen: () -> Void
    @State private var swipeOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Main document content
            Button(action: {
                if swipeOffset == 0 {
                    onOpen()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 17))
                        .foregroundStyle(theme.secondary)
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: 16))
                        .foregroundStyle(theme.primary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .offset(x: swipeOffset)
            .zIndex(1)
            
            // Delete button that appears on swipe
            HStack {
                Spacer()
                Button(action: {
                    print("🗑️ Document delete button tapped for: \(document.title)")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onRemove()
                        swipeOffset = 0
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 36)
                        .background(Color.red)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .opacity(swipeOffset < -10 ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: swipeOffset)
            .zIndex(swipeOffset < -10 ? 2 : 0)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if value.translation.width < 0 && !isOrganizeDocumentsActive {
                        swipeOffset = max(value.translation.width, -80)
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if value.translation.width < -40 {
                            swipeOffset = -60
                        } else {
                            swipeOffset = 0
                        }
                    }
                }
        )
        .onChange(of: isOrganizeDocumentsActive) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    swipeOffset = 0
                }
            }
        }
    }
}

extension FoldersPopupContent {
    
    // Function to load and open a document by ID
    func loadAndOpenDocument(id: String) {
        print("🔍 Loading document with ID: \(id)")
        
        // Check if document is in cache
        if let cachedDocument = DocumentCacheManager.shared.getDocument(id: id) {
            print("📂 Using cached document: \(cachedDocument.title)")
            
            // If document has a header image, ensure it's preloaded
            preloadHeaderImage(for: cachedDocument) {
                // Update the document binding from cache
                DispatchQueue.main.async {
                    // Setting the document and sidebar mode immediately without animation
                    // for better performance
                    document = cachedDocument
                    sidebarMode = .details
                    isRightSidebarVisible = true
                    
                    // Post notification that document has loaded
                    NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                }
            }
            return
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        let fileURL = appDirectory.appendingPathComponent("\(id).canvas")
        print("📂 Looking for file at: \(fileURL.path)")
        
        // Load document in a background thread to improve performance
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: fileURL)
                print("📂 Successfully read data from file: \(fileURL.lastPathComponent)")
                let loadedDocument = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                print("📂 Successfully decoded document: \(loadedDocument.title)")
                
                // Preload the header image before showing the document
                self.preloadHeaderImage(for: loadedDocument) {
                    // Update cache
                    DispatchQueue.main.async {
                        DocumentCacheManager.shared.cacheDocument(id: id, document: loadedDocument)
                        
                        // Setting the document and sidebar mode without animation
                        // for better performance
                        document = loadedDocument
                        sidebarMode = .details
                        isRightSidebarVisible = true
                        
                        // Post notification that document has loaded
                        NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                    }
                }
            } catch {
                print("❌ Error loading document with ID \(id): \(error)")
            }
        }
    }
    
    // Helper function to preload header image before showing document
    private func preloadHeaderImage(for document: Letterspace_CanvasDocument, completion: @escaping () -> Void) {
        // Only try to preload if document has header image and header is expanded
        if document.isHeaderExpanded,
           let headerElement = document.elements.first(where: { $0.type == .headerImage }),
           !headerElement.content.isEmpty {
            
            // Check if image is already in cache
            let cacheKey = "\(document.id)_\(headerElement.content)"
            if ImageCache.shared.image(for: cacheKey) != nil {
                print("📸 Header image already in cache, showing document immediately")
                completion()
                return
            }
            
            // Image not in cache, load it first
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                completion()
                return
            }
            
            let documentPath = documentsPath.appendingPathComponent("\(document.id)")
            let imagesPath = documentPath.appendingPathComponent("Images")
            let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
            
            print("📸 Preloading header image before showing document")
            DispatchQueue.global(qos: .userInitiated).async {
                #if os(macOS)
                if let headerImage = NSImage(contentsOf: imageUrl) {
                    // Cache both with document-specific key and generic key
                    ImageCache.shared.setImage(headerImage, for: cacheKey)
                    ImageCache.shared.setImage(headerImage, for: headerElement.content)
                    print("📸 Header image preloaded successfully")
                }
                #elseif os(iOS)
                if let imageData = try? Data(contentsOf: imageUrl),
                   let headerImage = UIImage(data: imageData) {
                    // Cache both with document-specific key and generic key
                    ImageCache.shared.setImage(headerImage, for: cacheKey)
                    ImageCache.shared.setImage(headerImage, for: headerElement.content)
                    print("📸 Header image preloaded successfully")
                }
                #endif
                
                // Always complete, even if image load fails
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            // No header image to preload
            completion()
        }
    }
}

struct FolderListView: View {
    @Binding var folders: [Folder]
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Folders header with plus button
            HStack(spacing: 4) {
                Text("Folders")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.primary)
                
                Button(action: {
                    let newFolder = Folder(id: UUID(), name: "New Folder", isEditing: true)
                    folders.append(newFolder)
                    
                    // Save folders to ensure persistence
                    if let encoded = try? JSONEncoder().encode(folders) {
                        UserDefaults.standard.set(encoded, forKey: "SavedFolders")
                        UserDefaults.standard.synchronize()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.bottom, 8)
            
            ForEach($folders) { $folder in
                FolderRowView(folder: $folder, folders: $folders)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct FolderRowView: View {
    @Binding var folder: Folder
    @Binding var folders: [Folder]
    @Environment(\.themeColors) var theme
    @FocusState private var isFocused: Bool
    
    var body: some View {
        if folder.isEditing {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(theme.secondary)
                
                TextField("Folder name", text: $folder.name)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.secondary)
                    .focused($isFocused)
                    .onAppear {
                        isFocused = true
                    }
                    .onSubmit {
                        saveFolderName()
                    }
                    #if os(macOS)
                    .onExitCommand {
                        saveFolderName()
                    }
                    #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        } else {
            ZStack {
                // Delete button that appears on swipe
                HStack {
                    Spacer()
                    Button(action: {
                        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                            folders.remove(at: index)
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 32)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                }
                .opacity(folder.swipeOffset < 0 ? 1 : 0)
                
                // Folder button with swipe gesture
                DocumentFolderButton(title: folder.name, icon: "folder", action: {})
                    .font(.system(size: 14))
                    .offset(x: folder.swipeOffset)
                    .contentShape(Rectangle()) // Added contentShape
                    .contextMenu {
                        Button(role: .destructive, action: {
                            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                                folders.remove(at: index)
                                
                                // Save to UserDefaults after deletion
                                if let encoded = try? JSONEncoder().encode(folders) {
                                    UserDefaults.standard.set(encoded, forKey: "SavedFolders")
                                    UserDefaults.standard.synchronize()
                                }
                            }
                        }) {
                            Label("Delete Folder", systemImage: "trash")
                        }
                    }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if value.translation.width < 0 {
                            withAnimation(.interactiveSpring()) {
                                folder.swipeOffset = value.translation.width
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width < -30 {
                                // Show delete button fully
                                folder.swipeOffset = -60
                            } else {
                                // Reset position
                                folder.swipeOffset = 0
                            }
                        }
                    }
            )
        }
    }
    
    private func saveFolderName() {
        let finalName = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalName.isEmpty {
            folder.name = "Untitled"
        }
        folder.isEditing = false
        
        // Update the folder in the array
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
        }
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: "SavedFolders")
        }
    }
}

extension Folder {
    var swipeOffset: CGFloat {
        get { UserDefaults.standard.double(forKey: "folder_offset_\(id.uuidString)") }
        set { UserDefaults.standard.set(newValue, forKey: "folder_offset_\(id.uuidString)") }
    }
}

// Folders modal view
struct FoldersView: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    let onDismiss: () -> Void
    @State private var folders: [Folder] = []
    @State private var activePopup: ActivePopup = .folders
    @State private var document = Letterspace_CanvasDocument(title: "", subtitle: "", elements: [], id: "", markers: [], series: nil, variations: [], isVariation: false, parentVariationId: nil, createdAt: Date(), modifiedAt: Date(), tags: nil, isHeaderExpanded: false, isSubtitleVisible: true, links: [])
    @State private var sidebarMode: RightSidebar.SidebarMode = .allDocuments
    @State private var isRightSidebarVisible = false
    @State private var isHoveringClose = false
    
    var body: some View {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #endif
        
        Group {
            #if os(iOS)
            if isPhone {
                // iPhone: Use NavigationStack (iOS 16+) for better performance, fallback to VStack for older iOS
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        FoldersPopupContent(
                            activePopup: $activePopup,
                            folders: $folders,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            isRightSidebarVisible: $isRightSidebarVisible,
                            onAddFolder: addFolder,
                            showHeader: false // Don't show header since we have navigation title
                        )
                        .navigationTitle("Folders")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: {
                                #if os(iOS)
                                .navigationBarTrailing
                                #else
                                .automatic
                                #endif
                            }()) {
                                Button("Done", action: onDismiss)
                            }
                        }
                    }
                } else {
                    // Fallback for iOS 15 and below: Use simple VStack to avoid NavigationView delays
                    VStack(spacing: 0) {
                        // Simple header for older iOS
                        HStack {
                            Text("Folders")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Button("Done", action: onDismiss)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemGroupedBackground))
                        
                        Divider()
                        
                        FoldersPopupContent(
                            activePopup: $activePopup,
                            folders: $folders,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            isRightSidebarVisible: $isRightSidebarVisible,
                            onAddFolder: addFolder,
                            showHeader: false
                        )
                    }
                }
            } else {
                // iPad: Use regular VStack
                VStack(spacing: 0) {
                    foldersViewBody
                }
            }
            #else
            // macOS: Use regular VStack
            VStack(spacing: 0) {
                foldersViewBody
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: Defer heavy folder loading to avoid blocking sheet presentation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    loadFolders()
                }
            } else {
                // iPad: Load folders normally  
                loadFolders()
            }
            #else
            // macOS: Load folders normally
            loadFolders()
            #endif
        }
    }
    
    private var foldersViewBody: some View {
        Group {
            // Header
            HStack {
                Text("Folders")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
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
            .padding(.bottom, 8)
            
            // Folders content
            FoldersPopupContent(
                activePopup: $activePopup,
                folders: $folders,
                document: $document,
                sidebarMode: $sidebarMode,
                isRightSidebarVisible: $isRightSidebarVisible,
                onAddFolder: addFolder,
                showHeader: false // Don't show header since modal already has one
            )
        }
    }
    
    private func loadFolders() {
        if let savedData = UserDefaults.standard.data(forKey: "SavedFolders"),
           let decodedFolders = try? JSONDecoder().decode([Folder].self, from: savedData) {
            folders = decodedFolders
        } else {
            folders = [
                Folder(id: UUID(), name: "Sermons", isEditing: false, subfolders: [], documentIds: Set<String>()),
                Folder(id: UUID(), name: "Bible Studies", isEditing: false, subfolders: [], documentIds: Set<String>()),
                Folder(id: UUID(), name: "Notes", isEditing: false, subfolders: [], documentIds: Set<String>()),
                Folder(id: UUID(), name: "Archive", isEditing: false, subfolders: [], documentIds: Set<String>())
            ]
            }
    }
    
    private func addFolder(_ folder: Folder, to parentId: UUID?) {
        folders.append(folder)
        // Save folders
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: "SavedFolders")
            UserDefaults.standard.synchronize()
            }
    }
}

struct DocumentSelectionRow: View {
    let document: Letterspace_CanvasDocument
    let isSelected: Bool
    let theme: ThemeColors
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(theme.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Document info
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.title.isEmpty ? "Untitled" : document.title)
                            .font(.system(size: 16))
                            .foregroundStyle(theme.primary)
                            .lineLimit(1)
                        
                        if !document.subtitle.isEmpty {
                            Text(document.subtitle)
                                .font(.system(size: 14))
                                .foregroundStyle(theme.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}