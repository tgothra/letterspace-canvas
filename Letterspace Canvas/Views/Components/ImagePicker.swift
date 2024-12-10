import SwiftUI
import PhotosUI

struct ImagePicker: View {
    @Binding var selectedImage: String
    var aspectRatio: CGSize
    @Environment(\.dismiss) private var dismiss
    @State private var image: NSImage?
    
    init(selectedImage: Binding<String>, aspectRatio: CGSize = CGSize(width: 1920, height: 1080)) {
        self._selectedImage = selectedImage
        self.aspectRatio = aspectRatio
    }
    
    var body: some View {
        VStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400)
            }
            
            Button("Choose Image") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [.image]
                
                if panel.runModal() == .OK {
                    if let url = panel.url {
                        if let loadedImage = NSImage(contentsOf: url) {
                            // Resize image to target aspect ratio
                            let targetSize = calculateTargetSize(for: loadedImage)
                            if let resizedImage = resizeImage(loadedImage, to: targetSize) {
                                image = resizedImage
                                // Save the image to the app's documents directory
                                if let savedPath = saveImage(resizedImage) {
                                    selectedImage = savedPath
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        }
        .padding()
    }
    
    private func calculateTargetSize(for image: NSImage) -> NSSize {
        let imageAspect = image.size.width / image.size.height
        let targetAspect = aspectRatio.width / aspectRatio.height
        
        if imageAspect > targetAspect {
            // Image is wider than target
            let height = aspectRatio.height
            let width = height * imageAspect
            return NSSize(width: width, height: height)
        } else {
            // Image is taller than target
            let width = aspectRatio.width
            let height = width / imageAspect
            return NSSize(width: width, height: height)
        }
    }
    
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    private func saveImage(_ image: NSImage) -> String? {
        let fileName = UUID().uuidString + ".png"
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imagesPath = documentsPath.appendingPathComponent("Images")
            try? FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
            let fileURL = imagesPath.appendingPathComponent(fileName)
            
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let imageRep = NSBitmapImageRep(cgImage: cgImage)
                if let imageData = imageRep.representation(using: .png, properties: [:]) {
                    try? imageData.write(to: fileURL)
                    return fileName
                }
            }
        }
        return nil
    }
}

#Preview {
    ImagePicker(selectedImage: .constant(""))
} 