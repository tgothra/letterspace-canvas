#if os(macOS)
import AppKit

extension DocumentTextView {
    // MARK: - Paste Handling

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        
        // Check if the pasteboard has RTF or attributed string content
        if let attributedString = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)?.first as? NSAttributedString {
            // Get the document's base attributes for text styling
            let baseAttributes = self.typingAttributes
            
            // Create a mutable copy to modify
            let mutableString = NSMutableAttributedString(attributedString: attributedString)
            let range = NSRange(location: 0, length: mutableString.length)
            
            // Apply base paragraph style to ensure consistent layout
            if let baseStyle = baseAttributes[.paragraphStyle] as? NSParagraphStyle {
                mutableString.addAttribute(.paragraphStyle, value: baseStyle, range: range)
            }
            
            // Apply document's font family and size while preserving weight variations
            if let baseFont = baseAttributes[.font] as? NSFont {
                // Go through each character to preserve bold/italic while using document's font
                mutableString.enumerateAttribute(.font, in: range, options: []) { (font, subrange, stop) in
                    if let originalFont = font as? NSFont {
                        // Get traits from original font (bold, italic)
                        let fontManager = NSFontManager.shared
                        let traits = fontManager.traits(of: originalFont)
                        
                        // Create a new font with document's font family but preserve weight
                        var newFont = baseFont
                        
                        // Apply bold if original had it
                        if traits.contains(.boldFontMask) {
                            newFont = fontManager.convert(newFont, toHaveTrait: .boldFontMask)
                        }
                        
                        // Apply italic if original had it
                        if traits.contains(.italicFontMask) {
                            newFont = fontManager.convert(newFont, toHaveTrait: .italicFontMask)
                        }
                        
                        mutableString.addAttribute(.font, value: newFont, range: subrange)
                    } else {
                        // If no font specified, use document's default font
                        mutableString.addAttribute(.font, value: baseFont, range: subrange)
                    }
                }
            }
            
            // Ensure text color matches the editor's theme
            if let baseColor = baseAttributes[.foregroundColor] as? NSColor {
                mutableString.addAttribute(.foregroundColor, value: baseColor, range: range)
            }
            
            // Get the current insertion point
            let initialRange = selectedRange()
            
            // Insert the modified attributed string
            if shouldChangeText(in: initialRange, replacementString: mutableString.string) {
                insertText(mutableString, replacementRange: initialRange)
                
                // Calculate where the cursor should be after the paste
                let newCursorLocation = initialRange.location + mutableString.length
                
                // Set cursor position to the end of the pasted text
                setSelectedRange(NSRange(location: newCursorLocation, length: 0))
                
                // Scroll to make the cursor visible
                scrollRangeToVisible(selectedRange())
                
                didChangeText()
            }
        } else if let plainText = pasteboard.string(forType: .string) {
            // Fallback to plain text if no rich text is available
            let initialRange = selectedRange()
            
            if shouldChangeText(in: initialRange, replacementString: plainText) {
                insertText(plainText, replacementRange: initialRange)
                
                // Calculate where the cursor should be after the paste
                let newCursorLocation = initialRange.location + plainText.count
                
                // Set cursor position to the end of the pasted text
                setSelectedRange(NSRange(location: newCursorLocation, length: 0))
                
                // Scroll to make the cursor visible
                scrollRangeToVisible(selectedRange())
                
                didChangeText()
            }
        } else {
            // Use default paste as last resort
            super.paste(sender)
            
            // Ensure cursor is visible even with default paste
            scrollRangeToVisible(selectedRange())
        }
    }
}
#endif 