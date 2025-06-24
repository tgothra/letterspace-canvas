import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

#if os(iOS)
struct IOSImagePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let sourceRect: CGRect
    let onImagePicked: (URL) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // Create action sheet with options
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Photo Library option
        let photoLibraryAction = UIAlertAction(title: "Photo Library", style: .default) { _ in
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            viewController.present(picker, animated: true)
        }
        
        // Browse Files option
        let browseFilesAction = UIAlertAction(title: "Browse Files", style: .default) { _ in
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .jpeg, .png, .heic, .gif, .webP])
            documentPicker.delegate = context.coordinator
            documentPicker.allowsMultipleSelection = false
            viewController.present(documentPicker, animated: true)
        }
        
        // Cancel option
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            isPresented = false
            onCancel()
        }
        
        actionSheet.addAction(photoLibraryAction)
        actionSheet.addAction(browseFilesAction)
        actionSheet.addAction(cancelAction)
        
        // For iPad, set the popover presentation
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = parent.sourceRect
            popoverController.permittedArrowDirections = [.up, .down]
        }
        
        // Present the action sheet after a slight delay to ensure the view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                topController.present(actionSheet, animated: true)
            }
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate, UIDocumentPickerDelegate {
        let parent: IOSImagePicker
        
        init(_ parent: IOSImagePicker) {
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