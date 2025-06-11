#if os(macOS)
import AppKit

// Extension to provide text view reset capabilities and ensure consistent text container settings
extension NSTextView {
    
    /// Resets a text view's layout-related properties and caches to their default state
    func resetLayoutAndCaches() {
        // Store current selection and text
        let currentSelectedRange = selectedRange()
        let attributedString = self.attributedString()
        
        // Reset text storage
        textStorage?.beginEditing()
        
        // Store a backup of the current text
        let mutableText = NSMutableAttributedString(attributedString: attributedString)
        
        // Clear the text storage
        textStorage?.setAttributedString(NSAttributedString(string: ""))
        
        // Reset text container settings
        textContainer?.lineFragmentPadding = 0
        
        // Set the standard inset to exactly 19px
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        
        // Restore the text
        textStorage?.setAttributedString(mutableText)
        textStorage?.endEditing()
        
        // Invalidate layout
        layoutManager?.ensureLayout(for: textContainer!)
        
        // Restore selection if possible
        if currentSelectedRange.location < attributedString.length {
            setSelectedRange(currentSelectedRange)
        } else if attributedString.length > 0 {
            setSelectedRange(NSRange(location: 0, length: 0))
        }
        
        // Force a redraw
        needsDisplay = true
    }
    
    /// Ensures text container has correct settings
    func ensureCorrectTextContainerSettings() {
        // Set line fragment padding to exactly 0
        textContainer?.lineFragmentPadding = 0
        
        // Ensure text container inset is exactly 19px
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        
        // Invalidate and recreate layout
        layoutManager?.ensureLayout(for: textContainer!)
        
        // Force a redraw
        needsDisplay = true
    }
    
    /// Call this when text view is empty to ensure cursor is positioned correctly
    func ensureCorrectEmptyTextCursorPosition() {
        guard string.isEmpty else { return }
        
        // Force cursor to beginning with explicit positioning
        setSelectedRange(NSRange(location: 0, length: 0))
        
        // Reset paragraph style to remove any indent
        let defaultStyle = NSMutableParagraphStyle()
        defaultStyle.defaultTabInterval = NSParagraphStyle.default.defaultTabInterval
        defaultStyle.lineSpacing = NSParagraphStyle.default.lineSpacing
        defaultStyle.paragraphSpacing = NSParagraphStyle.default.paragraphSpacing
        defaultStyle.headIndent = 0
        defaultStyle.tailIndent = 0
        defaultStyle.firstLineHeadIndent = 0
        defaultStyle.alignment = .natural
        
        // Update typing attributes
        typingAttributes[.paragraphStyle] = defaultStyle
        
        // Force redisplay
        needsDisplay = true
    }
    
    /// Check if text subsystem reset is needed based on UserDefaults flag
    /// Call this during view initialization
    func checkForResetFlag() {
        if UserDefaults.standard.bool(forKey: "com.letterspace.forceReinitializeTextViews") {
            // Perform reset operations
            resetLayoutAndCaches()
            
            // Clear the flag for this run
            UserDefaults.standard.set(false, forKey: "com.letterspace.forceReinitializeTextViews")
        }
    }
    
    /// Adds a red debug border to the text view to visualize layout
    func addDebugBorder(color: NSColor = .red, width: CGFloat = 2.0) {
        // Debug visualization disabled
        // To re-enable, uncomment the following code
        
        /*
        // Enable layer for the view if needed
        self.wantsLayer = true
        
        // Set background color to light red for better visibility
        self.backgroundColor = NSColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0)
        
        // Create a CALayer-based border
        self.layer?.borderColor = color.cgColor
        self.layer?.borderWidth = width
        
        // Add visual markers at the 19px inset position
        let insetMarker = NSView(frame: NSRect(x: textContainerInset.width, y: 0, width: 1, height: bounds.height))
        insetMarker.wantsLayer = true
        insetMarker.layer?.backgroundColor = NSColor.blue.cgColor
        self.addSubview(insetMarker)
        
        // Add notification observer to update inset marker when view is resized
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: self, queue: nil) { [weak self, weak insetMarker] _ in
            guard let self = self, let marker = insetMarker else { return }
            marker.frame = NSRect(x: self.textContainerInset.width, y: 0, width: 1, height: self.bounds.height)
        }
        */
    }
    
    /// Shows debug information about text container insets
    func showInsetDebugInfo() {
        // Debug visualization disabled
        // To re-enable, uncomment the following code
        
        /*
        // Create a yellow semi-transparent view to show the text container inset area
        let insetView = NSView(frame: NSRect(x: 0, y: 0, width: textContainerInset.width, height: bounds.height))
        insetView.wantsLayer = true
        insetView.layer?.backgroundColor = NSColor.yellow.withAlphaComponent(0.2).cgColor
        self.addSubview(insetView)
        
        // Create a debug label to show inset measurements
        let debugLabel = NSTextField(labelWithString: """
        TextContainer Inset: \(textContainerInset.width)px
        Line Fragment Padding: \(textContainer?.lineFragmentPadding ?? 0)px
        Total Left Margin: \(textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0))px
        """)
        debugLabel.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        debugLabel.textColor = NSColor.white
        debugLabel.font = NSFont.systemFont(ofSize: 11)
        debugLabel.frame = NSRect(x: 5, y: bounds.height - 55, width: 200, height: 50)
        debugLabel.isBezeled = false
        debugLabel.isEditable = false
        debugLabel.drawsBackground = true
        self.addSubview(debugLabel)
        
        // Update inset views when frame changes
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: self, queue: nil) { [weak self, weak insetView, weak debugLabel] _ in
            guard let self = self else { return }
            
            if let insetView = insetView {
                insetView.frame = NSRect(x: 0, y: 0, width: self.textContainerInset.width, height: self.bounds.height)
            }
            
            if let debugLabel = debugLabel {
                debugLabel.frame = NSRect(x: 5, y: self.bounds.height - 55, width: 200, height: 50)
                debugLabel.stringValue = """
                TextContainer Inset: \(self.textContainerInset.width)px
                Line Fragment Padding: \(self.textContainer?.lineFragmentPadding ?? 0)px
                Total Left Margin: \(self.textContainerInset.width + (self.textContainer?.lineFragmentPadding ?? 0))px
                """
            }
        }
        */
    }
    
    /// Adds a grid for positioning
    func addPositionGrid() {
        // Debug visualization disabled
        // To re-enable, uncomment the following code
        
        /*
        // Create a grid overlay
        let grid = NSView(frame: bounds)
        grid.wantsLayer = true
        self.addSubview(grid)
        
        // Add vertical lines every 20px
        for x in stride(from: 0, to: Int(bounds.width), by: 20) {
            let line = NSView(frame: NSRect(x: CGFloat(x), y: 0, width: 1, height: bounds.height))
            line.wantsLayer = true
            line.layer?.backgroundColor = NSColor.green.withAlphaComponent(0.2).cgColor
            grid.addSubview(line)
        }
        
        // Add horizontal lines every 20px
        for y in stride(from: 0, to: Int(bounds.height), by: 20) {
            let line = NSView(frame: NSRect(x: 0, y: CGFloat(y), width: bounds.width, height: 1))
            line.wantsLayer = true
            line.layer?.backgroundColor = NSColor.green.withAlphaComponent(0.2).cgColor
            grid.addSubview(line)
        }
        
        // Update grid when the view size changes
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: self, queue: nil) { [weak self, weak grid] _ in
            guard let self = self, let grid = grid else { return }
            
            grid.frame = self.bounds
            
            // Clear existing grid lines
            grid.subviews.forEach { $0.removeFromSuperview() }
            
            // Recreate vertical lines
            for x in stride(from: 0, to: Int(self.bounds.width), by: 20) {
                let line = NSView(frame: NSRect(x: CGFloat(x), y: 0, width: 1, height: self.bounds.height))
                line.wantsLayer = true
                line.layer?.backgroundColor = NSColor.green.withAlphaComponent(0.2).cgColor
                grid.addSubview(line)
            }
            
            // Recreate horizontal lines
            for y in stride(from: 0, to: Int(self.bounds.height), by: 20) {
                let line = NSView(frame: NSRect(x: 0, y: CGFloat(y), width: self.bounds.width, height: 1))
                line.wantsLayer = true
                line.layer?.backgroundColor = NSColor.green.withAlphaComponent(0.2).cgColor
                grid.addSubview(line)
            }
        }
        */
    }
}
#endif 