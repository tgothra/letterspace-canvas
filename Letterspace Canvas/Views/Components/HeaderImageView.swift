import SwiftUI

struct BlockHeaderImageView: View {
    let imagePath: String
    @Environment(\.themeColors) var theme
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
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
        
        let imagesPath = documentsPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(imagePath)
        image = NSImage(contentsOf: imageUrl)
    }
} 