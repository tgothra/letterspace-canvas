#if os(macOS)
import AppKit

extension DocumentTextView {
    // MARK: - Text Change Handling
    @objc func textDidChange(_ notification: Notification) {
        // Check if all content is deleted
        if string.isEmpty {
            // Reset to default paragraph style
            let defaultStyle = NSMutableParagraphStyle()
            defaultStyle.lineSpacing = 0
            defaultStyle.paragraphSpacing = 4
            defaultStyle.lineHeightMultiple = 1.3
            defaultStyle.firstLineHeadIndent = 0
            defaultStyle.headIndent = 0
            
            // Reset typing attributes to defaults - using labelColor for proper dark/light mode support
            typingAttributes = [
                .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15),
                .paragraphStyle: defaultStyle,
                .foregroundColor: NSColor.labelColor
            ]
            
            // Reset text storage attributes if any content remains
            if let textStorage = textStorage {
                textStorage.beginEditing()
                let fullRange = NSRange(location: 0, length: textStorage.length)
                textStorage.removeAttribute(.font, range: fullRange)
                textStorage.removeAttribute(.foregroundColor, range: fullRange)
                textStorage.removeAttribute(.backgroundColor, range: fullRange)
                textStorage.removeAttribute(.underlineStyle, range: fullRange)
                textStorage.removeAttribute(.strikethroughStyle, range: fullRange)
                textStorage.removeAttribute(.paragraphStyle, range: fullRange)
                textStorage.addAttributes(typingAttributes, range: fullRange)
                textStorage.endEditing()
            }
            
            // Force cursor to beginning with explicit positioning
            setSelectedRange(NSRange(location: 0, length: 0))
        } else if let textStorage = textStorage {
            // For non-empty documents, ensure first line formatting is consistent
            let nsString = string as NSString
            let firstLineRange = nsString.paragraphRange(for: NSRange(location: 0, length: 0))
            
            // Only apply if there's an actual first line
            if firstLineRange.length > 0 {
                // Check if the first line has proper formatting
                if let font = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont,
                   font.pointSize != 15 || font.fontName != "Inter-Regular" {
                   
                    // Create consistent paragraph style
                    let style = NSMutableParagraphStyle()
                    style.lineHeightMultiple = 1.3
                    style.paragraphSpacing = 4
                    style.firstLineHeadIndent = 0
                    style.headIndent = 0
                    
                    // Apply consistent formatting to first line
                    textStorage.beginEditing()
                    
                    // First add font and paragraph style
                    textStorage.addAttribute(.font, value: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15), range: firstLineRange)
                    textStorage.addAttribute(.paragraphStyle, value: style, range: firstLineRange)
                    
                    // Get the current appearance mode for proper text color
                    let isDarkMode = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    let fullOpacityColor = isDarkMode ? NSColor.white : NSColor.black
                    
                    // Then explicitly set foreground color to ensure visibility with full opacity
                    textStorage.addAttribute(.foregroundColor, value: fullOpacityColor, range: firstLineRange)
                    
                    textStorage.endEditing()
                    print("🔄 Applied consistent formatting to first line")
                }
            }
            
            // Apply consistent text color throughout the document
            forceTextColorForCurrentAppearance()
        }
        
        // Ensure text container inset is exactly 19px
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        
        // Reset line fragment padding to 0
        textContainer?.lineFragmentPadding = 0
        
        // Force redraw
        needsDisplay = true
    }

    // Add new method to detect slash commands via text change notification
    @objc func handleTextInputChange() {
        // Safety check for inconsistent state - forcibly reset if needed
        if (isScriptureSearchActive && actionMenuPanel == nil && scriptureSearchPanel == nil) ||
           (actionMenuPanel != nil && scriptureSearchPanel != nil) {
            print("⚠️ Detected inconsistent state in handleTextInputChange - forcing reset")
            forceResetAllState()
        }
    
        // Only process if we're not already in a special mode
        if isScriptureSearchActive || actionMenuPanel != nil {
            return
        }
        
        // Check the current insertion point and text
        let range = selectedRange()
        if range.length > 0 || range.location == 0 {
            return // Not an insertion point or at beginning
        }
        
        // Get the text before the cursor
        let nsString = string as NSString
        let previousCharRange = NSRange(location: range.location - 1, length: 1)
        
        // Safety check that we have enough text
        if previousCharRange.location < 0 || 
           previousCharRange.location + previousCharRange.length > nsString.length {
            return
        }
        
        // Get the character before the cursor
        let previousChar = nsString.substring(with: previousCharRange)
        
        // If the character is a slash, show the action menu
        if previousChar == "/" {
            print("📝 Detected slash via text change, showing action menu")
            
            // Ensure any previous state is cleared
            if isScriptureSearchActive {
                print("⚠️ Found inconsistent state before showing action menu - forcing reset")
                forceResetAllState()
            }
            
            // Store the position of the slash character
            slashCommandLocation = previousCharRange.location // Needs to be accessible
            // For now, this will cause an error. We need to make slashCommandLocation internal or handle it via associated object.
            // For simplicity in this step, I'll comment it out. We will address it.
            // print("📝 Slash command location would be: \(previousCharRange.location)") // Placeholder

            // Add a slight delay before showing the action menu to prevent accidental activation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                // Only show if we're still the first responder
                if self.window?.firstResponder === self {
                    print("📝 Showing action menu after delay")
                    self.showActionMenu()
                }
            }
        }
    }

    // MARK: - Scripture Notification Handling
    @objc func handleScriptureLayoutSelection(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let layout = userInfo["layout"] as? Int {
            
            print("🔑 Layout notification received with value: \(layout)")
            
            // Verify raw values match between files
            print("🔢 LAYOUT HANDLER CHECK: individualVerses raw = \(ScriptureLayoutStyle.individualVerses.rawValue)")
            print("🔢 LAYOUT HANDLER CHECK: paragraph raw = \(ScriptureLayoutStyle.paragraph.rawValue)")
            print("🔢 LAYOUT HANDLER CHECK: reference raw = \(ScriptureLayoutStyle.reference.rawValue)")
            
            // Set the next layout that will be used for insertion
            // DocumentTextView.nextScriptureLayout needs to be made internal or handled via associated object
            // For now, this will cause an error. We will address it.
            // For simplicity in this step, I'll comment it out.
            
            switch layout {
            case 0:
                DocumentTextView.nextScriptureLayout = .individualVerses
                print("📜 Next layout set to: Individual Verses")
            case 1:
                DocumentTextView.nextScriptureLayout = .paragraph
                print("📜 Next layout set to: Paragraph")
            case 2:
                DocumentTextView.nextScriptureLayout = .reference
                print("📜 Next layout set to: Reference")
            default:
                DocumentTextView.nextScriptureLayout = .individualVerses
                print("📜 Default next layout set to: Individual Verses (from value \(layout))")
            }
            
            // print("📜 Layout selection would be processed for layout: \(layout)") // Placeholder

        } else {
            print("❌ ERROR: Layout notification received but no valid layout value found")
        }
    }

    func setupScriptureNotifications() {
        // Listen for scripture selection
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ScriptureSelected"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let scripture = notification.object as? ScriptureElement {
                self?.insertScripture(scripture) // insertScripture needs to be accessible
            }
        }
        
        // Listen for scripture search dismissal
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ScriptureSearchDismissed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closeScripturePanel() // closeScripturePanel needs to be accessible
        }
    }

    // Helper method to fix scripture indentation
    internal func fixScriptureIndentation() {
        guard let textStorage = self.textStorage else { return }
        
        // Find scripture blocks with our custom attribute
        textStorage.enumerateAttribute(DocumentTextView.isScriptureBlockQuote, 
                                    in: NSRange(location: 0, length: textStorage.length), 
                                    options: []) { value, range, _ in
            
            // Check if this range has the isScriptureBlockQuote attribute with true value
            guard let hasBlockQuote = value as? Bool, hasBlockQuote else { return }
            
            // Find the end of the scripture block
            let nsString = self.string as NSString
            let end = range.location + range.length
            
            // Safety check - make sure end is valid
            guard end <= nsString.length else { return }
            
            // Find the last paragraph in this range
            var lastParagraphStart = range.location
            for i in (range.location..<end).reversed() {
                if i == range.location || (i > 0 && nsString.character(at: i-1) == 10) { // 10 is newline
                    lastParagraphStart = i
                    break
                }
            }
            
            // Get the paragraph range
            let lastParagraphRange = nsString.paragraphRange(for: NSRange(location: lastParagraphStart, length: 0))
            
            // Get the existing paragraph style
            let existingStyle = textStorage.attribute(.paragraphStyle, at: lastParagraphRange.location, effectiveRange: nil) as? NSParagraphStyle
            
            // Only proceed if we have an existing style to preserve
            if let existing = existingStyle {
                // Create a mutable copy to potentially modify spacing later if needed,
                // but keep indentation and tab stops as they are.
                let mutableStyle = existing.mutableCopy() as! NSMutableParagraphStyle
                
                // **NO LONGER RESETTING INDENTATION HERE**
                // We rely on the initial insertScripture formatting to set the correct style.
                // This method now only ensures the attribute is applied, preserving the original style.
                
                // Re-apply the potentially modified (but indentation-preserved) style
                textStorage.addAttribute(.paragraphStyle, 
                                       value: mutableStyle, 
                                       range: lastParagraphRange)
                print("✅ Preserved existing paragraph style (incl. indentation/tabs) in fixScriptureIndentation for range: \(lastParagraphRange)")
            } else {
                print("⚠️ Could not find existing paragraph style in fixScriptureIndentation for range: \(lastParagraphRange)")
                // Optionally apply a default style here if needed, but it might cause issues.
                // For now, we'll just log if no style is found.
            }
        }
    }
}
#endif 