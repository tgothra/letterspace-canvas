import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct DocumentArea_New: View {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Binding var isHeaderExpanded: Bool
    @Binding var isSubtitleVisible: Bool
    @Binding var documentHeight: CGFloat
    @Binding var viewportHeight: CGFloat
    let isDistractionFreeMode: Bool
    @Binding var viewMode: ViewMode
    let availableWidth: CGFloat
    let onHeaderClick: () -> Void
    @Binding var isSearchActive: Bool
    let shouldPauseHover: Bool
    
    // Image states
    #if os(macOS)
    @State private var headerImage: NSImage?
    #elseif os(iOS)
    @State private var headerImage: UIImage?
    #endif
    @State private var isShowingImagePicker = false
    
    // Scroll tracking
    @State private var scrollOffset: CGFloat = 0
    @State private var headerImageHeight: CGFloat = 400
    
    // UI states
    @State private var isDocumentVisible: Bool = false
    @State private var isEditorFocused: Bool = false
    @State private var isTitleVisible: Bool = true
    @FocusState private var isTitleFocused: Bool
    
    // Constants
    private let paperWidth: CGFloat = 800
    private let collapsedHeaderHeight: CGFloat = 64
    
    private var calculatedHeaderImageHeight: CGFloat {
        if let headerImage = headerImage {
            let size = headerImage.size
            let aspectRatio = size.height / size.width
            return paperWidth * aspectRatio
        }
        return 400 // Default height for placeholder
    }
    
    private var shouldShowStickyHeader: Bool {
        // Show sticky header when scrolled past the header image
        return scrollOffset > headerImageHeight - collapsedHeaderHeight && headerImage != nil && isHeaderExpanded
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Main scrollable content
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Scroll offset tracker
                            GeometryReader { scrollGeo in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self,
                                              value: -scrollGeo.frame(in: .named("scroll")).minY)
                            }
                            .frame(height: 0)
                            
                            // Header image (inline with content)
                            if isHeaderExpanded {
                                headerImageSection
                                    .id("header")
                            }
                            
                            // Document content
                            documentContent(geo: geo)
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                            scrollOffset = value
                        }
                    }
                }
                
                // Sticky header overlay
                if shouldShowStickyHeader {
                    stickyHeader
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            loadHeaderImage()
            withAnimation(.easeOut(duration: 0.6)) {
                isDocumentVisible = true
            }
        }
        .fileImporter(
            isPresented: $isShowingImagePicker,
            allowedContentTypes: [UTType.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageImport(result: result)
        }
    }
    
    // MARK: - Header Image Section
    private var headerImageSection: some View {
        Group {
            if let headerImage = headerImage {
                // Actual image
                #if os(macOS)
                Image(nsImage: headerImage)
                #elseif os(iOS)
                Image(uiImage: headerImage)
                #endif
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: paperWidth, height: calculatedHeaderImageHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onAppear {
                        headerImageHeight = calculatedHeaderImageHeight
                    }
                    .contextMenu {
                        Button("Change Image") {
                            isShowingImagePicker = true
                        }
                        Button("Remove Image", role: .destructive) {
                            removeHeaderImage()
                        }
                    }
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ?
                        Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15) :
                        Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95))
                    .frame(width: paperWidth, height: 300)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                                .padding(.bottom, 8)
                            
                            Text("Add Header Image")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                        }
                    )
                    .onTapGesture {
                        isShowingImagePicker = true
                    }
                    .onAppear {
                        headerImageHeight = 300
                    }
            }
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Sticky Header
    private var stickyHeader: some View {
        ZStack {
            // Blurred background
            if let headerImage = headerImage {
                #if os(macOS)
                Image(nsImage: headerImage)
                #elseif os(iOS)
                Image(uiImage: headerImage)
                #endif
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: collapsedHeaderHeight)
                    .blur(radius: 20)
                    .overlay(Color.black.opacity(0.4))
                    .clipped()
            }
            
            // Content
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if !document.subtitle.isEmpty && isSubtitleVisible {
                        Text(document.subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Options menu
                Menu {
                    Button("Change Image") {
                        isShowingImagePicker = true
                    }
                    Button("Remove Header", role: .destructive) {
                        removeHeaderImage()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: collapsedHeaderHeight)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Document Content
    private func documentContent(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Title section (when no header image)
            if !isHeaderExpanded {
                titleSection
            }
            
            // Document editor
            #if os(macOS)
            DocumentEditorView(document: $document, selectedBlock: .constant(nil))
                .frame(minHeight: geo.size.height)
            #elseif os(iOS)
            IOSDocumentEditor(document: $document)
                .frame(minHeight: geo.size.height)
            #endif
        }
        .frame(width: paperWidth)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.04),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .opacity(isDocumentVisible ? 1 : 0)
        .offset(y: isDocumentVisible ? 0 : 20)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            TextField("Untitled", text: Binding(
                get: { document.title },
                set: { document.title = $0; document.save() }
            ))
            .font(.system(size: isEditorFocused ? 16 : 48, weight: .bold))
            .textFieldStyle(.plain)
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .focused($isTitleFocused)
            
            // Subtitle
            if isSubtitleVisible {
                TextField("Add a subtitle", text: Binding(
                    get: { document.subtitle },
                    set: { document.subtitle = $0; document.save() }
                ))
                .font(.system(size: isEditorFocused ? 14 : 20, weight: .light))
                .textFieldStyle(.plain)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, isEditorFocused ? 16 : 32)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditorFocused)
    }
    
    // MARK: - Helper Functions
    private func loadHeaderImage() {
        guard let headerElement = document.elements.first(where: { $0.type == .headerImage }),
              !headerElement.content.isEmpty,
              let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else { return }
        
        let documentPath = appDirectory.appendingPathComponent("\(document.id)")
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
        
        #if os(macOS)
        if let image = NSImage(contentsOf: imageUrl) {
            self.headerImage = image
        }
        #elseif os(iOS)
        if let image = UIImage(contentsOfFile: imageUrl.path) {
            self.headerImage = image
        }
        #endif
    }
    
    private func handleImageImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first else { return }
        
        do {
            let imageData = try Data(contentsOf: url)
            let fileName = "\(UUID().uuidString).jpg"
            
            // Save image
            guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else { return }
            let documentPath = appDirectory.appendingPathComponent("\(document.id)")
            let imagesPath = documentPath.appendingPathComponent("Images")
            
            try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
            
            let destinationURL = imagesPath.appendingPathComponent(fileName)
            try imageData.write(to: destinationURL)
            
            // Update document
            if let index = document.elements.firstIndex(where: { $0.type == .headerImage }) {
                document.elements[index].content = fileName
            } else {
                let headerElement = DocumentElement(type: .headerImage, content: fileName)
                document.elements.insert(headerElement, at: 0)
            }
            
            document.save()
            
            // Load the image
            #if os(macOS)
            self.headerImage = NSImage(contentsOf: destinationURL)
            #elseif os(iOS)
            self.headerImage = UIImage(contentsOfFile: destinationURL.path)
            #endif
            
        } catch {
            print("Error handling image: \(error)")
        }
    }
    
    private func removeHeaderImage() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            // Clear image
            self.headerImage = nil
            self.isHeaderExpanded = false
            
            // Update document
            if let index = document.elements.firstIndex(where: { $0.type == .headerImage }) {
                document.elements.remove(at: index)
            }
            document.isHeaderExpanded = false
            document.save()
        }
    }
} 