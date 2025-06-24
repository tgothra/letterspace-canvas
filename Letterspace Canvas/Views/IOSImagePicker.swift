import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

#if os(iOS)
struct IOSImagePickerController: UIViewRepresentable {
    @Binding var isPresented: Bool
    let sourceRect: CGRect
    let onImagePicked: (URL) -> Void
    let onCancel: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if isPresented && !context.coordinator.hasPresented {
            context.coordinator.hasPresented = true
            presentActionSheet(from: uiView, context: context)
        } else if !isPresented {
            context.coordinator.hasPresented = false
        }
    }
    
    private func presentActionSheet(from view: UIView, context: Context) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Find the top-most view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // Create action sheet with options
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Photo Library option
        let photoLibraryAction = UIAlertAction(title: "Photo Library", style: .default) { _ in
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            topController.present(picker, animated: true)
        }
        
        // Browse Files option
        let browseFilesAction = UIAlertAction(title: "Browse Files", style: .default) { _ in
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .jpeg, .png, .heic, .gif, .webP])
            documentPicker.delegate = context.coordinator
            documentPicker.allowsMultipleSelection = false
            topController.present(documentPicker, animated: true)
        }
        
        // Cancel option
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            DispatchQueue.main.async {
                self.isPresented = false
                self.onCancel()
            }
        }
        
        actionSheet.addAction(photoLibraryAction)
        actionSheet.addAction(browseFilesAction)
        actionSheet.addAction(cancelAction)
        
        // For iPad, set the popover presentation
        if let popoverController = actionSheet.popoverPresentationController {
            // Convert the source rect to the current view's coordinate system
            let convertedRect = view.convert(sourceRect, from: nil)
            popoverController.sourceView = view
            popoverController.sourceRect = convertedRect
            popoverController.permittedArrowDirections = [.up, .down]
        }
        
        topController.present(actionSheet, animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate, UIDocumentPickerDelegate {
        let parent: IOSImagePickerController
        var hasPresented = false
        
        init(_ parent: IOSImagePickerController) {
            self.parent = parent
        }
        
        // MARK: - PHPickerViewControllerDelegate
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                parent.isPresented = false
                parent.onCancel()
                return
            }
            
            // Load the image from Photos
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                DispatchQueue.main.async {
                    if let url = url, error == nil {
                        // Copy to a temporary location since the provided URL is temporary
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                        do {
                            if let imageData = try? Data(contentsOf: url),
                               let image = UIImage(data: imageData) {
                                // Save as JPEG to ensure compatibility
                                if let jpegData = image.jpegData(compressionQuality: 0.9) {
                                    try jpegData.write(to: tempURL)
                                    self.parent.onImagePicked(tempURL)
                                }
                            }
                        } catch {
                            print("Error processing photo library image: \(error)")
                            self.parent.onCancel()
                        }
                    } else {
                        self.parent.onCancel()
                    }
                    self.parent.isPresented = false
                }
            }
        }
        
        // MARK: - UIDocumentPickerDelegate
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            controller.dismiss(animated: true)
            
            if let url = urls.first {
                parent.onImagePicked(url)
            } else {
                parent.onCancel()
            }
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            controller.dismiss(animated: true)
            parent.isPresented = false
            parent.onCancel()
        }
    }
}
#endif 