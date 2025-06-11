#if os(macOS)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HeaderImageThumbnail: View {
    let imagePath: String
    let documentId: String
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var image: NSImage?
    @State private var isHovering = false
    @State private var showImageMenu = false
    @Binding var document: Letterspace_CanvasDocument
    
    var body: some View {
        Group {
            if let image = image {
                if image.size.width > 0 && image.size.height > 0 {
                    // Valid image with content
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .overlay(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                colorScheme == .dark
                                                    ? Color.black.opacity(0.5)
                                                    : Color.white.opacity(0.1),
                                                Color.clear
                                            ]),
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                            )
                            .onHover { hovering in
                                // Add small delay before hiding to improve usability
                                if !hovering {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        // Only hide if still not hovering after delay
                                        if !isHovering {
                                            isHovering = hovering
                                        }
                                    }
                                } else {
                                    isHovering = hovering
                                }
                            }
                        
                        // Image management menu
                        if isHovering {
                            Menu {
                                Button(action: {
                                    replaceImage()
                                }) {
                                    Label("Replace Image", systemImage: "photo")
                                }
                                
                                Button(action: {
                                    downloadImage()
                                }) {
                                    Label("Download Image", systemImage: "square.and.arrow.down")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive, action: {
                                    deleteImage()
                                }) {
                                    Label("Delete Image", systemImage: "trash")
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(.sRGB, white: 0.3, opacity: 0.4))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                                        )
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color(.sRGB, white: 0.97, opacity: 1))
                                }
                                .contentShape(Rectangle().size(CGSize(width: 50, height: 50)))
                            }
                            .onHover { hovering in
                                if hovering {
                                    isHovering = true
                                }
                            }
                            .padding(12) // Increased padding for larger hit area
                            .buttonStyle(.plain)
                            .transition(.opacity)
                        }
                    }
                } else {
                    // Empty image fallback
                    headerImagePlaceholder
                }
            } else {
                // Loading state
                Rectangle()
                    .fill(theme.surface)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    // Placeholder for empty or invalid images
    private var headerImagePlaceholder: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(theme.surface)
                .frame(maxWidth: .infinity)
                .overlay(
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(theme.secondary.opacity(0.5))
                        
                        Text("Header Image")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondary.opacity(0.7))
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                )
                .onTapGesture {
                    replaceImage()
                }
                .onHover { hovering in
                    isHovering = hovering
                }
            
            // Image management menu for placeholder too
            if isHovering {
                Menu {
                    Button(action: {
                        replaceImage()
                    }) {
                        Label("Add Image", systemImage: "photo")
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(.sRGB, white: 0.3, opacity: 0.4))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(.sRGB, white: 0.97, opacity: 1))
                    }
                    .contentShape(Rectangle())
                }
                .onHover { hovering in
                    if hovering {
                        isHovering = true
                    }
                }
                .padding(12)
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }
    
    private func loadImage() {
        guard !imagePath.isEmpty,
              let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Empty image path or couldn't access documents directory")
            DispatchQueue.main.async {
                // Set to empty UIImage to prevent infinite spinner
                self.image = NSImage()
            }
            return
        }
        
        // First try to get the image from cache
        let cacheKey = "\(documentId)_\(imagePath)"
        if let cachedImage = ImageCache.shared.image(for: cacheKey) {
            image = cachedImage
            return
        }
        
        // If not in cache, load from disk and cache it
        let documentPath = documentsPath.appendingPathComponent(documentId)
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(imagePath)
        
        // Check if file exists before trying to load
        if !FileManager.default.fileExists(atPath: imageUrl.path) {
            print("⚠️ Image file doesn't exist at path: \(imageUrl.path)")
            DispatchQueue.main.async {
                // Set to empty UIImage to prevent infinite spinner
                self.image = NSImage()
            }
            return
        }
        
        print("🔄 Loading image from path: \(imageUrl.path)")
        
        // Load image asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            if let loadedImage = NSImage(contentsOf: imageUrl) {
                ImageCache.shared.setImage(loadedImage, for: cacheKey)
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.image = loadedImage
                    print("✅ Successfully loaded image: \(cacheKey)")
                }
            } else {
                print("❌ Failed to load image from: \(imageUrl.path)")
                DispatchQueue.main.async {
                    // Set to empty UIImage to prevent infinite spinner
                    self.image = NSImage()
                }
            }
        }
        
        // Set a timeout to prevent infinite spinner
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.image == nil {
                print("⏱️ Image loading timed out for: \(cacheKey)")
                self.image = NSImage()
            }
        }
    }
    
    private func replaceImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.image]
        
        if panel.runModal() == .OK, let url = panel.url {
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            do {
                // Create document image directory if needed
                let documentPath = documentsPath.appendingPathComponent(documentId)
                let imagesPath = documentPath.appendingPathComponent("Images")
                
                if !FileManager.default.fileExists(atPath: imagesPath.path) {
                    try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
                }
                
                // Delete old image if it exists and clear from cache
                let oldImageUrl = imagesPath.appendingPathComponent(imagePath)
                let oldCacheKey = "\(documentId)_\(imagePath)"
                ImageCache.shared.removeImage(for: oldCacheKey)
                
                if FileManager.default.fileExists(atPath: oldImageUrl.path) {
                    try FileManager.default.removeItem(at: oldImageUrl)
                    print("✅ Removed old image file: \(oldImageUrl.path)")
                }
                
                // Generate a unique filename
                let fileName = "header_\(UUID().uuidString).\(url.pathExtension)"
                let fileURL = imagesPath.appendingPathComponent(fileName)
                
                // Copy the image to the document's image directory
                try FileManager.default.copyItem(at: url, to: fileURL)
                print("✅ Copied new image to: \(fileURL.path)")
                
                // Update document with new image path
                var updatedDoc = document
                
                // Update the header image element
                if let index = updatedDoc.elements.firstIndex(where: { $0.type == .headerImage }) {
                    print("🔄 Updating existing header image element")
                    updatedDoc.elements[index].content = fileName
                } else {
                    print("➕ Adding new header image element")
                    let headerElement = DocumentElement(type: .headerImage, content: fileName)
                    updatedDoc.elements.insert(headerElement, at: 0)
                }
                
                // Set proper flags to ensure header image toggle is ON
                updatedDoc.isHeaderExpanded = true
                
                // Set hasHeaderImage in the document metadata
                if var metadata = updatedDoc.metadata {
                    metadata["hasHeaderImage"] = true
                    updatedDoc.metadata = metadata
                } else {
                    updatedDoc.metadata = ["hasHeaderImage": true]
                }
                
                // Update the CanvasDocument
                let canvasDoc = updatedDoc.canvasDocument
                // Set the hasHeaderImage property in canvasDoc metadata
                canvasDoc.metadata.hasHeaderImage = true
                updatedDoc.canvasDocument = canvasDoc
                
                // Save document and update the binding
                document = updatedDoc
                updatedDoc.save()
                
                // Update image in the UI
                if let newImage = NSImage(contentsOf: fileURL) {
                    let newCacheKey = "\(documentId)_\(fileName)"
                    print("🖼️ Caching new image with key: \(newCacheKey)")
                    ImageCache.shared.setImage(newImage, for: newCacheKey)
                    DispatchQueue.main.async {
                        image = newImage
                    }
                } else {
                    print("⚠️ Failed to load new image after replacement")
                }
                
                // Post notification to update document list and the document itself
                NotificationCenter.default.post(
                    name: NSNotification.Name("DocumentDidUpdate"), 
                    object: nil,
                    userInfo: ["documentId": documentId]
                )
                
                // Also post the general list update notification
                NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                
                print("✅ Header image replaced successfully with fileName: \(fileName)")
            } catch {
                print("❌ Error replacing header image: \(error)")
            }
        }
    }
    
    private func downloadImage() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let documentPath = documentsPath.appendingPathComponent(documentId)
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(imagePath)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.image]
        savePanel.nameFieldStringValue = imagePath
        
        if savePanel.runModal() == .OK, let destinationURL = savePanel.url {
            do {
                try FileManager.default.copyItem(at: imageUrl, to: destinationURL)
            } catch {
                print("Error downloading image: \(error)")
            }
        }
    }
    
    private func deleteImage() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            // Remove the image file
            let documentPath = documentsPath.appendingPathComponent(documentId)
            let imagesPath = documentPath.appendingPathComponent("Images")
            let imageUrl = imagesPath.appendingPathComponent(imagePath)
            
            if FileManager.default.fileExists(atPath: imageUrl.path) {
                try FileManager.default.removeItem(at: imageUrl)
            }
            
            // Update document
            var updatedDoc = document
            
            // Update document element
            if let index = updatedDoc.elements.firstIndex(where: { $0.type == .headerImage }) {
                // Just set content to empty but maintain the element's existence
                updatedDoc.elements[index].content = ""
            }
            
            // Set proper flags to disable header image toggle
            updatedDoc.isHeaderExpanded = false
            
            // Update metadata to indicate no header image
            if var metadata = updatedDoc.metadata {
                metadata["hasHeaderImage"] = false
                updatedDoc.metadata = metadata
            } else {
                updatedDoc.metadata = ["hasHeaderImage": false]
            }
            
            // Update the CanvasDocument
            let canvasDoc = updatedDoc.canvasDocument
            canvasDoc.metadata.hasHeaderImage = false
            updatedDoc.canvasDocument = canvasDoc
            
            // Save document and update binding
            document = updatedDoc
            updatedDoc.save()
            
            // Clear the cached image
            ImageCache.shared.removeImage(for: "\(documentId)_\(imagePath)")
            DispatchQueue.main.async {
                image = nil
            }
            
            // Post notification to update the document itself
            NotificationCenter.default.post(
                name: NSNotification.Name("DocumentDidUpdate"), 
                object: nil,
                userInfo: ["documentId": documentId]
            )
            
            // Also post notification to update document list
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
            
            print("✅ Header image deleted successfully")
        } catch {
            print("❌ Error deleting header image: \(error)")
        }
    }
}
#endif
