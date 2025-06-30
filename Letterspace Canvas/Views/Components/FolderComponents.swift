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
    var onAddFolder: (Folder, UUID?) -> Void
    
    private var sortedFolders: [Folder] {
        folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var isOrganizeDocumentsActive: Bool {
        activePopup == .organizeDocuments
    }
    
    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            // Header - Only show on iPad, macOS uses system popup title
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
            #endif

                        // Breathing room after separator
                    Spacer()
                .frame(height: 6)
                    
            if currentFolder == nil {
                HStack(spacing: 8) {
                    // "Organize" button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            activePopup = .organizeDocuments
                        }
                    }) {
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
                    .disabled(isOrganizeDocumentsActive)
                    .onHover { isHovered in
                        if !isOrganizeDocumentsActive {
                            hoveredFolder = isHovered ? "organize" : nil
                        }
                    }
                    
                    // "New Folder" button
                        Button(action: {
                            addNewFolder()
                        }) {
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Navigation header
                    if let currentFolder = currentFolder {
                        HStack(spacing: 8) {
                            // Back button and folder name when inside a folder
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    self.currentFolder = nil
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(theme.primary)
                                    .padding(6)
                                    .background(theme.primary.opacity(hoveredFolder == "back" ? 0.05 : 0))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .disabled(isOrganizeDocumentsActive)
                            .onHover { isHovered in
                                if !isOrganizeDocumentsActive {
                                    hoveredFolder = isHovered ? "back" : nil
                                }
                            }
                            
                            Text(currentFolder.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.primary)
                            
                            Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                activePopup = .organizeDocuments
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 10))
                                Text("Organize")
                                    .font(.system(size: 11))
                            }
                                .foregroundStyle(hoveredFolder == "organize_inner" ? theme.accent : theme.secondary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                                .frame(width: 80)
                                .background(theme.secondary.opacity(hoveredFolder == "organize_inner" ? 0 : 0.1))
                                .background(theme.accent.opacity(hoveredFolder == "organize_inner" ? 0.1 : 0))
                            .cornerRadius(4)
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
                    LazyVStack(spacing: 4) {
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
                                    SimpleFolderRow(folder: folder, hoveredFolder: $hoveredFolder, folders: $folders, currentFolder: $currentFolder, isOrganizeDocumentsActive: isOrganizeDocumentsActive, theme: theme)
                                }
                                ForEach(folderDocs) { doc in
                                    Text(doc.title)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(theme.primary)
                                        .padding()
                                                            }
                                                        }
                                        } else {
                            // Root folder view
                            ForEach(sortedFolders) { folder in
                                SimpleFolderRow(folder: folder, hoveredFolder: $hoveredFolder, folders: $folders, currentFolder: $currentFolder, isOrganizeDocumentsActive: isOrganizeDocumentsActive, theme: theme)
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
            
                        if currentFolder == nil {
                Spacer()
                    .frame(height: 8)
                                                                
                                                                Divider()
                                                                
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 3)
                    
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
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .offset(y: 12)
                                    }
                .frame(height: 50)
            }
        }
        .offset(y: -8)
        .frame(height: 380)
        .onAppear(perform: loadDocuments)
        .onChange(of: currentFolder) { _, _ in loadDocuments() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CurrentFolderDidUpdate"))) { notification in
            if let updatedFolder = notification.userInfo?["folder"] as? Folder {
                currentFolder = updatedFolder
            }
        }
    }
    
    private func addNewFolder(parentId: UUID? = nil) {
        let newFolder = Folder(
            id: UUID(),
            name: "New Folder",
            isEditing: true,
            subfolders: [],
            parentId: parentId,
            documentIds: Set<String>()
        )
        onAddFolder(newFolder, parentId)
        focusedFolderId = newFolder.id
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
    
    var body: some View {
                                    Button(action: {
                                        if !isOrganizeDocumentsActive {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                        currentFolder = folders[index]
                }
            }
                                        }
                                    }) {
            HStack(spacing: 8) {
                                            Image(systemName: "folder")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.primary)
                                            Text(folder.name)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(hoveredFolder == folder.id.uuidString ? theme.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { isHovered in
                                            hoveredFolder = isHovered ? folder.id.uuidString : nil
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
        VStack(spacing: 0) {
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
                onAddFolder: addFolder
            )
        }
        .frame(width: {
            #if os(iOS)
            return UIDevice.current.userInterfaceIdiom == .pad ? 500 : 400
            #else
            return 400
            #endif
        }())
        .padding(20)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
        .cornerRadius(16)
        .onAppear {
            loadFolders()
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
