import SwiftUI
import PhotosUI
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

@available(iOS 26.0, macOS 15.0, *)
struct CleanNativeEditorView: View {
    @Binding var document: Letterspace_CanvasDocument
    let isDistractionFreeMode: Bool

    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    // Floating header state
    @State private var headerImage: PlatformImage? = nil
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var showHeaderImageMenu: Bool = false
    @State private var showPhotosPicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isSubtitleFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // Text editor with scrollable space using safeAreaInset
            TextEditor(text: $attributedText, selection: $selection)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .top, spacing: 0) {
                    // Invisible spacer that creates scrollable space but doesn't block content
                    Color.clear.frame(height: isDistractionFreeMode ? 0 : headerHeight)
                }
                .onAppear(perform: load)
                .onChange(of: attributedText) { _, newValue in
                    save(newValue)
                }
                #if os(iOS)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        iOS26NativeToolbarWrapper(
                            text: $attributedText,
                            selection: $selection
                        )
                    }
                }
                #endif

            // Floating header card (liquid glass)
            if !isDistractionFreeMode {
                FloatingHeaderCard(
                    title: Binding(get: { document.title }, set: { document.title = $0; document.save() }),
                    subtitle: Binding(get: { document.subtitle }, set: { document.subtitle = $0; document.save() }),
                    image: $headerImage,
                    isIcon: {
                        let isIcon = document.elements.first(where: { $0.type == .headerImage })?.content.contains("header_icon_") ?? false
                        print("🔍 CleanNativeEditorView: isIcon = \(isIcon)")
                        if let headerElement = document.elements.first(where: { $0.type == .headerImage }) {
                            print("🔍 CleanNativeEditorView: header content = '\(headerElement.content)'")
                        }
                        return isIcon
                    }(),
                    onRemoveImage: { removeHeaderImage() },
                    photosPickerItem: $photosPickerItem,
                    showHeaderImageMenu: $showHeaderImageMenu,
                    onImagePicked: { img, data in
                        Task { await saveHeaderImageToDocument(img, data: data) }
                    }
                )
                .padding(.horizontal, 6)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard)
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let img = Self.decodeImage(from: data) {
                    headerImage = img
                     await saveHeaderImageToDocument(img, data: data)
                }
            }
        }
        .sheet(isPresented: $showHeaderImageMenu) {
            HeaderImageMenuView(
                onFilesSelected: {
                    showHeaderImageMenu = false
                    // Browse Files - trigger document picker as nested sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showDocumentPicker = true
                    }
                },
                onPhotoLibrarySelected: {
                    showHeaderImageMenu = false
                    // Photo Library - trigger photos picker
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showPhotosPicker = true
                    }
                },
                onIconSelected: { iconName in
                    showHeaderImageMenu = false
                    // Icon selected - create image from SF Symbol with matching color
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Find the color for this icon - using platform-specific colors
                        #if os(iOS)
                        let iconColors: [String: UIColor] = [
                            "book.fill": UIColor.systemIndigo,
                            "cross.fill": UIColor.systemPurple,
                            "heart.fill": UIColor.systemPink,
                            "star.fill": UIColor.systemOrange,
                            "flame.fill": UIColor.systemRed,
                            "leaf.fill": UIColor.systemGreen,
                            "mountain.2.fill": UIColor.systemTeal,
                            "sun.max.fill": UIColor.systemYellow,
                            "moon.fill": UIColor.systemBlue,
                            "hands.sparkles.fill": UIColor.systemMint
                        ]
                        let platformIconColor = iconColors[iconName] ?? UIColor.systemBlue
                        #else
                        let iconColors: [String: NSColor] = [
                            "book.fill": NSColor.systemIndigo,
                            "cross.fill": NSColor.systemPurple,
                            "heart.fill": NSColor.systemPink,
                            "star.fill": NSColor.systemOrange,
                            "flame.fill": NSColor.systemRed,
                            "leaf.fill": NSColor.systemGreen,
                            "mountain.2.fill": NSColor.systemTeal,
                            "sun.max.fill": NSColor.systemYellow,
                            "moon.fill": NSColor.systemBlue,
                            "hands.sparkles.fill": NSColor.systemMint
                        ]
                        let platformIconColor = iconColors[iconName] ?? NSColor.systemBlue
                        #endif
                        
                        if let iconImage = IconToImageConverter.createCircularIconWithPlatformColor(
                            from: iconName,
                            size: CGSize(width: 120, height: 120),
                            backgroundColor: platformIconColor
                        ),
                        let imageData = IconToImageConverter.createImageDataWithPlatformColor(
                            from: iconName,
                            backgroundColor: platformIconColor,
                            isCircular: true
                        ) {
                            headerImage = iconImage
                            Task { await saveHeaderImageToDocument(iconImage, data: imageData, isIcon: true, iconName: iconName) }
                        }
                    }
                },
                onCancel: {
                    showHeaderImageMenu = false
                }
            )
            .presentationDetents([.height(600)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showPhotosPicker) {
            PhotosPickerView(photosPickerItem: $photosPickerItem)
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            print("🔍 File picker result received")
            switch result {
            case .success(let urls):
                print("🔍 File picker success with \(urls.count) URLs")
                guard let url = urls.first else { 
                    print("❌ No URL in file picker result")
                    return 
                }
                print("🔍 Selected file URL: \(url)")
                
                // Load the image data
                DispatchQueue.global(qos: .userInitiated).async {
                    print("🔍 Attempting to load data from URL...")
                    
                    // Start accessing security scoped resource
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if gotAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    do {
                        let data = try Data(contentsOf: url)
                        print("🔍 Successfully loaded \(data.count) bytes")
                        
                        if let img = Self.decodeImage(from: data) {
                            print("🔍 Successfully decoded image")
                            DispatchQueue.main.async {
                                print("🔍 Setting headerImage on main thread")
                                headerImage = img
                                Task { 
                                    print("🔍 Saving image to document...")
                                    await saveHeaderImageToDocument(img, data: data) 
                                    print("🔍 Image save completed")
                                }
                            }
                        } else {
                            print("❌ Failed to decode image from data")
                        }
                    } catch {
                        print("❌ Failed to load data from URL: \(error)")
                    }
                }
            case .failure(let error):
                print("❌ Document picker error: \(error)")
            }
        }
    }

    // MARK: - Cross-platform image helpers
    private static func decodeImage(from data: Data) -> PlatformImage? {
        #if os(iOS)
        return UIImage(data: data)
        #else
        return NSImage(data: data)
        #endif
    }

    private static func pngData(from image: PlatformImage) -> Data? {
        #if os(iOS)
        return image.pngData()
        #else
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
        #endif
    }
    
    private func platformImage(_ image: PlatformImage) -> Image {
        #if os(iOS)
        return Image(uiImage: image)
        #else
        return Image(nsImage: image)
        #endif
    }

    // Returns width/height for the provided platform image. Falls back to 16:9 if size is unavailable.
    private func imageAspectRatio(_ image: PlatformImage) -> CGFloat {
        #if os(iOS)
        let height = image.size.height
        return height > 0 ? (image.size.width / height) : (16.0/9.0)
        #else
        let height = image.size.height
        return height > 0 ? (image.size.width / height) : (16.0/9.0)
        #endif
    }

    private var headerHeight: CGFloat {
        let base: CGFloat = 120
        let internalTextTopPadding: CGFloat = 12 // ensures text starts slightly lower
        return base + internalTextTopPadding // Base height - container will grow dynamically
    }

    private func load() {
        // Load text content
        if let element = document.elements.first(where: { $0.type == .textBlock }) {
            if let data = element.rtfData,
               let decoded = try? JSONDecoder().decode(AttributedString.self, from: data) {
                attributedText = decoded
            } else {
                attributedText = AttributedString(element.content)
            }
        } else {
            attributedText = AttributedString()
        }
        
        // Load existing header image
        loadHeaderImage()
    }
    
    private func loadHeaderImage() {
        // Check if document has a header image element
        if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
           !headerElement.content.isEmpty {
            
            guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
                print("❌ Could not access documents directory for header image")
                return
            }
            
            let documentPath = appDirectory.appendingPathComponent(document.id)
            let imagesPath = documentPath.appendingPathComponent("Images")
            let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
            
            // Load image asynchronously
            Task {
                if let imageData = try? Data(contentsOf: imageUrl),
                   let image = Self.decodeImage(from: imageData) {
                    await MainActor.run {
                        headerImage = image
                        print("✅ Loaded existing header image: \(headerElement.content)")
                    }
                }
            }
        }
    }
    
    private func saveHeaderImageToDocument(_ image: PlatformImage, data: Data, isIcon: Bool = false, iconName: String? = nil) async {
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("❌ Could not access documents directory for header image")
            return
        }
        
        do {
            // Create document image directory if needed
            let documentPath = appDirectory.appendingPathComponent(document.id)
            let imagesPath = documentPath.appendingPathComponent("Images")
            
            if !FileManager.default.fileExists(atPath: imagesPath.path) {
                try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Generate a unique filename with appropriate prefix
            let fileName = isIcon ? "header_icon_\(iconName ?? "unknown")_\(UUID().uuidString).png" : "header_\(UUID().uuidString).png"
            let fileURL = imagesPath.appendingPathComponent(fileName)
            
            // Remove old header image if it exists
            if let oldHeaderElement = document.elements.first(where: { $0.type == .headerImage }),
               !oldHeaderElement.content.isEmpty {
                let oldImageUrl = imagesPath.appendingPathComponent(oldHeaderElement.content)
                if FileManager.default.fileExists(atPath: oldImageUrl.path) {
                    try FileManager.default.removeItem(at: oldImageUrl)
                    print("✅ Removed old header image: \(oldHeaderElement.content)")
                }
            }
            
            // Save new image as PNG
            if let pngData = Self.pngData(from: image) {
                try pngData.write(to: fileURL)
                print("✅ Saved header image to: \(fileURL.path)")
                
                // Update document with header image element
                await MainActor.run {
                    var updatedDoc = document
                    
                    // Add or update the header image element
                    let headerElement = DocumentElement(type: .headerImage, content: fileName)
                    
                    if let index = updatedDoc.elements.firstIndex(where: { $0.type == .headerImage }) {
                        updatedDoc.elements[index] = headerElement
                        print("🔄 Updated existing header image element")
                    } else {
                        updatedDoc.elements.insert(headerElement, at: 0)
                        print("➕ Added new header image element")
                    }
                    
                    // Set proper flags like the old implementation
                    updatedDoc.isHeaderExpanded = true
                    
                    // Set hasHeaderImage in the document metadata
                    if var metadata = updatedDoc.metadata {
                        metadata["hasHeaderImage"] = true
                        updatedDoc.metadata = metadata
                    } else {
                        updatedDoc.metadata = ["hasHeaderImage": true]
                    }
                    
                    // Update the document and save
                    document = updatedDoc
                    document.save()
                    
                    print("✅ Header image saved to document metadata")
                }
            }
        } catch {
            print("❌ Error saving header image: \(error)")
        }
    }
    
    private func removeHeaderImage() {
        // Remove from UI
        headerImage = nil
        
        // Remove from document
        if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
           !headerElement.content.isEmpty {
            
            // Remove image file from disk
            if let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                let documentPath = appDirectory.appendingPathComponent(document.id)
                let imagesPath = documentPath.appendingPathComponent("Images")
                let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
                
                do {
                    if FileManager.default.fileExists(atPath: imageUrl.path) {
                        try FileManager.default.removeItem(at: imageUrl)
                        print("✅ Removed header image file: \(headerElement.content)")
                    }
                } catch {
                    print("❌ Error removing header image file: \(error)")
                }
            }
            
            // Remove from document metadata
            var updatedDoc = document
            updatedDoc.elements.removeAll { $0.type == .headerImage }
            
            // Update metadata
            if var metadata = updatedDoc.metadata {
                metadata["hasHeaderImage"] = false
                updatedDoc.metadata = metadata
            } else {
                updatedDoc.metadata = ["hasHeaderImage": false]
            }
            
            // Update the document
            document = updatedDoc
            document.save()
            
            print("✅ Removed header image from document metadata")
        }
    }

    private func save(_ newValue: AttributedString) {
        var updated = document
        if let idx = updated.elements.firstIndex(where: { $0.type == .textBlock }) {
            var el = updated.elements[idx]
            el.content = String(newValue.characters)
            el.rtfData = (try? JSONEncoder().encode(newValue))
            updated.elements[idx] = el
        } else {
            var el = DocumentElement(type: .textBlock)
            el.content = String(newValue.characters)
            el.rtfData = (try? JSONEncoder().encode(newValue))
            updated.elements.append(el)
        }
        document = updated
        DispatchQueue.global(qos: .utility).async { document.save() }
    }

    private func toggleBold() {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else { return }
        attributedText.transform(updating: &selection) { text in
            let hasBold = text[ranges].runs.contains { run in
                if let f = run.font { return String(describing: f).lowercased().contains("bold") }
                return false
            }
            text[ranges].font = hasBold ? .system(size: 16, weight: .regular) : .system(size: 16, weight: .bold)
        }
    }

    private func toggleItalic() {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else { return }
        attributedText.transform(updating: &selection) { text in
            let hasItalic = text[ranges].runs.contains { run in
                if let f = run.font { return String(describing: f).lowercased().contains("italic") }
                return false
            }
            text[ranges].font = hasItalic ? .system(size: 16, weight: .regular) : .system(size: 16, weight: .regular).italic()
        }
    }

    private func toggleUnderline() {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else { return }
        attributedText.transform(updating: &selection) { text in
            let hasUnderline = text[ranges].runs.contains { $0.underlineStyle == Text.LineStyle.single }
            text[ranges].underlineStyle = hasUnderline ? nil : Text.LineStyle.single
        }
    }
}

// MARK: - Photos Picker View (Direct Access)
@available(iOS 26.0, macOS 15.0, *)
private struct PhotosPickerView: View {
    @Binding var photosPickerItem: PhotosPickerItem?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                    
                    VStack(spacing: 8) {
                        Text("Choose Photo")
                            .font(.title2.bold())
                        Text("Select a photo from your library")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Photo Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #endif
            }
        }
        .onChange(of: photosPickerItem) { _, newItem in
            if newItem != nil {
                dismiss()
            }
        }
    }
}

// MARK: - Floating Header Card
@available(iOS 26.0, macOS 15.0, *)
private struct FloatingHeaderCard: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var image: PlatformImage?
    let isIcon: Bool // Whether the current image is an icon
    let onRemoveImage: () -> Void
    @Binding var photosPickerItem: PhotosPickerItem?
    @Binding var showHeaderImageMenu: Bool
    let onImagePicked: (PlatformImage, Data) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    @Namespace private var imageNamespace
    
    private func platformImage(_ image: PlatformImage) -> Image {
        #if os(iOS)
        return Image(uiImage: image)
        #else
        return Image(nsImage: image)
        #endif
    }
    
    private func decodeImage(from data: Data) -> PlatformImage? {
        #if os(iOS)
        return UIImage(data: data)
        #else
        return NSImage(data: data)
        #endif
    }

    // Compute intrinsic aspect ratio (width/height) for sizing the expanded image
    private func imageAspectRatio(_ image: PlatformImage) -> CGFloat {
        #if os(iOS)
        let height = image.size.height
        return height > 0 ? (image.size.width / height) : (16.0/9.0)
        #else
        let height = image.size.height
        return height > 0 ? (image.size.width / height) : (16.0/9.0)
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Expanded state: Only show the image
                if let image {
                    ZStack(alignment: .topTrailing) {
                        platformImage(image)
                            .resizable()
                            // Use icon-appropriate sizing and content mode
                            .aspectRatio(isIcon ? 1.0 : imageAspectRatio(image), contentMode: isIcon ? .fit : .fit)
                            .frame(maxWidth: isIcon ? 150 : .infinity)
                            .clipShape({
                                print("🔍 FloatingHeaderCard expanded: isIcon = \(isIcon), using \(isIcon ? "Circle" : "RoundedRectangle")")
                                return isIcon ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 14))
                            }())
                            .matchedGeometryEffect(id: "headerImage", in: imageNamespace)
                            #if os(macOS)
                            .onTapGesture {
                                // macOS: Show header image menu when clicking the floating header image
                                print("📸 macOS: User clicked floating header image - showing menu")
                                showHeaderImageMenu = true
                            }
                            #endif
                        
                        // Subtle action buttons overlay
                        HStack(spacing: 8) {
                        #if os(iOS)
                        Button {
                            showHeaderImageMenu = true
                        } label: {
                                Image(systemName: "photo")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                            .buttonStyle(.plain)
                        #else
                        Button {
                            // macOS: Show header image menu instead of direct file picker
                            print("📸 macOS: User clicked floating header button - showing menu")
                            showHeaderImageMenu = true
                        } label: {
                            Image(systemName: "photo")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(.black.opacity(0.6), in: Circle())
                        }
                        .buttonStyle(.plain)
                        #endif
                            
                            Button {
                                onRemoveImage()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                    ))
                }
            } else {
                // Compact state: Show header content
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Title", text: $title)
                            .font(.system(size: 16, weight: .semibold))
                            .textFieldStyle(.plain)
                            .foregroundStyle(.primary)

                        TextField("Subtitle", text: $subtitle)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()

                    // Thumbnail image or photo picker button
                    if let image {
                        Button {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isExpanded = true
                            }
                            
                            // Auto-collapse after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    isExpanded = false
                                }
                            }
                        } label: {
                            platformImage(image)
                                .resizable()
                                .aspectRatio(isIcon ? 1.0 : 16/9, contentMode: isIcon ? .fit : .fill)
                                .frame(width: isIcon ? 50 : 120, height: isIcon ? 50 : 68) // Smaller square for icons, 16:9 for images
                                .clipShape({
                                    print("🔍 FloatingHeaderCard collapsed: isIcon = \(isIcon), using \(isIcon ? "Circle" : "RoundedRectangle")")
                                    return isIcon ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 14))
                                }())
                                .overlay(
                                    Group {
                                        if isIcon {
                                            Circle().stroke(.quaternary, lineWidth: 0.5)
                                        } else {
                                            RoundedRectangle(cornerRadius: 14).stroke(.quaternary, lineWidth: 0.5)
                                        }
                                    }
                                )
                                .matchedGeometryEffect(id: "headerImage", in: imageNamespace)
                        }
                        .buttonStyle(.plain)
                    } else {
                        #if os(iOS)
                        Button {
                            showHeaderImageMenu = true
                        } label: {
                            Image(systemName: "photo.badge.plus")
                                .font(.title)
                                .foregroundStyle(.primary)
                                .frame(width: 120, height: 68) // Match larger 16:9 thumbnail dimensions
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        #else
                        Button {
                            // macOS: Show header image menu instead of direct file picker for placeholder
                            print("📸 macOS: User clicked floating header placeholder - showing menu")
                            showHeaderImageMenu = true
                        } label: {
                            Image(systemName: "photo.badge.plus")
                                .font(.title)
                                .foregroundStyle(.primary)
                                .frame(width: 120, height: 68)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                }
                .padding(.leading, 13) // Added 1 more pt: 12px → 13px
                .padding(.top, 9)      // Added 2 more pts: 7px → 9px
                .padding(.bottom, 9)   // Added 2 more pts: 7px → 9px
                .padding(.trailing, 8) // Added 1 more pt: 7px → 8px
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        )
        .shadow(color: (colorScheme == .dark ? .white.opacity(0.04) : .black.opacity(0.06)), radius: 6, x: 0, y: 4)
    }
}
