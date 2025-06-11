import SwiftUI
import PhotosUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ImagePicker: View {
    @Binding var selectedImage: String
    var aspectRatio: CGSize
    @Environment(\.dismiss) private var dismiss
    
    #if os(macOS)
    @State private var image: NSImage?
    #elseif os(iOS)
    @State private var image: UIImage?
    @State private var showPhotoPickerSheet = false
    #endif
    
    init(selectedImage: Binding<String>, aspectRatio: CGSize = CGSize(width: 1920, height: 1080)) {
        self._selectedImage = selectedImage
        self.aspectRatio = aspectRatio
    }
    
    var body: some View {
        VStack {
            #if os(macOS)
            if let स्थानीयImage = image { // Renamed to avoid conflict if image var is added for iOS preview
                Image(nsImage: स्थानीयImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400)
            }
            #elseif os(iOS)
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400)
            }
            #endif
            
            Button("Choose Image") {
                #if os(macOS)
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [UTType.image]
                
                if panel.runModal() == .OK {
                    if let url = panel.url {
                        if let loadedImage = NSImage(contentsOf: url) {
                            let targetSize = calculateTargetSize(for: loadedImage)
                            if let resizedImage = resizeImage(loadedImage, to: targetSize) {
                                self.image = resizedImage // Use self.image to refer to @State
                                if let savedPath = saveImage(resizedImage) {
                                    selectedImage = savedPath
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                #elseif os(iOS)
                showPhotoPickerSheet = true
                #endif
            }
            .padding()
            
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        }
        .padding()
        #if os(iOS)
        .sheet(isPresented: $showPhotoPickerSheet) {
            // Placeholder for PhotoPicker
            PhotoPickerView(selectedUIImage: $image, aspectRatio: aspectRatio) { savedPath in
                if let path = savedPath {
                    selectedImage = path
                    dismiss()
                }
                showPhotoPickerSheet = false // Dismiss sheet regardless of success
            }
        }
        #endif
    }
    
    #if os(macOS)
    private func calculateTargetSize(for image: NSImage) -> NSSize {
        let imageAspect = image.size.width / image.size.height
        let targetAspect = aspectRatio.width / aspectRatio.height
        
        if imageAspect > targetAspect {
            let height = aspectRatio.height
            let width = height * imageAspect
            return NSSize(width: width, height: height)
        } else {
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
            let imagesPath = documentsPath.appendingPathComponent("Images") // Standardized to "Images"
            try? FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
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
    #endif
    // iOS specific image functions will be added later
}

#if os(iOS)
// Placeholder for PhotoPickerView - to be implemented
struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedUIImage: UIImage?
    var aspectRatio: CGSize
    var onComplete: (String?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else {
                parent.onComplete(nil)
                return
            }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    guard let self = self, let uiImage = image as? UIImage else {
                        self?.parent.onComplete(nil)
                        return
                    }
                    
                    // Resize and save the image
                    let targetSize = self.calculateTargetSize(for: uiImage)
                    if let resizedImage = self.resizeImage(uiImage, to: targetSize) {
                        if let savedPath = self.saveImage(resizedImage) {
                            // Update the binding on the main thread
                            DispatchQueue.main.async {
                                self.parent.selectedUIImage = resizedImage
                                self.parent.onComplete(savedPath)
                            }
                            return
                        }
                    }
                    // If resize/save fails
                    DispatchQueue.main.async {
                       self.parent.onComplete(nil)
                    }
                }
            } else {
                 DispatchQueue.main.async {
                    self.parent.onComplete(nil)
                 }
            }
        }
        
        // iOS specific image functions - implementations needed
        private func calculateTargetSize(for image: UIImage) -> CGSize {
            let imageAspect = image.size.width / image.size.height
            let targetAspect = parent.aspectRatio.width / parent.aspectRatio.height
            
            var newSize: CGSize
            if imageAspect > targetAspect {
                // Image is wider than target, fit to target height
                newSize = CGSize(width: parent.aspectRatio.height * imageAspect, height: parent.aspectRatio.height)
            } else {
                // Image is taller than target, fit to target width
                newSize = CGSize(width: parent.aspectRatio.width, height: parent.aspectRatio.width / imageAspect)
            }
            // Ensure we don't exceed a max dimension if needed, e.g. max 1920
            let maxWidth: CGFloat = 1920 
            let maxHeight: CGFloat = 1920 
            if newSize.width > maxWidth || newSize.height > maxHeight {
                let scale = min(maxWidth / newSize.width, maxHeight / newSize.height)
                newSize = CGSize(width: newSize.width * scale, height: newSize.height * scale)
            }
            return newSize
        }
        
        private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
            UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
            defer { UIGraphicsEndImageContext() }
            image.draw(in: CGRect(origin: .zero, size: size))
            return UIGraphicsGetImageFromCurrentImageContext()
        }
        
        private func saveImage(_ image: UIImage) -> String? {
            let fileName = UUID().uuidString + ".png"
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
            
            let imagesPath = documentsPath.appendingPathComponent("Images") // Standardized folder name
            do {
                try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
                let fileURL = imagesPath.appendingPathComponent(fileName)
                if let imageData = image.pngData() {
                    try imageData.write(to: fileURL)
                    return fileName
                }
            } catch {
                print("Error saving image: \\(error)")
            }
            return nil
        }
    }
}
#endif

// Remove macOS-only Preview, or make it conditional if needed for both
// #Preview {
//     ImagePicker(selectedImage: .constant(""))
// } 