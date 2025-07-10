#if os(macOS) || os(iOS)
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit // For UIImage
#endif
import UniformTypeIdentifiers
import UserNotifications

#if os(macOS)
struct ScrollGestureHandler: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollView()
        view.onScroll = onScroll
        
        // Ensure the view is transparent and has no scrollers
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class ScrollView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        private var scrollMonitor: Any?
        private var lastScrollPosition: CGFloat = 0
        private var momentum: CGFloat = 0
        private var lastScrollTime: TimeInterval = 0
        private var displayLink: CVDisplayLink?
        private var isRubberBanding = false
        private var rubberBandingStart: CGFloat = 0
        private var scrollVelocity: CGFloat = 0
        private var lastDeltaY: CGFloat = 0
        private var accumulatedDelta: CGFloat = 0
        private var lastScrollDirection: CGFloat = 0
        private var isAnimating = false
        private var targetScrollbarHeight: CGFloat = 0
        private var currentScrollbarHeight: CGFloat = 0
        private var lastContentHeight: CGFloat = 0
        private static let velocityThreshold: CGFloat = 30
        private static let rubberBandingStiffness: CGFloat = 0.3
        private static let rubberBandingDamping: CGFloat = 0.8
        private static let scrollbarSmoothingFactor: CGFloat = 0.15
        
        override init(frame: NSRect) {
            super.init(frame: frame)
            setup()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }
        
        private func setup() {
            wantsLayer = true
            layer?.backgroundColor = .clear
            
            // Set up display link for smooth animation
            var displayLink: CVDisplayLink?
            CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
            self.displayLink = displayLink
            
            if let displayLink = displayLink {
                CVDisplayLinkSetOutputCallback(displayLink, { (displayLink, _, _, _, _, pointer) -> CVReturn in
                    let view = Unmanaged<ScrollView>.fromOpaque(pointer!).takeUnretainedValue()
                    DispatchQueue.main.async {
                        view.updateScrollPosition()
                        view.updateScrollbarSize()
                    }
                    return kCVReturnSuccess
                }, Unmanaged.passUnretained(self).toOpaque())
                
                CVDisplayLinkStart(displayLink)
            }
            
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                // Check if the event is within our window
                guard let window = self?.window else { return event }
                
                // Get the event location in window coordinates
                let eventLocation = event.locationInWindow
                let windowBounds = window.contentView?.bounds ?? NSRect.zero
                
                // Only process if the event is within our window bounds
                if windowBounds.contains(eventLocation) {
                    let deltaY = event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 0.1 : 1.0)
                    
                    if let self = self, abs(deltaY) > 0.01 { // Only process meaningful scroll events
                        DispatchQueue.main.async {
                        self.onScroll?(deltaY)
                    }
                    }
                }
                
                return event
            }
        }
        
        private func calculateScrollbarHeight(for contentHeight: CGFloat) -> CGFloat {
            let viewportHeight = bounds.height
            let ratio = viewportHeight / contentHeight
            return max(viewportHeight * ratio, 32) // Minimum scrollbar height of 32 points
        }
        

        
        private func updateScrollbarSize() {
            if let scrollView = window?.contentView?.subviews.first(where: { $0.className.contains("DocumentEditor") })?.enclosingScrollView {
                // Skip this update in distraction-free mode to prevent jitter
                if let documentArea = scrollView.documentView?.enclosingScrollView?.superview?.superview?.superview as? NSHostingView<DocumentArea>,
                   documentArea.rootView.isDistractionFreeMode {
                    return
                }
                
                // Smoothly interpolate current scrollbar height towards target height
                let delta = targetScrollbarHeight - currentScrollbarHeight
                currentScrollbarHeight += delta * ScrollView.scrollbarSmoothingFactor
                
                // Apply the smoothed height to the scrollbar
                if let scroller = scrollView.verticalScroller {
                    let knobProportion = currentScrollbarHeight / bounds.height
                    scroller.knobProportion = knobProportion
                }
            }
        }
        
        private func updateScrollPosition() {
            if isRubberBanding {
                // Spring force increases with distance
                let springForce = -lastScrollPosition * ScrollView.rubberBandingStiffness
                momentum += springForce
                momentum *= ScrollView.rubberBandingDamping
                
                // Stop animation when movement is minimal
                if abs(momentum) < 0.1 && abs(lastScrollPosition) < 0.1 {
                    momentum = 0
                    lastScrollPosition = 0
                    isRubberBanding = false
                    isAnimating = false
                } else {
                    lastScrollPosition += momentum
                    onScroll?(momentum)
                    isAnimating = true
                }
            } else if abs(momentum) > 0.1 {
                // Apply momentum with smooth decay
                let decay = isAnimating ? 0.95 : 0.98
                momentum *= decay
                
                // Apply velocity-based threshold for smoother stops
                if abs(momentum) < 0.1 {
                    momentum = 0
                    isAnimating = false
                } else {
                    lastScrollPosition += momentum
                    onScroll?(momentum)
                    isAnimating = true
                }
            } else {
                isAnimating = false
            }
        }
        
        deinit {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let displayLink = displayLink {
                CVDisplayLinkStop(displayLink)
            }
        }
        
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return true
        }
    }
}
#elseif os(iOS)
// iOS: Use UIViewRepresentable or just a placeholder
struct ScrollGestureHandler: UIViewRepresentable {
    var onScroll: (CGFloat) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // iOS handles scrolling differently, so this can be minimal
    }
}
#endif

struct DocumentArea: View {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isFocused: Bool = false
    @State private var isEditorFocused: Bool = false
    @Binding var isHeaderExpanded: Bool
    @Binding var isSubtitleVisible: Bool
    @State private var isImageExpanded = false
    
    #if os(macOS)
    @State private var headerImage: NSImage?
    #elseif os(iOS)
    @State private var headerImage: UIImage? // Use UIImage for iOS
    #endif
    
    @State private var isShowingImagePicker = false
    @State private var imagePickerSourceRect: CGRect = .zero
    @State private var isHeaderSectionActive = false
    @Binding var documentHeight: CGFloat
    @Binding var viewportHeight: CGFloat
    @State private var documentTitle: String = "Untitled"
    @FocusState private var isTitleFocused: Bool
    @State private var isTitleVisible: Bool = true

    @State private var isAnimatingHeaderCollapse = false
    let isDistractionFreeMode: Bool
    @Binding var viewMode: ViewMode
    let availableWidth: CGFloat
    let onHeaderClick: () -> Void
    @Binding var isSearchActive: Bool
    let shouldPauseHover: Bool
    @State private var isDocumentVisible: Bool = false
    @State private var isInitialAppearance = true // New state for tracking initial load
    @State private var elementsReady = false // New state to track when all elements are ready
    @State private var isScrollingToSearchResult = false // Add missing state variable
    @State private var showTapAgainPopup: Bool = false
    @State private var hasShownTapAgainPopup: Bool = false
    
    // Manual scroll-to-collapse state variables
    @State private var currentScrollOffset: CGFloat = 0.0
    @State private var headerCollapseProgress: CGFloat = 0.0 // 0.0 = fully expanded, 1.0 = fully collapsed
    @State private var smoothedHeaderProgress: CGFloat = 0.0 // Smoothed version for ultra-smooth slow scrolling
    
    // Remove unused state variables
    private let sidebarWidth: CGFloat = 220
    private let collapsedSidebarWidth: CGFloat = 48
    private let headerHeight: CGFloat = 200
    private let collapsedHeaderHeight: CGFloat = 48
    
    // Manual scroll-to-collapse constants
    private let maxScrollForCollapse: CGFloat = 150 // How much scroll distance to fully collapse
    private let expandedHeaderHeight: CGFloat = 200
    private let collapsedHeaderHeightConst: CGFloat = 64
    
    private var currentOverlap: CGFloat {
        if viewMode == .minimal || !isHeaderExpanded {
            return 16  // Minimal overlap
        }
        return 16  // Fully expanded
    }
    
    private var paperWidth: CGFloat {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if isPhone {
            // iPhone: Use 93% of screen width to match the dashboard layout
            return UIScreen.main.bounds.width * 0.93
        } else {
            // iPad: Keep original wider width
            return 800
        }
        #else
        // macOS: Keep original width
        return 800
        #endif
    }
    
    private var headerImageHeight: CGFloat {
        if let headerImage = headerImage {
            let size = headerImage.size
            let aspectRatio = size.height / size.width
            return paperWidth * aspectRatio
        }
        return 400  // Default height for placeholder
    }
    
    private var titleSectionHeight: CGFloat {
        if isSubtitleVisible {
            return isEditorFocused ? 44 : 140
        }
        return isEditorFocused ? 44 : 100
    }
    
    private var titleTopPadding: CGFloat {
        return isEditorFocused ? 16 : 32
    }
    
    private var subtitleBottomPadding: CGFloat {
        return isEditorFocused ? 16 : 16
    }
    
    var body: some View {
        GeometryReader { geo in
            // Main container for all document UI
            documentContainer(geo: geo)
        }
                #if os(iOS)
        .background(
            IOSImagePickerController(
                isPresented: $isShowingImagePicker,
                sourceRect: imagePickerSourceRect,
                onImagePicked: { url in
                    print("📸 iOS Image picker selected: \(url)")
                    // Handle the picked image
                    handleImageImport(result: .success([url]))
                },
                onCancel: {
                    print("📸 iOS Image picker cancelled")
                    // Handle cancellation if needed
                    if headerImage == nil {
                        // If no header image exists and picker was cancelled,
                        // you might want to collapse the header
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            isHeaderExpanded = false
                            document.isHeaderExpanded = false
                        }
                    }
                }
            )
        )
        #else
        .fileImporter(
            isPresented: $isShowingImagePicker,
            allowedContentTypes: [.image, .jpeg, .png, .heic, .gif, .webP],
            allowsMultipleSelection: false
        ) { result in
            print("📸 macOS Image picker result: \(result)")
            // Ensure picker is dismissed first
            isShowingImagePicker = false
            
            // Handle result after a slight delay to avoid presentation conflicts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            handleImageImport(result: result)
        }
        }
        #endif
    }
    
    // Break out main container into a separate method
    private func documentContainer(geo: GeometryProxy) -> some View {
            ZStack {
            // Background with tap gesture
            backgroundView
            

            
            // Main document content
            documentHStack(geo: geo)
            
            
            
            // "Tap again to edit" popup overlay - only show on macOS
            #if os(macOS)
            if showTapAgainPopup {
                tapAgainPopupOverlay
            }
            #endif
        } // End of main ZStack
        // Add card styling for iPad at the container level to fill entire area
        #if os(iOS)
        .background(
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color(.sRGB, white: 0.08) : Color(.sRGB, white: 0.98))
                } else {
                    Color.clear
                }
            }
        )
        .cornerRadius(UIDevice.current.userInterfaceIdiom == .pad ? 16 : 0)
        .shadow(
            color: UIDevice.current.userInterfaceIdiom == .pad ? 
                (colorScheme == .dark ? .black.opacity(0.25) : .black.opacity(0.12)) : .clear,
            radius: UIDevice.current.userInterfaceIdiom == .pad ? 12 : 0,
            x: 0,
            y: UIDevice.current.userInterfaceIdiom == .pad ? 4 : 0
        )
        #endif
        .onAppear { handleOnAppear(geo: geo) }
        .onChange(of: document.isHeaderExpanded) { oldValue, newValue in
            handleHeaderExpandedChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: isHeaderExpanded) { _, newValue in
            handleIsHeaderExpandedChange(newValue: newValue)
        }
        .onDisappear { handleOnDisappear() }
        .onAppear { setupEventObservers() }
        .onChange(of: document.id) { oldValue, newValue in
            handleDocumentIdChange(oldValue: oldValue, newValue: newValue) 
        }
    }
    
    // Background with tap gesture
    private var backgroundView: some View {
                theme.background
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Dismiss search when clicking anywhere in the document area
                        #if os(macOS) // isSearchActive only seems relevant to macOS context here
                        if isSearchActive {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearchActive = false
                            }
                        }
                        #endif
            }
    }
                
    // Main document content stack
    private func documentHStack(geo: GeometryProxy) -> some View {
                HStack(spacing: 0) {
                    Spacer()
            
            documentVStack(geo: geo)
            
            Spacer()
        }
        .frame(maxWidth: .infinity) // Ensure HStack takes max width
    }
    
    // Document vertical content stack
    private func documentVStack(geo: GeometryProxy) -> some View {
                        VStack(spacing: 0) {
            // Header section is ALWAYS rendered unless in focus mode or distraction-free mode
            // Show collapsed header bar for documents without images, full header for documents with images
            if viewMode != .focus && !isDistractionFreeMode {
                                headerView
                    .transition(createHeaderTransition())
            }
            
            // Document content always appears below the header (no overlapping)
            AnimatedDocumentContainer(document: $document) {
                            documentContentView
                    .frame(minHeight: geo.size.height)
            }
            // Always add padding since we always show a header now
            .padding(.top, 24)
                        }
                        .frame(width: paperWidth)
            // Remove overall animation on currentOverlap to prevent animating document title
            // when header is toggled (this was causing sliding effect)
            .padding(.top, 24)
                        .opacity(isDocumentVisible ? 1 : 0)
                        .offset(y: isDocumentVisible ? 0 : 20)
                    }
                
    
    
    // "Tap again to edit" popup overlay
    private var tapAgainPopupOverlay: some View {
        ZStack {
            // Fixed position container that appears in the same place regardless of header state
            VStack {
                Spacer()
                    .frame(height: 350) // Fixed distance from top of document
                
                tapAgainPopupContent
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped(antialiased: false)
        .allowsHitTesting(false)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3))
        .zIndex(9999)
    }
    
    // Content of the "Tap again to edit" popup
    private var tapAgainPopupContent: some View {
        VStack(spacing: 10) { // Reduced spacing from 12 to 10
            // Line 1: Animated swipe icon with "Swipe to read" text
            HStack(spacing: 6) { // Reduced spacing from 8 to 6
                // Animated swipe icon
                SwipeAnimationView()
                
                Text("Swipe to read")
                    .font(.system(size: 14, weight: .medium)) // Reduced from 15 to 14
                                .foregroundColor(.white)
            }
            
            // Line 2: "Tap again to edit" text with animated tap icon
            HStack(spacing: 6) { // Reduced spacing from 8 to 6
                // Animated tap icon
                TapAnimationView()
                
                Text("Tap again to edit")
                    .font(.system(size: 14, weight: .medium)) // Reduced from 15 to 14
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16) // Reduced from 20 to 16
        .padding(.vertical, 12) // Reduced from 14 to 12
                                .background(
            RoundedRectangle(cornerRadius: 10) // Reduced from 12 to 10
                .fill(Color.black.opacity(0.8))
                .shadow(color: Color.black.opacity(0.4), radius: 5, x: 0, y: 3)
        )
        .scaleEffect(1.0) // Removed the scale effect entirely (was 1.1)
    }
    
    // Handle image import result
    private func handleImageImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access the selected file")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                #if os(macOS)
                if let image = NSImage(contentsOf: url) {
                    // Save the image to the Images directory
                    let fileName = UUID().uuidString + ".png"
                    if let documentsPath = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                        let documentPath = documentsPath.appendingPathComponent("\(document.id)")
                        let imagesPath = documentPath.appendingPathComponent("Images")
                        
                        do {
                            try FileManager.default.createDirectory(at: documentPath, withIntermediateDirectories: true, attributes: nil)
                            try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
                            let fileURL = imagesPath.appendingPathComponent(fileName)
                            print("Created directories for image storage")
                            print("Document path: \(documentPath)")
                            print("Images path: \(imagesPath)")
                            print("Final file URL: \(fileURL)")
                            
                            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                let imageRep = NSBitmapImageRep(cgImage: cgImage)
                                if let imageData = imageRep.representation(using: .png, properties: [:]) {
                                    try imageData.write(to: fileURL)
                                    print("Successfully wrote image data to file")
                                    
                                    // Update document with new image path
                                    if var headerElement = document.elements.first(where: { $0.type == .headerImage }) {
                                        print("Updating existing header element")
                                        headerElement.content = fileName
                                        if let index = document.elements.firstIndex(where: { $0.type == .headerImage }) {
                                            document.elements[index] = headerElement
                                            print("Updated header element at index \(index)")
                                        }
                                    } else {
                                        print("Creating new header element")
                                        let headerElement = DocumentElement(type: .headerImage, content: fileName)
                                        document.elements.insert(headerElement, at: 0)
                                        print("Inserted new header element at index 0")
                                    }
                                    
                                    // Save document after adding image
                                    document.save()
                                    print("Saved document with updated header image")
                                    
                                    // Cache the image
                                    let cacheKey = "\(document.id)_\(fileName)"
                                    ImageCache.shared.setImage(image, for: cacheKey)
                                    ImageCache.shared.setImage(image, for: fileName)
                                    
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        self.headerImage = image // NSImage
                                        self.isImageExpanded = true // Always expanded for actual images
                                        self.viewMode = .normal
                                        self.isHeaderExpanded = true
                                        self.isEditorFocused = true
                                        self.isTitleVisible = true
                                        

                                    }
                                }
                            }
                        } catch {
                            print("Error saving image: \(error)")
                        }
                    }
                }
                #elseif os(iOS)
                // iOS: Load image data directly from URL and save
                do {
                    let imageData = try Data(contentsOf: url)
                    guard let image = UIImage(data: imageData) else {
                        print("iOS: Failed to create UIImage from data")
                        return
                    }
                    
                                        let fileName = UUID().uuidString + ".png"
                     if let documentsPath = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                        let documentPath = documentsPath.appendingPathComponent("\(document.id)")
                        let imagesPath = documentPath.appendingPathComponent("Images")
                        
                            try FileManager.default.createDirectory(at: documentPath, withIntermediateDirectories: true, attributes: nil)
                            try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
                            let fileURL = imagesPath.appendingPathComponent(fileName)
                            
                        print("iOS: Created directories for image storage")
                        print("iOS: Document path: \(documentPath)")
                        print("iOS: Images path: \(imagesPath)")
                        print("iOS: Final file URL: \(fileURL)")
                        
                        // Save as PNG data
                        if let pngData = image.pngData() {
                            try pngData.write(to: fileURL)
                                print("iOS: Successfully wrote image data to file")
                                
                                // Update document (same logic as macOS)
                                if var headerElement = document.elements.first(where: { $0.type == .headerImage }) {
                                print("iOS: Updating existing header element")
                                    headerElement.content = fileName
                                    if let index = document.elements.firstIndex(where: { $0.type == .headerImage }) {
                                        document.elements[index] = headerElement
                                    print("iOS: Updated header element at index \(index)")
                                    }
                                } else {
                                print("iOS: Creating new header element")
                                    let headerElement = DocumentElement(type: .headerImage, content: fileName)
                                    document.elements.insert(headerElement, at: 0)
                                print("iOS: Inserted new header element at index 0")
                                }
                            
                            // Save document after adding image
                                document.save()
                                print("iOS: Saved document with updated header image")
                            
                            // Cache the image
                            let cacheKey = "\(document.id)_\(fileName)"
                            ImageCache.shared.setImage(image, for: cacheKey)
                            ImageCache.shared.setImage(image, for: fileName)
                                
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.headerImage = image // UIImage
                                self.isImageExpanded = true // Always expanded for actual images
                                    self.viewMode = .normal
                                    self.isHeaderExpanded = true
                                    self.isEditorFocused = true 
                                    self.isTitleVisible = true
                            }
                                }
                            }
                        } catch {
                    print("iOS: Error loading or saving image: \(error)")
                }
                #endif
            }
        case .failure(let error):
            print("Error selecting image: \(error.localizedDescription)")
        }
    }
    
    // Handle onAppear event
    private func handleOnAppear(geo: GeometryProxy) {
        // First check if there's an actual header image or if this is a new document
        let hasRealHeaderImage = hasActualHeaderImage()
        let isNew = isNewDocument()
        
        print("📄 Document opened: has actual header image? \(hasRealHeaderImage), is new document? \(isNew)")
        
        // New documents should ALWAYS start with text-only header
        if isNew {
            print("📄 New document detected - starting with text-only header")
            // Initialize with text-only mode
            isHeaderExpanded = false
            document.isHeaderExpanded = false
            headerImage = nil
            isImageExpanded = false
            viewMode = .normal
            isEditorFocused = false  // Keep title in expanded format for text-only mode
            isTitleVisible = true
            
            // Save initial state
            document.save()
        }
        // For existing documents, always start with text-only header if no actual image exists
        else if !hasRealHeaderImage {
            // Force text-only mode regardless of saved state
            isHeaderExpanded = false
            document.isHeaderExpanded = false
            headerImage = nil
            isImageExpanded = false
            viewMode = .normal
            isEditorFocused = false  // Keep title in expanded format for text-only mode
            isTitleVisible = true
            
            // If the document state was incorrect, save it
            if document.isHeaderExpanded == true {
                document.save()
                print("📝 Reset to text-only header on document open (no actual image exists)")
            }
        } 
        else if hasRealHeaderImage && document.isHeaderExpanded {
            // Document has a real image and header should be expanded
            // Load the image
            if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
                   !headerElement.content.isEmpty,
                   let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                    let documentPath = appDirectory.appendingPathComponent("\(document.id)")
                    let imagesPath = documentPath.appendingPathComponent("Images")
                    let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
                    
                #if os(macOS)
                if let image = NSImage(contentsOf: imageUrl) {
                        ImageCache.shared.setImage(image, for: headerElement.content)
                        ImageCache.shared.setImage(image, for: "\(document.id)_\(headerElement.content)")
                        headerImage = image
                        // Use the saved header expanded state
                    isHeaderExpanded = true
                    isImageExpanded = true
                        viewMode = .normal
                        isEditorFocused = true  // Keep title/subtitle collapsed when header image is present
                        isTitleVisible = true
                }
                #elseif os(iOS)
                if let image = UIImage(contentsOfFile: imageUrl.path) {
                    // For iOS, load UIImage
                    headerImage = image
                    isHeaderExpanded = true
                    isImageExpanded = true
                    viewMode = .normal
                    isEditorFocused = true
                    isTitleVisible = true
                }
                #endif
            }
                    } else {
            // Document has a real image but header is not expanded
            // or any other case - ensure we're in text-only mode
                        isHeaderExpanded = false
                        document.isHeaderExpanded = false
                        isImageExpanded = false
                        viewMode = .normal
                        isEditorFocused = false  // When no image, keep title in expanded format
                        isTitleVisible = true
            headerImage = nil  // Ensure header image is nil when not expanded
        }
        
        // Add global event monitor to directly handle clicks in the text editor area
        // This helps ensure header image mode is properly turned off when clicked
        #if os(macOS)
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            // Check if the click is in the main document editor
            if let window = event.window,
               let contentView = window.contentView,
               let location = contentView.superview?.convert(event.locationInWindow, from: nil),
               let hitView = contentView.hitTest(location),
               (hitView.className.contains("DocumentEditor") || 
                hitView.superview?.className.contains("DocumentEditor") == true || 
                hitView.superview?.superview?.className.contains("DocumentEditor") == true) {
                
                // Special case: handle when user has header image enabled but no actual image uploaded
                if self.isHeaderExpanded && !self.hasActualHeaderImage() {
                    print("🖱️ Direct text editor click with header placeholder but no actual image")
                    
                    // Turn OFF header image mode completely
                        DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.isHeaderExpanded = false
                            self.document.isHeaderExpanded = false
                            self.headerImage = nil
                            self.isImageExpanded = false
                            self.isTitleVisible = true
                            self.isEditorFocused = false  // Text-only expanded title format
                            
                            // Save the document to persist this change
                            self.document.save()
                            print("📝 Turned off header image mode on direct text editor click (no actual image was uploaded)")
                        }
                    }
                }
            }
            
            // Return the event to continue normal processing
            return event
        }
        #endif
        
        // Continue with the rest of the onAppear logic
        viewportHeight = geo.size.height
        
        // Add notification observer for header state checks
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CheckHeaderExpandedState"),
            object: nil,
            queue: .main
        ) { notification in
            // Store the current header image expanded state in UserDefaults
            let isExpanded = self.isImageExpanded
            print("📝 Storing header image expanded state: \(isExpanded)")
            UserDefaults.standard.set(isExpanded, forKey: "Letterspace_HeaderImageExpanded")
            UserDefaults.standard.synchronize() // Force immediate write
        }
        
        // Add observer for direct header collapse without focus
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CollapseHeaderOnly"),
            object: nil,
            queue: .main
        ) { notification in
            print("📱 Received CollapseHeaderOnly notification")
            
            // Only handle if we have a header image and it's expanded
            if self.headerImage != nil && self.isHeaderExpanded {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    // Collapse the header image
                    self.isImageExpanded = false
                    
                    // Do NOT set isEditorFocused to true to prevent focus
                    print("🔍 Header collapsed without focusing editor")
                    
                    #if os(macOS)
                    // Clear any potential first responder
                    if let window = NSApp.keyWindow {
                        if window.firstResponder is NSTextView {
                            window.makeFirstResponder(nil)
                        }
                    }
                    #endif
                }
            }
        }
        
        // Trigger document fade-in animation with a better spring animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isDocumentVisible = true
                    }
                }
                
                // Reset the appearance state when the view appears
                isInitialAppearance = true
                elementsReady = false
                
                // Setup notification handling for AI content
                setupContentNotificationHandling()
            }
    
    // Handle changes to document.isHeaderExpanded
    private func handleHeaderExpandedChange(oldValue: Bool, newValue: Bool) {
                // Handle toggle changes: ON -> OFF and OFF -> ON
                if oldValue && !newValue { // Turned OFF
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { // Adjusted response from 0.4 to 0.55
                // Completely clear header state and UI
                        headerImage = nil // Clear visual image
                        isImageExpanded = false // Ensure visual collapse
                        isEditorFocused = false // Ensure expanded title format
                        isTitleVisible = true // Title should be visible now
                isHeaderExpanded = false // Update UI state to match document state
                
                // The sidebar toggle already saves the document with document.isHeaderExpanded = false
                    }
                } else if !oldValue && newValue { // Turned ON
            
            // IMPROVED TRANSITION:
            // 1. First, immediately suppress the text header without animation - NO ANIMATION BLOCK!
            isHeaderExpanded = true    // Set this flag immediately (needed for conditional rendering)
            headerImage = nil          // Keep this nil initially to hide text title via `if headerImage == nil` condition
            isEditorFocused = true     // Set to true for compact title format (will be hidden anyway)
            isTitleVisible = false     // IMPORTANT: Set this to false immediately to prevent title from showing
            
            // 2. After a slight delay to let the UI update, begin loading the header image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // Check if we have an existing header image to load
                let existingHeader = document.elements.first(where: { $0.type == .headerImage && !$0.content.isEmpty })
                
                if let headerElement = existingHeader,
                   let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                    let documentPath = appDirectory.appendingPathComponent("\(document.id)")
                    let imagesPath = documentPath.appendingPathComponent("Images")
                    let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
                    
                    // Check if image exists before attempting to load
                    let imageExists = FileManager.default.fileExists(atPath: imageUrl.path)
                    
                    #if os(macOS)
                    if imageExists, let image = NSImage(contentsOf: imageUrl) {
                        // Cache the image
                        ImageCache.shared.setImage(image, for: headerElement.content)
                        ImageCache.shared.setImage(image, for: "\(document.id)_\(headerElement.content)")
                        
                        // Now animate ONLY the header appearance, not the title disappearance
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            // Now load the actual image. This will cause the header to appear.
                            self.headerImage = image 
                            self.isImageExpanded = true  // Ensure image is expanded
                            print("🖼️ Header toggled ON: Loaded existing image '\(headerElement.content)'")
                        }
                    } else {
                        print("⚠️ Header toggled ON: Image file not found or couldn't be loaded.")
                        // Show placeholder instead
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.isImageExpanded = true
                            print("🖼️ Header toggled ON: No existing image or couldn't be loaded, showing placeholder.")
                        }
                    }
                    #elseif os(iOS)
                    if imageExists, let image = UIImage(contentsOfFile: imageUrl.path) {
                        // Cache the image
                        // For iOS, we'd need to adapt ImageCache to work with UIImage
                        // For now, just load the image
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.headerImage = image 
                            self.isImageExpanded = true
                            print("🖼️ Header toggled ON: Loaded existing image '\(headerElement.content)'")
                        }
                    } else {
                        print("⚠️ Header toggled ON: Image file not found or couldn't be loaded.")
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.isImageExpanded = true
                            print("🖼️ Header toggled ON: No existing image or couldn't be loaded, showing placeholder.")
                        }
                    }
                    #endif
                } else {
                    // No existing image, just show placeholder
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.isImageExpanded = true
                        print("🖼️ Header toggled ON: No existing image found, showing placeholder.")
                    }
                }
            }
        }
    }
    
    // Handle changes to isHeaderExpanded
    private func handleIsHeaderExpandedChange(newValue: Bool) {
                if !isInitialAppearance {
                    if newValue {
                        // When expanding header, immediately hide title without animation
                        // This prevents the title from being visible during the transition
                        isTitleVisible = false
                        
                        // Then animate the header expansion
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            // When expanding header
                            isImageExpanded = true
                        }
                    } else {
                        // When collapsing header, animate normally
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            // When collapsing header
                            isImageExpanded = false
                        }
                    }
                }
                
        // Update document state to match UI state
                document.isHeaderExpanded = newValue
                
                // Apply consistent text editor styling when header state changes
                updateHeaderState(isExpanded: newValue)
            }
    
    // Handle onDisappear event
    private func handleOnDisappear() {
                // Clear text selection and toolbar when navigating away
                #if os(macOS)
                if let window = NSApp.keyWindow {
                    // Clear any text selection
                    if let textView = window.firstResponder as? NSTextView {
                        textView.selectedRange = NSRange(location: 0, length: 0)
                    }
                    // Clear focus to hide toolbar
                    window.makeFirstResponder(nil)
                }
                #endif
                // Reset editor focused state
                isEditorFocused = false
        
        // Reset popup state
        hasShownTapAgainPopup = false
        showTapAgainPopup = false
        
        // CRITICAL FIX: If header is expanded but no actual image exists, reset to text-only
        if isHeaderExpanded && !hasActualHeaderImage() {
            // Update document state to not have expanded header
            isHeaderExpanded = false
            document.isHeaderExpanded = false
            // Clear placeholder and state
            headerImage = nil
            isImageExpanded = false
            
            // Save the document to persist this change
            document.save()
            print("📝 Reset to text-only header on document close (no image was uploaded)")
        }
    }
    
    // Setup event observers
    private func setupEventObservers() {
                // Set up notification observers for text changes
                #if os(macOS)
                NotificationCenter.default.addObserver(
                    forName: NSText.didChangeNotification,
                    object: nil,
                    queue: .main
                ) { notification in
                    // Only trigger full-screen effect if the text change is from the main editor
                    guard let textView = notification.object as? NSTextView,
                          textView.superview?.superview?.superview?.className.contains("DocumentEditor") == true else {
                        return
                    }
                }
                
                // Set up notification observers for focus changes
                NotificationCenter.default.addObserver(
                    forName: NSControl.textDidBeginEditingNotification,
                    object: nil,
                    queue: .main
                ) { notification in
            handleTextDidBeginEditing(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSControl.textDidEndEditingNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleTextDidEndEditing()
        }
        
        // Listen for scroll position changes from DocumentEditorView
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DocumentScrollPositionChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let scrollPosition = notification.userInfo?["scrollPosition"] as? CGFloat {
                self.handleScrollPositionChange(scrollPosition)
            }
        }
        #endif
        
        // Observe header toggling to ensure content snaps in place
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HeaderImageToggling"),
            object: nil,
            queue: .main
        ) { _ in
            // Nothing to do here - the AnimatedDocumentContainer already observes this notification
            // This is just to ensure the notification is registered in case it's sent before the container appears
            print("📱 DocumentArea received HeaderImageToggling notification")
        }
    }
    
    // Handle text editing begin notification
    private func handleTextDidBeginEditing(_ notification: Notification) {
                    #if os(macOS)
                    // Only trigger if the focus is in the main editor
                    guard let textView = notification.object as? NSTextView,
                          textView.superview?.superview?.superview?.className.contains("DocumentEditor") == true else {
                        return
                    }
                    
        // Check if this might be a first click (editor not yet editable)
        let clickCount = UserDefaults.standard.integer(forKey: "LetterSpace_EditorClickCounter")
        let isFirstClick = clickCount == 1
        
        print("📱 textDidBeginEditingNotification - clickCount: \(clickCount), isFirstClick: \(isFirstClick)")
        
        // If this is the first click with header image, don't focus editor
        if isFirstClick && self.headerImage != nil && self.isHeaderExpanded {
            print("⚠️ Ignoring first click focus change")
            
            #if os(macOS)
            // Clear focus from text editor if needed
            if let window = NSApp.keyWindow,
               window.firstResponder is NSTextView {
                window.makeFirstResponder(nil)
            }
            #endif
            return
        }
        
        // If this is the first click with no header image but expanded title, don't focus editor
        if isFirstClick && self.headerImage == nil && !self.isEditorFocused {
            print("⚠️ Ignoring first click focus change for document without header image")
            
            #if os(macOS)
            // Clear focus from text editor if needed
            if let window = NSApp.keyWindow,
               window.firstResponder is NSTextView {
                window.makeFirstResponder(nil)
            }
            #endif
            return
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            // Make title compact when editor genuinely gains focus
                        isEditorFocused = true
                        
            // Check if header is expanded but no actual image has been uploaded
            if isHeaderExpanded && !hasActualHeaderImage() {
                // Turn OFF header image mode completely instead of collapsing
                isHeaderExpanded = false
                document.isHeaderExpanded = false
                headerImage = nil
                            isImageExpanded = false
                isTitleVisible = true
                
                // Save the document to persist this change
                document.save()
                print("📝 Turned off header image mode (no actual image was uploaded)")
            }
            // If there's a REAL header image AND the header is expanded,
            // collapse the image visually
            else if headerImage != nil && isHeaderExpanded && hasActualHeaderImage() {
                isImageExpanded = false
                            isTitleVisible = false // Hide title section when image collapses
                        } else {
                           // Ensure title is visible when no image or header not expanded
                           isTitleVisible = true 
                        }
                    }
                    #endif
                }
                
    // Handle text editing end notification
    private func handleTextDidEndEditing() {
                    #if os(macOS)
                     // Only trigger if the focus ends in the main editor 
                     // (Check might be needed if other text fields exist)
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        // Expand title format unless there's an active, expanded header image
                        if !(headerImage != nil && isHeaderExpanded) {
                             isEditorFocused = false
                        }
                        // Always ensure title is visible when focus ends (unless header collapsed it)
                        if isImageExpanded || headerImage == nil {
                           isTitleVisible = true
                        }
                    }
                    #endif
                }
    
    // Handle document ID change
    private func handleDocumentIdChange(oldValue: String, newValue: String) {
        // When document changes, ensure animations complete quickly
        if oldValue != newValue {
            // Force immediate completion of any pending animations
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.2)) {
                    if !isHeaderExpanded {
                        isImageExpanded = false
                    }
                }
            }
            
            // Reset popup state for new document
            hasShownTapAgainPopup = false
            showTapAgainPopup = false
        }
    }
    
    private func handleScrollPositionChange(_ scrollPosition: CGFloat) {
        // If we're in distraction-free mode, don't handle scroll
        if isDistractionFreeMode {
            return
        }
        
        #if os(macOS)
        // Only process if there's actually a header image to avoid unnecessary work
        guard headerImage != nil || isHeaderExpanded else {
            return
        }

        // Update current scroll offset
        currentScrollOffset = scrollPosition
        
        // Calculate dynamic max scroll distance based on actual header height difference
        // This ensures the scroll distance matches the visual header height change
        let dynamicMaxScroll = calculateDynamicMaxScrollForCollapse()
        
        // Calculate header collapse progress (0.0 = fully expanded, 1.0 = fully collapsed)
        let linearProgress = min(max(scrollPosition / dynamicMaxScroll, 0.0), 1.0)
        
        // Apply very gentle easing function for ultra-smooth transition
        // Using a much gentler ease-out: f(x) = 1 - (1-x)^1.2 for smoother slow scrolling
        let progress = 1.0 - pow(1.0 - linearProgress, 1.2)
        
        // Much lower threshold for ultra-smooth updates during slow scrolling
        let threshold: CGFloat = 0.001 // Ultra-low threshold for smooth slow scrolling
        if abs(headerCollapseProgress - progress) > threshold {
            headerCollapseProgress = progress
            
            // Apply additional smoothing for ultra-smooth slow scrolling
            applySmoothingToHeaderProgress()
        }
        
        // Remove debug logging to improve performance
        // print("🖥️ macOS: Scroll position: \(scrollPosition), Progress: \(progress), DynamicMaxScroll: \(dynamicMaxScroll)")
        
        // Don't automatically change isImageExpanded - let it stay as user set it
        // Only update the visual collapse progress
        #endif
    }
    
    // iOS-specific scroll handling for header behavior
    private func handleIOSScrollChange(scrollOffset: CGFloat) {
        #if os(iOS)
        // If we're in distraction-free mode, don't handle scroll
        if isDistractionFreeMode {
            return
                            }
                            
        // Only process if there's actually a header image to avoid unnecessary work
        guard headerImage != nil || isHeaderExpanded else {
            return
        }

        // Update current scroll offset
        currentScrollOffset = scrollOffset
        
        // Calculate dynamic max scroll distance based on actual header height difference
        // This ensures the scroll distance matches the visual header height change
        let dynamicMaxScroll = calculateDynamicMaxScrollForCollapse()
        
        // Calculate header collapse progress (0.0 = fully expanded, 1.0 = fully collapsed)
        let linearProgress = min(max(scrollOffset / dynamicMaxScroll, 0.0), 1.0)
        
        // Apply very gentle easing function for ultra-smooth transition
        // Using a much gentler ease-out: f(x) = 1 - (1-x)^1.2 for smoother slow scrolling
        let progress = 1.0 - pow(1.0 - linearProgress, 1.2)
                    
        // Much lower threshold for ultra-smooth updates during slow scrolling
        let threshold: CGFloat = 0.001 // Ultra-low threshold for smooth slow scrolling
        if abs(headerCollapseProgress - progress) > threshold {
            headerCollapseProgress = progress
            
            // Apply additional smoothing for ultra-smooth slow scrolling
            applySmoothingToHeaderProgress()
        }
        
        // Remove debug logging to improve performance
        // print("📱 iOS: Scroll offset: \(scrollOffset), Progress: \(progress), DynamicMaxScroll: \(dynamicMaxScroll)")
        
        // Don't automatically change isImageExpanded - let it stay as user set it
        // Only update the visual collapse progress
        #endif
    }
    
    // Calculate the appropriate scroll distance for collapse based on actual header dimensions
    private func calculateDynamicMaxScrollForCollapse() -> CGFloat {
        guard let headerImage = headerImage else {
            return maxScrollForCollapse // fallback to default
        }
        
        // Calculate actual header height (same logic as HeaderImageSection)
        let size = headerImage.size
        let aspectRatioValue = size.height / size.width
        let baseHeaderHeight = paperWidth * aspectRatioValue
        let collapsedHeight: CGFloat = 80 // Same as HeaderImageSection
        
        // The scroll distance should correlate to the actual visual height difference
        let heightDifference = baseHeaderHeight - collapsedHeight
        
        // Use a factor to make scroll feel natural and smooth (lower = more scroll needed)
        // Increased factor to slow down both text scroll AND header collapse
        let scrollFactor: CGFloat = 0.8 // 80% of height difference for slower, more gradual collapse
        
        return max(heightDifference * scrollFactor, 250) // Increased minimum to 250px for slower collapse
    }
    
    // Apply smoothing to header progress for ultra-smooth slow scrolling
    private func applySmoothingToHeaderProgress() {
        withAnimation(.linear(duration: 0.1)) {
            smoothedHeaderProgress = headerCollapseProgress
        }
    }
    
    private var collapsedTextOnlyHeaderView: some View {
        ZStack {
            // Background for the header bar
            Rectangle()
                .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1.0))
                .frame(height: 80)
            
            HStack {
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
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .onSubmit {
                        isTitleFocused = false
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
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        // Move focus away when done
                        isTitleFocused = false
                    }
                }
                .padding(.leading, 20)
                
                Spacer()
                
                // Button to add header image
                Button(action: {
                    // When user clicks the photo button, enable header image mode
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isHeaderExpanded = true
                        document.isHeaderExpanded = true
                        isImageExpanded = false // Start with collapsed image placeholder
                        document.save()
                    }
                }) {
                    Image(systemName: "photo")
                        .font(.system(size: 14))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
                        .padding(8)
                        .background(Circle().fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
        }
        .frame(height: 80)
        .frame(maxWidth: paperWidth)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var headerView: some View {
        Group {
            if headerImage != nil || isHeaderExpanded {
                // Full header section with image or image placeholder
                HeaderImageSection(
                    isExpanded: $isImageExpanded,
                    headerImage: $headerImage,
                    isShowingImagePicker: $isShowingImagePicker,
                    document: $document,
                    viewMode: $viewMode,
                    colorScheme: colorScheme,
                    paperWidth: paperWidth,
                    isHeaderSectionActive: $isHeaderSectionActive,
                    isHeaderExpanded: $isHeaderExpanded,
                    isEditorFocused: $isEditorFocused,
                    onClick: {
                        // No longer needed - header images don't collapse on tap
                    },
                    headerCollapseProgress: smoothedHeaderProgress, // Pass smoothed scaling progress for ultra-smooth slow scrolling
                    isTitleVisible: $isTitleVisible
                )
                .buttonStyle(.plain)
                .padding(.top, 24)
                // Remove fixed height constraint - let HeaderImageSection determine its own height
                // .frame(height: calculateDynamicHeaderHeight()) // REMOVED: This was forcing 200px height
                .clipped() // Only clip overflow, not the content itself
                // Remove scroll-based animation to improve iOS performance
                // .animation(.easeOut(duration: 0.1), value: headerCollapseProgress)
                .onPreferenceChange(ImagePickerSourceRectKey.self) { rect in
                    imagePickerSourceRect = rect
                }
            } else {
                // Show collapsed header bar for documents without header images
                collapsedTextOnlyHeaderView
                    .padding(.top, 24)
            }
        }
    }
    
    // Calculate the current header height based on collapse progress
    private func calculateDynamicHeaderHeight() -> CGFloat {
        let expandedHeight = expandedHeaderHeight
        let collapsedHeight = collapsedHeaderHeightConst
        
        // Smoothly interpolate between expanded and collapsed heights
        return expandedHeight - (headerCollapseProgress * (expandedHeight - collapsedHeight))
    }
    
    private var documentContentView: some View {
        VStack(spacing: 0) {
            // Don't show title/subtitle in document content anymore - 
            // they will be shown in the collapsed header bar instead
            
            // Document editor wrapped in a container for proper padding and constraints
            VStack(alignment: .leading, spacing: 0) {
                #if os(macOS)
                // Using DocumentEditorView for the main content area on macOS
                DocumentEditorView(document: $document, selectedBlock: .constant(nil))
                    .allowsHitTesting(!isAnimatingHeaderCollapse)
                    .overlay(
                        GeometryReader { geometry in
                            Color.clear // Use Color.clear for geometry reading
                                .onAppear {
                                    viewportHeight = geometry.size.height
                                }
                                .onChange(of: geometry.size.height) { _, newHeight in
                                    viewportHeight = newHeight
                                }
                        }
                    )

                #elseif os(iOS)
                // iOS: SwiftUI-based text editor optimized for touch with scroll-based header behavior
                IOSDocumentEditor(
                    document: $document,
                    onScrollChange: { scrollOffset in
                        handleIOSScrollChange(scrollOffset: scrollOffset)
                    }
                )
                    .allowsHitTesting(!isAnimatingHeaderCollapse)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewMode)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isDistractionFreeMode)
                    .overlay(
                        GeometryReader { geometry in
                            Color.clear // Use Color.clear for geometry reading
                                .onAppear {
                                    viewportHeight = geometry.size.height
                                }
                                .onChange(of: geometry.size.height) { _, newHeight in
                                    viewportHeight = newHeight
                                }
                        }
                    )

                #endif
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewMode)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isDistractionFreeMode)
            
            // Add extra space at bottom to ensure scrollbar is contained (only on non-iPad)
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom != .pad {
            Spacer()
                .frame(height: 16)
            }
            #else
            Spacer()
                .frame(height: 16)
            #endif
        }
        .frame(width: paperWidth)
        .clipShape(TopRoundedRectangle(radius: 12))
        .background(
            TopRoundedRectangle(radius: 12)
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.04),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Use animation with value-based modifiers instead of deprecated ones
        // Add a global tap gesture recognizer for the entire document content area
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // For iOS, be less aggressive - only turn off header if no image in memory
                    // For macOS, keep the original file-based check
                    #if os(iOS)
                    if isHeaderExpanded && headerImage == nil {
                        print("🔄 iOS: Global document tap detected with header but no image in memory")
                        
                        // Add slight delay to allow other gestures to process first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                // Turn off header mode completely
                                isHeaderExpanded = false
                                document.isHeaderExpanded = false
                                isImageExpanded = false
                                isTitleVisible = true
                                isEditorFocused = false  // Text-only expanded title format
                                
                                // Save the document to persist this change
                                document.save()
                                print("📝 iOS: Turned off header image mode on global document tap (no image in memory)")
                            }
                        }
                    }
                    #else
                    // macOS: Use the more thorough file-based check
                    if isHeaderExpanded && !hasActualHeaderImage() {
                        print("🔄 macOS: Global document tap detected with header placeholder but no actual image")
                        
                        // Add slight delay to allow other gestures to process first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                // Turn off header mode completely
                                isHeaderExpanded = false
                                document.isHeaderExpanded = false
                                headerImage = nil
                                isImageExpanded = false
                                isTitleVisible = true
                                isEditorFocused = false  // Text-only expanded title format
                                
                                // Save the document to persist this change
                                document.save()
                                print("📝 macOS: Turned off header image mode on global document tap (no actual image uploaded)")
                            }
                        }
                    }
                    #endif
                }
        )
    }
    
    private var documentTitleView: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    if isEditorFocused {
                        // Single line format when editor is focused
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            // Title and subtitle content
                            Group {
                                // Title
                                ZStack(alignment: .leading) {
                                    if document.title.isEmpty {
                                        Text("Untitled")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(colorScheme == .dark ? Color(.sRGB, white: 1, opacity: 0.3) : Color(.sRGB, white: 0, opacity: 0.3))
                                            .allowsHitTesting(false)
                                    }
                                    TextField("", text: Binding(
                                        get: { document.title },
                                        set: { newValue in
                                            document.title = newValue
                                            document.save()
                                        }
                                    ))
                                        .font(.system(size: 16, weight: .medium))
                                        .textFieldStyle(.plain)
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                }
                                .fixedSize()
                                
                                if isSubtitleVisible {
                                    Text(":")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .opacity(0.5)
                                        .padding(.horizontal, 2)
                                    
                                    // Subtitle
                                    ZStack(alignment: .leading) {
                                        if document.subtitle.isEmpty {
                                            Text("Add a subtitle")
                                                .font(.system(size: 16, weight: .light))
                                                .foregroundColor(colorScheme == .dark ? Color(.sRGB, white: 1, opacity: 0.3) : Color(.sRGB, white: 0, opacity: 0.3))
                                                .allowsHitTesting(false)
                                        }
                                        TextField("", text: Binding(
                                            get: { document.subtitle },
                                            set: { newValue in
                                                document.subtitle = newValue
                                                document.save()
                                            }
                                        ))
                                            .font(.system(size: 16, weight: .light))
                                            .textFieldStyle(.plain)
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .padding(.top, 20)  // Changed from 24 to 20
                        .padding(.bottom, isDistractionFreeMode ? 16 : 24)
                    } else {
                        // Original expanded format
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack(alignment: .leading) {
                                if document.title.isEmpty {
                                    Text("Untitled")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? Color(.sRGB, white: 1, opacity: 0.3) : Color(.sRGB, white: 0, opacity: 0.3))
                                        .padding(.horizontal, 24)
                                        .padding(.top, 2)
                                        .allowsHitTesting(false)
                                }
                                TextField("", text: Binding(
                                    get: { document.title },
                                    set: { newValue in
                                        document.title = newValue
                                        document.save()
                                    }
                                ))
                                    .font(.system(size: 48, weight: .bold))
                                    .textFieldStyle(.plain)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .frame(maxWidth: geo.size.width * 0.75)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 2)
                            }
                            .padding(.top, titleTopPadding)
                            .padding(.bottom, 4)
                            .focused($isTitleFocused)
                            
                            if isSubtitleVisible {
                                ZStack(alignment: .leading) {
                                    if document.subtitle.isEmpty {
                                        Text("Add a subtitle")
                                            .font(.system(size: 20, weight: .light))
                                            .foregroundColor(colorScheme == .dark ? Color(.sRGB, white: 1, opacity: 0.3) : Color(.sRGB, white: 0, opacity: 0.3))
                                            .padding(.horizontal, 24)
                                            .allowsHitTesting(false)
                                    }
                                    TextField("", text: Binding(
                                        get: { document.subtitle },
                                        set: { newValue in
                                            document.subtitle = newValue
                                            document.save()
                                        }
                                    ))
                                        .font(.system(size: 20, weight: .light))
                                        .textFieldStyle(.plain)
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .frame(maxWidth: geo.size.width * 0.75)
                                        .padding(.horizontal, 24)
                                }
                                .padding(.bottom, subtitleBottomPadding)
                            }
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
                
                Spacer()
            }
        }
        .frame(height: isEditorFocused ? 44 : titleSectionHeight)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isEditorFocused)
    }
    
    private func calculateTitleFontSize(text: String, width: CGFloat) -> CGFloat {
        let baseSize: CGFloat = 48
        let minSize: CGFloat = 24
        
        #if os(macOS)
        let font = NSFont.boldSystemFont(ofSize: baseSize)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        
        if size.width > width {
            let scaleFactor = width / size.width
            return max(baseSize * scaleFactor, minSize)
        }
        #elseif os(iOS)
        let font = UIFont.boldSystemFont(ofSize: baseSize)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        
        if size.width > width {
            let scaleFactor = width / size.width
            return max(baseSize * scaleFactor, minSize)
        }
        #endif
        
        return baseSize
    }
    
    // Add function to handle header image toggle state to maintain consistent text editor formatting
    private func updateHeaderState(isExpanded: Bool) {
        // Ensure document state is updated
        isHeaderExpanded = isExpanded
        document.isHeaderExpanded = isExpanded
        
        #if os(macOS)
        // Allow layout to update first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Find all text views in the view hierarchy and ensure they have consistent styling
            if let hostingWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "documentWindow" }) {
                // Define the recursive function properly
                func findTextViews(in views: [NSView]) -> [NSTextView] {
                    var textViews: [NSTextView] = []
                    for view in views {
                        if let textView = view as? NSTextView {
                            textViews.append(textView)
                        }
                        textViews.append(contentsOf: findTextViews(in: view.subviews))
                    }
                    return textViews
                }
                
                // Process text views
                for textView in findTextViews(in: hostingWindow.contentView?.subviews ?? []) {
                    // Apply consistent settings
                    textView.textContainerInset = NSSize(width: 17, height: textView.textContainerInset.height)
                    
                    // Clear any custom formatting
                    let style = NSMutableParagraphStyle()
                    textView.defaultParagraphStyle = style
                    
                    // Apply consistent font
                    textView.font = NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
                    
                    // Apply simpler layout manager settings
                    if let layoutManager = textView.layoutManager {
                        layoutManager.showsInvisibleCharacters = false
                        layoutManager.showsControlCharacters = false
                    }
                    
                    // Update text container settings
                    if let container = textView.textContainer {
                        container.widthTracksTextView = true
                    }
                }
            }
        }
        #endif
    }
    
    // MARK: - Document Content Handling
    private func setupContentNotificationHandling() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AddContentToDocument"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let content = userInfo["content"] as? String {
                // Handle AI-generated content
                print("Received content to add to document: \(content)")
            }
        }
    }
    
    private func showTemporaryMessage(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Letterspace Canvas"
        content.body = message
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error showing notification: \(error.localizedDescription)")
                }
            }
        }
    }
}

    // Add a helper function to check if document actually has a header image file
    private func hasActualHeaderImage() -> Bool {
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
    
    // Add a check to specifically handle new documents
    private func isNewDocument() -> Bool {
        // A new document will have minimal content
        // Check if all content arrays are empty or only have default elements
        return document.elements.isEmpty || 
               (document.elements.count <= 1 && document.elements.first?.type == .textBlock && document.elements.first?.content.isEmpty == true)
    }
}

// Helper shape for top-only rounded corners
struct TopRoundedRectangle: Shape {
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Top left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                         control: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        
        // Top right corner
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                         control: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge (straight)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        
        path.closeSubpath()
        return path
    }
}

// Animation container view
struct AnimatedDocumentContainer<Content: View>: View {
    @Binding var document: Letterspace_CanvasDocument
    @Namespace private var animation
    let content: Content
    @State private var isTogglingHeader = false
    
    init(document: Binding<Letterspace_CanvasDocument>, @ViewBuilder content: () -> Content) {
        self._document = document
        self.content = content()
    }
    
    var body: some View {
        // Wrap content in ZStack to prevent layout animation
        ZStack {
            content
                .id(document.id)
                .onChange(of: document.isHeaderExpanded) { _, _ in
                    // Set flag when header is toggled to avoid animating document content
                    isTogglingHeader = true
                    // Reset the flag after the transition should be complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        isTogglingHeader = false
                    }
                }
                .onAppear {
                    // Set up notification observer for manual header toggles
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("HeaderImageToggling"), 
                                                        object: nil, 
                                                        queue: .main) { _ in
                        // Set flag to prevent animation when header is manually toggled
                        isTogglingHeader = true
                        print("📱 AnimatedDocumentContainer: Received HeaderImageToggling notification")
                        
                        // Reset flag after animation should be complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            isTogglingHeader = false
                        }
                    }
                }
        }
        // Apply the transition to the entire ZStack
        .transition(
            // Only use transitions when not toggling header
            isTogglingHeader 
            ? .identity // No transition when toggling header (in either direction)
            : .asymmetric(
                insertion: .opacity
                    .combined(with: .scale(scale: 0.98))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8)),
                removal: .identity // No animation for removal - instant transition
            )
        )
        // Explicitly use no animation during header toggle
        .animation(isTogglingHeader ? nil : .default, value: document.isHeaderExpanded)
    }
}

// MARK: - Vertical Bookmark Timeline
struct VerticalBookmarkTimelineView: View {
    let activeDocument: Letterspace_CanvasDocument
    @GestureState private var hoveredPosition: CGFloat?
    @State private var hoveredBookmarkIndex: Int?
    @State private var contentSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Simple Bookmarks header
                Text("Bookmarks")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.primary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                
                // ScrollView to enable scrolling through bookmarks
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Bookmark dots with their labels
                        ZStack(alignment: .trailing) { // Right-aligned ZStack
                            // All bookmarks sorted by position
                            if !activeDocument.markers.filter({ $0.type == "bookmark" }).isEmpty {
                                let bookmarks = activeDocument.markers.filter({ $0.type == "bookmark" }).sorted(by: { $0.position < $1.position })
                                
                                // Then add the bookmarks themselves in a VStack
                                VStack(spacing: 0) {
                                    ForEach(Array(bookmarks.enumerated()), id: \.element.id) { index, marker in
                                        VerticalBookmarkDot(bookmark: marker, isHovered: hoveredBookmarkIndex == activeDocument.markers.firstIndex(where: { $0.id == marker.id }))
                                            .onTapGesture {
                                                scrollToBookmark(marker)
                                            }
                                            .onHover { isHovered in
                                                hoveredBookmarkIndex = isHovered ? activeDocument.markers.firstIndex(where: { $0.id == marker.id }) : nil
                                            }
                                            .padding(.vertical, 4)
                                    }
                                }
                            } else {
                                // Empty state message
                                VStack(spacing: 4) {
                                    Text("No bookmarks yet")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.primary.opacity(0.5))
                                        .padding(.top, 8)
                                    
                                    Text("Use ⌘+B to add bookmarks")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.primary.opacity(0.4))
                                        .padding(.bottom, 8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding(.top, 24) // Add padding to align with document area top
            .onChange(of: geometry.size) { oldSize, newSize in
                contentSize = newSize
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    contentSize = geometry.size
                }
            }
        }
    }
    
    private func scrollToBookmark(_ bookmark: DocumentMarker) {
        // Create navigation notification with bookmark data
        var userInfo: [String: Any] = ["lineNumber": bookmark.position]
        
        // Add character position metadata if available
        if let metadata = bookmark.metadata {
            if let charPosition = metadata["charPosition"], 
               let charLength = metadata["charLength"] {
                userInfo["charPosition"] = Int(charPosition)
                userInfo["charLength"] = Int(charLength)
            }
        }
        
        // Post notification to navigate to this bookmark
        NotificationCenter.default.post(
            name: NSNotification.Name("ScrollToBookmark"), 
            object: nil, 
            userInfo: userInfo
        )
    }
}

struct VerticalBookmarkDot: View {
    let bookmark: DocumentMarker
    var isHovered: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 8) { // Increased spacing between dot and text
            // Bookmark dot (moved to left side)
            Circle()
                .fill(Color.blue)
                .frame(width: isHovered ? 8 : 6, height: isHovered ? 8 : 6)
                .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            // Bookmark name with left alignment
            Text(bookmark.title.isEmpty ? "Bookmark" : bookmark.title)
                .font(.system(size: 11)) // Reduced from 12 to 11
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                .truncationMode(.tail)
                .lineLimit(2) // Limit to 2 lines maximum
                .multilineTextAlignment(.leading) // Left align the text
                .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading) // Full width with leading alignment
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8) // Slightly increased horizontal padding
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(colorScheme == .dark ?
                      Color.black.opacity(isHovered ? 0.5 : 0.25) :
                      Color.white.opacity(isHovered ? 0.7 : 0.5))
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .opacity(isHovered ? 1.0 : 0.9)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// Add SwipeAnimationView struct at the end of the DocumentArea struct
// (before the closing brace of the DocumentArea struct)

// Add this after the last function in DocumentArea struct but before the closing brace
struct SwipeAnimationView: View {
    // Use a timer to drive the animation 
    @State private var isAnimating = false
    
    var body: some View {
        // Just the animated arrow pointing down, no dots
        Image(systemName: "arrow.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .opacity(isAnimating ? 1.0 : 0.3)  // Fade in and out
            .offset(y: isAnimating ? 5 : -2)   // Move down and up
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                // Start the animation immediately when view appears
                isAnimating = true
            }
    }
}

// Add TapAnimationView struct after SwipeAnimationView struct
struct TapAnimationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Finger icon pointing to top-left
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .scaleEffect(isAnimating ? 0.8 : 1.0)  // Pressing effect
                .offset(x: isAnimating ? -1 : 1, y: isAnimating ? -1 : 1)  // Moving diagonally for tap effect
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear {
            // Start the animation immediately when view appears
            isAnimating = true
        }
    }
}

// Add this helper method at the bottom of the DocumentArea struct to simplify the transition creation
private func createHeaderTransition() -> AnyTransition {
    // Create the insertion transition
    let insertionAnimation = Animation.spring(response: 0.5, dampingFraction: 0.8)
    let insertionTransition = AnyTransition.opacity.combined(with: .scale(scale: 0.98))
        .animation(insertionAnimation)
    
    // Create the removal transition
    let removalTransition = AnyTransition.opacity
        .animation(.easeOut(duration: 0.2))
    
    // Combine them in an asymmetric transition
    return AnyTransition.asymmetric(
        insertion: insertionTransition,
        removal: removalTransition
    )
}

#endif
