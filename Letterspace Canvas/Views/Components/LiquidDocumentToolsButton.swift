import SwiftUI

#if os(iOS)
import UIKit
#endif

struct LiquidDocumentToolsButton: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var showToolsSheet = false
    @Binding var document: Letterspace_CanvasDocument
    @Binding var selectedElement: UUID?
    @Binding var scrollOffset: CGFloat
    @Binding var documentHeight: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var viewMode: ViewMode
    @Binding var isHeaderExpanded: Bool
    @Binding var isSubtitleVisible: Bool
    
    var body: some View {
        Button(action: {
            HapticFeedback.safeTrigger(.light)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showToolsSheet = true
            }
        }) {
            // Document tools icon on top of glass
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(.clear)
                        .glassEffect(.regular, in: Circle())
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .frame(width: 64, height: 64) // Same frame as CircularMenuButton
        .contentShape(Circle()) // Better touch detection
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showToolsSheet) {
            DocumentToolsSheet(
                document: $document,
                selectedElement: $selectedElement,
                scrollOffset: $scrollOffset,
                documentHeight: $documentHeight,
                viewportHeight: $viewportHeight,
                viewMode: $viewMode,
                isHeaderExpanded: $isHeaderExpanded,
                isSubtitleVisible: $isSubtitleVisible,
                isPresented: $showToolsSheet
            )
        }
    }
}



struct DocumentToolsSheet: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @Binding var document: Letterspace_CanvasDocument
    @Binding var selectedElement: UUID?
    @Binding var scrollOffset: CGFloat
    @Binding var documentHeight: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var viewMode: ViewMode
    @Binding var isHeaderExpanded: Bool
    @Binding var isSubtitleVisible: Bool
    @Binding var isPresented: Bool
    
    @State private var selectedTool: DocumentTool = .details
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var hoveredToolIndex: Int? = nil
    
    enum DocumentTool: String, CaseIterable {
        case details = "Details"
        case series = "Series"
        case tags = "Tags"
        case variations = "Variations"
        case bookmarks = "Bookmarks"
        case links = "Links"
        
        var icon: String {
            switch self {
            case .details: return "info.circle"
            case .series: return "square.stack.3d.up"
            case .tags: return "tag"
            case .variations: return "square.on.square"
            case .bookmarks: return "bookmark"
            case .links: return "link"
            }
        }
        
        var color: Color {
            switch self {
            case .series: return .blue
            case .tags: return .green
            case .variations: return .purple
            case .bookmarks: return .orange
            case .links: return .pink
            case .details: return .gray
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Beautiful header with liquid design
                VStack(spacing: 16) {
                    // Handle bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 6)
                        .padding(.top, 8)
                    
                    // Document title
                    VStack(spacing: 4) {
                        Text(document.title.isEmpty ? "Untitled Document" : document.title)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(theme.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("Document Tools")
                            .font(.caption)
                            .foregroundColor(theme.secondary)
                    }
                    
                    // Tool selection with liquid morphing
                    LiquidToolSelector(selectedTool: $selectedTool)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .background(
                    Rectangle()
                        .fill(theme.surface)
                        .ignoresSafeArea(edges: .top)
                )
                
                // Content area
                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedTool {
                        case .series:
                            SeriesToolView(document: $document)
                        case .tags:
                            TagsToolView(document: $document)
                        case .variations:
                            VariationsToolView(document: $document)
                        case .bookmarks:
                            BookmarksToolContentView(document: $document)
                        case .links:
                            LinksToolView(document: $document)
                        case .details:
                            DetailsToolView(
                                document: $document,
                                selectedElement: $selectedElement,
                                scrollOffset: $scrollOffset,
                                documentHeight: $documentHeight,
                                viewportHeight: $viewportHeight,
                                viewMode: $viewMode,
                                isHeaderExpanded: $isHeaderExpanded,
                                isSubtitleVisible: $isSubtitleVisible
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Safe area padding
                }
                .background(theme.background)
            }
#if !os(macOS)
            .navigationBarHidden(true)
#endif
        }
        .presentationDragIndicator(.hidden)
        .presentationDetents([.medium, .large])
        .presentationBackground(theme.background)
    }
}

struct LiquidToolSelector: View {
    @Environment(\.themeColors) var theme
    @Binding var selectedTool: DocumentToolsSheet.DocumentTool
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DocumentToolsSheet.DocumentTool.allCases, id: \.self) { tool in
                    toolButton(for: tool)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
    }
    
    private func toolButton(for tool: DocumentToolsSheet.DocumentTool) -> some View {
        let isSelected = selectedTool == tool
        
        return Button(action: {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedTool = tool
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : tool.color)
                
                Text(tool.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : theme.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [tool.color, tool.color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [theme.surface, theme.surface],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? Color.clear : tool.color.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Tool Views (Placeholders - these will use existing RightSidebar components)

struct SeriesToolView: View {
    @Environment(\.themeColors) var theme
    @Binding var document: Letterspace_CanvasDocument
    @State private var seriesSearchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Series Management")
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.primary)
                .padding(.top, 20)
            
            // Current series display
            if let currentSeries = document.series {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Series")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.secondary)
                    
                    HStack {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundColor(.blue)
                        Text(currentSeries.name)
                            .font(.body.weight(.medium))
                            .foregroundColor(theme.primary)
                        
                        Spacer()
                        
                        Button("Remove") {
                            document.series = nil
                            document.save()
                        }
                        .foregroundColor(.red)
                        .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.surface)
                    .cornerRadius(8)
                }
                .padding(.bottom, 16)
            }
            
            // Add to series
            VStack(alignment: .leading, spacing: 8) {
                Text("Add to Series")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.secondary)
                
                TextField("Search or create new series", text: $seriesSearchText)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(theme.surface)
                    .cornerRadius(8)
                    .focused($isSearchFocused)
                    .onSubmit {
                        if !seriesSearchText.isEmpty {
                            document.series = DocumentSeries(
                                id: UUID(),
                                name: seriesSearchText,
                                documents: [document.id],
                                order: 1
                            )
                            document.save()
                            seriesSearchText = ""
                            isSearchFocused = false
                        }
                    }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TagsToolView: View {
    @Environment(\.themeColors) var theme
    @Binding var document: Letterspace_CanvasDocument
    @State private var newTag = ""
    @FocusState private var isTagFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Tags Management")
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.primary)
                .padding(.top, 20)
            
            // Current tags
            if let tags = document.tags, !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Tags")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(theme.primary)
                                
                                Button(action: {
                                    var updatedTags = document.tags ?? []
                                    updatedTags.removeAll { $0 == tag }
                                    document.tags = updatedTags.isEmpty ? nil : updatedTags
                                    document.save()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            
            // Add new tag
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Tag")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.secondary)
                
                TextField("Enter tag name", text: $newTag)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(theme.surface)
                    .cornerRadius(8)
                    .focused($isTagFieldFocused)
                    .onSubmit {
                        if !newTag.isEmpty {
                            var updatedTags = document.tags ?? []
                            if !updatedTags.contains(newTag) {
                                updatedTags.append(newTag)
                            }
                            document.tags = updatedTags
                            document.save()
                            newTag = ""
                            isTagFieldFocused = false
                        }
                    }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VariationsToolView: View {
    @Environment(\.themeColors) var theme
    @Binding var document: Letterspace_CanvasDocument
    @State private var showTranslationModal = false
    
    var currentVariations: [Letterspace_CanvasDocument] {
        // This would need to be implemented to load variations from storage
        // For now, return the document's variations
        return []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Document Variations")
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.primary)
                .padding(.top, 20)
            
            // Original document section
            VStack(alignment: .leading, spacing: 8) {
                Text("Original")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.secondary)
                
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.body.weight(.medium))
                        .foregroundColor(theme.primary)
                    
                    Spacer()
                    
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.surface)
                .cornerRadius(8)
            }
            
            // Variations section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Variations")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.secondary)
                    
                    Spacer()
                    
                    // Translate button
                    Button(action: {
                        showTranslationModal = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text("Translate")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#7662E9"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#7662E9").opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    
                    // New variation button
                    Button(action: {
                        createNewVariation()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                            Text("New")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#22c27d"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#22c27d").opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                if document.variations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 32))
                            .foregroundColor(theme.secondary.opacity(0.5))
                        
                        Text("No variations yet")
                            .font(.body.weight(.medium))
                            .foregroundColor(theme.secondary)
                        
                        Text("Create variations for different audiences or translations")
                            .font(.caption)
                            .foregroundColor(theme.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(document.variations, id: \.id) { variation in
                        VariationRowView(variation: variation, document: $document)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showTranslationModal) {
            // Translation modal would go here
            Text("Translation Modal")
        }
    }
    
    private func createNewVariation() {
        // Implementation for creating new variation
        let newVariation = DocumentVariation(
            id: UUID(),
            name: "New Variation",
            documentId: UUID().uuidString,
            parentDocumentId: document.id,
            createdAt: Date()
        )
        
        var updatedDoc = document
        updatedDoc.variations.append(newVariation)
        document = updatedDoc
        document.save()
    }
}

struct VariationRowView: View {
    @Environment(\.themeColors) var theme
    let variation: DocumentVariation
    @Binding var document: Letterspace_CanvasDocument
    
    var body: some View {
        HStack {
            Image(systemName: "doc.on.doc")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(variation.name)
                    .font(.body.weight(.medium))
                    .foregroundColor(theme.primary)
                
                if let date = variation.datePresented {
                    Text("Presented \(date, style: .date)")
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                } else {
                    Text("Created \(variation.createdAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                // Navigate to variation
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surface)
        .cornerRadius(8)
    }
}

struct BookmarksToolContentView: View {
    @Environment(\.themeColors) var theme
    @Binding var document: Letterspace_CanvasDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Bookmarks")
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.primary)
                .padding(.top, 20)
            
            // Bookmarks list - using same logic as right sidebar
            let bookmarkedMarkers = document.markers.filter { $0.type == "bookmark" }
            
            if bookmarkedMarkers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 48))
                        .foregroundColor(theme.secondary.opacity(0.5))
                    
                    Text("No bookmarks yet")
                        .font(.headline)
                        .foregroundColor(theme.secondary)
                    
                    Text("Add bookmarks while reading to quickly return to important sections")
                        .font(.body)
                        .foregroundColor(theme.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(bookmarkedMarkers, id: \.id) { bookmark in
                            BookmarkRowView(bookmark: bookmark, document: $document)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LinksToolView: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Binding var document: Letterspace_CanvasDocument
    @State private var newLinkTitle = ""
    @State private var newLinkURL = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isURLFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Links Management")
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.primary)
                .padding(.top, 20)
            
            // Add new link section
            VStack(alignment: .leading, spacing: 8) {
                Text("Add New Link")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.secondary)
                
                TextField("Link Title", text: $newLinkTitle)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(12)
                    .background(theme.surface)
                    .cornerRadius(8)
                    .focused($isTitleFocused)
                    .onSubmit {
                        if !newLinkTitle.isEmpty && newLinkURL.isEmpty {
                            isURLFocused = true
                        } else if !newLinkTitle.isEmpty && !newLinkURL.isEmpty {
                            addLink()
                        }
                    }
                
                TextField("Link URL", text: $newLinkURL)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(12)
                    .background(theme.surface)
                    .cornerRadius(8)
                    .focused($isURLFocused)
                    .onSubmit {
                        if !newLinkTitle.isEmpty && !newLinkURL.isEmpty {
                            addLink()
                        }
                    }
                
                Button(action: addLink) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Link")
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(newLinkTitle.isEmpty || newLinkURL.isEmpty)
                .opacity(newLinkTitle.isEmpty || newLinkURL.isEmpty ? 0.5 : 1.0)
            }
            
            Divider()
            
            // Links list
            VStack(alignment: .leading, spacing: 8) {
                Text("Attached Links")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.secondary)
                
                if document.links.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.system(size: 32))
                            .foregroundColor(theme.secondary.opacity(0.5))
                        
                        Text("No links attached yet")
                            .font(.body.weight(.medium))
                            .foregroundColor(theme.secondary)
                        
                        Text("Add links to reference materials, websites, or related content")
                            .font(.caption)
                            .foregroundColor(theme.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(document.links) { link in
                                LinkRowView(link: link, document: $document)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func addLink() {
        guard !newLinkTitle.isEmpty, !newLinkURL.isEmpty else { return }
        
        let newLink = DocumentLink(
            id: UUID().uuidString,
            title: newLinkTitle,
            url: newLinkURL,
            createdAt: Date()
        )
        
        var updatedDoc = document
        updatedDoc.links.append(newLink)
        document = updatedDoc
        document.save()
        
        // Clear input fields
        newLinkTitle = ""
        newLinkURL = ""
        isTitleFocused = false
        isURLFocused = false
    }
}

struct LinkRowView: View {
    @Environment(\.themeColors) var theme
    let link: DocumentLink
    @Binding var document: Letterspace_CanvasDocument
    
    var body: some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(link.title)
                    .font(.body.weight(.medium))
                    .foregroundColor(theme.primary)
                    .lineLimit(1)
                
                Text(link.url)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    if let url = URL(string: link.url) {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 16))
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    removeLink(link)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surface)
        .cornerRadius(8)
    }
    
    private func removeLink(_ link: DocumentLink) {
        var updatedDoc = document
        updatedDoc.links.removeAll { $0.id == link.id }
        document = updatedDoc
        document.save()
    }
}

struct DetailsToolView: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Binding var document: Letterspace_CanvasDocument
    @Binding var selectedElement: UUID?
    @Binding var scrollOffset: CGFloat
    @Binding var documentHeight: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var viewMode: ViewMode
    @Binding var isHeaderExpanded: Bool
    @Binding var isSubtitleVisible: Bool
    
    @State private var locationSearchText = ""
    @State private var showPresentationManager = false
    @FocusState private var isLocationFocused: Bool
    
    var matchingLocations: [String] {
        // This would be populated from saved locations
        ["Main Sanctuary", "Youth Chapel", "Conference Room A", "Outdoor Pavilion"]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Document Details")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(theme.primary)
                    .padding(.top, 20)
                
                // Title Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.secondary)
                    
                    TextField("Untitled", text: Binding(
                        get: { document.title },
                        set: { newValue in
                            document.title = newValue
                            document.save()
                        }
                    ))
                    .font(.body.weight(.semibold))
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(theme.surface)
                    .cornerRadius(8)
                }
                
                // Subtitle Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Subtitle")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(theme.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSubtitleVisible.toggle()
                            }
                        }) {
                            Text(isSubtitleVisible ? "Hide" : "Show")
                                .font(.caption.weight(.medium))
                                .foregroundColor(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if isSubtitleVisible {
                        TextField("Add a subtitle", text: Binding(
                            get: { document.subtitle },
                            set: { newValue in
                                document.subtitle = newValue
                                document.save()
                            }
                        ))
                        .font(.body)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(theme.surface)
                        .cornerRadius(8)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }
                }
                
                // Presentation Management
                VStack(alignment: .leading, spacing: 8) {
                    Text("Presentation Schedule")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.secondary)
                    
                    Button(action: {
                        showPresentationManager = true
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text(getPresentationText())
                                .font(.body)
                                .foregroundColor(theme.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(theme.secondary)
                        }
                        .padding(12)
                        .background(theme.surface)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Location Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        TextField("Add location", text: $locationSearchText)
                            .font(.body)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(theme.surface)
                            .cornerRadius(8)
                            .focused($isLocationFocused)
                            .onSubmit {
                                saveLocationToDocument()
                            }
                            .onChange(of: isLocationFocused) { oldValue, newValue in
                                if !newValue && !locationSearchText.isEmpty {
                                    saveLocationToDocument()
                                }
                            }
                        
                        // Location suggestions dropdown
                        if isLocationFocused && !matchingLocations.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(matchingLocations.prefix(5), id: \.self) { location in
                                    Button(action: {
                                        locationSearchText = location
                                        saveLocationToDocument()
                                        isLocationFocused = false
                                    }) {
                                        HStack {
                                            Image(systemName: "location")
                                                .font(.system(size: 12))
                                                .foregroundColor(theme.secondary)
                                            
                                            Text(location)
                                                .font(.body)
                                                .foregroundColor(theme.primary)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if location != matchingLocations.prefix(5).last {
                                        Divider()
                                    }
                                }
                            }
                            .background(theme.surface)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .offset(y: 48)
                            .zIndex(1)
                        }
                    }
                }
                
                Divider()
                
                // Document Statistics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Document Statistics")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.secondary)
                    
                    VStack(spacing: 8) {
                        StatRow(label: "Elements", value: "\(document.elements.count)")
                        StatRow(label: "Bookmarks", value: "\(document.markers.filter { $0.type == "bookmark" }.count)")
                        StatRow(label: "Links", value: "\(document.links.count)")
                        StatRow(label: "Created", value: document.createdAt.formatted(date: .abbreviated, time: .omitted))
                        StatRow(label: "Modified", value: document.modifiedAt.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                
                // Header Expansion Control
                VStack(alignment: .leading, spacing: 8) {
                    Text("Header Display")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.secondary)
                    
                    Toggle("Expanded Header", isOn: Binding(
                        get: { isHeaderExpanded },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isHeaderExpanded = newValue
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showPresentationManager) {
            // Presentation manager would go here
            Text("Presentation Manager")
        }
    }
    
    private func getPresentationText() -> String {
        // This would check for scheduled presentations
        return "Schedule presentation..."
    }
    
    private func saveLocationToDocument() {
        if !locationSearchText.isEmpty {
            // Save location to document metadata
            var updatedDoc = document
            if updatedDoc.metadata == nil {
                updatedDoc.metadata = [:]
            }
            updatedDoc.metadata?["location"] = locationSearchText
            document = updatedDoc
            document.save()
        }
    }
}

struct StatRow: View {
    @Environment(\.themeColors) var theme
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(theme.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surface.opacity(0.5))
        .cornerRadius(6)
    }
}

struct BookmarksSheet: View {
    @Environment(\.themeColors) var theme
    @Environment(\.dismiss) var dismiss
    @Binding var document: Letterspace_CanvasDocument
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 6)
                    .padding(.top, 8)
                
                // Header
                VStack(spacing: 8) {
                    Text("Bookmarks")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(theme.primary)
                    
                    Text("Quick access to your saved locations")
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                }
                
                // Bookmarks list - using same logic as right sidebar
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let bookmarkedMarkers = document.markers.filter { $0.type == "bookmark" }
                        ForEach(bookmarkedMarkers, id: \.id) { bookmark in
                            BookmarkRowView(bookmark: bookmark, document: $document)
                        }
                        
                        if bookmarkedMarkers.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 48))
                                    .foregroundColor(theme.secondary.opacity(0.5))
                                
                                Text("No bookmarks yet")
                                    .font(.headline)
                                    .foregroundColor(theme.secondary)
                                
                                Text("Add bookmarks while reading to quickly return to important sections")
                                    .font(.body)
                                    .foregroundColor(theme.secondary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
#if !os(macOS)
            .navigationBarHidden(true)
#endif
        }
        .presentationDragIndicator(.hidden)
        .presentationDetents([.medium, .large])
        .presentationBackground(theme.background)
    }
}

struct BookmarkRowView: View {
    @Environment(\.themeColors) var theme
    let bookmark: DocumentMarker
    @Binding var document: Letterspace_CanvasDocument
    
    var body: some View {
        HStack(spacing: 12) {
            // Bookmark icon
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
            
            // Bookmark content
            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title.isEmpty ? "Bookmark" : bookmark.title)
                    .font(.body.weight(.medium))
                    .foregroundColor(theme.primary)
                    .lineLimit(2)
                
                Text("Line \(bookmark.position)")
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
            
            Spacer()
            
            // Navigate to bookmark
            Button(action: {
                // TODO: Implement navigation to bookmark position
                HapticFeedback.selection()
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surface)
        )
    }
}

 
