import SwiftUI

// MARK: - Floating Contextual Toolbar for iPad
struct FloatingContextualToolbar: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    private var popoverBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @Binding var isCollapsed: Bool
    @Binding var dragAmount: CGSize
    var isDistractionFreeMode: Bool = false
    

    
    // Track which panel is currently open
    @State private var activePanel: ToolType? = nil
    
    // Computed property for available tools based on mode
    private var availableTools: [ToolType] {
        if isDistractionFreeMode {
            return [.bookmarks] // Only bookmarks in distraction-free mode
        } else {
            return ToolType.allCases // All tools in normal mode
        }
    }
    
    // Available tools with their own panels
    enum ToolType: CaseIterable {
        case details
        case series
        case tags
        case variations
        case bookmarks
        case search
        
        var icon: String {
            switch self {
            case .details: return "doc.text"
            case .series: return "books.vertical"
            case .tags: return "tag"
            case .variations: return "doc.on.doc"
            case .bookmarks: return "bookmark"
            case .search: return "magnifyingglass"
            }
        }
        
        var title: String {
            switch self {
            case .details: return "Details"
            case .series: return "Series"
            case .tags: return "Tags"
            case .variations: return "Variations"
            case .bookmarks: return "Bookmarks"
            case .search: return "Search"
            }
        }
        
        var color: String {
            switch self {
            case .details: return "blue"
            case .series: return "green" 
            case .tags: return "orange"
            case .variations: return "purple"
            case .bookmarks: return "pink"
            case .search: return "gray"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if !isCollapsed {
                if isDistractionFreeMode {
                    // In distraction-free mode, show bookmarks content directly
                    bookmarksPanel
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(1)
                } else {
                    // Normal mode: show active panel if selected
                    if let activePanel = activePanel {
                        toolPanel(for: activePanel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                            .zIndex(1)
                    }
                    
                    // Floating tool buttons (when expanded)
                    floatingToolButtons
                        .zIndex(2)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                // Collapsed indicator - thin vertical line on the right edge
                collapsedIndicator
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showTranslationModal) {
            TranslationPreviewView(document: $document, isPresented: $showTranslationModal)
        }
    }
    
    // MARK: - Unified Floating Toolbar Bar
    private var floatingToolButtons: some View {
        VStack(spacing: 12) {
            // Show only bookmarks in distraction-free mode, all tools in normal mode
            ForEach(availableTools, id: \.self) { toolType in
                Button(action: { toggleTool(toolType) }) {
                    Image(systemName: toolType.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(activePanel == toolType ? Color.white : theme.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(activePanel == toolType ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(activePanel == toolType ? 0.95 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: activePanel == toolType)
            }
            
            // Show separator only if there are multiple tools (normal mode)
            if !isDistractionFreeMode {
                // Separator
                Divider()
                    .frame(width: 24)
                    .foregroundStyle(theme.secondary.opacity(0.3))
            }
            
            // Collapse arrow (no button styling)
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isCollapsed = true
                    UserDefaults.standard.set(true, forKey: "floatingToolbarIsCollapsed")
                    // Close any active panel when collapsing
                    activePanel = nil
                }
            }) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 40, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            // Glassmorphism effect (matching left sidebar)
            ZStack {
                // Base blur
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.background.opacity(0.3),
                        theme.background.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            // Border (matching left sidebar)
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: -5, y: 0) // Shadow to the left instead of right
        // Add swipe gesture to hide toolbar when expanded
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        // Slow down the manual drag by applying a damping factor
                        dragAmount = CGSize(
                            width: value.translation.width * 0.4, // 40% of actual drag distance
                            height: value.translation.height
                        )
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragAmount = .zero
                        // Swipe right to hide toolbar (using original translation for threshold)
                        if value.translation.width > 50 {
                            isCollapsed = true
                            UserDefaults.standard.set(true, forKey: "floatingToolbarIsCollapsed")
                            // Close any active panel when collapsing
                            activePanel = nil
                        }
                    }
                }
        )
    }
    
    // MARK: - Distraction-Free Bookmarks Panel
    private var bookmarksPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bookmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                
                Text("Bookmarks")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isCollapsed = true
                        UserDefaults.standard.set(true, forKey: "floatingToolbarIsCollapsed")
                    }
                }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(theme.secondary.opacity(0.1)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .foregroundStyle(theme.secondary.opacity(0.2))
            
            // Bookmarks content
            ScrollView {
                bookmarksContent
                    .padding(16)
            }
            .frame(maxHeight: 500)
        }
        .frame(width: 320, alignment: .leading)
        .background(
            // Glassmorphism effect for panel (matching toolbar)
            ZStack {
                // Base blur
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.background.opacity(0.3),
                        theme.background.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            // Border
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: -4, y: 0)
        // Add swipe gesture to hide panel when expanded
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        // Slow down the manual drag by applying a damping factor
                        dragAmount = CGSize(
                            width: value.translation.width * 0.4, // 40% of actual drag distance
                            height: value.translation.height
                        )
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragAmount = .zero
                        // Swipe right to hide panel (using original translation for threshold)
                        if value.translation.width > 50 {
                            isCollapsed = true
                            UserDefaults.standard.set(true, forKey: "floatingToolbarIsCollapsed")
                        }
                    }
                }
        )
    }
    
    // MARK: - Collapsed Indicator
    private var collapsedIndicator: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.primary.opacity(0.3))
            .frame(width: 3, height: 60)
            .scaleEffect(dragAmount.width < 0 ? 1.2 : 1.0) // Visual feedback when dragging
            .opacity(1.0)
            .animation(.easeOut(duration: 0.1), value: dragAmount.width)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            // Slow down the manual drag by applying a damping factor
                            dragAmount = CGSize(
                                width: value.translation.width * 0.4, // 40% of actual drag distance
                                height: value.translation.height
                            )
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragAmount = .zero
                            // Swipe left to show toolbar (using original translation for threshold)
                            if value.translation.width < -50 {
                                isCollapsed = false
                                UserDefaults.standard.set(false, forKey: "floatingToolbarIsCollapsed")
                            }
                        }
                    }
            )
    }
    

    
    // MARK: - Helper Methods
    private func toggleTool(_ toolType: ToolType) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if activePanel == toolType {
                // Close if same tool is tapped
                activePanel = nil
            } else {
                // Open the selected tool panel
                activePanel = toolType
            }
        }
    }
    
    private func setMode(_ mode: RightSidebar.SidebarMode) {
        sidebarMode = mode
        // Show the traditional right sidebar for full functionality
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isRightSidebarVisible = true
            activePanel = nil
        }
    }
    
    private func getPresentationText() -> String {
        if let firstVariation = document.variations.first,
           let datePresented = firstVariation.datePresented {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: datePresented)
        }
        return "No date scheduled"
    }
    
    // Get recent locations from all documents
    private var recentLocations: [String] {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            var locations: Set<String> = []
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Collect locations from variations
                    for variation in doc.variations {
                        if let location = variation.location, !location.isEmpty {
                            locations.insert(location)
                        }
                    }
                } catch {
                    continue // Skip documents that can't be loaded
                }
            }
            
            return Array(locations).sorted()
        } catch {
            return []
        }
    }
    
    private var matchingLocations: [String] {
        guard !locationSearchText.isEmpty else { return recentLocations }
        return recentLocations.filter { 
            $0.localizedCaseInsensitiveContains(locationSearchText) 
        }
    }
    
    private func loadSeriesDocuments() {
        guard let currentSeries = document.series else {
            seriesDocuments = []
            return
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            seriesDocuments = []
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            var documents: [(title: String, date: String, isActive: Bool, documentId: String)] = []
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Check if this document is in the same series
                    if let docSeries = doc.series, docSeries.name == currentSeries.name {
                        documents.append((
                            title: doc.title.isEmpty ? "Untitled" : doc.title,
                            date: formatDate(doc.modifiedAt),
                            isActive: doc.id == document.id,
                            documentId: doc.id
                        ))
                    }
                } catch {
                    continue // Skip documents that can't be loaded
                }
            }
            
            // Sort by date (most recent first)
            documents.sort { $0.date > $1.date }
            
            // Convert to the format expected by the UI
            seriesDocuments = documents.map { (title: $0.title, date: $0.date, isActive: $0.isActive) }
        } catch {
            seriesDocuments = []
        }
    }
    
    private func openSeriesDocument(title: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if doc.title == title || (doc.title.isEmpty && title == "Untitled") {
                        // Switch to the document directly using the binding
                        DispatchQueue.main.async {
                            self.document = doc
                            
                            // Post notification that document has loaded (similar to MainLayout)
                            NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                            
                            // Close the panel
                            self.activePanel = nil
                        }
                        return
                    }
                } catch {
                    continue
                }
            }
        } catch {
            print("Error loading series document: \(error)")
        }
    }
    
    private func addToSeries(_ seriesName: String) {
        // Create or attach to series
        let newSeries = DocumentSeries(
            id: UUID(),
            name: seriesName,
            documents: [document.id],
            order: 1
        )
        document.series = newSeries
        document.save()
        seriesSearchText = ""
        isSeriesSearchFocused = false
        
        // Reload series documents to show the updated list
        loadSeriesDocuments()
    }
    
    private func loadAllSeries() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            allSeries = []
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            var series: Set<String> = []
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Collect series names from all documents
                    if let docSeries = doc.series, !docSeries.name.isEmpty {
                        series.insert(docSeries.name)
                    }
                } catch {
                    continue // Skip documents that can't be loaded
                }
            }
            
            allSeries = Array(series).sorted()
        } catch {
            allSeries = []
        }
    }
    
    private var matchingSeries: [String] {
        guard !seriesSearchText.isEmpty else { return allSeries }
        return allSeries.filter { 
            $0.localizedCaseInsensitiveContains(seriesSearchText) 
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func saveLocationToDocument() {
        // Update first variation's location
        if var firstVariation = document.variations.first {
            firstVariation.location = locationSearchText.isEmpty ? nil : locationSearchText
            document.variations[0] = firstVariation
            document.save()
        } else {
            // Create first variation if it doesn't exist
            let variation = DocumentVariation(
                id: UUID(),
                name: "Original",
                documentId: document.id,
                parentDocumentId: document.id,
                createdAt: Date(),
                datePresented: nil,
                location: locationSearchText.isEmpty ? nil : locationSearchText
            )
            document.variations = [variation]
            document.save()
        }
    }
    
    // Variations panel functions
    private func openVariation(_ variation: DocumentVariation) {
        // Load the variation document from the file system
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            // Look for a variation document with matching parent ID and variation name
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Check if this is a variation document that matches our variation
                    if doc.isVariation && doc.parentVariationId == document.id {
                        // Check if document title or another identifier matches the variation name
                        if doc.title == variation.name || 
                           (doc.title.isEmpty && variation.name.contains("Variation")) {
                            // Switch to the variation document
                            DispatchQueue.main.async {
                                self.document = doc
                                
                                // Post notification that document has loaded
                                NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                                
                                // Close the panel
                                self.activePanel = nil
                            }
                            return
                        }
                    }
                } catch {
                    continue
                }
            }
            
            // If no variation document found, create one
            createVariationDocument(from: variation)
        } catch {
            print("Error loading variation document: \(error)")
        }
    }
    
    private func createVariationDocument(from variation: DocumentVariation) {
        // Create a new document based on the current document for this variation
        var variationDocument = Letterspace_CanvasDocument(
            title: variation.name,
            subtitle: document.subtitle,
            elements: document.elements, // Copy all elements
            id: variation.id.uuidString,
            markers: document.markers,
            series: document.series,
            variations: [], // Variations don't have sub-variations
            isVariation: true,
            parentVariationId: document.id,
            createdAt: variation.createdAt,
            modifiedAt: Date(),
            tags: document.tags,
            isHeaderExpanded: document.isHeaderExpanded,
            isSubtitleVisible: document.isSubtitleVisible,
            links: document.links
        )
        
        // Save the variation document
        variationDocument.save()
        
        // Switch to the variation document
        DispatchQueue.main.async {
            self.document = variationDocument
            
            // Post notification that document has loaded
            NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
            
            // Close the panel
            self.activePanel = nil
        }
    }
    
    private func createNewVariation() {
        // Create a new variation based on the current document
        let newVariation = DocumentVariation(
            id: UUID(),
            name: "Variation \(document.variations.count + 1)",
            documentId: UUID().uuidString, // New document ID for the variation
            parentDocumentId: document.id,
            createdAt: Date(),
            datePresented: nil,
            location: document.variations.first?.location
        )
        
        // Add to current document and save
        document.variations.append(newVariation)
        document.save()
        
        // Create and switch to the new variation document
        createVariationDocument(from: newVariation)
    }
    
    private func openOriginalDocument(parentId: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if doc.id == parentId {
                        DispatchQueue.main.async {
                            self.document = doc
                            
                            // Post notification that document has loaded
                            NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                            
                            // Close the panel
                            self.activePanel = nil
                        }
                        return
                    }
                } catch {
                    continue
                }
            }
        } catch {
            print("Error loading original document: \(error)")
        }
    }
    
    private func getOriginalDocumentTitle(parentId: String) -> String {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return "Original Document"
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if doc.id == parentId {
                        return doc.title.isEmpty ? "Untitled" : doc.title
                    }
                } catch {
                    continue
                }
            }
        } catch {
            // Fall through to default
        }
        
        return "Original Document"
    }
    
    private func syncVariationTitle() {
        // If this is a variation document, update the variation name in the parent document
        guard document.isVariation, let parentId = document.parentVariationId else {
            return
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    var parentDoc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if parentDoc.id == parentId {
                        // Find the variation in the parent document and update its name
                        if let variationIndex = parentDoc.variations.firstIndex(where: { $0.documentId == document.id }) {
                            parentDoc.variations[variationIndex].name = document.title.isEmpty ? "Untitled" : document.title
                            parentDoc.save()
                            print("Updated variation name in parent document to: \(document.title)")
                        }
                        return
                    }
                } catch {
                    continue
                }
            }
        } catch {
            print("Error syncing variation title: \(error)")
        }
    }
    
    private func getVariationDocuments() -> [Letterspace_CanvasDocument] {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        var variationDocs: [Letterspace_CanvasDocument] = []
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Check if this is a variation of the current document
                    if doc.isVariation && doc.parentVariationId == document.id && doc.id != document.id {
                        variationDocs.append(doc)
                    }
                } catch {
                    continue
                }
            }
        } catch {
            // Return empty array on error
        }
        
        return variationDocs.sorted { $0.modifiedAt > $1.modifiedAt } // Most recent first
    }
    
    private func openVariationDocument(_ variationDoc: Letterspace_CanvasDocument) {
        DispatchQueue.main.async {
            self.document = variationDoc
            
            // Post notification that document has loaded
            NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
            
            // Close the panel
            self.activePanel = nil
        }
    }
    
    private func renameVariation(_ variationDoc: Letterspace_CanvasDocument, newName: String) {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Update the variation document itself
        var updatedDoc = variationDoc
        updatedDoc.title = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedDoc.save()
        
        // Update the variation metadata in the parent document
        guard let parentId = variationDoc.parentVariationId else { return }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    var parentDoc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if parentDoc.id == parentId {
                        // Find and update the variation in the parent document
                        if let variationIndex = parentDoc.variations.firstIndex(where: { $0.documentId == variationDoc.id }) {
                            parentDoc.variations[variationIndex].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            parentDoc.save()
                        }
                        break
                    }
                } catch {
                    continue
                }
            }
        } catch {
            print("Error updating parent document: \(error)")
        }
        
        // If we're currently viewing this variation, update the current document
        if document.id == variationDoc.id {
            document.title = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            document.save()
        }
    }
    
    private func deleteVariation(_ variationDoc: Letterspace_CanvasDocument) {
        // Delete the variation document file
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        let documentPath = appDirectory.appendingPathComponent("\(variationDoc.id).canvas")
        
        do {
            if FileManager.default.fileExists(atPath: documentPath.path) {
                try FileManager.default.removeItem(at: documentPath)
                print("Deleted variation document file: \(variationDoc.id).canvas")
            }
        } catch {
            print("Error deleting variation document file: \(error)")
        }
        
        // Remove the variation from the parent document's variations array
        guard let parentId = variationDoc.parentVariationId else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    var parentDoc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if parentDoc.id == parentId {
                        // Remove the variation from the parent document
                        parentDoc.variations.removeAll { $0.documentId == variationDoc.id }
                        parentDoc.save()
                        break
                    }
                } catch {
                    continue
                }
            }
        } catch {
            print("Error updating parent document: \(error)")
        }
        
        // If we're currently viewing the deleted variation, switch to the parent document
        if document.id == variationDoc.id {
            openOriginalDocument(parentId: parentId)
        }
    }
    
    private func translateDocument() {
        // Show translation modal
        showTranslationModal = true
        activePanel = nil
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        // Search through document elements
        var results: [(text: String, lineNumber: Int)] = []
        var lineNumber = 1
        
        for element in document.elements {
            if element.type == .textBlock || element.type == .header || element.type == .subheader || element.type == .title {
                let lines = element.content.components(separatedBy: CharacterSet.newlines)
                for line in lines {
                    if line.localizedCaseInsensitiveContains(searchText) {
                        results.append((text: line.trimmingCharacters(in: .whitespaces), lineNumber: lineNumber))
                    }
                    lineNumber += 1
                }
            }
        }
        
        searchResults = results
    }
    
    private func jumpToLine(_ lineNumber: Int) {
        // Post notification to jump to specific line in the document
        NotificationCenter.default.post(
            name: .jumpToLine,
            object: nil,
            userInfo: ["lineNumber": lineNumber, "documentId": document.id]
        )
        activePanel = nil
    }
    
    // MARK: - Tool Panel for specific tool
    @ViewBuilder
    private func toolPanel(for toolType: ToolType) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: toolType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                
                Text(toolType.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activePanel = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(theme.secondary.opacity(0.1)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .foregroundStyle(theme.secondary.opacity(0.2))
            
            // Content for specific tool
            ScrollView {
                toolContent(for: toolType)
                    .padding(16)
            }
            .frame(maxHeight: 500)
        }
        .frame(width: 320, alignment: .leading)
        .background(
            // Glassmorphism effect for panel (matching toolbar)
            ZStack {
                // Base blur
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.background.opacity(0.3),
                        theme.background.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            // Border
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: -4, y: 0)
    }
    
    @ViewBuilder
    private func toolContent(for toolType: ToolType) -> some View {
        switch toolType {
        case .details:
            detailsContent
        case .series:
            seriesContent
        case .tags:
            tagsContent
        case .variations:
            variationsContent
        case .bookmarks:
            bookmarksContent
        case .search:
            searchContent
        }
    }
    
    // MARK: - Tool Content Views
    @State private var isSubtitleVisible: Bool = true
    @State private var isHeaderExpanded: Bool = false
    @State private var location: String = ""
    @State private var showPresentationManager = false
    @State private var locationSearchText: String = ""
    @FocusState private var isLocationFocused: Bool
    
    private var detailsContent: some View {
        VStack(spacing: 8) {
            // Document name (title)
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondary)
                TextField("Untitled", text: Binding(
                    get: { document.title },
                    set: { newValue in
                        document.title = newValue
                        document.save()
                    }
                ))
                .font(.system(size: 13, weight: .semibold))
                .textFieldStyle(.plain)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                )
            }
            
            // Subtitle (if visible)
            if isSubtitleVisible {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subtitle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.secondary)
                    TextField("Add a subtitle", text: Binding(
                        get: { document.subtitle },
                        set: { newValue in
                            document.subtitle = newValue
                            document.save()
                        }
                    ))
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    )
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            // Document Calendar
            VStack(alignment: .leading, spacing: 4) {
                Text("Document Calendar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondary)
                Button(action: {
                    showPresentationManager = true
                }) {
                    Text(getPresentationText())
                        .font(.system(size: 13))
                        .foregroundColor(theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                        )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showPresentationManager) {
                    PresentationManager(document: document, isPresented: $showPresentationManager)
                        .presentationBackground(.clear)
                        .presentationBackgroundInteraction(.enabled)
                }
            }
            
            // Location
            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondary)
                
                ZStack(alignment: .topLeading) {
                                    TextField("Add location", text: $locationSearchText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    )
                    .focused($isLocationFocused)
                    .onSubmit {
                        saveLocationToDocument()
                    }
                    .onChange(of: isLocationFocused) { oldValue, newValue in
                        if !newValue && !locationSearchText.isEmpty {
                            // Field lost focus, save the location
                            saveLocationToDocument()
                        }
                    }
                    
                    // Location suggestions dropdown
                    if isLocationFocused && !matchingLocations.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(matchingLocations.prefix(5), id: \.self) { location in
                                Button(action: {
                                    // Set the location
                                    locationSearchText = location
                                    saveLocationToDocument()
                                    isLocationFocused = false
                                }) {
                                    HStack {
                                        Image(systemName: "location")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.secondary)
                                        
                                        Text(location)
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                if location != matchingLocations.prefix(5).last {
                                    Divider()
                                }
                            }
                        }
                        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                        .cornerRadius(6)
                        .shadow(radius: 4)
                        .offset(y: 36)
                        .zIndex(1)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Document Options
            VStack(spacing: 12) {
                Text("Sections")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Header Image Toggle
                HStack {
                    Text("Header Image")
                        .font(.system(size: 13))
                        .foregroundColor(theme.primary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.isHeaderExpanded },
                        set: { newValue in
                            document.isHeaderExpanded = newValue
                            document.save()
                        }
                    ))
                    .scaleEffect(0.8)
                }
                
                // Subtitle Toggle
                HStack {
                    Text("Subtitle")
                        .font(.system(size: 13))
                        .foregroundColor(theme.primary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.isSubtitleVisible },
                        set: { newValue in
                            document.isSubtitleVisible = newValue
                            isSubtitleVisible = newValue
                            document.save()
                        }
                    ))
                    .scaleEffect(0.8)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Word and Character Count
                let textContent = document.elements.compactMap { element in
                    if element.type == .textBlock || element.type == .header || element.type == .subheader || element.type == .title {
                        return element.content
                    }
                    return nil
                }.joined(separator: " ")
                
                let words = textContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                let wordCount = words.count
                let characterCount = textContent.count
                
                HStack {
                    Text("Word Count")
                        .font(.system(size: 13))
                        .foregroundColor(theme.primary)
                    Spacer()
                    Text("\(wordCount)")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondary)
                }
                
                HStack {
                    Text("Character Count")
                        .font(.system(size: 13))
                        .foregroundColor(theme.primary)
                    Spacer()
                    Text("\(characterCount)")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondary)
                }
            }
        }
        .onAppear {
            isSubtitleVisible = document.isSubtitleVisible
            isHeaderExpanded = document.isHeaderExpanded
            // Initialize location search text with current document location
            locationSearchText = document.variations.first?.location ?? ""
        }
    }
    
    @State private var seriesSearchText: String = ""
    @State private var seriesDocuments: [(title: String, date: String, isActive: Bool)] = []
    @FocusState private var isSeriesSearchFocused: Bool
    @State private var allSeries: [String] = []
    
    private var seriesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Add to series
            VStack(alignment: .leading, spacing: 8) {
                Text("Add to Series")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.secondary)
                
                ZStack(alignment: .topLeading) {
                    TextField("Search or create new series", text: $seriesSearchText)
                        .font(.system(size: 13))
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                        )
                        .focused($isSeriesSearchFocused)
                        .onSubmit {
                            if !seriesSearchText.isEmpty {
                                addToSeries(seriesSearchText)
                            }
                        }
                    
                    // Series suggestions dropdown
                    if isSeriesSearchFocused && !matchingSeries.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(matchingSeries.prefix(5), id: \.self) { seriesName in
                                Button(action: {
                                    addToSeries(seriesName)
                                }) {
                                    HStack {
                                        Image(systemName: "folder")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.secondary)
                                        
                                        Text(seriesName)
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                if seriesName != matchingSeries.prefix(5).last {
                                    Divider()
                                }
                            }
                        }
                        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                        .cornerRadius(6)
                        .shadow(radius: 4)
                        .offset(y: 36)
                        .zIndex(1)
                    }
                }
            }
            
            // Current series (if any)
            if let currentSeries = document.series {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Series")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    HStack {
                        Text(currentSeries.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            document.series = nil
                            document.save()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(theme.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.accent.opacity(0.1))
                    )
                    
                    // Show documents in series
                    if !seriesDocuments.isEmpty {
                        Text("Documents in Series (\(seriesDocuments.count))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.secondary)
                            .padding(.top, 8)
                        
                        ForEach(seriesDocuments.prefix(5), id: \.title) { item in
                            Button(action: {
                                if !item.isActive {
                                    openSeriesDocument(title: item.title)
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 13))
                                            .foregroundColor(item.isActive ? theme.accent : theme.primary)
                                            .lineLimit(1)
                                        
                                        Text(item.date)
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if item.isActive {
                                        Text("Current")
                                            .font(.system(size: 10))
                                            .foregroundColor(theme.accent)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(theme.accent.opacity(0.2))
                                            )
                                    }
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(item.isActive ? theme.accent.opacity(0.05) : theme.secondary.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if seriesDocuments.count > 5 {
                            Text("+ \(seriesDocuments.count - 5) more")
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Load series documents and all series when panel opens
            loadSeriesDocuments()
            loadAllSeries()
        }
    }
    
    @State private var tagSearchText: String = ""
    @FocusState private var isTagSearchFocused: Bool
    @State private var allTags: [String] = []
    
    private func loadAllTags() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            allTags = []
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            var tags: Set<String> = []
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Collect tags from all documents
                    if let docTags = doc.tags {
                        for tag in docTags {
                            tags.insert(tag)
                        }
                    }
                } catch {
                    continue // Skip documents that can't be loaded
                }
            }
            
            allTags = Array(tags).sorted()
        } catch {
            allTags = []
        }
    }
    
    private var matchingTags: [String] {
        guard !tagSearchText.isEmpty else { return allTags }
        return allTags.filter { 
            $0.localizedCaseInsensitiveContains(tagSearchText) 
        }
    }
    
    private var tagsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Add tag
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Tag")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.secondary)
                
                ZStack(alignment: .topLeading) {
                    TextField("Type a tag", text: $tagSearchText)
                        .font(.system(size: 13))
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                        )
                        .focused($isTagSearchFocused)
                        .onChange(of: tagSearchText) { oldValue, newValue in
                            if !tagSearchText.isEmpty {
                                isTagSearchFocused = true
                            }
                        }
                        .onSubmit {
                            if !tagSearchText.isEmpty {
                                var updatedTags = document.tags ?? []
                                if !updatedTags.contains(where: { $0.localizedCaseInsensitiveCompare(tagSearchText) == .orderedSame }) {
                                    updatedTags.append(tagSearchText)
                                    document.tags = updatedTags
                                    document.save()
                                }
                                tagSearchText = ""
                                isTagSearchFocused = false
                            }
                        }
                    
                    // Tag suggestions dropdown
                    if isTagSearchFocused && !tagSearchText.isEmpty && !matchingTags.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(matchingTags.prefix(5), id: \.self) { tag in
                                Button(action: {
                                    var updatedTags = document.tags ?? []
                                    if !updatedTags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
                                        updatedTags.append(tag)
                                        document.tags = updatedTags
                                        document.save()
                                    }
                                    tagSearchText = ""
                                    isTagSearchFocused = false
                                }) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 6, height: 6)
                                        
                                        Text(tag)
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                if tag != matchingTags.prefix(5).last {
                                    Divider()
                                }
                            }
                        }
                        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                        .cornerRadius(6)
                        .shadow(radius: 4)
                        .offset(y: 36)
                        .zIndex(1)
                    }
                }
            }
            
            // Current tags
            if let tags = document.tags, !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Tags")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            
                            Text(tag)
                                .font(.system(size: 13))
                                .foregroundColor(theme.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                var updatedTags = document.tags ?? []
                                updatedTags.removeAll { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }
                                document.tags = updatedTags
                                document.save()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.secondary.opacity(0.1))
                        )
                    }
                }
            }
        }
        .onAppear {
            loadAllTags()
        }
    }
    
    private var variationsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Show original document section - different behavior if this IS a variation
            originalDocumentSection
            
            // Show existing variations
            existingVariationsSection
            
            // Create new variation
            createVariationButton
        }
    }
    
    private var originalDocumentSection: some View {
        Group {
            if document.isVariation, let parentId = document.parentVariationId {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    Button(action: {
                        openOriginalDocument(parentId: parentId)
                    }) {
                        HStack {
                            Text(getOriginalDocumentTitle(parentId: parentId))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(theme.primary)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 11))
                                .foregroundColor(theme.accent)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.secondary.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // This is the original document
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    HStack {
                        Text(document.title.isEmpty ? "Untitled" : document.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primary)
                        
                        Spacer()
                        
                        Text("Current")
                            .font(.system(size: 11))
                            .foregroundColor(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.accent.opacity(0.2))
                            )
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.secondary.opacity(0.1))
                    )
                }
            }
        }
    }
    
    private var existingVariationsSection: some View {
        Group {
            if !getVariationDocuments().isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Variations (\(getVariationDocuments().count))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    ForEach(getVariationDocuments().prefix(3), id: \.id) { variationDoc in
                        variationDocumentRow(variationDoc)
                    }
                    
                    if getVariationDocuments().count > 3 {
                        Text("+ \(getVariationDocuments().count - 3) more")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    private func variationDocumentRow(_ variationDoc: Letterspace_CanvasDocument) -> some View {
        HStack {
            // Main variation content - clickable
            Button(action: {
                openVariationDocument(variationDoc)
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(variationDoc.title.isEmpty ? "Untitled" : variationDoc.title)
                            .font(.system(size: 13))
                            .foregroundColor(theme.primary)
                        
                        Spacer()
                        
                        // Show variation indicator
                        Text("Variation")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(theme.secondary.opacity(0.1))
                            )
                    }
                    
                    HStack {
                        Text(formatDate(variationDoc.modifiedAt))
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondary)
                        
                        Text("• \(variationDoc.elements.count) elements")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // 3-dot menu button - separate from main content
            variationMenuButton(variationDoc)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.secondary.opacity(0.05))
        )
    }
    
    private func variationMenuButton(_ variationDoc: Letterspace_CanvasDocument) -> some View {
        Button(action: {
            selectedVariationForMenu = variationDoc
            activeVariationMenuId = variationDoc.id
        }) {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14))
                .foregroundColor(theme.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding<Bool>(
            get: { activeVariationMenuId == variationDoc.id },
            set: { if !$0 { activeVariationMenuId = nil } }
        ), attachmentAnchor: .point(.center)) {
            VStack(spacing: 0) {
                Button(action: {
                    activeVariationMenuId = nil
                    renameText = variationDoc.title
                    showRenameAlert = true
                }) {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                        
                        Text("Rename")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                
                Button(action: {
                    activeVariationMenuId = nil
                    deleteVariation(variationDoc)
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        
                        Text("Delete")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(width: 150)
                                    .background(popoverBackgroundColor)
            .cornerRadius(8)
            .presentationCompactAdaptation(.popover)
        }
    }
    
    private var createVariationButton: some View {
        VStack(spacing: 12) {
            // Create new variation
            Button(action: {
                createNewVariation()
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                        .foregroundColor(theme.accent)
                    
                    Text("Create New Variation")
                        .font(.system(size: 13))
                        .foregroundColor(theme.accent)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Translate feature
            Button(action: {
                translateDocument()
            }) {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(theme.accent)
                    
                    Text("Translate Document")
                        .font(.system(size: 13))
                        .foregroundColor(theme.accent)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
                .onChange(of: document.title) { oldValue, newValue in
            // When the title changes, sync it to the parent document if this is a variation
            if document.isVariation {
                syncVariationTitle()
            }
        }
        .alert("Rename Variation", isPresented: $showRenameAlert) {
            TextField("Variation name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let variation = selectedVariationForMenu {
                    renameVariation(variation, newName: renameText)
                }
            }
                 } message: {
             Text("Enter a new name for this variation")
         }
     }
     

    
    private var bookmarksContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Show existing bookmarks
            if !document.markers.filter({ $0.type == "bookmark" }).isEmpty {
                let bookmarks = document.markers.filter({ $0.type == "bookmark" }).sorted(by: { $0.position < $1.position })
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bookmarks (\(bookmarks.count))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    ForEach(bookmarks.prefix(5), id: \.id) { bookmark in
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            
                            Text(bookmark.title.isEmpty ? "Bookmark" : bookmark.title)
                                .font(.system(size: 13))
                                .foregroundColor(theme.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("Line \(bookmark.position)")
                                .font(.system(size: 11))
                                .foregroundColor(theme.secondary)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.secondary.opacity(0.05))
                        )
                        .onTapGesture {
                            // Could implement bookmark navigation here
                        }
                    }
                    
                    if bookmarks.count > 5 {
                        Text("+ \(bookmarks.count - 5) more")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondary)
                            .padding(.top, 4)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No bookmarks yet")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondary)
                    
                    Text("Use ⌘+B to add bookmarks while editing")
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.secondary.opacity(0.05))
                )
            }
        }
    }
    
    @State private var searchText: String = ""
    @State private var searchResults: [(text: String, lineNumber: Int)] = []
    @State private var showTranslationModal: Bool = false
    @State private var selectedVariationForMenu: Letterspace_CanvasDocument?
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var activeVariationMenuId: String?
    
    private var searchContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Document search
            VStack(alignment: .leading, spacing: 8) {
                Text("Search Document")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.secondary)
                
                TextField("Search in document", text: $searchText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    )
                    .onChange(of: searchText) { oldValue, newValue in
                        performSearch()
                    }
                    .onSubmit {
                        performSearch()
                    }
                
                // Show search results
                if !searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(searchResults.count) results")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondary)
                        
                        ForEach(searchResults.prefix(5), id: \.lineNumber) { result in
                            Button(action: {
                                jumpToLine(result.lineNumber)
                            }) {
                                HStack {
                                    Text("Line \(result.lineNumber)")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.secondary)
                                        .frame(width: 50, alignment: .leading)
                                    
                                    Text(result.text)
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(theme.secondary.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if searchResults.count > 5 {
                            Text("+ \(searchResults.count - 5) more results")
                                .font(.system(size: 11))
                                .foregroundColor(theme.secondary)
                                .padding(.top, 2)
                        }
                    }
                }
            }
            
            // Quick search options
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Actions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.secondary)
                
                Button(action: {
                    // Close this panel first
                    activePanel = nil
                    
                    // Trigger find and replace functionality
                    #if os(macOS)
                    DispatchQueue.main.async {
                        // Trigger Command+F to open the find interface
                        let keyCode: CGKeyCode = 3 // F key
                        let source = CGEventSource(stateID: .hidSystemState)
                        let event1 = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                        let event2 = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                        
                        event1?.flags = .maskCommand
                        event2?.flags = .maskCommand
                        
                        event1?.post(tap: .cghidEventTap)
                        event2?.post(tap: .cghidEventTap)
                    }
                    #endif
                }) {
                    HStack {
                        Image(systemName: "textformat")
                            .font(.system(size: 14))
                            .foregroundColor(theme.accent)
                            .frame(width: 20)
                        
                        Text("Find & Replace")
                            .font(.system(size: 13))
                            .foregroundColor(theme.primary)
                        
                        Spacer()
                        
                        Text("⌘F")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.secondary.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Helper Components
struct ToolSection<Content: View>: View {
    let title: String
    let content: Content
    
    @Environment(\.themeColors) var theme
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: 4) {
                content
            }
        }
    }
}

struct ToolButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    @Environment(\.themeColors) var theme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? theme.accent.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0) { } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
} 