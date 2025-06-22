#if os(macOS)
import SwiftUI
import AppKit
import Combine
import ObjectiveC

// MARK: - Document Editor View
struct DocumentEditorView: NSViewRepresentable {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var selectedBlock: UUID?
    @State private var showToolbar = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isLoading = true
    
    func makeNSView(context: Context) -> NSView {
        print("🏗️ Creating text view without internal scrolling...")
        
        // Create a wrapper view that will properly size itself
        let wrapperView = DynamicHeightView()
        
        // Create a fixed size container with appropriate sizing
        let containerWidth = 752.0
        let textContainer = NSTextContainer(containerSize: NSSize(width: containerWidth - 38, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false // Force fixed width
        textContainer.heightTracksTextView = false  // Don't track height
        textContainer.lineFragmentPadding = 0
        
        // Create a layout manager with improved configuration
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = false
        layoutManager.backgroundLayoutEnabled = true
        layoutManager.defaultAttachmentScaling = .scaleProportionallyDown
        
        // Set up the text storage system
        let textStorage = NSTextStorage()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // Create the text view directly - no container view
        let textView = NoScrollTextView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: 100), textContainer: textContainer)
        
        // Configure appearance and behavior
        textView.font = NSFont(name: "Inter-Regular", size: 15) // Already at 15pt
        textView.textContainerInset = NSSize(width: 19, height: 24) // Increased vertical inset
        textView.isEditable = true
        textView.isSelectable = true
        textView.importsGraphics = true
        textView.isRichText = true
        textView.allowsImageEditing = false
        
        // CRITICAL: Configure for dynamic sizing
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []  // No autoresizing
        
        // Set size constraints for proper expansion
        textView.minSize = NSSize(width: containerWidth, height: 50)
        textView.maxSize = NSSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        
        // CRITICAL: Tell SwiftUI to use intrinsic content size
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        
        // Configure the text view for the current document
        textView.document = document
        textView.delegate = context.coordinator
        textView.coordinator = context.coordinator  // Set the coordinator property
        context.coordinator.textView = textView
        
        // Configure background
        textView.backgroundColor = colorScheme == .dark ? NSColor.textBackgroundColor : NSColor.textBackgroundColor
        textView.drawsBackground = true
        
        // Reset paragraph indentation
        textView.resetParagraphIndentation()
        
        // Add text view to wrapper
        wrapperView.textView = textView
        wrapperView.addSubview(textView)
        
        // Ensure layout is complete before returning
        layoutManager.ensureLayout(for: textContainer)
        textView.layoutManager?.ensureLayout(for: textContainer)
        
        // Set default typing attributes with consistent styling across all lines
        let isDarkModeInitial = colorScheme == .dark
        let initialTypingColor = isDarkModeInitial ? NSColor.white : NSColor.black
        textView.typingAttributes = [
            .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineHeightMultiple = 1.3
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.paragraphSpacing = 4
                return style
            }(),
            .foregroundColor: initialTypingColor // Explicit color setting based on initial colorScheme
        ]
        
        // Force apply text color to ensure uniform appearance
        textView.forceTextColorForCurrentAppearance()
        
        // IMPORTANT: Explicitly restore scripture attributes when first creating the view
        // This ensures scripture blocks are properly protected from the start
        print("🏗️ Initial restoration of scripture attributes during view creation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Small delay to ensure text is fully loaded before applying attributes
            textView.restoreScriptureAttributes()
        }
        
        return wrapperView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Get text view from wrapper
        guard let wrapperView = nsView as? DynamicHeightView,
              let textView = wrapperView.textView as? NoScrollTextView else { return }
        textView.colorScheme = colorScheme  // Update colorScheme when it changes
        
        // CRITICAL FIX: Force update the header state and ensure editing capability
        let isHeaderExpanded = document.isHeaderExpanded
        textView.isHeaderImageCurrentlyExpanded = isHeaderExpanded
        
        // If header isn't expanded, force enable editing
        if !isHeaderExpanded {
            DispatchQueue.main.async {
                textView.isEditable = true
                textView.isSelectable = true
                // Reset the first click flag to ensure future clicks work normally
                if UserDefaults.standard.bool(forKey: "Letterspace_FirstClickHandled") {
                    UserDefaults.standard.set(false, forKey: "Letterspace_FirstClickHandled")
                    UserDefaults.standard.synchronize()
                    print("⚠️ Forced reset of FirstClickHandled flag in updateNSView")
                }
            }
        }
        
        // Maintain fixed width constraints
        textView.minSize = NSSize(width: 752, height: 0)
        textView.maxSize = NSSize(width: 752, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: 752, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        
        // Track if document ID changed to ensure complete reset
        let documentChanged = textView.document?.id != document.id

        // CRITICAL: Update content if document changed OR if not actively editing
        // This prevents losing unsaved scripture when focus changes but ensures new documents start fresh
        if documentChanged {
            print("📄 Document ID changed in DocumentEditorView updateNSView: Clearing and reloading content for new document.")
            
            // Always update document reference
            textView.document = document
            
            // Explicitly clear the text view
            textView.string = ""
            
            // Reload content from the new document
            if let textElement = document.elements.first(where: { $0.type == .textBlock }),
               let attributedContent = textElement.attributedContent {
                
                let mutableContent = NSMutableAttributedString(attributedString: attributedContent)
                
                // Apply scripture ranges if present in the textElement
                if !textElement.scriptureRanges.isEmpty {
                    for rangeArray in textElement.scriptureRanges {
                        if rangeArray.count == 2 {
                            let location = rangeArray[0]
                            let length = rangeArray[1]
                            let scriptureRange = NSRange(location: location, length: length)
                            if location + length <= mutableContent.length {
                                mutableContent.addAttribute(DocumentTextView.nonEditableAttribute, value: true, range: scriptureRange)
                                mutableContent.addAttribute(DocumentTextView.isScriptureBlockQuote, value: true, range: scriptureRange)
                            }
                        }
                    }
                }
                
                // Set the text storage to the new content
                textView.textStorage?.setAttributedString(mutableContent)
                
            } else if !document.elements.contains(where: { $0.type == .textBlock }) {
                // If no text block, ensure text view is empty
                if !textView.string.isEmpty {
                    textView.string = ""
                }
            }
            
        } else if textView.window?.firstResponder !== textView {
            // This part handles updates when not actively editing (e.g., focus changes)
            // It should preserve existing content unless it's a completely different document (handled above)
            print("🔄 DocumentEditorView updateNSView: Updating content while not actively editing.")

            // Always update document reference
            textView.document = document
            
            // Clear the text view if there's no text block element
            if !document.elements.contains(where: { $0.type == .textBlock }) {
                if !textView.string.isEmpty {
                    textView.string = ""
                }
                return
            }
            
            // Only restore content if there's a text block element with content
            if let textElement = document.elements.first(where: { $0.type == .textBlock }),
               let attributedContent = textElement.attributedContent {
                
                // Check if content needs updating by comparing string length
                // This prevents unnecessary updates during scrolling
                if textView.textStorage?.length != attributedContent.length {
                    print("📤 Updating text view content - preserving scripture formatting")
                
                // Create a mutable copy to ensure we can modify attributes
                let mutableContent = NSMutableAttributedString(attributedString: attributedContent)
                    
                    // Apply scripture ranges if present in the textElement
                    if !textElement.scriptureRanges.isEmpty {
                    // Apply both attributes to each stored range
                        for rangeArray in textElement.scriptureRanges {
                        if rangeArray.count == 2 {
                            let location = rangeArray[0]
                            let length = rangeArray[1]
                            
                            // Create an NSRange from the stored integers
                            let scriptureRange = NSRange(location: location, length: length)
                            
                            // Safety check to ensure range is within bounds
                            if location + length <= mutableContent.length {
                                // Apply non-editable attribute
                                mutableContent.addAttribute(DocumentTextView.nonEditableAttribute, value: true, range: scriptureRange)
                                
                                // Apply block quote attribute (for green line)
                                mutableContent.addAttribute(DocumentTextView.isScriptureBlockQuote, value: true, range: scriptureRange)
                                
                                    print("📥 Re-applied scripture attributes from stored range: \\(scriptureRange)")
                                }
                            }
                        }
                    }
                    
                    // Set the text storage to the new content
                    textView.textStorage?.setAttributedString(mutableContent)
                }
            }
            
            // No scroll position restoration needed - using outer scroll view
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DocumentEditorView
        weak var textView: DocumentTextView?
        var hideSearchTimer: Timer?
        var searchQueryField: NSTextField?
        var searchPlaceholderLabel: NSTextField?
        var prevSearchText: String = ""
        var searchBarAnimating = false
        var contentWasUpdated = false
        
        init(_ parent: DocumentEditorView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Create a mutable copy of the attributed string to preserve all attributes
            let attributedString = NSMutableAttributedString(attributedString: textView.textStorage!)
            
            // Enumerate through all paragraph styles to ensure they are preserved exactly as they are
            attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { (value, range, stop) in
                if let paragraphStyle = value as? NSParagraphStyle {
                    let mutableStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                    attributedString.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
                }
            }
            
            // --> START: Preserve link attributes when saving <--
            // Ensure link attributes are preserved in the saved RTFD data
            textView.textStorage?.enumerateAttribute(.link,
                                                in: NSRange(location: 0, length: textView.textStorage!.length),
                                                options: []) { value, range, _ in
                if let url = value as? URL {
                    // Add the link attribute to the string copy that gets saved
                    attributedString.addAttribute(.link, value: url, range: range)
                    // Ensure proper styling for links
                    attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                    attributedString.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
                }
            }
            // --> END: Preserve link attributes <--
            
            // --> START: Preserve nonEditableAttribute when saving <--
            // Ensure nonEditableAttribute is preserved in the saved RTFD data
            textView.textStorage?.enumerateAttribute(DocumentTextView.nonEditableAttribute,
                                                in: NSRange(location: 0, length: textView.textStorage!.length),
                                                options: []) { value, range, _ in
                if let isNonEditable = value as? Bool, isNonEditable {
                    // Add the attribute to the string copy that gets saved
                    attributedString.addAttribute(DocumentTextView.nonEditableAttribute, value: true, range: range)
                }
            }
            // --> END: Preserve nonEditableAttribute <--
            
            // Convert to RTFD data for storage (will include .backgroundColor)
            if let rtfdData = attributedString.rtfd(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
                // Create or update text block element
                var element = DocumentElement(type: .textBlock)
                element.content = attributedString.string
                element.rtfData = rtfdData
                
                // Store scripture ranges (keep this logic)
                var scriptureRanges: [[Int]] = []
                if let textStorage = textView.textStorage {
                    var potentialRanges: [NSRange] = []
                    textStorage.enumerateAttribute(DocumentTextView.nonEditableAttribute,
                                              in: NSRange(location: 0, length: textStorage.length),
                                              options: []) { value, range, _ in
                        if let isNonEditable = value as? Bool, isNonEditable {
                            potentialRanges.append(range)
                        }
                    }
                    for range in potentialRanges {
                        let hasBlockQuote = textStorage.attribute(DocumentTextView.isScriptureBlockQuote,
                                                              at: range.location,
                                                              effectiveRange: nil) != nil
                        if hasBlockQuote { // Simplified check - assume nonEditable + blockQuote = scripture
                            scriptureRanges.append([range.location, range.length])
                            print("📦 Storing valid scripture range: \(range.location), \(range.length)")
                        } else {
                            print("⚠️ Skipping range without block quote attribute: \(range)")
                        }
                    }
                } else {
                    // Fallback (should ideally not be reached)
                    textView.textStorage?.enumerateAttribute(DocumentTextView.nonEditableAttribute,
                                                       in: NSRange(location: 0, length: textView.textStorage!.length),
                                                       options: []) { value, range, _ in
                        if let isNonEditable = value as? Bool, isNonEditable {
                            scriptureRanges.append([range.location, range.length])
                            print("📦 Storing scripture range (legacy method): \(range.location), \(range.length)")
                        }
                    }
                }
                element.scriptureRanges = scriptureRanges
                
                // Update the document's elements array
                var updatedDocument = parent.document
                if let index = updatedDocument.elements.firstIndex(where: { $0.type == .textBlock }) {
                    updatedDocument.elements[index] = element
                } else {
                    updatedDocument.elements.append(element)
                }
                
                // Update the binding and save
                DispatchQueue.main.async {
                    self.parent.document = updatedDocument
                    updatedDocument.save()
                    print("💾 Document Saved (Text Did Change)")
                }
            }
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? DocumentTextView else { return }
            
            // Reset paragraph indentation when focus begins
            textView.resetParagraphIndentation()
        }
        
        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? DocumentTextView else { return }
            
            // Reset paragraph indentation when focus ends
            textView.resetParagraphIndentation()
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            print("📍 Selection changed")
        }

        // MARK: - NSTextViewDelegate conformance
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // --- Bookmark Deletion Logic ---
            // Check if this change is a deletion
            if (replacementString == nil || replacementString!.isEmpty) && affectedCharRange.length > 0 {
                if let textStorage = textView.textStorage {
                    // Enumerate the .isBookmark attribute over the range being deleted
                    textStorage.enumerateAttribute(.isBookmark, in: affectedCharRange, options: []) { (value, range, stop) in
                        if let bookmarkIDString = value as? String, let bookmarkUUID = UUID(uuidString: bookmarkIDString) {
                            // Found a bookmark in the range to be deleted
                            print("🔖 Deleting bookmark with ID: \\(bookmarkUUID) because its text is being removed at range: \\(range)")
                            var doc = parent.document // Access the document through the parent coordinator
                            doc.removeMarker(id: bookmarkUUID)
                            parent.document = doc // Update the document binding
                            // No need to explicitly remove the attribute from textStorage,
                            // as the text itself is being deleted.
                        }
                    }
                }
            }
            // --- End Bookmark Deletion Logic ---

            // --- List Breaking Logic ---
            if replacementString == "\n", let textStorage = textView.textStorage {
                // Check paragraph style at the insertion point
                let currentLocation = affectedCharRange.location
                if currentLocation > 0 && currentLocation <= textStorage.length {
                    let paragraphRange = (textStorage.string as NSString).paragraphRange(for: NSRange(location: currentLocation - 1, length: 0))
                    
                    if let currentParagraphStyle = textStorage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle {
                        
                        // Check if it's a list item (textLists is non-optional)
                        if !currentParagraphStyle.textLists.isEmpty {
                            // Check if the line content before the insertion point is empty (whitespace only)
                            let lineContentRange = NSRange(location: paragraphRange.location, length: affectedCharRange.location - paragraphRange.location)
                            let lineContent = textStorage.attributedSubstring(from: lineContentRange).string
                            
                            if lineContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // Line is empty, break the list
                                textView.undoManager?.beginUndoGrouping()
                                // Apply default paragraph style to remove list formatting
                                let defaultStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                                // Keep alignment if it was set
                                defaultStyle.alignment = currentParagraphStyle.alignment
                                textStorage.addAttribute(.paragraphStyle, value: defaultStyle, range: paragraphRange)
                                textView.undoManager?.endUndoGrouping()
                                
                                // Allow the newline insertion, which will now be on a non-list styled line
                                return true
                            }
                        }
                    }
                }
            }
            // --- End List Breaking Logic ---
            
            // --- Scripture Block Protection ---
            if let textStorage = textView.textStorage {
                // Get all scripture blocks in the document
                var scriptureRanges: [NSRange] = []
                textStorage.enumerateAttribute(
                    DocumentTextView.nonEditableAttribute,
                    in: NSRange(location: 0, length: textStorage.length),
                    options: []
                ) { value, range, stop in
                    if value != nil {
                        scriptureRanges.append(range)
                        print("📜 Found scripture range: \(range)")
                    }
                }
                
                // Check for line breaks
                let isLineBreak = replacementString == "\n"
                
                // Check for backspace at start of block
                let isBackspace = (replacementString == nil || replacementString!.isEmpty) &&
                                  affectedCharRange.length == 1 &&
                                  affectedCharRange.location > 0
                
                // ENHANCED PROTECTION: First check if this is ANY edit inside a scripture block
                for scriptureRange in scriptureRanges {
                    // Check if ANY part of the affected range overlaps with scripture
                    let intersectionStart = max(affectedCharRange.location, scriptureRange.location)
                    let intersectionEnd = min(affectedCharRange.location + affectedCharRange.length,
                                             scriptureRange.location + scriptureRange.length)
                    
                    if intersectionStart < intersectionEnd {
                        // We have overlap with a scripture block
                        
                        // Special case: Allow complete deletion of entire scripture blocks
                        let isDeletion = replacementString == nil || replacementString!.isEmpty
                        
                        // Allow deletion if the entire scripture block is covered by the deletion range
                        if isDeletion &&
                           affectedCharRange.location <= scriptureRange.location &&
                           (affectedCharRange.location + affectedCharRange.length) >= (scriptureRange.location + scriptureRange.length) {
                            print("✅ Allowing deletion of entire scripture block")
                            return true
                        }
                        
                        // Special case: Allow line break at the very end of scripture block
                        if isLineBreak &&
                           affectedCharRange.location == scriptureRange.location + scriptureRange.length {
                            print("✅ Allowing line break at end of scripture block")
                            return true
                        }
                        
                        // Block all other edits inside scripture ranges
                        NSSound.beep()
                        print("⛔️ Blocked edit inside scripture block - affected range: \(affectedCharRange), scripture range: \(scriptureRange)")
                        return false
                    }
                }
                
                // Also check if we're at the boundary of a scripture block (for backspace)
                if isBackspace {
                    // Check if backspace is being used immediately before a scripture block
                    let locationAfterBackspace = affectedCharRange.location
                    
                    // Check if any scripture block starts exactly at this position
                    for range in scriptureRanges {
                        // This check protects the beginning of scripture blocks
                        if range.location == locationAfterBackspace + 1 {
                            NSSound.beep()
                            print("⛔️ Blocked backspace before scripture block header")
                            return false
                        }
                    }
                }
                
                // Also check for line breaks at the start of a scripture block
                if isLineBreak {
                    for range in scriptureRanges {
                        if affectedCharRange.location == range.location {
                            NSSound.beep()
                            print("⛔️ Blocked line break at start of scripture block")
                            return false
                        }
                    }
                }
            }
            // --- End Scripture Block Protection ---
            
            // Allow other text changes
            return true
        }
    }
    
    func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        // Get text view from wrapper
        if let wrapperView = nsView as? DynamicHeightView,
           let textView = wrapperView.textView as? DocumentTextView {
            textView.selectedRange = NSRange(location: 0, length: 0)
            
            // Close any floating panels (including toolbar)
            if let window = textView.window {
                window.childWindows?.forEach { childWindow in
                    if childWindow.className.contains("Panel") {
                        childWindow.close()
                    }
                }
                window.makeFirstResponder(nil)
            }
            
            // Reset state
            textView.isEditable = false
            textView.isSelectable = false
        }
        
        // Clean up any timers
        coordinator.hideSearchTimer?.invalidate()
        coordinator.hideSearchTimer = nil
    }
}

// MARK: - Custom Classes for No-Scroll Text View

/// Wrapper view that dynamically sizes itself based on text view content
class DynamicHeightView: NSView {
    var textView: NSTextView? {
        didSet {
            if let textView = textView {
                // Position text view at origin
                textView.frame = NSRect(x: 0, y: 0, width: 752, height: textView.intrinsicContentSize.height)
            }
        }
    }
    
    override var intrinsicContentSize: NSSize {
        if let textView = textView {
            let size = textView.intrinsicContentSize
            return NSSize(width: 752, height: size.height)
        }
        return NSSize(width: 752, height: 100)
    }
    
    override func layout() {
        super.layout()
        
        if let textView = textView {
            // Update text view frame to match our bounds
            textView.frame = bounds
            
            // Check if size changed
            let newHeight = textView.intrinsicContentSize.height
            if abs(frame.height - newHeight) > 1 {
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        // Set up observer for text view changes
        if let textView = textView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(textViewDidChange),
                name: NSText.didChangeNotification,
                object: textView
            )
            
            // Set up scroll monitoring
            if window != nil {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(scrollViewWillBeginScrolling),
                    name: NSScrollView.willStartLiveScrollNotification,
                    object: nil
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(scrollViewDidEndScrolling),
                    name: NSScrollView.didEndLiveScrollNotification,
                    object: nil
                )
            }
        }
    }
    
    @objc private func textViewDidChange(_ notification: Notification) {
        // Don't force immediate updates - let the text view handle batching
        // This prevents double-updates that cause jitter
    }
    
    @objc private func scrollViewWillBeginScrolling(_ notification: Notification) {
        // Notify text view that scrolling has started
        if let textView = textView as? NoScrollTextView {
            textView.setScrolling(true)
        }
    }
    
    @objc private func scrollViewDidEndScrolling(_ notification: Notification) {
        // Notify text view that scrolling has ended
        if let textView = textView as? NoScrollTextView {
            textView.setScrolling(false)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

/// Custom text view that never scrolls internally and sizes to content
class NoScrollTextView: DocumentTextView {
    
    private var lastCalculatedHeight: CGFloat = 100
    private var heightUpdateTimer: Timer?
    private var pendingHeightUpdate = false
    private var isScrolling = false
    private var scrollEndTimer: Timer?
    private var cachedHeight: CGFloat = 100
    
    override var intrinsicContentSize: NSSize {
        // If we're scrolling, return the cached height to avoid recalculation
        if isScrolling {
            return NSSize(width: 752, height: cachedHeight)
        }
        
        // Calculate the size needed for all text content
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return NSSize(width: 752, height: lastCalculatedHeight)
        }
        
        // Force complete layout
        layoutManager.ensureLayout(for: textContainer)
        
        // Get the used rect for the text
        let usedRect = layoutManager.usedRect(for: textContainer)
        let insets = textContainerInset
        
        // Calculate height based on actual content
        let contentHeight = usedRect.height + insets.height * 2
        lastCalculatedHeight = max(contentHeight, 50)
        cachedHeight = lastCalculatedHeight
        
        return NSSize(width: 752, height: lastCalculatedHeight)
    }
    
    override func didChangeText() {
        super.didChangeText()
        
        // Cancel existing timer
        heightUpdateTimer?.invalidate()
        
        // Mark that we need an update
        pendingHeightUpdate = true
        
        // For large changes (like paste), update immediately
        // Otherwise batch small changes (typing)
        let changeSize = abs(lastCalculatedHeight - intrinsicContentSize.height)
        let updateDelay = changeSize > 100 ? 0.0 : 0.1
        
        if updateDelay == 0 {
            performHeightUpdate()
        } else {
            // Schedule update after a short delay (batch multiple keystrokes)
            heightUpdateTimer = Timer.scheduledTimer(withTimeInterval: updateDelay, repeats: false) { [weak self] _ in
                self?.performHeightUpdate()
            }
        }
    }
    
    private func performHeightUpdate() {
        guard pendingHeightUpdate else { return }
        pendingHeightUpdate = false
        
        // Ensure layout is complete
        layoutManager?.ensureLayout(for: textContainer!)
        
        // Invalidate intrinsic content size
        invalidateIntrinsicContentSize()
        
        // Notify SwiftUI that size changed
        if let window = window {
            window.layoutIfNeeded()
        }
    }
    
    override func layout() {
        super.layout()
        
        // Skip layout updates during scrolling
        guard !isScrolling else { return }
        
        // Ensure text container matches our width
        textContainer?.containerSize = NSSize(width: bounds.width - textContainerInset.width * 2, 
                                             height: CGFloat.greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = false
        
        // Force layout manager to recalculate
        layoutManager?.ensureLayout(for: textContainer!)
    }
    
    override var isVerticallyResizable: Bool {
        get { true }
        set { /* Always true */ }
    }
    
    override var isHorizontallyResizable: Bool {
        get { false }
        set { /* Always false */ }
    }
    
    // Prevent any scrolling
    override func scrollRangeToVisible(_ range: NSRange) {
        // Do nothing - prevent internal scrolling
    }
    
    override func scrollToVisible(_ rect: NSRect) -> Bool {
        // Do nothing - prevent internal scrolling
        return false
    }
    
    // Clean up timer on dealloc
    deinit {
        heightUpdateTimer?.invalidate()
        heightUpdateTimer = nil
        scrollEndTimer?.invalidate()
        scrollEndTimer = nil
    }
    
    // Force immediate update when text view loses focus
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        
        // If there's a pending update, perform it immediately
        if pendingHeightUpdate {
            heightUpdateTimer?.invalidate()
            performHeightUpdate()
        }
        
        return result
    }
    
    // Handle scroll state changes
    func setScrolling(_ scrolling: Bool) {
        scrollEndTimer?.invalidate()
        
        if scrolling {
            isScrolling = true
        } else {
            // Delay the end of scrolling state to handle momentum scrolling
            scrollEndTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.isScrolling = false
                // Update height after scrolling ends
                if self?.pendingHeightUpdate == true {
                    self?.performHeightUpdate()
                }
            }
        }
    }
}

// Extension to handle text color updates
extension DocumentTextView {
    func forceTextColorForCurrentAppearance() {
        guard let textStorage = self.textStorage else { return }
        
        // Apply the label color to all text to ensure proper dark/light mode handling
        textStorage.beginEditing()
        
        // Get the current appearance mode
        let isDarkMode = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        // Use explicit black/white with full opacity instead of labelColor
        let fullOpacityColor = isDarkMode ? NSColor.white : NSColor.black
        
        // Apply full opacity color to the entire document range first
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.foregroundColor, value: fullOpacityColor, range: fullRange)
        
        // Check specifically for any paragraphs with transparent/missing colors
        let nsString = string as NSString
        
        // Extra care for the first paragraph
        if textStorage.length > 0 {
            let firstParagraphRange = nsString.paragraphRange(for: NSRange(location: 0, length: 0))
            if firstParagraphRange.length > 0 {
                // Ensure proper font and style for first paragraph
                let fontAttribute = NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
                textStorage.addAttribute(.font, value: fontAttribute, range: firstParagraphRange)
                
                // Create a proper paragraph style with explicit line height and spacing
                let style = NSMutableParagraphStyle()
                style.lineHeightMultiple = 1.3
                style.paragraphSpacing = 4
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                textStorage.addAttribute(.paragraphStyle, value: style, range: firstParagraphRange)
                
                // Double-ensure color is set correctly with full opacity on first paragraph
                textStorage.addAttribute(.foregroundColor, value: fullOpacityColor, range: firstParagraphRange)
                print("📝 Fixed first paragraph formatting")
            }
        }
        
        // Then check for any title-like text and ensure it's properly styled
        textStorage.enumerateAttribute(.font, in: fullRange, options: []) { (value, range, stop) in
            if let font = value as? NSFont {
                // If it's title text (large font), ensure it's also solid color
                if font.pointSize > 20 {
                    textStorage.addAttribute(.foregroundColor, value: fullOpacityColor, range: range)
                }
            }
        }
        
        textStorage.endEditing()
        print("🎨 Applied full opacity color for current appearance mode: \(isDarkMode ? "dark" : "light")")
        
        // Force immediate layout refresh
        layoutManager?.ensureLayout(for: textContainer!)
        needsDisplay = true
    }
}
#endif
