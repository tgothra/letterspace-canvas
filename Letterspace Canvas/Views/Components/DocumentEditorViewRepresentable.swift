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
    
    // Header-related bindings
    @Binding var isHeaderExpanded: Bool
    @Binding var headerImage: NSImage?
    @Binding var isShowingImagePicker: Bool
    
    func makeNSView(context: Context) -> NSView {
        print("🏗️ Creating text view with INTEGRATED HEADER approach...")
        
        // Create a wrapper view that will properly size itself
        let wrapperView = DynamicHeightView()
        
        // FIXED: Create container with stable sizing
        let containerWidth = 752.0
        let textContainer = NSTextContainer(containerSize: NSSize(width: containerWidth - 38, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false // Force fixed width
        textContainer.heightTracksTextView = false  // Don't track height
        textContainer.lineFragmentPadding = 0
        
        // OPTIMIZED: Create layout manager with minimal configuration
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = false
        layoutManager.backgroundLayoutEnabled = false // Disable background layout for immediate rendering
        layoutManager.defaultAttachmentScaling = .scaleProportionallyDown
        // Note: defaultLineHeight is a method, we'll set line height via paragraph style instead
        
        // Set up the text storage system
        let textStorage = NSTextStorage()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // Create the text view with INTEGRATED HEADER
        let textView = NoScrollTextView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: 100), textContainer: textContainer)
        
        // DEBUG: Print header state values
        print("🎯 Header Debug - isHeaderExpanded: \(isHeaderExpanded)")
        print("🎯 Header Debug - headerImage: \(headerImage != nil ? "HAS IMAGE" : "NO IMAGE")")
        print("🎯 Header Debug - document.title: '\(document.title)'")
        
        // Configure header state - FORCE VISIBLE FOR TESTING
        textView.isHeaderExpanded = true // Force true for testing
        textView.setHeaderImage(headerImage)
        textView.setTitle(document.title.isEmpty ? "Test Document" : document.title)
        
        print("🎯 Header Debug - Set textView.isHeaderExpanded to: \(textView.isHeaderExpanded)")
        
        // Set up notification observer for header image picker
        NotificationCenter.default.addObserver(
            forName: .headerImagePickerRequested,
            object: textView,
            queue: .main
        ) { _ in
            isShowingImagePicker = true
        }
        
        // Configure appearance and behavior
        textView.font = NSFont(name: "Inter-Regular", size: 15) // Already at 15pt
        textView.isEditable = true
        textView.isSelectable = true
        textView.importsGraphics = true
        textView.isRichText = true
        textView.allowsImageEditing = false
        
        // FIXED: Configure for stable sizing
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []  // No autoresizing
        
        // FIXED: Set size constraints once
        textView.minSize = NSSize(width: containerWidth, height: 50)
        textView.maxSize = NSSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        
        // OPTIMIZED: Minimal priority settings
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
        
        // REMOVED: No layout manager forcing - let it render naturally
        
        // Set default typing attributes with consistent styling across all lines
        let isDarkModeInitial = colorScheme == .dark
        let initialTypingColor = isDarkModeInitial ? NSColor.white : NSColor.black
        textView.typingAttributes = [
            .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                // FIXED: Use consistent line heights for smooth rendering
                style.minimumLineHeight = 19.5
                style.maximumLineHeight = 19.5
                style.lineHeightMultiple = 1.0 // Use 1.0 since we're setting explicit heights
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.paragraphSpacing = 4
                return style
            }(),
            .foregroundColor: initialTypingColor // Explicit color setting based on initial colorScheme
        ]
        
        // Force apply text color to ensure uniform appearance
        textView.forceTextColorForCurrentAppearance()
        
        // SMOOTH: Apply fixed line heights to any existing content
        textView.applyFixedLineHeights()
        
        // IMPORTANT: Explicitly restore scripture attributes when first creating the view
        // This ensures scripture blocks are properly protected from the start
        print("🏗️ Initial restoration of scripture attributes during view creation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Small delay to ensure text is fully loaded before applying attributes
            textView.restoreScriptureAttributes()
            // SMOOTH: Reapply fixed line heights after scripture restoration
            textView.applyFixedLineHeights()
        }
        
        return wrapperView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Get text view from wrapper
        guard let wrapperView = nsView as? DynamicHeightView,
              let textView = wrapperView.textView as? NoScrollTextView else { return }
        textView.colorScheme = colorScheme  // Update colorScheme when it changes
        
        // HEADER INTEGRATION: Update header state
        textView.isHeaderExpanded = isHeaderExpanded
        textView.setHeaderImage(headerImage)
        textView.setTitle(document.title)
        
        // CRITICAL FIX: Force update the header state and ensure editing capability
        let isHeaderExpandedValue = document.isHeaderExpanded
        textView.isHeaderImageCurrentlyExpanded = isHeaderExpandedValue
        
        // If header isn't expanded, force enable editing
        if !isHeaderExpandedValue {
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
        
        // FIXED: Maintain fixed width constraints without forcing layout
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
            
            // Update header content for new document
            textView.setTitle(document.title)
            
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
                
                // SMOOTH: Apply fixed line heights to updated content
                textView.applyFixedLineHeights()
                
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
                    
                    // SMOOTH: Apply fixed line heights to updated content
                    textView.applyFixedLineHeights()
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
            
            // SMOOTH: Apply fixed line heights to new text as it's typed
            if let documentTextView = textView as? DocumentTextView {
                documentTextView.applyFixedLineHeights()
            }
            
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

/// Wrapper view that sizes to its text view content without internal scrolling
class DynamicHeightView: NSView {
    var textView: NSTextView? {
        didSet {
            if let textView = textView {
                // FIXED: Position text view at origin with fixed width
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
            // SMOOTH: Simple frame update, no size change detection
            textView.frame = bounds
        }
    }
}

/// Custom text view that includes header as part of scrollable content
class DocumentTextViewWithHeader: DocumentTextView {
    
    // Header properties
    var headerImageView: NSImageView?
    var titleTextField: NSTextField?
    var subtitleTextField: NSTextField?
    var headerContainerView: NSView?
    var placeholderView: NSView?
    
    // Header state
    var hasHeaderImage: Bool = false
    var isHeaderExpanded: Bool = false {
        didSet {
            updateHeaderVisibility()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupHeaderViews()
    }
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupHeaderViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupHeaderViews()
    }
    
    private func setupHeaderViews() {
        print("🎯 Header Setup - setupHeaderViews() called")
        
        // Create header container
        headerContainerView = NSView()
        headerContainerView?.wantsLayer = true
        headerContainerView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create image view for header image
        headerImageView = NSImageView()
        headerImageView?.imageScaling = .scaleProportionallyUpOrDown
        headerImageView?.wantsLayer = true
        headerImageView?.layer?.cornerRadius = 8
        headerImageView?.layer?.masksToBounds = true
        
        // Create title text field
        titleTextField = NSTextField()
        titleTextField?.isEditable = true
        titleTextField?.isSelectable = true
        titleTextField?.isBordered = false
        titleTextField?.drawsBackground = false
        titleTextField?.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        titleTextField?.placeholderString = "Untitled"
        
        // Create subtitle text field  
        subtitleTextField = NSTextField()
        subtitleTextField?.isEditable = true
        subtitleTextField?.isSelectable = true
        subtitleTextField?.isBordered = false
        subtitleTextField?.drawsBackground = false
        subtitleTextField?.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        subtitleTextField?.placeholderString = "Add a subtitle..."
        
        // Create placeholder view for when no header image
        placeholderView = NSView()
        placeholderView?.wantsLayer = true
        placeholderView?.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.2).cgColor
        placeholderView?.layer?.cornerRadius = 8
        
        // Add click gesture to placeholder
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(headerPlaceholderClicked))
        placeholderView?.addGestureRecognizer(clickGesture)
        
        // Add all to header container
        if let container = headerContainerView,
           let imageView = headerImageView,
           let titleField = titleTextField,
           let subtitleField = subtitleTextField,
           let placeholder = placeholderView {
            
            container.addSubview(imageView)
            container.addSubview(titleField)
            container.addSubview(subtitleField)
            container.addSubview(placeholder)
            
            // Add container to text view
            addSubview(container)
            
            print("🎯 Header Setup - All header views added to container and container added to text view")
        }
        
        updateHeaderVisibility()
        print("🎯 Header Setup - setupHeaderViews() completed")
        
        // Force layout after a short delay to ensure bounds are set
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.layoutHeaderViews()
            print("🎯 Header Setup - Delayed layout call completed")
        }
    }
    
    @objc private func headerPlaceholderClicked() {
        // Notify delegate about image picker request
        NotificationCenter.default.post(name: .headerImagePickerRequested, object: self)
    }
    
    private func updateHeaderVisibility() {
        guard let container = headerContainerView else { return }
        
        print("🎯 Header Visibility - isHeaderExpanded: \(isHeaderExpanded)")
        container.isHidden = !isHeaderExpanded
        print("🎯 Header Visibility - container.isHidden: \(container.isHidden)")
        layoutHeaderViews()
    }
    
    private func layoutHeaderViews() {
        guard let container = headerContainerView,
              let imageView = headerImageView,
              let titleField = titleTextField,
              let subtitleField = subtitleTextField,
              let placeholder = placeholderView else { 
            print("🎯 Header Layout - Missing header views, skipping layout")
            return 
        }
        
        print("🎯 Header Layout - layoutHeaderViews() called")
        print("🎯 Header Layout - bounds: \(bounds)")
        print("🎯 Header Layout - hasHeaderImage: \(hasHeaderImage)")
        
        // SIMPLIFIED: Make header always visible at the top, regardless of bounds height
        let containerWidth = max(bounds.width - 40, 200) // Ensure minimum width
        let headerHeight: CGFloat = 200 // Fixed height for now
        
        // Position header container at the TOP of the text view (y = bounds.height - headerHeight)
        // But if bounds.height is small, position it at y = 0
        let yPosition = max(0, bounds.height - headerHeight)
        container.frame = NSRect(x: 20, y: yPosition, width: containerWidth, height: headerHeight)
        
        // Give container a visible background for debugging
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
        container.layer?.borderColor = NSColor.red.cgColor
        container.layer?.borderWidth = 2.0
        
        print("🎯 Header Layout - container.frame: \(container.frame)")
        
        // Always show placeholder for now (simpler)
        imageView.isHidden = true
        placeholder.isHidden = false
        
        // Simple layout - stack vertically with padding
        let padding: CGFloat = 10
        placeholder.frame = NSRect(x: padding, y: 140, width: containerWidth - 2*padding, height: 50)
        titleField.frame = NSRect(x: padding, y: 100, width: containerWidth - 2*padding, height: 30)
        subtitleField.frame = NSRect(x: padding, y: 60, width: containerWidth - 2*padding, height: 30)
        
        // Give placeholder a visible background
        placeholder.wantsLayer = true
        placeholder.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.7).cgColor
        placeholder.layer?.borderColor = NSColor.black.cgColor
        placeholder.layer?.borderWidth = 1.0
        
        // Make title field visible
        titleField.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.3)
        titleField.isBordered = true
        
        print("🎯 Header Layout - Simplified layout: placeholder.frame: \(placeholder.frame)")
        print("🎯 Header Layout - titleField.frame: \(titleField.frame)")
        
        // Adjust text container inset to account for header
        if isHeaderExpanded {
            textContainerInset = NSSize(width: 19, height: headerHeight + 40)
            print("🎯 Header Layout - Set textContainerInset to: \(textContainerInset)")
        } else {
            textContainerInset = NSSize(width: 19, height: 24)
            print("🎯 Header Layout - Set textContainerInset to default: \(textContainerInset)")
        }
        
        // Force a redraw
        container.needsDisplay = true
        needsDisplay = true
        
        // Ensure container is visible
        container.isHidden = false
        print("🎯 Header Layout - Container visibility: \(container.isHidden ? "HIDDEN" : "VISIBLE")")
    }
    
    override func layout() {
        super.layout()
        print("🎯 Header Layout - DocumentTextViewWithHeader layout() called, bounds: \(bounds)")
        layoutHeaderViews()
    }
    
    func setHeaderImage(_ image: NSImage?) {
        headerImageView?.image = image
        hasHeaderImage = image != nil
        layoutHeaderViews()
    }
    
    func setTitle(_ title: String) {
        print("🎯 Header Title - setTitle called with: '\(title)'")
        titleTextField?.stringValue = title
        print("🎯 Header Title - titleTextField.stringValue set to: '\(titleTextField?.stringValue ?? "nil")'")
    }
    
    func setSubtitle(_ subtitle: String) {
        subtitleTextField?.stringValue = subtitle
    }
}

// Notification for header image picker
extension Notification.Name {
    static let headerImagePickerRequested = Notification.Name("headerImagePickerRequested")
}

/// Custom text view that never scrolls internally and sizes to content
class NoScrollTextView: DocumentTextViewWithHeader {
    
    // FIXED HEIGHT APPROACH - No more dynamic calculations
    private let fixedLineHeight: CGFloat = 19.5 // Inter-Regular at 15pt with 1.3 line height
    private let baseHeight: CGFloat = 100
    private let minHeight: CGFloat = 50
    
    // Cache for performance
    private var cachedHeight: CGFloat = 100
    private var lastLineCount: Int = 0
    
    override var intrinsicContentSize: NSSize {
        // SMOOTH: Calculate height directly from line count, no layout manager
        let lineCount = max(1, string.components(separatedBy: .newlines).count)
        
        // Only recalculate if line count changed
        if lineCount != lastLineCount {
            lastLineCount = lineCount
            
            // Simple calculation: lines * height + padding
            let contentHeight = CGFloat(lineCount) * fixedLineHeight
            let totalHeight = contentHeight + textContainerInset.height * 2
            cachedHeight = max(totalHeight, minHeight)
        }
        
        return NSSize(width: 752, height: cachedHeight)
    }
    
    override func didChangeText() {
        super.didChangeText()
        
        // SMOOTH: Only invalidate if line count actually changed
        let newLineCount = string.components(separatedBy: .newlines).count
        if newLineCount != lastLineCount {
            invalidateIntrinsicContentSize()
        }
    }
    
    override func layout() {
        super.layout()
        
        // FIXED: Set container size once and never change it
        textContainer?.containerSize = NSSize(width: bounds.width - textContainerInset.width * 2, 
                                             height: CGFloat.greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = false
        textContainer?.heightTracksTextView = false
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
    
    // DIRECT RENDERING: Override drawing for immediate feedback
    override func draw(_ dirtyRect: NSRect) {
        // FIXED: Ensure consistent line height through paragraph style instead of layout manager
        // Note: defaultLineHeight is a method, not a property
        super.draw(dirtyRect)
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
        
        // FIXED: Apply consistent line heights to all text
        applyFixedLineHeights()
        
        // Check specifically for any paragraphs with transparent/missing colors
        let nsString = string as NSString
        
        // Extra care for the first paragraph
        if textStorage.length > 0 {
            let firstParagraphRange = nsString.paragraphRange(for: NSRange(location: 0, length: 0))
            if firstParagraphRange.length > 0 {
                // Ensure proper font and style for first paragraph
                let fontAttribute = NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
                textStorage.addAttribute(.font, value: fontAttribute, range: firstParagraphRange)
                
                // FIXED: Create paragraph style with fixed line heights
                let style = NSMutableParagraphStyle()
                style.minimumLineHeight = 19.5
                style.maximumLineHeight = 19.5
                style.lineHeightMultiple = 1.0
                style.paragraphSpacing = 4
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                textStorage.addAttribute(.paragraphStyle, value: style, range: firstParagraphRange)
                
                // Double-ensure color is set correctly with full opacity on first paragraph
                textStorage.addAttribute(.foregroundColor, value: fullOpacityColor, range: firstParagraphRange)
                print("📝 Fixed first paragraph formatting with fixed line heights")
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
        print("🎨 Applied full opacity color and fixed line heights for current appearance mode: \(isDarkMode ? "dark" : "light")")
        
        // Force immediate layout refresh
        layoutManager?.ensureLayout(for: textContainer!)
        needsDisplay = true
    }
    
    // SMOOTH: Apply fixed line heights to all existing text
    func applyFixedLineHeights() {
        guard let textStorage = self.textStorage, textStorage.length > 0 else { return }
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        // Apply fixed line heights to all paragraphs
        textStorage.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { (value, range, stop) in
            let currentStyle = (value as? NSParagraphStyle) ?? NSParagraphStyle.default
            let newStyle = currentStyle.mutableCopy() as! NSMutableParagraphStyle
            
            // FIXED: Set consistent line heights
            newStyle.minimumLineHeight = 19.5
            newStyle.maximumLineHeight = 19.5
            newStyle.lineHeightMultiple = 1.0
            
            textStorage.addAttribute(.paragraphStyle, value: newStyle, range: range)
        }
        
        print("🔧 Applied fixed line heights to all existing text")
    }
}
#endif
