import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit // For UIImage and potentially other UIKit elements if needed later
#endif
import UniformTypeIdentifiers

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
    @State private var isHoveringPhoto = false
    @State private var isHoveringX = false
    @State private var isHoveringHeader = false
    @Binding var isTitleVisible: Bool
    @Binding var showTooltip: Bool
    @Binding var hasShownTooltip: Bool
    @Binding var hasShownRevealTooltip: Bool
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
    
    // Add state variables for debouncing
    @State private var isToggling: Bool = false
    @State private var lastToggleTime: Date = Date()
    private let debounceInterval: TimeInterval = 0.5 // 500ms debounce interval
    
    // Heights for the collapsed header bar
    private let collapsedBarHeight: CGFloat = 64
    
    // Access underlying NSWindow to manage first responder
    #if os(macOS)
    private var window: NSWindow? {
        return NSApp.keyWindow
    }
    #elseif os(iOS)
    private var window: UIWindow? {
        return UIApplication.shared.windows.first { $0.isKeyWindow }
    }
    #endif
    
    private func toggleHeader() {
        // Implement debouncing to prevent rapid toggling
        let now = Date()
        let timeSinceLastToggle = now.timeIntervalSince(lastToggleTime)
        if isToggling || timeSinceLastToggle < debounceInterval {
            print("🛑 Debouncing header toggle - ignoring click")
            return
        }
        isToggling = true
        lastToggleTime = now
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isToggling = false
        }
        
        let hasActualImage = checkForActualImage()
        
        // Case 1: Currently expanded
        if isExpanded {
            if headerImage == nil && !hasActualImage {
                // Expanded placeholder was clicked (not via image picker)
                // This typically means user clicked the background of the placeholder.
                // Action: Show image picker.
                print("🖼️ User clicked expanded placeholder background.")
                withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                    isShowingImagePicker = true // This should be the primary action.
                }
                // The .sheet onCancel/onImageSelected will handle collapsing or state changes.
                return
            }
            
            // Collapsing an actual image or collapsing from an expanded placeholder (if picker was cancelled)
            #if os(macOS)
            NotificationCenter.default.post(name: NSNotification.Name("HeaderImageToggling"), object: nil)
            #endif
            withAnimation(.easeInOut(duration: 0.35)) {
                isExpanded = false // Collapse the view
                if hasActualImage {
                    isTitleVisible = true // For collapsed actual image bar
                    isEditorFocused = true // Keep editor active
                    onClick() // Trigger the onClick handler for actual image collapse
                    UserDefaults.standard.set(true, forKey: "Letterspace_FirstClickHandled")
                } else {
                    // If collapsing from an expanded placeholder (e.g., picker cancelled, no image chosen)
                    // We want to go to the collapsed placeholder state.
                    // isHeaderExpanded remains true.
                    isTitleVisible = true // For collapsed placeholder bar
                    isEditorFocused = false // Or true, depending on desired focus for collapsed placeholder
                }
            }
            // Focus management for macOS when collapsing actual image
            if hasActualImage {
                #if os(macOS)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let window = NSApp.keyWindow,
                       let documentTextView = window.contentView?.firstSubview(ofType: NSTextView.self) as? DocumentTextView {
                        documentTextView.isHeaderImageCurrentlyExpanded = false
                        window.makeFirstResponder(documentTextView)
                        documentTextView.forceEnableEditing()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if let window = NSApp.keyWindow,
                       let documentTextView = window.contentView?.firstSubview(ofType: NSTextView.self) as? DocumentTextView {
                        documentTextView.isHeaderImageCurrentlyExpanded = false
                        documentTextView.forceEnableEditing()
                        window.recalculateKeyViewLoop()
                        window.makeFirstResponder(documentTextView)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if UserDefaults.standard.bool(forKey: "Letterspace_FirstClickHandled") {
                        UserDefaults.standard.set(false, forKey: "Letterspace_FirstClickHandled")
                        UserDefaults.standard.synchronize()
                    }
                }
                #endif
            }
        // Case 2: Currently collapsed
        } else { // !isExpanded
            if headerImage == nil { // Collapsed placeholder was tapped
                print("➕ User clicked collapsed placeholder to add image.")
                // Action: Expand to show the large placeholderImageView for image selection.
                // isHeaderExpanded remains true.
                withAnimation(.easeInOut(duration: 0.35)) {
                    isExpanded = true
                    isTitleVisible = true // Title might be part of placeholderImageView or managed by it
                    #if os(macOS)
                    if let window = NSApp.keyWindow, window.firstResponder is NSTextView {
                        window.makeFirstResponder(nil)
                    }
                    #endif
                }
                return // Explicitly return to avoid falling into the "turn off header" logic below
            }

            // Expanding an actual, existing image from its collapsed bar state
            if hasActualImage { // This check is important here
                #if os(macOS)
                NotificationCenter.default.post(name: NSNotification.Name("HeaderImageToggling"), object: nil)
                #endif
                withAnimation(.easeInOut(duration: 0.35)) {
                    isExpanded = true
                    isTitleVisible = true // Title is usually part of expanded image view context
                    isEditorFocused = true // Maintain editor focus compatibility
                    #if os(macOS)
                    if let window = NSApp.keyWindow, window.firstResponder is NSTextView {
                        window.makeFirstResponder(nil)
                    }
                    #endif
                }
            } else {
                // This case should ideally not be hit if the above logic for `headerImage == nil` is correct.
                // This is the original logic for: !isExpanded && !hasActualImage
                // which means a collapsed bar (that isn't a placeholder) was tapped, but no image file exists.
                // This could happen if `isHeaderExpanded` is true, but `document.elements` for header image is empty/file missing.
                // Action: Turn off header feature completely.
                print("⚠️ Collapsed bar tapped, but no actual image file. Turning off header feature.")
                withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                    // isExpanded = false; // Already false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                        isHeaderExpanded = false // Turn off the feature
                        document.isHeaderExpanded = false
                        // headerImage = nil; // Should already be nil or effectively nil
                        isTitleVisible = true
                        isEditorFocused = false
                        document.save()
                    }
                }
            }
        }
    }
    
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
    private func handleImageSelection(url: URL) {
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("❌ Could not access documents directory")
            isShowingImagePicker = false
            return
        }

        let documentImagesPath = appDirectory.appendingPathComponent(document.id).appendingPathComponent("Images")

        do {
            // Create document-specific images directory if it doesn't exist
            try FileManager.default.createDirectory(at: documentImagesPath, withIntermediateDirectories: true, attributes: nil)

            let fileName = "header_\(UUID().uuidString).\(url.pathExtension)"
            let destinationURL = documentImagesPath.appendingPathComponent(fileName)

            // Copy the selected image to the app's storage
            try FileManager.default.copyItem(at: url, to: destinationURL)

            // Update document model
            var updatedDoc = document
            if let index = updatedDoc.elements.firstIndex(where: { $0.type == .headerImage }) {
                // Remove old image file if content was different
                let oldFileName = updatedDoc.elements[index].content
                if !oldFileName.isEmpty && oldFileName != fileName {
                    let oldFileURL = documentImagesPath.appendingPathComponent(oldFileName)
                    try? FileManager.default.removeItem(at: oldFileURL)
                }
                updatedDoc.elements[index].content = fileName
            } else {
                let headerElement = DocumentElement(type: .headerImage, content: fileName)
                updatedDoc.elements.insert(headerElement, at: 0) // Insert at the beginning
            }
            updatedDoc.isHeaderExpanded = true // Ensure header feature is on

            self.document = updatedDoc // Update the binding
            self.document.save()

            // Update the displayed image
            #if os(macOS)
            self.headerImage = NSImage(contentsOf: destinationURL)
            #elseif os(iOS)
            self.headerImage = UIImage(contentsOfFile: destinationURL.path)
            #endif
            
            // Ensure the header is visually expanded
            if !self.isExpanded {
                 withAnimation(.easeInOut(duration: 0.35)) {
                    self.isExpanded = true
                }
            }

            print("🖼️ Header image selected and saved: \(fileName)")

        } catch {
            print("❌ Error handling image selection: \(error)")
        }
        isShowingImagePicker = false
    }
    
    var body: some View {
        if !self.isHeaderExpanded { // If the header FEATURE is off (e.g. user explicitly removed header)
            EmptyView()
        } else { // Header FEATURE is ON
            ZStack {
                Button(action: toggleHeader) { // This button's action might need to be context-aware
                    if let headerImage = headerImage { // Actual image EXISTS
                        if isExpanded {
                            expandedHeaderView(headerImage)
                        } else { // isExpanded is false (image exists, but visually collapsed)
                            collapsedHeaderView(headerImage)
                        }
                    } else { // Actual image is NIL (placeholder mode)
                        if isExpanded { // isExpanded is true (show large placeholder)
                            placeholderImageView
                        } else { // isExpanded is false (show small collapsed placeholder bar)
                            collapsedPlaceholderView
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: paperWidth)
                .onHover { hovering in
                    if isExpanded && headerImage != nil { // Only show menu hover for expanded actual image
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isHoveringHeader = hovering
                        }
                    }
                }
                
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
            .frame(width: paperWidth)
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
            .sheet(isPresented: $isShowingImagePicker) {
                #if os(macOS)
                // Assuming ImagePicker is the correct view.
                // It expects a Binding<String> for selectedImage path, which we don't directly use here.
                // We'll pass a dummy state and use our own handleImageSelection.
                // Or, ImagePicker needs to be adapted to use a callback with URL.
                // For now, let's use NSOpenPanel directly as it's simpler for this specific case.
                // ImagePickerMacOS( <<-- This was the original problematic line
                // We will reconstruct the panel logic here as it's more direct than adapting ImagePicker
                // The 'ImagePicker' found is more of a full component with its own save logic.
                // HeaderImageSection needs direct control over the URL.
                
                // Re-implementing a simple panel presentation here:
                // This requires handleImageSelection to be called from within this closure if an image is picked.
                // However, .sheet is not the right place for this kind of imperative logic.
                // The original ImagePickerMacOS likely was a struct that took a callback.
                // Let's define a simple local picker view for macOS.
                
                // Re-implementing a simple panel presentation here:
                // This requires handleImageSelection to be called from within this closure if an image is picked.
                // However, .sheet is not the right place for this kind of imperative logic.
                // The original ImagePickerMacOS likely was a struct that took a callback.
                // Let's define a simple local picker view for macOS.
                
                SimpleMacOSFilePicker(
                    isPresented: $isShowingImagePicker,
                    allowedContentTypes: [UTType.image],
                    onFilePicked: { url in
                        handleImageSelection(url: url)
                    },
                    onCancel: {
                        // Copied from original onCancel logic for the sheet
                        if headerImage == nil && !checkForActualImage() {
                            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                                    isHeaderExpanded = false
                                    document.isHeaderExpanded = false
                                    isTitleVisible = true
                                    isEditorFocused = false
                                    document.save()
                                }
                            }
                        }
                    }
                )
                #elseif os(iOS)
                // For iOS, you'd use something like PHPickerViewController representable
                // For now, keeping EmptyView as per previous refactoring
                EmptyView() // Placeholder for iOS image picker
                #endif
            }
        }
    }

    // MARK: - Expanded Header View
    @ViewBuilder
    private func expandedHeaderView(_ image: PlatformSpecificImage) -> some View {
        let size = image.size
        let aspectRatioValue = size.height / size.width // Calculate aspect ratio once
        let headerHeight = paperWidth * aspectRatioValue

        // Apply modifiers directly inside platform blocks
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: paperWidth, height: headerHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98))),
                removal: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98)))
            ))
            .animation(.easeInOut(duration: 0.35), value: isExpanded)
            .drawingGroup()
            .overlay(alignment: .bottomTrailing) {
                if isHoveringHeader { headerMenu }
            }
        #elseif os(iOS)
        Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: paperWidth, height: headerHeight)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98))),
                                        removal: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98)))
                                    ))
                                    .animation(.easeInOut(duration: 0.35), value: isExpanded)
                                    .drawingGroup()
                                    .overlay(alignment: .bottomTrailing) {
                if isHoveringHeader { headerMenu }
            }
        #else
        // Fallback for other platforms or if specific image type isn't available
        EmptyView() // Or some placeholder text
        #endif
    }

    // MARK: - Collapsed Header View
    @ViewBuilder
    private func collapsedHeaderView(_ image: PlatformSpecificImage) -> some View {
        ZStack {
            // Blurred and cropped background image
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: paperWidth, height: collapsedBarHeight)
                .blur(radius: 8)
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                )
                .clipped()
            #elseif os(iOS)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: paperWidth, height: collapsedBarHeight)
                .blur(radius: 8)
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                )
                .clipped()
            #else
            EmptyView()
            #endif
            // Common modifiers for the ZStack content (Image part)
            // These were previously applied to the result of the #if block.
            // Now they are applied inside, or the structure doesn't need them outside.
            // .clipShape(RoundedRectangle(cornerRadius: 12)) // Now applied to the ZStack itself for the whole bar
            // .transition(...) // Applied to the ZStack
            // .animation(...) // Applied to the ZStack
            // .drawingGroup() // Applied to the ZStack

            // Title and subtitle in collapsed header bar (remains the same)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if document.subtitle.isNotEmpty {
                        Text(document.subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 20)
                Spacer()
            }
            .padding(.horizontal)
        }
        .frame(height: collapsedBarHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Clipping the whole bar
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98))),
            removal: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98)))
        ))
        .animation(.easeInOut(duration: 0.35), value: isExpanded)
        .drawingGroup() // Apply drawingGroup to the whole ZStack if needed for performance
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
                #endif
                                                    isShowingImagePicker = true
                                                }) {
                                                    Label("Replace Image", systemImage: "photo")
                                                }
                                                
            #if os(macOS) // Download specific to macOS
                                                Button(action: {
                                                    if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
                                                       !headerElement.content.isEmpty,
                                                       let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                                        let documentPath = documentsPath.appendingPathComponent("\(document.id)")
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
                                .drawingGroup()
                                .overlay(
                                    Button(action: {
                    // Action to show the image picker
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            isShowingImagePicker = true
                                        }
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
            .drawingGroup()
    }
}

#if os(macOS)
struct SimpleMacOSFilePicker: NSViewRepresentable {
    @Binding var isPresented: Bool
    let allowedContentTypes: [UTType]
    let onFilePicked: (URL) -> Void
    let onCancel: (() -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView() // Dummy view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // This needs to be triggered carefully to avoid multiple presentations
        // Typically, this logic is better outside updateNSView or controlled by a separate state.
        // For simplicity in this context, we'll attempt to show it if isPresented is true
        // and the panel isn't already up (which is hard to check from here directly).
        // A better approach for production would be a more robust coordinator pattern.

        // Guard against re-presenting if already handled by a previous update cycle
        if isPresented && context.coordinator.panelPresentedThisUpdateCycle == false {
            context.coordinator.panelPresentedThisUpdateCycle = true // Mark as presented for this cycle
            
            DispatchQueue.main.async { // Ensure panel is presented on the main thread
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = allowedContentTypes
                
                // If we present it modally, it blocks.
                // If we need it non-modal, it requires more complex handling.
                // For a sheet-like behavior, modal is usually expected.
                if panel.runModal() == .OK, let url = panel.url {
                    onFilePicked(url)
                } else {
                    onCancel?()
                }
                // Reset presentation state binding
                self.isPresented = false
                // Allow panel to be presented again in future update cycles
                context.coordinator.panelPresentedThisUpdateCycle = false
            }
        } else if !isPresented {
            // If isPresented becomes false, ensure we reset the cycle guard
             context.coordinator.panelPresentedThisUpdateCycle = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
                            }

    class Coordinator: NSObject {
        var parent: SimpleMacOSFilePicker
        var panelPresentedThisUpdateCycle: Bool = false // Guard

        init(_ parent: SimpleMacOSFilePicker) {
            self.parent = parent
            }
        }
    }
#endif

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
