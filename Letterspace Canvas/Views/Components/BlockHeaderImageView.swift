import SwiftUI

struct BlockHeaderImageView: View {
    let imagePath: String
    let documentId: String
    @Environment(\.themeColors) var theme
    #if os(macOS)
    @State private var image: NSImage?
    #elseif os(iOS)
    @State private var image: UIImage?
    #endif
    
    var body: some View {
        Group {
            if let image = image {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                #elseif os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                #endif
            } else {
                Rectangle()
                    .fill(theme.surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundColor(theme.secondary)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard !imagePath.isEmpty,
              let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        // First try to get the image from cache
        let cacheKey = "\(documentId)_\(imagePath)"
        
        #if os(macOS)
        if let cachedImage = ImageCache.shared.image(for: cacheKey) as? NSImage {
            image = cachedImage
            return
        }
        #elseif os(iOS)
        if let cachedImage = ImageCache.shared.image(for: cacheKey) as? UIImage {
            image = cachedImage
            return
        }
        #endif
        
        // If not in cache, load from disk and cache it
        let documentPath = documentsPath.appendingPathComponent(documentId)
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(imagePath)
        
        #if os(macOS)
        if let loadedImage = NSImage(contentsOf: imageUrl) {
            ImageCache.shared.setImage(loadedImage, for: cacheKey)
            image = loadedImage
        }
        #elseif os(iOS)
        if let loadedImage = UIImage(contentsOfFile: imageUrl.path) {
            ImageCache.shared.setImage(loadedImage, for: cacheKey)
            image = loadedImage
        }
        #endif
    }
} 