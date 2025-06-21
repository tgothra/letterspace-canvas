#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Ultra-Clean Text Editor (No Headers, Pure Text)
struct CleanDocumentEditor: NSViewRepresentable {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.colorScheme) var colorScheme
    
    func makeNSView(context: Context) -> CleanEditorWrapper {
        print("🚀 ULTRA-CLEAN EDITOR: Creating header-free text editor")
        
        // Create wrapper view for proper height management
        let wrapperView = CleanEditorWrapper()
        
        // Create scroll view with optimal settings
        let scrollView = NSScrollView()
        
        // Configure scroll view for smooth performance
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .overlay
        scrollView.scrollsDynamically = true
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.usesPredominantAxisScrolling = true
        
        // Create text container with fixed width
        let textContainer = NSTextContainer(containerSize: NSSize(width: 714, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        
        // Create layout manager with performance optimizations
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = false
        layoutManager.backgroundLayoutEnabled = false
        layoutManager.showsInvisibleCharacters = false
        layoutManager.showsControlCharacters = false
        
        // Create text storage
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        // Create the ultra-clean text view
        let textView = UltraCleanTextView(frame: .zero, textContainer: textContainer)
        textView.colorScheme = colorScheme
        
        // Configure text view for optimal performance
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 19, height: 19)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        // CRITICAL: Configure for dynamic height growth
        textView.minSize = NSSize(width: 714, height: 100)
        textView.maxSize = NSSize(width: 714, height: CGFloat.greatestFiniteMagnitude)
        
        // Set content priorities for proper SwiftUI integration
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        
        // Set default font and attributes
        let defaultFont = NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
        let textColor = colorScheme == .dark ? NSColor.white : NSColor.black
        
        textView.font = defaultFont
        textView.textColor = textColor
        textView.typingAttributes = [
            .font: defaultFont,
            .foregroundColor: textColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineHeightMultiple = 1.3
                style.paragraphSpacing = 4
                return style
            }()
        ]
        
        // Load simple text content (no complex document structure)
        let textContent = extractSimpleTextContent(from: document)
        if !textContent.isEmpty {
            textView.string = textContent
        }
        
        // Set up coordinator
        context.coordinator.textView = textView
        context.coordinator.document = document
        textView.delegate = context.coordinator
        
        // Add to scroll view
        scrollView.documentView = textView
        
        // Set up wrapper
        wrapperView.scrollView = scrollView
        wrapperView.textView = textView
        wrapperView.addSubview(scrollView)
        
        // Configure scroll view frame
        scrollView.frame = wrapperView.bounds
        scrollView.autoresizingMask = [.width, .height]
        
        return wrapperView
    }
    
    func updateNSView(_ nsView: CleanEditorWrapper, context: Context) {
        guard let textView = nsView.textView else { return }
        
        // Update color scheme
        textView.colorScheme = colorScheme
        let textColor = colorScheme == .dark ? NSColor.white : NSColor.black
        textView.textColor = textColor
        
        // Update coordinator document reference
        context.coordinator.document = document
        
        // Update content if document changed (simple text only)
        let currentContent = extractSimpleTextContent(from: document)
        if textView.string != currentContent {
            textView.string = currentContent
        }
    }
    
    // Extract simple text content, ignoring complex document structure
    private func extractSimpleTextContent(from document: Letterspace_CanvasDocument) -> String {
        // Get all text from text blocks, ignoring headers and other elements
        return document.elements
            .filter { $0.type == .textBlock }
            .compactMap { $0.content }
            .joined(separator: "\n\n")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: UltraCleanTextView?
        var document: Letterspace_CanvasDocument?
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? UltraCleanTextView else { return }
            
            print("🚀 ULTRA-CLEAN EDITOR: Text changed, updating document (plain text only)")
            
            // Update document with simple text content
            DispatchQueue.main.async { [weak self] in
                self?.updateDocumentWithPlainText(textView.string)
            }
        }
        
        private func updateDocumentWithPlainText(_ text: String) {
            guard var document = document else { return }
            
            // Remove all existing text blocks
            document.elements.removeAll { $0.type == .textBlock }
            
            // Add single text block with current content
            if !text.isEmpty {
                let textElement = DocumentElement(
                    type: .textBlock,
                    content: text
                )
                document.elements.append(textElement)
            }
            
            // Update the document reference
            self.document = document
        }
    }
}

// MARK: - Clean Editor Wrapper for Dynamic Height
class CleanEditorWrapper: NSView {
    var scrollView: NSScrollView?
    var textView: UltraCleanTextView?
    
    private var lastReportedHeight: CGFloat = 100
    
    override var intrinsicContentSize: NSSize {
        guard let textView = textView else {
            return NSSize(width: 714, height: 100)
        }
        
        let textViewSize = textView.intrinsicContentSize
        let finalHeight = max(textViewSize.height, 100)
        
        // Only invalidate if height changed significantly
        if abs(finalHeight - lastReportedHeight) > 5 {
            print("🚀 ULTRA-CLEAN EDITOR: Height changed from \(lastReportedHeight) to \(finalHeight)")
            lastReportedHeight = finalHeight
            
            DispatchQueue.main.async { [weak self] in
                self?.superview?.needsLayout = true
                if let scrollView = self?.scrollView {
                    scrollView.needsLayout = true
                }
            }
        }
        
        return NSSize(width: 714, height: finalHeight)
    }
    
    override func layout() {
        super.layout()
        
        // Ensure scroll view fills the wrapper
        scrollView?.frame = bounds
        
        // Update text view height if needed
        if let textView = textView {
            let textSize = textView.intrinsicContentSize
            if textSize.height != textView.frame.height {
                textView.frame.size.height = textSize.height
            }
        }
    }
}

// MARK: - Ultra-Clean Text View (No Headers, Pure Text Focus)
class UltraCleanTextView: NSTextView {
    var colorScheme: ColorScheme = .light
    
    // Cache for performance
    private var lastCalculatedHeight: CGFloat = 100
    private var lastStringLength: Int = 0
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupUltraCleanTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUltraCleanTextView()
    }
    
    private func setupUltraCleanTextView() {
        print("🚀 ULTRA-CLEAN EDITOR: Setting up header-free text view")
        
        // Minimal setup for maximum performance
        wantsLayer = true
        layer?.drawsAsynchronously = false // Synchronous for better text rendering
        
        // Disable features that can cause performance issues
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        
        // Configure for smooth scrolling
        enclosingScrollView?.scrollsDynamically = true
        
        // Set up simple placeholder
        setupSimplePlaceholder()
    }
    
    private func setupSimplePlaceholder() {
        let placeholderText = "Start writing..."
        let placeholderAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
        ]
        
        // Store placeholder using a simple approach
        setValue(NSAttributedString(string: placeholderText, attributes: placeholderAttributes), 
                forKey: "placeholderAttributedString")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Minimal drawing override for performance
        super.draw(dirtyRect)
        
        // Draw placeholder if needed
        if string.isEmpty {
            drawPlaceholder(in: dirtyRect)
        }
    }
    
    private func drawPlaceholder(in rect: NSRect) {
        guard let placeholder = value(forKey: "placeholderAttributedString") as? NSAttributedString else { return }
        
        let placeholderRect = NSRect(
            x: textContainerInset.width,
            y: textContainerInset.height,
            width: rect.width - textContainerInset.width * 2,
            height: rect.height - textContainerInset.height * 2
        )
        
        placeholder.draw(in: placeholderRect)
    }
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool) {
        // Minimal selection handling to prevent jitter
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        
        // Minimal scrolling - only if completely outside visible area
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds
        let selectionRect = firstRect(forCharacterRange: charRange, actualRange: nil)
        
        if !visibleRect.intersects(selectionRect) && charRange.length > 0 {
            scrollRangeToVisible(charRange)
        }
    }
    
    override func didChangeText() {
        super.didChangeText()
        
        // Minimal text change handling
        needsDisplay = true
        
        // CRITICAL: Notify SwiftUI of size changes
        DispatchQueue.main.async { [weak self] in
            self?.invalidateIntrinsicContentSize()
            self?.superview?.needsLayout = true
        }
    }
    
    // CRITICAL: Override intrinsicContentSize for dynamic height
    override var intrinsicContentSize: NSSize {
        // Use cached size if content hasn't changed significantly for performance
        let currentLength = string.count
        if abs(currentLength - lastStringLength) < 10 {
            return NSSize(width: 714, height: lastCalculatedHeight)
        }
        
        // Calculate the actual height needed for the text
        guard let textContainer = textContainer,
              let layoutManager = layoutManager else {
            return NSSize(width: 714, height: 100)
        }
        
        // Ensure layout is up to date
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        
        // Calculate total height including insets
        let contentHeight = usedRect.height + textContainerInset.height * 2
        let finalHeight = max(contentHeight, 100) // Minimum height
        
        // Cache the result
        lastCalculatedHeight = finalHeight
        lastStringLength = currentLength
        
        print("🚀 ULTRA-CLEAN EDITOR: Calculated height: \(finalHeight) for text length: \(currentLength)")
        
        return NSSize(width: 714, height: finalHeight)
    }
    
    // Override to prevent automatic scrolling that causes jitter
    override func scrollRangeToVisible(_ range: NSRange) {
        // Only scroll if the range is significantly outside the visible area
        guard let scrollView = enclosingScrollView else {
            super.scrollRangeToVisible(range)
            return
        }
        
        let visibleRect = scrollView.documentVisibleRect
        let rangeRect = firstRect(forCharacterRange: range, actualRange: nil)
        
        // Add buffer zone to prevent unnecessary scrolling
        let bufferedVisibleRect = visibleRect.insetBy(dx: 0, dy: 50)
        
        if !bufferedVisibleRect.contains(rangeRect.origin) {
            super.scrollRangeToVisible(range)
        }
    }
}

#endif 