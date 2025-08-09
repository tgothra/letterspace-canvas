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
                    onRemoveImage: { removeHeaderImage() },
                    photosPickerItem: $photosPickerItem,
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
    
    private func saveHeaderImageToDocument(_ image: PlatformImage, data: Data) async {
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
            
            // Generate a unique filename
            let fileName = "header_\(UUID().uuidString).png"
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

// MARK: - Floating Header Card
@available(iOS 26.0, macOS 15.0, *)
private struct FloatingHeaderCard: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var image: PlatformImage?
    let onRemoveImage: () -> Void
    @Binding var photosPickerItem: PhotosPickerItem?
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

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Expanded state: Only show the image
                if let image {
                    ZStack(alignment: .topTrailing) {
                        platformImage(image)
                            .resizable()
                            // Fit the image using its intrinsic aspect ratio so the container sizes
                            .aspectRatio(imageAspectRatio(image), contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .matchedGeometryEffect(id: "headerImage", in: imageNamespace)
                        
                        // Subtle action buttons overlay
                        HStack(spacing: 8) {
                        #if os(iOS)
                        PhotosPicker(selection: $photosPickerItem, matching: .images) {
                                Image(systemName: "photo")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                            .buttonStyle(.plain)
                        #else
                        Button {
                            // macOS: open panel fallback for change
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.image]
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url), let img = decodeImage(from: data) {
                                self.image = img
                                onImagePicked(img, data)
                            }
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
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(width: 120, height: 68) // Larger 16:9 ratio (120x68)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(.quaternary, lineWidth: 0.5)
                                )
                                .matchedGeometryEffect(id: "headerImage", in: imageNamespace)
                        }
                        .buttonStyle(.plain)
                    } else {
                        #if os(iOS)
                        PhotosPicker(selection: $photosPickerItem, matching: .images) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title)
                                .foregroundStyle(.primary)
                                .frame(width: 120, height: 68) // Match larger 16:9 thumbnail dimensions
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        #else
                        Button {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.image]
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url), let img = decodeImage(from: data) {
                                image = img
                                onImagePicked(img, data)
                            }
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
