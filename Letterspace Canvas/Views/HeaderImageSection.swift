import SwiftUI
import UniformTypeIdentifiers
import CoreData
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
import PhotosUI
#endif

// MARK: - Preference Key for Image Picker Source Rect
struct ImagePickerSourceRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// Extension for String isEmpty check
extension String {
    var isNotEmpty: Bool {
        return !self.isEmpty
    }
}

struct HeaderImageSection: View {
    @Binding var isExpanded: Bool
    #if os(macOS)
    @Binding var headerImage: NSImage?
    #elseif os(iOS)
    @Binding var headerImage: UIImage?
    #endif
    @Binding var isShowingImagePicker: Bool
    @Binding var document: Letterspace_CanvasDocument
    @State private var isHoveringSubtitle = false
    @Binding var viewMode: ViewMode
    let colorScheme: ColorScheme
    let paperWidth: CGFloat
    @Binding var isHeaderSectionActive: Bool
    @Binding var isHeaderExpanded: Bool
    @Binding var isEditorFocused: Bool
    let onClick: () -> Void
    let headerCollapseProgress: CGFloat // Add scroll-based scaling parameter
    @State private var isHoveringPhoto = false
    @State private var isHoveringX = false
    @State private var isHoveringHeader = false
    @Binding var isTitleVisible: Bool
    @State private var isImageLoading = false
    @State private var placeholderOpacity: Double = 0.0
    #if os(macOS)
    @State private var lastUploadedImage: NSImage? = nil
    #elseif os(iOS)
    @State private var lastUploadedImage: UIImage? = nil
    #endif
    @FocusState private var isContentEditorFocused: Bool
    // New state to control visibility timing
    @State private var isVisible: Bool = false
    
    // iPhone swipe-to-dismiss state variables
    @State private var isDismissing: Bool = false
    let onDismiss: (() -> Void)?
    @Binding var swipeDownProgress: CGFloat

    
    // iOS-specific state for action sheet
    #if os(iOS)
    @State private var showImageActionSheet: Bool = false
    // Store coordinators to prevent weak reference issues
    @State private var photoPickerCoordinator: PhotoPickerCoordinator?
    @State private var documentPickerCoordinator: DocumentPickerCoordinator?
    #endif
    
    // Heights for the collapsed header bar
    private let collapsedBarHeight: CGFloat = 80
    
    // Access underlying NSWindow to manage first responder
    #if os(macOS)
    private var window: NSWindow? {
        return NSApp.keyWindow
    }
    #elseif os(iOS)
    private var window: UIWindow? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }
        return windowScene.windows.first { $0.isKeyWindow }
    }
    #endif
    

    
    // Helper function to check if document has an actual image file
    private func checkForActualImage() -> Bool {
        // Check if we have a header element with a non-empty content string
        if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
           !headerElement.content.isEmpty,
           let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
            // Verify the image file actually exists
            let documentPath = appDirectory.appendingPathComponent("\(document.id)")
            let imagesPath = documentPath.appendingPathComponent("Images")
            let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
            return FileManager.default.fileExists(atPath: imageUrl.path)
        }
        return false
    }
    
    private func loadHeaderImageIfNeeded() {
        // Only load if we don't already have an image and document has a header
        if headerImage == nil && document.isHeaderExpanded {
            if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
               !headerElement.content.isEmpty {
                
                // First check if image is in cache
                let cacheKey = "\(document.id)_\(headerElement.content)"
                if let cachedImage = ImageCache.shared.image(for: cacheKey) {
                    self.headerImage = cachedImage
                    return
                }
                
                // Set loading state and load from disk
                isImageLoading = true
                
                if let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                    let documentPath = appDirectory.appendingPathComponent("\(document.id)")
                    let imagesPath = documentPath.appendingPathComponent("Images")
                    let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
                    
                    // Load image asynchronously
                    DispatchQueue.global(qos: .userInitiated).async {
                        #if os(macOS)
                        if let loadedImage = NSImage(contentsOf: imageUrl) {
                            ImageCache.shared.setImage(loadedImage, for: cacheKey)
                            ImageCache.shared.setImage(loadedImage, for: headerElement.content)
                            
                            DispatchQueue.main.async {
                                self.headerImage = loadedImage
                                self.isImageLoading = false
                                self.isExpanded = true // Always show images expanded
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.isImageLoading = false
                            }
                        }
                        #elseif os(iOS)
                        if let loadedImage = UIImage(contentsOfFile: imageUrl.path) {
                            // Assuming ImageCache can handle UIImage or needs an iOS equivalent
                            ImageCache.shared.setImage(loadedImage, for: cacheKey) 
                            ImageCache.shared.setImage(loadedImage, for: headerElement.content)
                            // print("iOS: ImageCache handling for UIImage needs review.") // Comment was here
                            DispatchQueue.main.async {
                                self.headerImage = loadedImage
                                self.isImageLoading = false
                                self.isExpanded = true // Always show images expanded
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.isImageLoading = false
                            }
                        }
                        #endif
                    }
                }
            }
        }
    }
    
    private func removeHeaderImage() {
        let filenameToDelete = self.document.elements.first(where: { $0.type == .headerImage })?.content

        // Set states to trigger parent (DocumentArea) to remove this view.
        // Use a single animation block for atomicity and to allow parent to animate the transition.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { // Animation for state changes
            self.headerImage = nil                // Clear image data in DocumentArea's state
            self.isHeaderExpanded = false         // Turn OFF header feature in DocumentArea's state (THE KEY for removal)

            // Update document model consistently
            if let index = self.document.elements.firstIndex(where: { $0.type == .headerImage }) {
                self.document.elements[index].content = ""
            }
            self.document.isHeaderExpanded = false // Persist feature OFF in model

            // Also ensure internal visual expansion state is consistent (affects DocumentArea.$isImageExpanded)
            self.isExpanded = false 
            
            // Make sure title becomes visible as we are switching to text-only header
            self.isTitleVisible = true
            self.isEditorFocused = false // Standard text-only title format
        }

        // File I/O and saving the document can happen after UI state changes have initiated animations.
        // Perform file deletion on a background thread.
        if let name = filenameToDelete, !name.isEmpty {
            DispatchQueue.global(qos: .background).async {
                if let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                    let documentPath = appDirectory.appendingPathComponent("\(self.document.id)")
                    let imagesPath = documentPath.appendingPathComponent("Images")
                    let imageUrl = imagesPath.appendingPathComponent(name)
                    try? FileManager.default.removeItem(at: imageUrl)
                    print("🗑️ Image file \(name) removed.")
                }
            }
        }
        
        // Save document changes (can also be dispatched if it's slow, but often done on main if tied to UI model objects)
        // Assuming document.save() is safe to call after state changes.
        DispatchQueue.main.async {
            self.document.save()
            print("🗑️ Header image settings saved, document updated.")
        }
    }
    
    // MARK: - Image Handling
    // Note: Image selection is now handled by DocumentArea's fileImporter
    
    var body: some View {
        if !self.isHeaderExpanded { // If the header FEATURE is off (e.g. user explicitly removed header)
            EmptyView()
        } else { // Header FEATURE is ON
            ZStack {
                // Container for header content - no more tap-to-collapse functionality
                Group {
                    if let headerImage = headerImage { // Actual image EXISTS - always show expanded view
                            expandedHeaderView(headerImage)
                            .onHover { hovering in
                                // Only show menu hover for expanded actual image
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isHoveringHeader = hovering
                                }
                        }
                    } else { // Actual image is NIL (placeholder mode)
                        if isExpanded { // isExpanded is true (show large placeholder)
                            // Make placeholder clickable to add image
                            Button(action: {
                                print("🖼️ User clicked expanded placeholder background.")
                                withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                                    isShowingImagePicker = true
                                }
                            }) {
                            placeholderImageView
                            }
                            .buttonStyle(.plain)
                        } else { // isExpanded is false (show small collapsed placeholder bar)
                            // Make collapsed placeholder clickable to expand
                            Button(action: {
                                print("➕ User clicked collapsed placeholder to expand.")
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    isExpanded = true
                                    isTitleVisible = true
                                    #if os(macOS)
                                    if let window = NSApp.keyWindow, window.firstResponder is NSTextView {
                                        window.makeFirstResponder(nil)
                                    }
                                    #endif
                                }
                            }) {
                            collapsedPlaceholderView
                }
                .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: paperWidth, maxHeight: .infinity) // Allow content to expand to full size
                

                
                // Loading indicator (remains the same)
                if isImageLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                        .edgesIgnoringSafeArea(.all)
                }
            }
            .frame(maxWidth: paperWidth, maxHeight: .infinity) // Allow ZStack to expand to content size

            .onAppear {
                loadHeaderImageIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isVisible = true
                    }
                }
            }
            .onChange(of: document.id) {
                headerImage = nil
                loadHeaderImageIfNeeded()
            }
            #if os(iOS)
            .confirmationDialog("Header Image Options", isPresented: $showImageActionSheet) {
                Button("Photo Library") {
                    presentPhotoLibraryPicker()
                }
                Button("Browse Files") {
                    presentDocumentPicker()
                }
                Button("Remove Image", role: .destructive) {
                    removeHeaderImage()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("What would you like to do with this image?")
            }
            #endif

        }
    }

    // MARK: - Expanded Header View
    @ViewBuilder
    private func expandedHeaderView(_ image: PlatformSpecificImage) -> some View {
        let size = image.size
        let aspectRatioValue = size.height / size.width // Calculate aspect ratio once
        let baseHeaderHeight = paperWidth * aspectRatioValue
        
        // Apply scroll-based scaling using headerCollapseProgress
        // When progress = 0.0 (fully expanded), use full height
        // When progress = 1.0 (fully collapsed), use collapsed height
        let collapsedHeight: CGFloat = 80 // Target collapsed height (matches collapsed bar)
        let currentHeight = baseHeaderHeight - (headerCollapseProgress * (baseHeaderHeight - collapsedHeight))
        
        // Calculate staggered transition timing for smoother effect
        let imageExitThreshold: CGFloat = 0.7 // Image starts fading out at 70%
        let barEntryThreshold: CGFloat = 0.85 // Collapsed bar starts fading in at 85%
        
        // Image fades out from 70% to 80%
        let imageExitProgress = max(0, min(1, (headerCollapseProgress - imageExitThreshold) / 0.1))
        let expandedOpacity = 1.0 - imageExitProgress
        
        // Bar fades in from 85% to 95%
        let barEntryProgress = max(0, min(1, (headerCollapseProgress - barEntryThreshold) / 0.1))
        let collapsedOpacity = barEntryProgress
        
        // Colors for collapsed state
        let collapsedBarColor = colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1.0)
        let textColor = colorScheme == .dark ? Color.white : Color.black
        let subtitleColor = colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.7)
        
        // Calculate scroll-based visual effects based on collapse progress

        // Clean design without expensive effects - smooth transitions
        ZStack {
            // Expanded state: clean image without blur or overlay
            Group {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
                    .frame(width: paperWidth, height: currentHeight)
            .clipped()
        #elseif os(iOS)
        Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                    .frame(width: paperWidth, height: currentHeight)
                                    .clipped()
                                    .onTapGesture {
                                        // iOS: Show action sheet when tapping the expanded image
                                        print("📸 iOS: User tapped expanded header image - showing action sheet")
                                        showImageActionSheet = true
                                    }
                #endif
                
                // Header menu (fade out as we approach collapsed state)
                if isHoveringHeader {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            headerMenu
                                .padding(.trailing, 16)
                                .padding(.bottom, 16)
                        }
                    }
                    .opacity(expandedOpacity)
                }
            }
            .opacity(expandedOpacity)
            
            // Collapsed state: solid bar with image thumbnail on left + title on right
            if collapsedOpacity > 0 {
                ZStack {
                                         // Background bar
                     RoundedRectangle(cornerRadius: 12)
                         .fill(collapsedBarColor)
                         .frame(height: 80)
                    
                    HStack(spacing: 12) {
                        // Image thumbnail on the left - make it clickable
                        Button(action: {
                            #if os(iOS)
                            print("📸 iOS: User tapped collapsed header image thumbnail - showing action sheet")
                            showImageActionSheet = true
                            #endif
                        }) {
                            #if os(macOS)
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            #elseif os(iOS)
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            #endif
                        }
                        .buttonStyle(.plain)
                        
                                                 // Title and subtitle on the right - make them editable
                         VStack(alignment: .leading, spacing: 2) {
                                                           // Editable title
                              TextField("Untitled", text: Binding(
                                  get: { document.title.isEmpty ? "" : document.title },
                                  set: { newValue in
                                      document.title = newValue
                                      document.save()
                                  }
                              ))
                              .font(.system(size: 18, weight: .semibold))
                              .foregroundColor(textColor)
                              .textFieldStyle(.plain)
                              .onSubmit {
                                  // Move focus away when done
                              }
                              
                              // Editable subtitle
                              TextField("Add subtitle...", text: Binding(
                                  get: { document.subtitle },
                                  set: { newValue in
                                      document.subtitle = newValue
                                      document.save()
                                  }
                              ))
                              .font(.system(size: 14, weight: .regular))
                              .foregroundColor(subtitleColor)
                              .textFieldStyle(.plain)
                              .onSubmit {
                                  // Move focus away when done
                              }
                         }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                                 }
                 .frame(height: 80)
                 .opacity(collapsedOpacity)
            }
        }
        .frame(width: paperWidth, height: currentHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98))),
            removal: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98)))
        ))
        .animation(.easeInOut(duration: 0.35), value: isExpanded)
    }



    // MARK: - Header Menu (for expanded view)
    @ViewBuilder
    private var headerMenu: some View {
                                            Menu {
                                                Button(action: {
                #if os(macOS)
                                                    // Clear text editor focus
                                                    if let window = NSApp.keyWindow,
                                                       window.firstResponder is NSTextView {
                                                        window.makeFirstResponder(nil)
                                                    }
                                                    isShowingImagePicker = true
                #elseif os(iOS)
                                                    // On iOS, show the action sheet to choose Photo Library or Browse Files
                                                    showImageActionSheet = true
                #endif
                                                }) {
                                                    Label("Replace Image", systemImage: "photo")
                                                }
                                                
            #if os(macOS) // Download specific to macOS
                                                Button(action: {
                                                    if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
                                                       !headerElement.content.isEmpty,
                                                       let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                                                        let documentPath = appDirectory.appendingPathComponent("\(document.id)")
                                                        let imagesPath = documentPath.appendingPathComponent("Images")
                                                        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
                                                        
                                                        let savePanel = NSSavePanel()
                                                        savePanel.allowedContentTypes = [UTType.image]
                                                        savePanel.nameFieldStringValue = headerElement.content
                                                        
                                                        if savePanel.runModal() == .OK {
                                                            if let destinationURL = savePanel.url {
                                                                try? FileManager.default.copyItem(at: imageUrl, to: destinationURL)
                                                            }
                                                        }
                                                    }
                                                }) {
                                                    Label("Download Image", systemImage: "square.and.arrow.down")
                                                }
            #endif
                                                
                                                Divider()
                                                
                                                Button(role: .destructive, action: removeHeaderImage) {
                                                    Label("Remove Image", systemImage: "trash")
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .frame(width: 32, height: 32)
                                                    .background(
                                                        ZStack {
                                                            // Darker background with opacity for visibility
                                                            Circle()
                                                                .fill(Color.black.opacity(0.6))
                                                            
                                                            // Border to help with visibility
                                                            Circle()
                                                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                                        }
                                                    )
                                                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                                            }
                                            .buttonStyle(.plain)
                                            .onHover { hovering in
            isHoveringPhoto = hovering // This state might be for the ellipsis icon itself
                                            }
                                            .padding(.trailing, 16)
                                            .padding(.bottom, 16)
                                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                        }
    
    // MARK: - Placeholder Image View
    @ViewBuilder
    private var placeholderImageView: some View {
        // This is shown when headerImage is nil but isExpanded is true
                            Rectangle()
                                .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1.0))
                                .frame(maxWidth: paperWidth)
            // The height might need to be dynamic based on viewMode or a fixed value for placeholder
            .frame(height: viewMode == .minimal ? 160 : 300) // Adjusted height for placeholder
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98))),
                                    removal: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98)))
                                ))
            .animation(.easeInOut(duration: 0.35), value: isExpanded) // Make sure this animation is desired here
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ImagePickerSourceRectKey.self, value: geometry.frame(in: .global))
                }
            )
                                .overlay(
                                    Button(action: {
                    // Action to show the image picker
                    print("📸 iOS: Add Header Image button tapped")
                    print("📸 iOS: Before - isShowingImagePicker: \(isShowingImagePicker)")
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            isShowingImagePicker = true
                                        }
                    print("📸 iOS: After - isShowingImagePicker: \(isShowingImagePicker)")
                                    }) {
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.system(size: 48))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                                                .padding(.bottom, 8)
                                            
                                            Text("Add Header Image")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                                        }
                    .contentShape(Rectangle()) // Ensure the whole area is tappable
                                    }
                                    .buttonStyle(.plain)
                                )
    }

    // MARK: - Collapsed Placeholder View
    @ViewBuilder
    private var collapsedPlaceholderView: some View {
        // This is shown when headerImage is nil AND isExpanded is false
                            ZStack {
                                // Background for the header bar
                                Rectangle()
                                    .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1.0))
                                    .frame(height: collapsedBarHeight)
                // .clipShape(RoundedRectangle(cornerRadius: 12)) // Keep consistent with other collapsed view
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(document.title.isEmpty ? "Untitled" : document.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                            .lineLimit(1)
                                        
                                        if document.subtitle.isNotEmpty {
                                            Text(document.subtitle)
                            .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                                                .lineLimit(1)
                                        }
                                    }
                .padding(.leading, 20)
                                    
                                    Spacer()
                                    
                // Button to add header image (which should expand the header)
                // The main Button(action: toggleHeader) should handle this if isExpanded is false
                // So this inner button might not be needed, or toggleHeader needs to be smarter
                // For now, let's assume toggleHeader will correctly set isExpanded = true
                Image(systemName: "photo") // Visually indicates add image action, main button handles it
                                            .font(.system(size: 14))
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
                                            .padding(8)
                                            .background(Circle().fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)))
                                    }
            .padding(.horizontal, 16) // Original padding was 16
        }
        .frame(height: collapsedBarHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Apply clipping to the ZStack
        .transition(.asymmetric( // Consistent transition
            insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98))),
            removal: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98)))
        ))
        .animation(.easeInOut(duration: 0.35), value: isExpanded)
    }
    
    // MARK: - Image Selection Helper
    #if os(iOS)
    private func handleImageSelection(url: URL) {
        // Post notification to DocumentArea to handle the image import
        NotificationCenter.default.post(
            name: NSNotification.Name("HandleImageImport"),
            object: nil,
            userInfo: ["imageURL": url]
        )
    }
    
    private func presentPhotoLibraryPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        let photoCoordinator = PhotoPickerCoordinator { url in
            self.handleImageSelection(url: url)
        }
        picker.delegate = photoCoordinator
        // Store coordinator to prevent deallocation
        self.photoPickerCoordinator = photoCoordinator
        topController.present(picker, animated: true)
    }
    
    private func presentDocumentPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .jpeg, .png, .heic, .gif, .webP])
        let documentCoordinator = DocumentPickerCoordinator { url in
            self.handleImageSelection(url: url)
        }
        documentPicker.delegate = documentCoordinator
        // Store coordinator to prevent deallocation
        self.documentPickerCoordinator = documentCoordinator
        documentPicker.allowsMultipleSelection = false
        topController.present(documentPicker, animated: true)
    }
    #endif
    
    // MARK: - Scroll to Top Function
    private func scrollToTop() {
        print("🔝 Scrolling to top of document")

#if os(macOS)
        // For macOS, find the NSScrollView more reliably
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow {
                // Try multiple approaches to find the scroll view
                var scrollView: NSScrollView?
                
                // Method 1: Look for DocumentTextView and get its enclosing scroll view
                if let nsScrollView = window.contentView?.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
                   let textView = nsScrollView.documentView as? NSTextView {
                    scrollView = textView.enclosingScrollView
                    print("🔍 Found scroll view via DocumentTextView")
                }
                
                // Method 2: Look directly for NSScrollView
                if scrollView == nil {
                    scrollView = window.contentView?.subviews.first { $0 is NSScrollView } as? NSScrollView
                    print("🔍 Found scroll view directly")
                }
                
                // Method 3: Recursive search for NSScrollView
                if scrollView == nil {
                    func findScrollView(in view: NSView) -> NSScrollView? {
                        if let scrollView = view as? NSScrollView {
                            return scrollView
                        }
                        for subview in view.subviews {
                            if let found = findScrollView(in: subview) {
                                return found
                            }
                        }
                        return nil
                    }
                    
                    if let contentView = window.contentView {
                        scrollView = findScrollView(in: contentView)
                        print("🔍 Found scroll view via recursive search")
                    }
                }
                
                if let scrollView = scrollView {
                    // First, dismiss any active text editing focus to prevent conflicts
                    if let textView = scrollView.documentView as? NSTextView,
                       window.firstResponder == textView {
                        print("📝 Dismissing text editor focus before scroll to top")
                        window.makeFirstResponder(nil)
                        
                        // Wait a brief moment for focus dismissal to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.performScrollToTop(scrollView: scrollView)
                        }
                    } else {
                        // No active text editing, scroll immediately
                        self.performScrollToTop(scrollView: scrollView)
                    }
                } else {
                    print("⚠️ Could not find NSScrollView for scroll to top")
                }
            }
        }
        #elseif os(iOS)
        // For iOS, post a notification to scroll to top
        // This follows the same pattern as ScrollToBookmark
        NotificationCenter.default.post(
            name: NSNotification.Name("ScrollToTop"),
            object: nil,
            userInfo: nil
        )
        #endif
    }
    
    #if os(macOS)
    // Helper function to perform the actual scroll to top animation
    private func performScrollToTop(scrollView: NSScrollView) {
        // Account for all the various insets and padding:
        // - ScrollView content insets: top 16
        // - DocumentArea top padding when header expanded: 24  
        // - TextContainer inset: 24
        let contentInsets = scrollView.contentInsets
        let documentAreaPadding: CGFloat = 24 // From DocumentArea when header is expanded
        let textContainerInset: CGFloat = 24 // From DocumentTextView textContainerInset
        
        // Calculate total offset needed to get to true top
        let totalOffset = contentInsets.top + documentAreaPadding + textContainerInset
        let scrollPoint = NSPoint(x: 0, y: -totalOffset)
        
        print("🔝 Animating scroll to top: \(scrollPoint)")
        print("📏 Content insets: \(contentInsets), Document padding: \(documentAreaPadding), Text inset: \(textContainerInset)")
        print("📏 Total offset: \(totalOffset)")
        
        // Get current scroll position for debugging
        let currentPosition = scrollView.contentView.bounds.origin
        print("🔍 Current scroll position: \(currentPosition)")
        
        // Animate the scroll to top
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scrollView.contentView.animator().setBoundsOrigin(scrollPoint)
        }, completionHandler: {
            scrollView.reflectScrolledClipView(scrollView.contentView)
            let finalPosition = scrollView.contentView.bounds.origin
            print("🔝 Scroll to top animation completed. Final position: \(finalPosition)")
        })
    }
#endif
}



// Custom button style to prevent flash effect
struct NoFlashButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(1.0)
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.35), value: configuration.isPressed)
    }
}

#if os(iOS)
// Coordinator for PHPickerViewController
class PhotoPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    let onImagePicked: (URL) -> Void
    
    init(onImagePicked: @escaping (URL) -> Void) {
        self.onImagePicked = onImagePicked
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
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
                                self.onImagePicked(tempURL)
                            }
                        }
                    } catch {
                        print("Error processing photo library image: \(error)")
                    }
                }
            }
        }
    }
}

// Coordinator for UIDocumentPickerViewController
class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    let onImagePicked: (URL) -> Void
    
    init(onImagePicked: @escaping (URL) -> Void) {
        self.onImagePicked = onImagePicked
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.dismiss(animated: true)
        if let url = urls.first {
            onImagePicked(url)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
}
#endif

