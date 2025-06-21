#if os(macOS)
import AppKit
import SwiftUI // For ColorScheme

// Define keys as string constants at the top of the file
private struct AssociatedKeys {
    static let cachedScriptureLineRects = "cachedScriptureLineRects"
    static let lastDrawnVisibleRect = "lastDrawnVisibleRect"
    // Removed placeholderAttributedString as it's accessed directly through the DocumentTextView property
}

extension DocumentTextView {
    // MARK: - Core Overrides
    override var drawsBackground: Bool {
        get { return true }
        set { super.drawsBackground = newValue }
    }

    override var frame: NSRect {
        get { return super.frame }
        set {
            let oldFrame = super.frame
            super.frame = newValue
            
            // Only trigger display update if frame actually changed
            if !oldFrame.equalTo(newValue) {
                // Clear cache when frame changes significantly
                if abs(oldFrame.width - newValue.width) > 1 {
                    cachedScriptureLineRects.removeAll()
                }
                // Remove immediate needsDisplay call - let the system handle it
                // needsDisplay = true
                // layoutManager?.ensureLayout(for: textContainer!)
            }
        }
    }

    // Cache for scripture line rectangles - improves stability when scrolling
    internal var cachedScriptureLineRects: [NSRange: NSRect] {
        get {
            // Attempt to retrieve from associated object
            return objc_getAssociatedObject(self, AssociatedKeys.cachedScriptureLineRects) as? [NSRange: NSRect] ?? [:]
        }
        set {
            // Store in associated object
            objc_setAssociatedObject(self, AssociatedKeys.cachedScriptureLineRects, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var lastDrawnVisibleRect: NSRect {
        get {
            return objc_getAssociatedObject(self, AssociatedKeys.lastDrawnVisibleRect) as? NSRect ?? .zero
        }
        set {
            objc_setAssociatedObject(self, AssociatedKeys.lastDrawnVisibleRect, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        cachedScriptureLineRects.removeAll()
    }

    // MARK: - Drawing Methods
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw placeholder if text is empty
        if string.isEmpty,
           let placeholderString = placeholderAttributedString { // Direct access to the property
            // Calculate the position to draw the placeholder
            var placeholderRect = dirtyRect
            placeholderRect.origin.x = 19  // Reduced by 1 character from 20
            placeholderRect.origin.y = textContainerInset.height + 3  // Moved down by 3 points to better align with cursor
            
            placeholderString.draw(in: placeholderRect)
        }
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        
        // Safety check - make sure we have text storage
        guard let textStorage = self.textStorage, let layoutManager = self.layoutManager else { return }
        
        // Only recalculate the line rects if the visible rect has changed significantly
        let currentVisibleRect = self.visibleRect
        let rectChanged = abs(lastDrawnVisibleRect.origin.y - currentVisibleRect.origin.y) > 5 || 
                         abs(lastDrawnVisibleRect.size.height - currentVisibleRect.size.height) > 5
        
        let shouldRecalculateRects = cachedScriptureLineRects.isEmpty || rectChanged
        
        // Update the last visible rect for future comparisons
        if rectChanged {
            lastDrawnVisibleRect = currentVisibleRect
        }
        
        // Get the selected line color from AppSettings.shared
        let lineColor = AppSettings.shared.scriptureLineNSColor()
        
        // Use NSGraphicsContext to batch drawing operations
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        
        // Find scripture blocks with our custom attribute
        textStorage.enumerateAttribute(DocumentTextView.isScriptureBlockQuote, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, _ in
            // Check if this range has the isScriptureBlockQuote attribute with true value
            guard let hasBlockQuote = value as? Bool, hasBlockQuote else { return }
            
            // Get the visible rect to optimize drawing
            let visibleRect = currentVisibleRect
            
            // Retrieve cached rect or calculate a new one
            var lineRect: NSRect
            
            if shouldRecalculateRects || cachedScriptureLineRects[range] == nil {
                // Create a direct rect for the entire scripture block
                let boundingRect = layoutManager.boundingRect(forGlyphRange: layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil), in: self.textContainer!)
                
                // Calculate insets to trim the extra line height at top and bottom
                let topInset: CGFloat = 24
                
                // Ensure the line extends to include the newline after the scripture
                let extraHeight: CGFloat = 40
                
                // Create adjusted rect for the line - use stable coordinates
                let lineY = round(boundingRect.minY + topInset)
                let lineHeight = round(boundingRect.height - topInset + extraHeight)
                
                // Create a stable, rounded rect for the line
                lineRect = NSRect(
                    x: round(boundingRect.minX + 4), 
                    y: lineY,
                    width: 3, 
                    height: lineHeight
                )
                
                // Cache the calculated rect
                cachedScriptureLineRects[range] = lineRect
            } else {
                // Use the cached rect
                lineRect = cachedScriptureLineRects[range]!
            }
            
            // Only draw if in visible area with some padding
            let expandedVisibleRect = visibleRect.insetBy(dx: 0, dy: -50)
            guard lineRect.intersects(expandedVisibleRect) else { return }
            
            // Draw the vertical line with rounded corners using the selected color
            let bezierPath = NSBezierPath(roundedRect: lineRect, xRadius: 1.5, yRadius: 1.5)
            lineColor.setFill()
            bezierPath.fill()
        }
        
        context.restoreGraphicsState()
    }
    
    private func drawScriptureBackgrounds(in dirtyRect: NSRect) {
        guard let layoutManager = layoutManager,
              let textStorage = textStorage,
              let textContainer = textContainer else { return }

        let glyphRange = layoutManager.glyphRange(forBoundingRect: dirtyRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let scriptureBackgroundColor = colorScheme == .dark ? NSColor(calibratedWhite: 0.15, alpha: 1.0) : NSColor(red: 0.94, green: 0.97, blue: 1.0, alpha: 1.0) // AliceBlue equivalent
        let verticalLineColor = colorScheme == .dark ? NSColor.systemGreen.withAlphaComponent(0.7) : NSColor.systemGreen.withAlphaComponent(0.9)
        
        textStorage.enumerateAttribute(DocumentTextView.isScriptureBlockQuote, in: charRange, options: []) { value, range, _ in
            guard value != nil else { return } 
            
            let scriptureGlyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            
            var blockBoundingRect = NSRect.null
            layoutManager.enumerateLineFragments(forGlyphRange: scriptureGlyphRange) { rect, usedRect, _, glyphRange, _ in
                let lineRect = usedRect.offsetBy(dx: self.textContainerInset.width, dy: self.textContainerInset.height)
                 if blockBoundingRect.isNull {
                    blockBoundingRect = lineRect
                } else {
                    blockBoundingRect = blockBoundingRect.union(lineRect)
                }
            }
            
            guard !blockBoundingRect.isNull else { return }

            let indentWidth: CGFloat = 20.0
            let backgroundRect = NSRect(x: blockBoundingRect.minX,
                                       y: blockBoundingRect.minY,
                                       width: indentWidth,
                                       height: blockBoundingRect.height)
            scriptureBackgroundColor.setFill()
            let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 4, yRadius: 4)
            backgroundPath.fill()
            
            let lineRect = NSRect(x: blockBoundingRect.minX + 5, 
                                y: blockBoundingRect.minY,
                                width: 2,
                                height: blockBoundingRect.height)
            verticalLineColor.setFill()
            let linePath = NSBezierPath(roundedRect: lineRect, xRadius: 1, yRadius: 1)
            linePath.fill()
        }
    }

    // MARK: - Setup
    func setup() { // Made it internal access
        print("🔧 Starting DocumentTextView setup")
        
        // Set up placeholder text
        let style = NSMutableParagraphStyle()
        // Explicitly set paragraph indentation to zero
        style.firstLineHeadIndent = 0
        style.headIndent = 0
        style.tailIndent = 0
        
        // Use placeholderAttributedString directly from DocumentTextView
        // No longer accessing through associated object
        self.placeholderAttributedString = NSAttributedString(
            string: "Write the vision and make it plain...",
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15),
                .paragraphStyle: style
            ]
        )
        
        // Basic configuration
        isRichText = true
        isEditable = true
        isSelectable = true
        allowsUndo = true
        
        // Set text container inset to exactly 19 as specified
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        
        // Set line fragment padding to 0 as specified
        if let textContainer = textContainer {
            textContainer.lineFragmentPadding = 0
        }
        
        // Important: Configure layout manager for better scrolling performance
        if let layoutManager = layoutManager {
            layoutManager.showsInvisibleCharacters = false
            layoutManager.showsControlCharacters = false
            layoutManager.allowsNonContiguousLayout = false
            layoutManager.backgroundLayoutEnabled = true
        }
        
        // Set up default paragraph style with zero indentation
        let defaultStyle = NSMutableParagraphStyle()
        defaultStyle.defaultTabInterval = NSParagraphStyle.default.defaultTabInterval
        defaultStyle.lineSpacing = NSParagraphStyle.default.lineSpacing
        defaultStyle.paragraphSpacing = NSParagraphStyle.default.paragraphSpacing
        defaultStyle.headIndent = 0
        defaultStyle.tailIndent = 0
        defaultStyle.firstLineHeadIndent = 0
        defaultStyle.alignment = .natural
        defaultStyle.lineHeightMultiple = 1.2 // Changed from default to 1.2
        defaultParagraphStyle = defaultStyle
        
        // Set up typing attributes with Inter-Regular font and zero indentation
        typingAttributes = [
            .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15),
            .paragraphStyle: defaultStyle,
            .foregroundColor: NSColor.textColor
        ]
        
        // Enable formatting toolbar
        setupFormattingToolbar() // This method needs to be accessible
        print("✅ Formatting toolbar has been set up")
        
        // Set up keyboard shortcuts
        // setupKeyboardShortcuts() // This method also needs to be accessible (likely in Interaction extension)
        
        // Add observer for selection changes - important for showing the toolbar
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)), // This method needs to be accessible (likely in Selection extension)
            name: NSTextView.didChangeSelectionNotification,
            object: self
        )
        print("✅ Selection change observer registered")
        
        // Add observer for text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)), // This method will need to be accessible
            name: NSText.didChangeNotification,
            object: self
        )
        
        // Add new observer for detecting slash command
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextInputChange), // This method will need to be accessible
            name: NSTextView.didChangeNotification,
            object: self
        )
        
        // Add observer for scripture layout selection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScriptureLayoutSelection(_:)), // This method will need to be accessible
            name: NSNotification.Name("ScriptureLayoutSelected"),
            object: nil
        )
        
        // Set up the scripture notification handlers
        setupScriptureNotifications() // This method will need to be accessible
        
        // Force text color for current appearance mode initially
        // viewDidChangeEffectiveAppearance will handle subsequent changes.
        forceTextColorForCurrentAppearance()
        
        print("✅ DocumentTextView setup complete")
    }

    // MARK: - Appearance Handling
    // Removed setupAppearanceObserver and appearanceDidChangeNotification
    // as viewDidChangeEffectiveAppearance is the standard and preferred way.

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance() // Always call super

        print("🎨 Effective appearance changed. Updating text and typing attributes.")
        forceTextColorForCurrentAppearance() // Updates existing text storage

        // Update typingAttributes as well
        let isDarkMode = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let newTypingColor = isDarkMode ? NSColor.white : NSColor.black
        
        var currentTypingAttributes = self.typingAttributes
        currentTypingAttributes[.foregroundColor] = newTypingColor
        self.typingAttributes = currentTypingAttributes
        
        print("✒️ Typing attributes updated for new appearance.")
    }
}

// Define a struct for associated object keys to avoid string literals
// REMOVED: Duplicate AssociatedKeys struct to fix redeclaration issue
// private struct AssociatedKeys {
//     static var cachedScriptureLineRects = "cachedScriptureLineRects"
//     static var lastDrawnVisibleRect = "lastDrawnVisibleRect"
//     static var placeholderAttributedString = "placeholderAttributedString"
// }

// Extension to make placeholderAttributedString accessible via associated objects
// REMOVED: This extension conflicts with the property already declared in DocumentTextView
// extension DocumentTextView {
//     var placeholderAttributedString: NSAttributedString? {
//         get {
//             return objc_getAssociatedObject(self, AssociatedKeys.placeholderAttributedString) as? NSAttributedString
//         }
//         set {
//             objc_setAssociatedObject(self, AssociatedKeys.placeholderAttributedString, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
//         }
//     }
// }
#endif 