import SwiftUI
import AppKit

// MARK: - Document Editor View
struct DocumentEditor: NSViewRepresentable {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var selectedBlock: UUID?
    
    func makeNSView(context: Context) -> NSScrollView {
        // Create the scroll view without vertical scroller (main scroll view handles scrolling)
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        // Create text container for continuous editing
        let textContainer = NSTextContainer(size: NSSize(
            width: 0,  // Will be adjusted by layout
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage()
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // Create and configure the text view
        let textView = DocumentTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.document = document
        textView.onBlockSelected = { blockId in
            selectedBlock = blockId
        }
        
        // Configure for continuous text
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 0, height: 0)
        
        // Basic styling
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .placeholderTextColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        
        // Set up text view sizing
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        // Initialize with placeholder
        textView.string = "Start typing..."
        
        // Enable automatic link detection
        textView.enabledTextCheckingTypes = NSTextCheckingResult.CheckingType.link.rawValue
        
        // Set up paragraph style
        let defaultStyle = NSMutableParagraphStyle()
        defaultStyle.lineSpacing = 8
        defaultStyle.paragraphSpacing = 12
        textView.defaultParagraphStyle = defaultStyle
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? DocumentTextView else { return }
        textView.document = document
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DocumentEditor
        weak var textView: DocumentTextView?
        
        init(_ parent: DocumentEditor) {
            self.parent = parent
        }
        
        // Handle text changes
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? DocumentTextView else { return }
            
            // Handle placeholder text
            if textView.string == "Start typing..." && textView.textColor == .placeholderTextColor {
                textView.string = ""
                textView.textColor = .textColor
            }
            
            // Update paragraph style for new text
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 8
            style.paragraphSpacing = 12
            
            textView.textStorage?.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: textView.string.count))
            
            textView.updateDocument()
        }
        
        // Handle selection changes
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? DocumentTextView else { return }
            textView.handleSelectionChange()
        }
        
        // Handle when text view becomes first responder
        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? DocumentTextView else { return }
            if textView.string == "Start typing..." && textView.textColor == .placeholderTextColor {
                textView.string = ""
                textView.textColor = .textColor
            }
        }
        
        // Handle key commands
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Let the text view handle regular newlines
                return false
            }
            return false
        }
    }
}

// MARK: - Document Text View
class DocumentTextView: NSTextView {
    var document: Letterspace_CanvasDocument?
    var onBlockSelected: ((UUID) -> Void)?
    private var selectionObserver: Any?
    private var formattingToolbar: NSView?
    
    override init(frame: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // Set up keyboard handling
        selectionObserver = NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.handleSelectionChange()
        }
        
        // Enable smart quotes and dashes
        isAutomaticQuoteSubstitutionEnabled = true
        isAutomaticDashSubstitutionEnabled = true
        
        // Enable smooth text input and undo
        allowsUndo = true
        
        // Set up default paragraph style
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        style.paragraphSpacing = 12
        defaultParagraphStyle = style
        
        // Additional text view configuration
        isRichText = true
        isEditable = true
        isSelectable = true
        font = .systemFont(ofSize: 16)
        textColor = .placeholderTextColor
        backgroundColor = .clear
        drawsBackground = false
        
        // Set up text container
        textContainer?.widthTracksTextView = true
        textContainer?.lineFragmentPadding = 0
    }
    
    func handleSelectionChange() {
        let hasSelection = selectedRange().length > 0
        
        if hasSelection {
            showFormattingToolbar()
        } else {
            hideFormattingToolbar()
        }
    }
    
    private func showFormattingToolbar() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let layoutManager = layoutManager else { return }
        
        // Calculate position above selection
        let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer!)
        let position = NSPoint(x: boundingRect.midX, y: boundingRect.minY - 40)
        
        // Create toolbar if needed
        if formattingToolbar == nil {
            formattingToolbar = createFormattingToolbar()
        }
        
        // Position toolbar
        if let toolbar = formattingToolbar {
            toolbar.frame.origin = position
            if toolbar.superview == nil {
                addSubview(toolbar)
            }
        }
    }
    
    private func hideFormattingToolbar() {
        formattingToolbar?.removeFromSuperview()
    }
    
    private func createFormattingToolbar() -> NSView {
        let toolbar = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 40))
        
        // Add formatting buttons here
        // This is a placeholder - we'll implement the actual toolbar UI later
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.white.cgColor
        toolbar.layer?.cornerRadius = 6
        toolbar.layer?.shadowColor = NSColor.black.cgColor
        toolbar.layer?.shadowOpacity = 0.1
        toolbar.layer?.shadowRadius = 4
        toolbar.layer?.shadowOffset = NSSize(width: 0, height: 2)
        
        return toolbar
    }
    
    func updateDocument() {
        // Update document content based on text view content
        // This is where we'll implement block detection and management
    }
    
    override func insertNewline(_ sender: Any?) {
        super.insertNewline(sender)
        
        // Check if we need to create a new block
        let location = selectedRange().location
        let currentLine = self.string.components(separatedBy: .newlines)[max(0, location - 1)]
        
        // Here we'll add logic to:
        // 1. Detect block types (lists, quotes, etc.)
        // 2. Handle block transformations
        // 3. Manage block formatting
    }
    
    // Override paste to handle rich text
    override func paste(_ sender: Any?) {
        if let pasteboard = NSPasteboard.general.string(forType: .string) {
            insertText(pasteboard, replacementRange: selectedRange())
        } else {
            super.paste(sender)
        }
    }
    
    deinit {
        if let observer = selectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
} 