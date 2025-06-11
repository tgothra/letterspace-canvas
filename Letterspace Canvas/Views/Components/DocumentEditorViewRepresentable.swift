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
    
    func makeNSView(context: Context) -> NSScrollView {
        print("🏗️ Creating text view...")
        
        // Create the scroll view with improved configuration
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false // We're handling this ourselves
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.scrollerKnobStyle = .light
        scrollView.drawsBackground = false
        
        // Replace the default scroller with our custom one
        let customScroller = SlimScroller()
        customScroller.scrollerStyle = .overlay
        customScroller.knobStyle = .light
        customScroller.controlSize = .small
        customScroller.alphaValue = 1.0 // We'll handle transparency ourselves
        scrollView.verticalScroller = customScroller
        
        // Set reasonable content insets - not too large
        scrollView.contentInsets = NSEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        
        // Create a fixed size container with appropriate sizing
        let containerWidth = 752.0
        let textContainer = NSTextContainer(containerSize: NSSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false // Force fixed width
        textContainer.heightTracksTextView = false
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
        
        // Create the text view with improved configuration
        let textView = DocumentTextView(frame: .zero, textContainer: textContainer)
        
        // Configure appearance and behavior
        textView.font = NSFont(name: "Inter-Regular", size: 15) // Already at 15pt
        textView.textContainerInset = NSSize(width: 19, height: 24) // Increased vertical inset
        textView.isEditable = true
        textView.isSelectable = true
        textView.importsGraphics = true
        textView.isRichText = true
        textView.allowsImageEditing = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        // Set fixed width for text container
        textView.minSize = NSSize(width: containerWidth, height: 0)
        textView.maxSize = NSSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        
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
        
        // --- Use Custom Clip View ---
        // Create and configure clip view for smooth scrolling
        let clipView = BookmarkAwareClipView() // Use our custom clip view
        clipView.drawsBackground = false
        clipView.documentView = textView
        clipView.textView = textView // Pass the textView reference to the clip view
        // --- End Custom Clip View ---
        
        // Set up scroll view with clip view
        scrollView.contentView = clipView
        
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
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Get text view from coordinator
        guard let textView = context.coordinator.textView else { return }
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
            
            // Store current scroll position
            let scrollPosition = scrollView.contentView.bounds.origin
            
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
            
            // Restore scroll position
            scrollView.contentView.bounds.origin = scrollPosition
            
        } else if textView.window?.firstResponder !== textView {
            // This part handles updates when not actively editing (e.g., focus changes)
            // It should preserve existing content unless it's a completely different document (handled above)
            print("🔄 DocumentEditorView updateNSView: Updating content while not actively editing.")

            // Store current scroll position
            let scrollPosition = scrollView.contentView.bounds.origin

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
            
            // Restore scroll position
            scrollView.contentView.bounds.origin = scrollPosition
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
    
    func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        // Clear any text selection
        if let textView = nsView.documentView as? DocumentTextView {
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
