import AppKit

class CanvasTextView: NSTextView {
    var onTextChange: ((NSAttributedString) -> Void)?
    var onBlockSplit: ((Int) -> Void)?
    var onBlockMerge: ((Int, Int) -> Void)?
    var onBlockMove: ((Int, Int) -> Void)?
    var onSelectionChange: ((Bool) -> Void)?
    
    private var draggedRange: NSRange?
    private var dropLocation: Int?
    
    override init(frame: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isRichText = true
        allowsUndo = true
        isEditable = true
        isSelectable = true
        
        // Enable automatic layout
        layoutManager?.allowsNonContiguousLayout = false
        
        // Enable drag and drop
        registerForDraggedTypes([.string, .rtf])
        
        // Listen for text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeText),
            name: NSText.didChangeNotification,
            object: self
        )
        
        // Listen for selection changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: self
        )
    }
    
    // MARK: - Text Formatting
    
    func toggleBold() {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }
        let fontManager = NSFontManager.shared
        
        textStorage?.enumerateAttribute(.font, in: selectedRange) { value, range, stop in
            if let font = value as? NSFont {
                let newFont: NSFont
                if fontManager.weight(of: font) > 5 {
                    newFont = fontManager.convert(font, toHaveTrait: .unitalicFontMask)
                } else {
                    newFont = fontManager.convert(font, toHaveTrait: .boldFontMask)
                }
                textStorage?.addAttribute(.font, value: newFont, range: range)
            }
        }
        
        onTextChange?(attributedString())
    }
    
    func toggleItalic() {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }
        let fontManager = NSFontManager.shared
        
        textStorage?.enumerateAttribute(.font, in: selectedRange) { value, range, stop in
            if let font = value as? NSFont {
                let newFont: NSFont
                if font.fontDescriptor.symbolicTraits.contains(.italic) {
                    newFont = fontManager.convert(font, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = fontManager.convert(font, toHaveTrait: .italicFontMask)
                }
                textStorage?.addAttribute(.font, value: newFont, range: range)
            }
        }
        
        onTextChange?(attributedString())
    }
    
    func setTextColor(_ color: NSColor) {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }
        textStorage?.addAttribute(.foregroundColor, value: color, range: selectedRange)
        onTextChange?(attributedString())
    }
    
    func setHighlightColor(_ color: NSColor) {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }
        textStorage?.addAttribute(.backgroundColor, value: color, range: selectedRange)
        onTextChange?(attributedString())
    }
    
    func toggleUnderline() {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }
        
        var hasUnderline = false
        textStorage?.enumerateAttribute(.underlineStyle, in: selectedRange) { value, range, stop in
            if let style = value as? Int, style != 0 {
                hasUnderline = true
                stop.pointee = true
            }
        }
        
        let style = hasUnderline ? 0 : NSUnderlineStyle.single.rawValue
        textStorage?.addAttribute(.underlineStyle, value: style, range: selectedRange)
        onTextChange?(attributedString())
    }
    
    // MARK: - Notifications
    
    @objc private func selectionDidChange(_ notification: Notification) {
        let hasSelection = selectedRange().length > 0
        onSelectionChange?(hasSelection)
    }
    
    // Handle text changes
    override func didChangeText() {
        super.didChangeText()
        onTextChange?(attributedString())
    }
    
    // Handle key events for block operations
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { // Return key
            if event.modifierFlags.contains(.command) {
                // Split block at cursor
                if let selectedRange = selectedRanges.first?.rangeValue {
                    onBlockSplit?(selectedRange.location)
                    return
                }
            }
        } else if event.keyCode == 51 { // Delete/Backspace key
            if selectedRange.location == 0 && selectedRange.length == 0 {
                // Merge with previous block
                onBlockMerge?(selectedRange.location - 1, selectedRange.location)
                return
            }
        }
        
        super.keyDown(with: event)
    }
    
    // MARK: - Drag and Drop Support
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .move
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let point = convert(sender.draggingLocation, from: nil)
        dropLocation = characterIndex(for: point)
        needsDisplay = true
        return .move
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropLocation = nil
        needsDisplay = true
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let dropLocation = dropLocation,
              let draggedRange = draggedRange else {
            return false
        }
        
        // Calculate source and destination indices
        let sourceIndex = draggedRange.location
        let destinationIndex = dropLocation
        
        // Notify about block move
        onBlockMove?(sourceIndex, destinationIndex)
        
        self.dropLocation = nil
        self.draggedRange = nil
        needsDisplay = true
        
        return true
    }
    
    // Track drag source
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndex(for: point)
        
        // Check if clicking on a block
        if attributedString().attribute(.attachment, at: index, effectiveRange: nil) != nil {
            // Start drag operation
            let range = NSRange(location: index, length: 1)
            draggedRange = range
            
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(String(index), forType: .string)
            
            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            draggingItem.setDraggingFrame(bounds(forRange: range), contents: snapshot(for: range))
            
            beginDraggingSession(with: [draggingItem], event: event, source: self)
            return
        }
        
        super.mouseDown(with: event)
    }
    
    // MARK: - Helper Methods
    
    private func snapshot(for range: NSRange) -> NSImage {
        let rect = bounds(forRange: range)
        let image = NSImage(size: rect.size)
        
        image.lockFocus()
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
            draw(rect)
        }
        image.unlockFocus()
        
        return image
    }
    
    private func bounds(forRange range: NSRange) -> NSRect {
        guard let layoutManager = layoutManager,
              let container = textContainer else {
            return .zero
        }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
    }
    
    // Draw drop target indicator
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let dropLocation = dropLocation {
            NSColor.selectedControlColor.set()
            let rect = bounds(forRange: NSRange(location: dropLocation, length: 0))
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.minY))
            path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
            path.lineWidth = 2
            path.stroke()
        }
    }
} 