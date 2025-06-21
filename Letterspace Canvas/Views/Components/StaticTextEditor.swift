#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Static Text Editor (No Dynamic Height, No Jitters)
struct StaticTextEditor: NSViewRepresentable {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.colorScheme) var colorScheme
    
    func makeNSView(context: Context) -> NSScrollView {
        print("⚡ STATIC EDITOR: Creating jitter-free text editor")
        
        // Create scroll view with minimal configuration
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .overlay
        
        // CRITICAL: Disable dynamic scrolling features that cause jitter
        scrollView.scrollsDynamically = false
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.usesPredominantAxisScrolling = false
        
        // Create text container with FIXED dimensions
        let textContainer = NSTextContainer(containerSize: NSSize(width: 714, height: 10000)) // Fixed large height
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        
        // Create layout manager with minimal features
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true // Allow lazy loading
        layoutManager.backgroundLayoutEnabled = true // Background layout
        layoutManager.showsInvisibleCharacters = false
        layoutManager.showsControlCharacters = false
        
        // Create text storage
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        // Create minimal text view
        let textView = StaticTextView(frame: NSRect(x: 0, y: 0, width: 714, height: 10000), textContainer: textContainer)
        
        // CRITICAL: Disable all dynamic resizing
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []
        
        // Basic configuration only
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        // Set font without complex styling
        let defaultFont = NSFont.systemFont(ofSize: 15)
        let textColor = colorScheme == .dark ? NSColor.white : NSColor.black
        textView.font = defaultFont
        textView.textColor = textColor
        
        // Load content
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
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? StaticTextView else { return }
        
        // Minimal updates only
        let textColor = colorScheme == .dark ? NSColor.white : NSColor.black
        textView.textColor = textColor
        
        context.coordinator.document = document
        
        // Update content if needed
        let currentContent = extractSimpleTextContent(from: document)
        if textView.string != currentContent {
            textView.string = currentContent
        }
    }
    
    private func extractSimpleTextContent(from document: Letterspace_CanvasDocument) -> String {
        return document.elements
            .filter { $0.type == .textBlock }
            .compactMap { $0.content }
            .joined(separator: "\n\n")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: StaticTextView?
        var document: Letterspace_CanvasDocument?
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? StaticTextView else { return }
            
            // CRITICAL: No async operations, no layout invalidation
            updateDocumentSync(textView.string)
        }
        
        private func updateDocumentSync(_ text: String) {
            guard var document = document else { return }
            
            document.elements.removeAll { $0.type == .textBlock }
            
            if !text.isEmpty {
                let textElement = DocumentElement(
                    type: .textBlock,
                    content: text
                )
                document.elements.append(textElement)
            }
            
            self.document = document
        }
    }
}

// MARK: - Static Text View (No Dynamic Sizing)
class StaticTextView: NSTextView {
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupStaticTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupStaticTextView()
    }
    
    private func setupStaticTextView() {
        print("⚡ STATIC EDITOR: Setting up jitter-free text view")
        
        // CRITICAL: Disable layer-based rendering that can cause jitter
        wantsLayer = false
        
        // Disable ALL automatic features
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        
        // Disable smart features that cause layout recalculations
        smartInsertDeleteEnabled = false
        isRichText = false // Force plain text for maximum performance
        
        // Set up simple placeholder
        let placeholderText = "Type here..."
        setValue(NSAttributedString(string: placeholderText, attributes: [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: NSFont.systemFont(ofSize: 15)
        ]), forKey: "placeholderAttributedString")
    }
    
    // CRITICAL: Override all methods that could trigger layout recalculation
    override var intrinsicContentSize: NSSize {
        // Return fixed size to prevent any dynamic calculations
        return NSSize(width: 714, height: 10000)
    }
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool) {
        // Minimal selection handling with NO scrolling
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        // DO NOT call scrollRangeToVisible - let natural scrolling handle it
    }
    
    override func didChangeText() {
        super.didChangeText()
        // CRITICAL: No display invalidation, no layout calls
        // Just let the delegate handle the text change
    }
    
    override func scrollRangeToVisible(_ range: NSRange) {
        // CRITICAL: Completely disable automatic scrolling
        // This is a major source of jitter
        return
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Minimal drawing with placeholder support
        super.draw(dirtyRect)
        
        if string.isEmpty {
            if let placeholder = value(forKey: "placeholderAttributedString") as? NSAttributedString {
                let placeholderRect = NSRect(
                    x: textContainerInset.width,
                    y: textContainerInset.height,
                    width: dirtyRect.width - textContainerInset.width * 2,
                    height: dirtyRect.height - textContainerInset.height * 2
                )
                placeholder.draw(in: placeholderRect)
            }
        }
    }
}

#endif 