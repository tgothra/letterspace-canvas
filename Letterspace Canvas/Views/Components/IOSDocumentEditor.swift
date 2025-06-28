#if os(iOS)
import SwiftUI
import Combine

struct IOSDocumentEditor: View {
    @Binding var document: Letterspace_CanvasDocument
    let onScrollChange: ((CGFloat) -> Void)?
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool
    @State private var textContent: String = ""
    @State private var fileMonitor: DocumentFileMonitor?
    @State private var lastKnownModifiedDate: Date = Date()
    @State private var refreshTimer: Timer?
    @State private var backgroundOperationsPaused: Bool = false
    

    
    // Initialize with optional scroll callback
    init(document: Binding<Letterspace_CanvasDocument>, onScrollChange: ((CGFloat) -> Void)? = nil) {
        self._document = document
        self.onScrollChange = onScrollChange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main text editing area with dynamic content size management
            GeometryReader { geometry in
                IOSTextViewRepresentable(
                    text: $textContent,
                    isFocused: Binding(
                        get: { isFocused },
                        set: { isFocused = $0 }
                    ),
                    colorScheme: colorScheme,
                    availableHeight: geometry.size.height,
                    onTextChange: { newValue in
                        updateDocumentContent(newValue)
                    },
                    onScrollChange: onScrollChange
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.08) : Color(.sRGB, white: 0.98))
        )
        .onAppear {
            loadDocumentContent()
            // Temporarily disable file monitoring to prevent SIGTERM issues
            // startFileMonitoring()
            startPeriodicRefresh()
        }
        .onDisappear {
            // stopFileMonitoring()
            stopPeriodicRefresh()
        }
        .onChange(of: document.id) { _, _ in
            // Reload content when document changes (e.g., via iCloud sync)
            loadDocumentContent()
            // stopFileMonitoring()
            stopPeriodicRefresh()
            // startFileMonitoring()
            startPeriodicRefresh()
        }
        .onChange(of: document.modifiedAt) { _, _ in
            // Reload content when document is modified externally (e.g., from macOS)
            if document.modifiedAt != lastKnownModifiedDate {
                print("🔄 External document change detected, reloading content...")
                loadDocumentContent()
                lastKnownModifiedDate = document.modifiedAt
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh when app becomes active (user switches back from macOS)
            if !backgroundOperationsPaused {
                checkForExternalChanges()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PauseBackgroundOperations"))) { _ in
            backgroundOperationsPaused = true
            stopPeriodicRefresh()
            print("⏸️ Paused background operations for editing")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResumeBackgroundOperations"))) { _ in
            backgroundOperationsPaused = false
            startPeriodicRefresh()
            print("▶️ Resumed background operations after editing")
        }

        .onTapGesture {
            // Focus the text editor immediately when tapped
            isFocused = true
        }
    }
    
    private func loadDocumentContent() {
        // Load content from the unified textBlock element (same as macOS)
        if let textElement = document.elements.first(where: { $0.type == .textBlock }) {
            // Use the string content from the textBlock element
            textContent = textElement.content
            print("📖 iOS: Loaded document content (\(textElement.content.count) characters) from textBlock element")
        } else if !document.elements.isEmpty {
            // Fallback: if no textBlock exists but there are other elements, 
            // combine all element content for editing
            let combinedContent = document.elements.map { $0.content }.joined(separator: "\n\n")
            textContent = combinedContent
            print("📖 iOS: Loaded combined content from \(document.elements.count) elements (\(combinedContent.count) characters)")
            
            // Create a textBlock element with the combined content for future editing
            let textElement = DocumentElement(type: .textBlock, content: combinedContent)
            document.elements.append(textElement)
            document.save()
        } else {
            // If no content exists, create placeholder content
            textContent = "Start typing your document here...\n\nThis text editor is synchronized with the macOS version."
            print("📖 iOS: Created new document with placeholder content")
        }
        
        // Force update content size after loading document to ensure proper scrolling
        DispatchQueue.main.async {
            // Instead of accessing coordinator, we'll rely on the text content change to trigger updates
            // which will call updateTextViewContentSize in the representable
            self.textContent = self.textContent // Force a refresh
            print("🔄 Triggered content refresh after document load")
        }
    }
    
    private func updateDocumentContent(_ newContent: String) {
        // Update the unified textBlock element (same approach as macOS)
        if let index = document.elements.firstIndex(where: { $0.type == .textBlock }) {
            // Update existing textBlock element directly on the binding
            document.elements[index].content = newContent
            // For iOS, we don't handle attributedContent/rtfData but we preserve the structure
        } else {
            // Create new textBlock element
            let element = DocumentElement(type: .textBlock, content: newContent)
            document.elements.append(element)
        }
        
        // Update modification time
        document.modifiedAt = Date()
        
        // Update the canvasDocument content for consistency
        document.updateCanvasDocument()
        
        // Save the document immediately
        document.save()
        
        // Remove debug logging on every keystroke to improve performance
        // print("📝 iOS: Updated document content (\(newContent.count) characters) and saved to iCloud Documents")
    }
    
    private func startFileMonitoring() {
        stopFileMonitoring() // Stop any existing monitoring
        
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("❌ Cannot start file monitoring: no app directory")
            return
        }
        
        let fileURL = appDirectory.appendingPathComponent("\(document.id).canvas")
        
        // Only start monitoring if the file actually exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            fileMonitor = DocumentFileMonitor(fileURL: fileURL) { 
                DispatchQueue.main.async {
                    self.reloadDocumentFromDisk()
                }
            }
            print("🔍 Started file monitoring for: \(fileURL.lastPathComponent)")
        } else {
            print("⚠️ Document file does not exist yet, skipping file monitoring")
        }
        
        // Skip Images directory monitoring for now to reduce system load
        // This was causing SIGTERM issues with iCloud Documents
        print("📡 File monitoring setup complete")
    }
    
    private func stopFileMonitoring() {
        fileMonitor?.stopMonitoring()
        fileMonitor = nil
        print("🛑 Stopped file monitoring")
    }
    
    private func checkForExternalChanges() {
        // Skip external checks if background operations are paused (during editing)
        if backgroundOperationsPaused {
            print("⏸️ Skipping external changes check - background operations paused")
            return
        }
        
        print("🔄 Checking for external changes...")
        reloadDocumentFromDisk()
    }
    
    private func startPeriodicRefresh() {
        // Reduce frequency from 3 seconds to 10 seconds to be less aggressive
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            checkForExternalChanges()
        }
        print("⏰ Started periodic refresh timer (10s intervals)")
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("⏰ Stopped periodic refresh timer")
    }
    
    private func reloadDocumentFromDisk() {
        // Add safety check to prevent excessive reloading
        let currentTime = Date().timeIntervalSince1970
        let lastReloadKey = "LastDocumentReload_\(document.id)"
        let lastReloadTime = UserDefaults.standard.double(forKey: lastReloadKey)
        
        // Throttle reloads to maximum once per 2 seconds
        if currentTime - lastReloadTime < 2.0 {
            print("📝 Throttling document reload - too frequent")
            return
        }
        
        UserDefaults.standard.set(currentTime, forKey: lastReloadKey)
        
        // Load the latest version from disk with error handling
        guard let updatedDocument = Letterspace_CanvasDocument.load(id: document.id) else {
            print("⚠️ Could not reload document from disk")
            return
        }
        
        // Check if the content actually changed to avoid unnecessary updates
        let currentContentHash = document.elements.map { $0.content }.joined().hash
        let newContentHash = updatedDocument.elements.map { $0.content }.joined().hash
        
        if currentContentHash != newContentHash {
            print("🔄 Document content changed externally, updating...")
            document = updatedDocument
            loadDocumentContent()
            lastKnownModifiedDate = updatedDocument.modifiedAt
            
            // Force update text view content size after external document reload
            DispatchQueue.main.async {
                // Trigger content refresh to force updateTextViewContentSize
                self.textContent = self.textContent
                print("🔄 Triggered content refresh after external document reload")
            }
        } else {
            print("📝 Document unchanged, no update needed")
        }
    }
}

// MARK: - iOS Text View with Dynamic Content Size Management
struct IOSTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let colorScheme: ColorScheme
    let availableHeight: CGFloat

    let onTextChange: (String) -> Void
    let onScrollChange: ((CGFloat) -> Void)?
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let textView = UITextView()
        
        // Configure scroll view with enhanced settings for reliable scrolling
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.delegate = context.coordinator
        scrollView.isScrollEnabled = true // Explicitly enable scrolling
        scrollView.bounces = true // Enable bouncing
        scrollView.scrollsToTop = true // Enable scroll to top gesture
        
        // Configure text view with optimized settings for typing performance
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textView.backgroundColor = UIColor.clear
        textView.textColor = colorScheme == .dark ? UIColor.white : UIColor.black
        textView.isScrollEnabled = false // Disable text view scrolling, let scroll view handle it
        textView.isEditable = true
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        textView.text = text
        
        // Optimize for typing performance and fast keyboard response
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        textView.smartDashesType = .default
        textView.smartQuotesType = .default
        textView.smartInsertDeleteType = .default
        textView.keyboardType = .default
        textView.returnKeyType = .default
        textView.keyboardAppearance = .default
        
        // Set up formatting toolbar as keyboard accessory
        context.coordinator.setupFormattingToolbar(for: textView, colorScheme: colorScheme)
        
        // Optimize for faster keyboard presentation
        textView.resignFirstResponder() // Start unfocused
        
        // Pre-warm the input system for faster keyboard response (iOS optimization)
        textView.isHidden = false
        textView.alpha = 1.0
        
        // Add text view to scroll view with manual frame positioning (no Auto Layout)
        // This prevents conflicts with updateTextViewContentSize which sets frames manually
        scrollView.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = true // Enable manual frame positioning
        
        // Set initial frame based on scroll view bounds
        let initialWidth = scrollView.bounds.width > 0 ? scrollView.bounds.width : 800
        let initialHeight = scrollView.bounds.height > 0 ? scrollView.bounds.height : 600
        textView.frame = CGRect(x: 0, y: 15, width: initialWidth, height: initialHeight - 15)
        
        // Store references for coordinator
        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView
        context.coordinator.onTextChange = onTextChange
        context.coordinator.onScrollChange = onScrollChange
        
        // Initial content size calculation - defer and throttle to improve initial response time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.updateTextViewContentSize()
        }
        
        // Setup scroll to top notification
        context.coordinator.setupScrollToTopNotification()
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        
        // Only update text if it changed AND the text view is not currently being edited
        // This prevents interrupting the user's typing
        if textView.text != text && !textView.isFirstResponder {
            textView.text = text
            // Skip content size update during focus changes to improve keyboard response time
            if !isFocused {
                context.coordinator.updateTextViewContentSize()
            }
        }
        
        // Update colors only if needed
        let expectedColor = colorScheme == .dark ? UIColor.white : UIColor.black
        if textView.textColor != expectedColor {
            textView.textColor = expectedColor
        }
        
        // Update focus state only when necessary and not during active editing
        if isFocused && !textView.isFirstResponder {
            // Remove async delay for immediate keyboard response
            textView.becomeFirstResponder()
        } else if !isFocused && textView.isFirstResponder && !context.coordinator.isCurrentlyEditing {
            textView.resignFirstResponder()
        }
        
        // Only update content size if available height actually changed
        if context.coordinator.availableHeight != availableHeight {
            context.coordinator.availableHeight = availableHeight
            context.coordinator.updateTextViewContentSize()
            print("📐 iOS: Available height changed from \(context.coordinator.availableHeight) to \(availableHeight)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }
    
    class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool
        var onTextChange: ((String) -> Void)?
        var onScrollChange: ((CGFloat) -> Void)?
        var scrollView: UIScrollView?
        var textView: UITextView?
        var availableHeight: CGFloat = 0
        var isCurrentlyEditing: Bool = false

        private var scrollToTopObserver: NSObjectProtocol?
        
        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self._text = text
            self._isFocused = isFocused
        }
        
        deinit {
            if let observer = scrollToTopObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            textChangeTimer?.invalidate()
        }
        
        func setupScrollToTopNotification() {
            scrollToTopObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ScrollToTop"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.scrollToTop()
            }
        }
        
        func scrollToTop() {
            // print("🔝 iOS: Received ScrollToTop notification")
            guard let scrollView = scrollView else { return }
            
            // Dismiss keyboard first if active
            if let textView = textView, textView.isFirstResponder {
                textView.resignFirstResponder()
                isFocused = false
                
                // Wait for keyboard dismissal before scrolling
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.performScrollToTop()
                }
            } else {
                performScrollToTop()
            }
        }
        
        private func performScrollToTop() {
            guard let scrollView = scrollView else { return }
            
            UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseInOut], animations: {
                scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.contentInset.top), animated: false)
            }, completion: nil)
        }
        
        // Dynamic content size management - key method for top and bottom padding
        func updateTextViewContentSize() {
            guard let textView = textView, let scrollView = scrollView else { return }
            
            // Skip updates during initial editing to prevent hangs
            if isCurrentlyEditing && textView.isFirstResponder {
                return
            }
            
            // Ensure scroll view is properly configured for scrolling
            scrollView.isScrollEnabled = true
            scrollView.alwaysBounceVertical = true
            scrollView.showsVerticalScrollIndicator = true
            
            // Calculate the text size based on the actual scroll view width
            let scrollViewWidth = scrollView.bounds.width > 0 ? scrollView.bounds.width : scrollView.frame.width
            if scrollViewWidth <= 0 {
                // If we still don't have a valid width, try again later
                DispatchQueue.main.async {
                    self.updateTextViewContentSize()
                }
                return
            }
            
            let textWidth = scrollViewWidth - (textView.textContainerInset.left + textView.textContainerInset.right)
            
            let textSize = textView.sizeThatFits(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
            
            // Use static top padding to keep text stationary during header collapse
            let topPadding: CGFloat = 25 // Fixed top padding with extra breathing room
            let textContainerInsets = textView.textContainerInset.top + textView.textContainerInset.bottom
            let bottomPadding: CGFloat = 300
            let calculatedContentHeight = topPadding + textSize.height + textContainerInsets + bottomPadding
            let totalContentHeight = max(calculatedContentHeight, availableHeight)
            
            // Position text view with proper width and height
            let textViewWidth = scrollViewWidth
            let textViewHeight = max(textSize.height + textContainerInsets, scrollView.bounds.height - topPadding)
            textView.frame = CGRect(x: 0, y: topPadding, width: textViewWidth, height: textViewHeight)
            
            // Update scroll view content size
            let newContentSize = CGSize(width: scrollViewWidth, height: totalContentHeight)
            if scrollView.contentSize != newContentSize {
                scrollView.contentSize = newContentSize
                print("📏 iOS: Updated scroll content size - Width: \(scrollViewWidth), Height: \(totalContentHeight) (text: \(textSize.height), total calc: \(calculatedContentHeight))")
            }
            
            // Ensure the scroll view can actually scroll by verifying content size > frame size
            if totalContentHeight <= scrollView.frame.height {
                print("⚠️ iOS: Content height (\(totalContentHeight)) <= scroll view height (\(scrollView.frame.height)), may not scroll properly")
            }
        }
        
        // MARK: - UITextViewDelegate
        private var lastTextLength: Int = 0
        private let textLengthThreshold: Int = 100 // Only update content size every 100 characters
        private var textChangeTimer: Timer?
        
        func textViewDidChange(_ textView: UITextView) {
            // Update binding immediately for responsiveness
            text = textView.text
            
            // Debounce the document save to prevent excessive saves during typing
            textChangeTimer?.invalidate()
            textChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.onTextChange?(textView.text)
            }
            
            // Only update content size if text length changed significantly to improve performance
            let currentLength = textView.text.count
            if abs(currentLength - lastTextLength) > textLengthThreshold {
                lastTextLength = currentLength
                DispatchQueue.main.async {
                    self.updateTextViewContentSize()
                }
            }
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            isCurrentlyEditing = true
            isFocused = true
            print("📝 Text view began editing")
            
            // Temporarily pause heavy background operations during initial editing
            pauseBackgroundOperations()
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            isCurrentlyEditing = false
            isFocused = false
            // Save any pending changes when editing ends
            textChangeTimer?.invalidate()
            onTextChange?(textView.text)
            print("📝 Text view ended editing")
            
            // Resume background operations after editing ends
            resumeBackgroundOperations()
        }
        
        func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
            return true // Always allow editing
        }
        
        // MARK: - Background Operations Management
        private func pauseBackgroundOperations() {
            // Notify parent to pause heavy operations during initial editing
            NotificationCenter.default.post(name: NSNotification.Name("PauseBackgroundOperations"), object: nil)
        }
        
        private func resumeBackgroundOperations() {
            // Resume operations after a short delay to ensure smooth editing experience
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NotificationCenter.default.post(name: NSNotification.Name("ResumeBackgroundOperations"), object: nil)
            }
        }
        
        // MARK: - Formatting Toolbar Setup
        func setupFormattingToolbar(for textView: UITextView, colorScheme: ColorScheme) {
            let toolbar = IOSTextFormattingToolbar(
                onBold: { [weak self] in
                    self?.toggleBold()
                },
                onItalic: { [weak self] in
                    self?.toggleItalic()
                },
                onUnderline: { [weak self] in
                    self?.toggleUnderline()
                },
                onLink: { [weak self] in
                    self?.insertLink()
                },
                onTextColor: { [weak self] color in
                    self?.applyTextColor(color)
                },
                onHighlight: { [weak self] color in
                    self?.applyHighlight(color)
                },
                onBulletList: { [weak self] in
                    self?.toggleBulletList()
                },
                onAlignment: { [weak self] alignment in
                    self?.applyAlignment(alignment)
                },
                onDismiss: { [weak textView] in
                    textView?.resignFirstResponder()
                },
                isBold: getCurrentFormatting().isBold,
                isItalic: getCurrentFormatting().isItalic,
                isUnderlined: getCurrentFormatting().isUnderlined,
                hasLink: getCurrentFormatting().hasLink,
                hasBulletList: getCurrentFormatting().hasBulletList
            )
            
            let hostingController = IOSFormattingToolbarHostingController(toolbar: toolbar)
            textView.inputAccessoryView = hostingController.view
        }
        
        // MARK: - Text Formatting Methods
        private func toggleBold() {
            guard let textView = textView, textView.selectedRange.location != NSNotFound else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            attributedText.enumerateAttribute(.font, in: selectedRange) { fontAttribute, range, _ in
                if let currentFont = fontAttribute as? UIFont {
                    let traits = currentFont.fontDescriptor.symbolicTraits
                    let isBold = traits.contains(.traitBold)
                    
                    let newFont: UIFont
                    if isBold {
                        // Remove bold
                        if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.subtracting(.traitBold)) {
                            newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        } else {
                            newFont = currentFont
                        }
                    } else {
                        // Add bold
                        if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.union(.traitBold)) {
                            newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        } else {
                            newFont = currentFont
                        }
                    }
                    attributedText.addAttribute(.font, value: newFont, range: range)
                }
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            text = textView.text
        }
        
        private func toggleItalic() {
            guard let textView = textView, textView.selectedRange.location != NSNotFound else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            attributedText.enumerateAttribute(.font, in: selectedRange) { fontAttribute, range, _ in
                if let currentFont = fontAttribute as? UIFont {
                    let traits = currentFont.fontDescriptor.symbolicTraits
                    let isItalic = traits.contains(.traitItalic)
                    
                    let newFont: UIFont
                    if isItalic {
                        // Remove italic
                        if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.subtracting(.traitItalic)) {
                            newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        } else {
                            newFont = currentFont
                        }
                    } else {
                        // Add italic
                        if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.union(.traitItalic)) {
                            newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        } else {
                            newFont = currentFont
                        }
                    }
                    attributedText.addAttribute(.font, value: newFont, range: range)
                }
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            text = textView.text
        }
        
        private func toggleUnderline() {
            guard let textView = textView, textView.selectedRange.location != NSNotFound else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            attributedText.enumerateAttribute(.underlineStyle, in: selectedRange) { underlineAttribute, range, _ in
                let currentUnderline = underlineAttribute as? Int ?? 0
                let newUnderline = currentUnderline == 0 ? NSUnderlineStyle.single.rawValue : 0
                attributedText.addAttribute(.underlineStyle, value: newUnderline, range: range)
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            text = textView.text
        }
        
        private func insertLink() {
            // TODO: Implement link insertion
            print("Insert link tapped")
        }
        
        private func applyTextColor(_ color: Color) {
            guard let textView = textView, textView.selectedRange.location != NSNotFound else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            let uiColor = UIColor(color)
            
            attributedText.addAttribute(.foregroundColor, value: uiColor, range: selectedRange)
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            text = textView.text
        }
        
        private func applyHighlight(_ color: Color) {
            guard let textView = textView, textView.selectedRange.location != NSNotFound else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if color == .clear {
                attributedText.removeAttribute(.backgroundColor, range: selectedRange)
            } else {
                let uiColor = UIColor(color).withAlphaComponent(0.3)
                attributedText.addAttribute(.backgroundColor, value: uiColor, range: selectedRange)
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            text = textView.text
        }
        
        private func toggleBulletList() {
            // TODO: Implement bullet list functionality
            print("Toggle bullet list tapped")
        }
        
        private func applyAlignment(_ alignment: TextAlignment) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            let paragraphStyle = NSMutableParagraphStyle()
            switch alignment {
            case .leading:
                paragraphStyle.alignment = .left
            case .center:
                paragraphStyle.alignment = .center
            case .trailing:
                paragraphStyle.alignment = .right
            }
            
            // Find the paragraph range
            let text = attributedText.string
            let paragraphRange = (text as NSString).paragraphRange(for: selectedRange)
            
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            self.text = textView.text
        }
        
        private func getCurrentFormatting() -> TextFormatting {
            guard let textView = textView, textView.selectedRange.location != NSNotFound else {
                return TextFormatting()
            }
            
            var formatting = TextFormatting()
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                // Check formatting of selected text
                let attributes = textView.attributedText.attributes(at: selectedRange.location, effectiveRange: nil)
                
                if let font = attributes[.font] as? UIFont {
                    let traits = font.fontDescriptor.symbolicTraits
                    formatting.isBold = traits.contains(.traitBold)
                    formatting.isItalic = traits.contains(.traitItalic)
                }
                
                formatting.isUnderlined = (attributes[.underlineStyle] as? Int ?? 0) != 0
                formatting.hasLink = attributes[.link] != nil
                
                if let textColor = attributes[.foregroundColor] as? UIColor {
                    formatting.textColor = Color(textColor)
                }
                
                if let backgroundColor = attributes[.backgroundColor] as? UIColor {
                    formatting.highlightColor = Color(backgroundColor)
                }
            }
            
            return formatting
        }
        
        // Helper struct for formatting state
        private struct TextFormatting {
            var isBold: Bool = false
            var isItalic: Bool = false
            var isUnderlined: Bool = false
            var hasLink: Bool = false
            var textColor: Color? = nil
            var highlightColor: Color? = nil
            var hasBulletList: Bool = false
        }
        
        // MARK: - UIScrollViewDelegate
        private var lastScrollOffset: CGFloat = 0

        private let scrollThreshold: CGFloat = 2.0 // Only update every 2 points of scroll
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Get the current scroll offset (positive when scrolled down)
            let scrollOffset = scrollView.contentOffset.y
            
            // Only call handler if scroll changed significantly to improve performance
            if abs(scrollOffset - lastScrollOffset) > scrollThreshold {
                lastScrollOffset = scrollOffset
                onScrollChange?(scrollOffset)
            }
        }
    }
}

// MARK: - File Monitoring System
class DocumentFileMonitor {
    private let fileURL: URL
    private let onChange: () -> Void
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var isMonitoring = false
    
    init(fileURL: URL, onChange: @escaping () -> Void) {
        self.fileURL = fileURL
        self.onChange = onChange
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        // Ensure we're not already monitoring
        guard !isMonitoring else { return }
        
        // Check if file exists before attempting to monitor
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📡 File does not exist, skipping monitoring: \(fileURL.lastPathComponent)")
            return
        }
        
        // Open file descriptor with error handling
        fileDescriptor = open(fileURL.path, O_EVTONLY | O_NONBLOCK)
        guard fileDescriptor >= 0 else {
            print("❌ Failed to open file descriptor for monitoring: \(fileURL.path) (errno: \(errno))")
            return
        }
        
        // Create dispatch source with error handling
        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        guard let dispatchSource = dispatchSource else {
            print("❌ Failed to create dispatch source for monitoring")
            close(fileDescriptor)
            fileDescriptor = -1
            return
        }
        
        dispatchSource.setEventHandler { [weak self] in
            // Use weak self to prevent retain cycles
            guard let self = self else { return }
            
            // Throttle events to prevent excessive callbacks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.onChange()
            }
        }
        
        dispatchSource.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
            self.isMonitoring = false
        }
        
        dispatchSource.resume()
        isMonitoring = true
        print("📡 File monitoring started for: \(fileURL.lastPathComponent)")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        dispatchSource?.cancel()
        dispatchSource = nil
        
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        
        isMonitoring = false
        print("📡 File monitoring stopped")
    }
}

// Preview for development
#Preview {
    IOSDocumentEditor(document: .constant(Letterspace_CanvasDocument()), onScrollChange: nil)
        .padding()
}
#endif 