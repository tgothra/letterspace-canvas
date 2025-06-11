#if os(macOS)
import AppKit

extension DocumentTextView {
    // MARK: - KeyDown Handling
    override func keyDown(with event: NSEvent) {
        // Handle Enter and Return keys for the action menu
        if let panel = actionMenuPanel, panel.isVisible {
            if event.keyCode == 36 || event.keyCode == 76 { // Enter or Return key
                activateSelectedAction()
                return
            }
            
            if event.keyCode == 125 { // Down arrow
                navigateActionMenu(direction: 1)
                return
            } else if event.keyCode == 126 { // Up arrow
                navigateActionMenu(direction: -1)
                return
            } else if event.keyCode == 53 { // Escape key
                dismissActionMenu()
                return
            }
            
            // For any other key, dismiss the action menu and allow normal typing
            dismissActionMenu()
            super.keyDown(with: event)
            return
        }
        
        // Escape key handling
        if event.keyCode == 53 { // Escape key
            if let panel = actionMenuPanel, panel.isVisible {
                dismissActionMenu()
                return
            }
        
            // Use escape key as a way to reset state if needed
            if isScriptureSearchActive {
                print("⚠️ Escape pressed while isScriptureSearchActive is true - forcing reset")
                forceResetAllState()
                return
            }
        }
        
        // Special handling for the slash key - ensure state is fully reset before processing
        if event.charactersIgnoringModifiers == "/" {
            print("📢 Slash key detected - ensuring all state is reset before processing")
            // Only reset if we're in an inconsistent state to avoid disrupting normal typing
            if isScriptureSearchActive || actionMenuPanel != nil || scriptureSearchPanel != nil {
                print("⚠️ Found inconsistent state on slash press - forcing reset")
                forceResetAllState()
            }
            
            // IMPORTANT: We need to let the slash be processed normally
            // The text change handler will detect it and show the action menu
            // DO NOT automatically activate the menu here
        }
        
        // Check for space key to dismiss action menu and insert space
        if event.charactersIgnoringModifiers == " " {
            if let panel = actionMenuPanel, panel.isVisible {
                dismissActionMenu()
                super.keyDown(with: event) // Also insert the space
                return
            }
        }
        
        // SCRIPTURE PROTECTION: Handle backspace/delete keys to prevent editing inside scripture blocks
        // but allow deleting entire blocks
        if event.keyCode == 51 || event.keyCode == 117 { // Backspace or Delete key
            let selectedRange = self.selectedRange()
            
            // If cursor is positioned (not a selection)
            if selectedRange.length == 0 {
                if event.keyCode == 51 && selectedRange.location > 0 {
                    // Check the character before the cursor for backspace
                    let checkRange = NSRange(location: selectedRange.location - 1, length: 1)
                    
                    if let textStorage = self.textStorage {
                        // Check if the character before cursor is part of a non-editable region
                        if textStorage.attribute(DocumentTextView.nonEditableAttribute, at: checkRange.location, effectiveRange: nil) != nil {
                            // We need to check if we're at the beginning of a scripture block
                            var effectiveRange = NSRange()
                            textStorage.attribute(DocumentTextView.nonEditableAttribute, 
                                               at: checkRange.location, 
                                               effectiveRange: &effectiveRange)
                            
                            // If we're at the beginning of a scripture block, allow deletion of the entire block
                            if effectiveRange.location == checkRange.location {
                                print("🗑️ Allowing deletion of entire scripture block")
                                // Let the delete operation proceed by calling super
                                super.keyDown(with: event)
                                return
                            } else {
                                // We're inside a scripture block, prevent the edit
                                NSSound.beep() // Provide feedback
                                print("⛔️ Blocked backspace inside scripture block")
                                return // Prevent the backspace operation
                            }
                        }
                    }
                } else if event.keyCode == 117 && selectedRange.location < self.string.count {
                    // Check the character after the cursor for delete key
                    let checkRange = NSRange(location: selectedRange.location, length: 1)
                    
                    if let textStorage = self.textStorage {
                        // Check if the character after cursor is part of a non-editable region
                        if textStorage.attribute(DocumentTextView.nonEditableAttribute, at: checkRange.location, effectiveRange: nil) != nil {
                            // We need to check if we're at the beginning of a scripture block
                            var effectiveRange = NSRange()
                            textStorage.attribute(DocumentTextView.nonEditableAttribute, 
                                               at: checkRange.location, 
                                               effectiveRange: &effectiveRange)
                            
                            // If we're at the beginning of a scripture block, allow deletion of the entire block
                            if effectiveRange.location == checkRange.location {
                                print("🗑️ Allowing deletion of entire scripture block")
                                // Let the delete operation proceed by calling super
                                super.keyDown(with: event)
                                return
                            } else {
                                // We're inside a scripture block, prevent the edit
                                NSSound.beep() // Provide feedback
                                print("⛔️ Blocked deletion inside scripture block")
                                return // Prevent the delete operation
                            }
                        }
                    }
                }
            } else {
                // If there's a selection, check if it fully encompasses a non-editable region
                if let textStorage = self.textStorage {
                    var containsNonEditable = false
                    var isEntireBlock = false
                    
                    textStorage.enumerateAttribute(
                        DocumentTextView.nonEditableAttribute,
                        in: selectedRange,
                        options: []
                    ) { value, range, stop in
                        if value != nil {
                            containsNonEditable = true
                            
                            // Check if the selection fully contains the scripture block
                            if selectedRange.location <= range.location && 
                               (selectedRange.location + selectedRange.length) >= (range.location + range.length) {
                                isEntireBlock = true
                            }
                            
                            stop.pointee = true
                        }
                    }
                    
                    if containsNonEditable {
                        if isEntireBlock {
                            // Allow deletion of entire scripture block
                            print("🗑️ Allowing deletion of selected entire scripture block")
                            // Let the delete operation proceed by calling super
                            super.keyDown(with: event)
                            return
                        } else {
                            // Prevent partial deletion of scripture block
                            NSSound.beep() // Provide feedback
                            print("⛔️ Blocked partial deletion of scripture content")
                            return // Prevent the deletion
                        }
                    }
                }
            }
        }
        
        // Allow normal key processing - slash will now be handled via text change
        super.keyDown(with: event)
        
        // Reset paragraph indentation for certain keys that might create new paragraphs
        if event.keyCode == 51 || event.keyCode == 117 { // Backspace or Delete
            resetParagraphIndentation()
        }
    }

    override func insertNewline(_ sender: Any?) {
        // Store current selection range before newline
        let originalRange = selectedRange()
        
        // Get reference to text storage and document state before modification
        guard let textStorage = self.textStorage,
              let layoutManager = self.layoutManager,
              let textContainer = self.textContainer else {
            super.insertNewline(sender)
            return
        }
        
        // Get content after the cursor position to the end of the visible area
        let visibleRect = self.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        
        // Capture location for later restoration
        let originalLocation = originalRange.location
        
        // Let the superclass handle the actual newline insertion
        super.insertNewline(sender)
        
        // Get the new cursor position
        let newRange = selectedRange()
        
        // Create consistent paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.3
        paragraphStyle.paragraphSpacing = 4
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.headIndent = 0
        
        // Get the current appearance mode
        let isDarkMode = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let textColor = isDarkMode ? NSColor.white : NSColor.black
        
        // Define standard attributes for consistency
        let standardAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: textColor
        ]
        
        // If we successfully inserted a newline, ensure the paragraph styling is consistent
        if newRange.location > originalLocation {
            // Get the range of the newly created paragraph
            let nsString = textStorage.string as NSString
            let newParagraphRange = nsString.paragraphRange(for: NSRange(location: newRange.location, length: 0))
            
            // Apply consistent formatting
            textStorage.beginEditing()
            textStorage.setAttributes(standardAttributes, range: newParagraphRange)
            
            // Critical: Also apply consistent formatting to all affected lines
            // This helps with the pasted content issue
            let linesAfterCursor = NSRange(location: newRange.location, 
                                         length: min(textStorage.length - newRange.location, 
                                                    visibleCharRange.location + visibleCharRange.length - newRange.location))
            
            if linesAfterCursor.length > 0 {
                // Apply standard attributes to lines after cursor
                textStorage.addAttributes(standardAttributes, range: linesAfterCursor)
            }
            
            textStorage.endEditing()
            
            // Update typing attributes for next input
            self.typingAttributes = standardAttributes
        }
        
        // Force layout update and redraw
        layoutManager.ensureLayout(for: textContainer)
        needsDisplay = true
        
        // Force cursor to be visible
        scrollRangeToVisible(newRange)
    }

    // MARK: - Mouse Event Handling
    override func mouseDown(with event: NSEvent) {
        print("🖱️ Mouse down in text view")
        
        // CRITICAL FIX: Remove all header-related checks and force edit mode
        isEditable = true
        isSelectable = true
        isHeaderImageCurrentlyExpanded = false
        
        // Always reset first click flags
        UserDefaults.standard.set(false, forKey: "Letterspace_FirstClickHandled")
        UserDefaults.standard.synchronize()
        
        // Force first responder status
        if let window = self.window {
            window.makeFirstResponder(self)
        }
        
        // Reset counter for future interactions
        clickCounter = 0
        
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        print("🖱️ Mouse dragged in text view")
        super.mouseDragged(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        print("🖱️ Mouse up in text view")
        super.mouseUp(with: event)
    }

    // MARK: - First Responder & Keyboard Shortcuts
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "b":
                    self.toggleBold()
                    return nil
                case "i":
                    self.toggleItalic()
                    return nil
                case "u":
                    self.toggleUnderline()
                    return nil
                case "k":
                    self.insertLink()
                    return nil
                case "l":
                    self.toggleBulletList()
                    return nil
                case "n":
                    self.toggleNumberedList()
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    // MARK: - First Responder Lifecycle
    override func becomeFirstResponder() -> Bool {
        print("🎯 Text view becoming first responder, firstClickHandled=\(UserDefaults.standard.bool(forKey: "Letterspace_FirstClickHandled"))")
        
        // CRITICAL FIX: Remove all header-related checks and always accept first responder status
        
        // Reset flags unconditionally
        UserDefaults.standard.set(false, forKey: "Letterspace_FirstClickHandled")
        UserDefaults.standard.synchronize()
        
        // Force header state to false
        isHeaderImageCurrentlyExpanded = false
        
        // Reset paragraph indentation when focus begins
        resetParagraphIndentation()
        
        // Force text container inset to exact value
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        textContainer?.lineFragmentPadding = 0
        
        // Force layout refresh
        layoutManager?.ensureLayout(for: textContainer!)
        
        // EMERGENCY COLOR OVERRIDE: Force text color based on current appearance
        forceTextColorForCurrentAppearance()
        
        // Only post notification if we're not in scripture search
        if !isScriptureSearchActive {
            NotificationCenter.default.post(name: NSControl.textDidBeginEditingNotification, object: self)
        }
        
        // Delay one more reset after everything else happens
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.resetParagraphIndentation()
            self.needsDisplay = true
        }
        
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        print("👋 Text view resigning first responder")
        
        // CRITICAL: Force save any pending changes BEFORE resigning focus
        if let coordinator = coordinator, !string.isEmpty {
            print("💾 Force saving document before losing focus")
            
            // Create a mutable copy of the attributed string
            if let textStorage = self.textStorage {
                let attributedString = NSMutableAttributedString(attributedString: textStorage)
                
                // Ensure paragraph styles are preserved, especially for scripture
                attributedString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedString.length), options: []) { (value, range, stop) in
                    if let paragraphStyle = value as? NSParagraphStyle {
                        // Create a mutable copy of the paragraph style
                        let mutableStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                        
                        // IMPROVED SCRIPTURE DETECTION: Check comprehensive list of indicators
                        let isScripture = paragraphStyle.headIndent == 60 || paragraphStyle.headIndent == 40 || 
                                          paragraphStyle.headIndent == 120 || paragraphStyle.firstLineHeadIndent == 60 || 
                                          paragraphStyle.firstLineHeadIndent == 40 || paragraphStyle.paragraphSpacing == 120 || 
                                          paragraphStyle.paragraphSpacingBefore == 10 ||
                                          (paragraphStyle.headIndent == 120 && paragraphStyle.firstLineHeadIndent == 40) ||
                                          (paragraphStyle.tabStops.count >= 3 && 
                                           paragraphStyle.tabStops.contains(where: { $0.location >= 80 && $0.location <= 85 }) &&
                                           paragraphStyle.tabStops.contains(where: { $0.location >= 95 && $0.location <= 100 }) &&
                                           paragraphStyle.tabStops.contains(where: { $0.location >= 115 && $0.location <= 125 })) ||
                                          paragraphStyle.lineHeightMultiple >= 1.1 // Also detect scripture based on line height
                        
                        if isScripture {
                            print("📜 Preserving scripture formatting during focus loss at range: \(range)")
                            
                            // Critical: Log the line height details to debug any issues
                            print("📐 Scripture line height: multiple=\(paragraphStyle.lineHeightMultiple), " +
                                  "min=\(paragraphStyle.minimumLineHeight), max=\(paragraphStyle.maximumLineHeight), " +
                                  "spacing=\(paragraphStyle.lineSpacing)")
                            
                            // If lineHeightMultiple is not set, explicitly set it to scripture default
                            if mutableStyle.lineHeightMultiple == 0 {
                                mutableStyle.lineHeightMultiple = 1.2  // Default for scripture
                            }
                        }
                        
                        attributedString.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
                    }
                }
                
                // Convert to RTFD data for storage
                if let rtfdData = attributedString.rtfd(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
                    // Create or update text block element
                    var element = DocumentElement(type: .textBlock)
                    element.content = attributedString.string
                    element.rtfData = rtfdData
                    
                    // Update the document's elements array
                    var updatedDocument = coordinator.parent.document
                    if let index = updatedDocument.elements.firstIndex(where: { $0.type == .textBlock }) {
                        updatedDocument.elements[index] = element
                    } else {
                        updatedDocument.elements.append(element)
                    }
                    
                    // Update document SYNCHRONOUSLY before focus is lost
                    if Thread.isMainThread {
                        coordinator.parent.document = updatedDocument
                        updatedDocument.save()
                        print("💾 Document saved synchronously before losing focus")
                    } else {
                        DispatchQueue.main.sync {
                            coordinator.parent.document = updatedDocument
                            updatedDocument.save()
                            print("💾 Document saved via sync dispatch before losing focus")
                        }
                    }
                }
            }
        }
        
        // IMPORTANT: Store current attributes and selection before focus is lost
        let currentAttributes = typingAttributes
        let currentInset = textContainerInset
        let currentPadding = textContainer?.lineFragmentPadding ?? 0
        
        // Only reset paragraph indentation for NON-SCRIPTURE text
        if let textStorage = self.textStorage {
            // Only apply to non-scripture paragraphs
            let cleanStyle = NSMutableParagraphStyle()
            cleanStyle.firstLineHeadIndent = 0
            cleanStyle.headIndent = 0
            cleanStyle.tailIndent = 0
            cleanStyle.lineSpacing = NSParagraphStyle.default.lineSpacing
            cleanStyle.paragraphSpacing = NSParagraphStyle.default.paragraphSpacing
            cleanStyle.defaultTabInterval = NSParagraphStyle.default.defaultTabInterval
            cleanStyle.alignment = .natural
            cleanStyle.lineHeightMultiple = 1.2 // Changed from 1.0 to 1.2
            
            textStorage.beginEditing()
            
            // Selectively reset only non-scripture paragraphs
            textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: textStorage.length), options: []) { (value, range, stop) in
                if let paragraphStyle = value as? NSParagraphStyle {
                    // COMPREHENSIVE SCRIPTURE DETECTION: 
                    // Check all possible indicators of scripture formatting
                    let isScripture = paragraphStyle.headIndent == 60 || paragraphStyle.headIndent == 40 || 
                                      paragraphStyle.headIndent == 120 || paragraphStyle.firstLineHeadIndent == 60 || 
                                      paragraphStyle.firstLineHeadIndent == 40 || paragraphStyle.paragraphSpacing == 120 || 
                                      paragraphStyle.paragraphSpacingBefore == 10 ||
                                      (paragraphStyle.headIndent == 120 && paragraphStyle.firstLineHeadIndent == 40) ||
                                      (paragraphStyle.tabStops.count >= 3 && 
                                       paragraphStyle.tabStops.contains(where: { $0.location >= 80 && $0.location <= 85 }) &&
                                       paragraphStyle.tabStops.contains(where: { $0.location >= 95 && $0.location <= 100 }) &&
                                       paragraphStyle.tabStops.contains(where: { $0.location >= 115 && $0.location <= 125 })) ||
                                      paragraphStyle.lineHeightMultiple >= 1.1 // Also detect scripture based on line height
                    
                    if !isScripture {
                        // Only reset non-scripture text
                        textStorage.addAttribute(.paragraphStyle, value: cleanStyle, range: range)
                    } else {
                        // Leave scripture formatting untouched
                        // Create a copy to ensure we preserve exactly what we need
                        let scriptureStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                        
                        // If lineHeightMultiple is not set, explicitly set it to scripture default
                        if scriptureStyle.lineHeightMultiple == 0 {
                            scriptureStyle.lineHeightMultiple = 1.2  // Default for scripture
                        }
                        
                        textStorage.addAttribute(.paragraphStyle, value: scriptureStyle, range: range)
                        
                        print("📜 Preserving scripture formatting with line height \(scriptureStyle.lineHeightMultiple) during selective reset")
                    }
                }
            }
            
            textStorage.endEditing()
        }
        
        // Force text container inset to exact value
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        textContainer?.lineFragmentPadding = 0
        
        // Only post notification if we're not in scripture search
        if !isScriptureSearchActive {
            NotificationCenter.default.post(name: NSControl.textDidEndEditingNotification, object: self)
        }
        
        // Call the super implementation now that we've saved everything
        let result = super.resignFirstResponder()
        
        // Delay execution to ensure our changes persist after all other focus handlers run
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Reapply our settings to prevent unwanted changes
            self.typingAttributes = currentAttributes
            self.textContainerInset = currentInset
            self.textContainer?.lineFragmentPadding = currentPadding
            
            // No need to reset paragraph indentation again, as we've selectively preserved scripture formatting
            
            // Force redraw
                self.needsDisplay = true
            }
        
        return result
    }
    
    // Override to prevent losing focus during scripture search
    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        if isScriptureSearchActive {
            // If it's a button or control in the panel, allow it
            if responder is NSButton || responder is NSControl {
                return true
            }
            
            // If it's a text field in the panel, allow it
            if let view = responder as? NSView {
                var current: NSView? = view
                while let currentView = current {
                    if let window = currentView.window, window.className.contains("Panel") {
                        return true
                    }
                    current = currentView.superview
                }
            }
            
            // If it's the main text view, allow it
            if responder === self {
                return true
            }
            
            // For any other view, check if it's in the panel
            if let view = responder as? NSView,
               let window = view.window,
               window.className.contains("Panel") {
                return true
            }
            
            // Otherwise, prevent focus change
            return false
        }
        return super.validateProposedFirstResponder(responder, for: event)
    }

    // MARK: - Click Handling
    // Track first vs second click using UserDefaults
    private var clickCounter: Int {
        get { return UserDefaults.standard.integer(forKey: "LetterSpace_EditorClickCounter") }
        set { 
            UserDefaults.standard.set(newValue, forKey: "LetterSpace_EditorClickCounter")
            UserDefaults.standard.synchronize()
        }
    }
    
    // Reset click counter after delay
    private func scheduleClickCounterReset() {
        // Cancel any existing timer
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(resetClickCounter), object: nil)
        // Schedule new timer
        perform(#selector(resetClickCounter), with: nil, afterDelay: 1.0)
    }
    
    @objc private func resetClickCounter() {
        clickCounter = 0
        print("🔄 Click counter reset to 0")
    }

    // MARK: - State Management Helpers

    internal func forceEnableEditing() {
        // CRITICAL FIX: Always reset all state completely
        isEditable = true
        isSelectable = true
        isScriptureSearchActive = false
        isHeaderImageCurrentlyExpanded = false
        
        // Clear the first click handled flag
        UserDefaults.standard.set(false, forKey: "Letterspace_FirstClickHandled")
        UserDefaults.standard.synchronize()
        
        // Force immediate focus on this text view
        if let window = self.window {
            window.makeKey()
            window.makeMain()
            window.makeFirstResponder(self)
        }
        
        // Ensure text containers are properly configured
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        textContainer?.lineFragmentPadding = 0
        
        // Force layout refresh
        layoutManager?.ensureLayout(for: textContainer!)
        needsDisplay = true
        
        print("🔄 FORCE ENABLED EDITING - All state reset, text view should be fully interactive")
    }
}

// Extension to safely extract substrings
// ... existing code ...

#endif
