#if os(macOS)
import SwiftUI
import AppKit
import Combine

// Extension for DocumentTextView - Formatting Logic
extension DocumentTextView {
    func setupFormattingToolbar() {
        print("🔧 Setting up formatting toolbar...")
        
        // Create floating panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 40),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel for proper visibility
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = true // Enable panel shadow
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.contentView?.wantsLayer = true
        
        // Hide standard window buttons
        panel.hideStandardButtons()
        
        // Add a visible border
        panel.contentView?.layer?.borderWidth = 0.5
        panel.contentView?.layer?.borderColor = NSColor.gray.withAlphaComponent(0.2).cgColor
        panel.contentView?.layer?.cornerRadius = 8
        panel.contentView?.layer?.masksToBounds = true
        
        // Get current formatting
        let formatting = getCurrentFormatting()
        
        // Create toolbar view using the shared TextFormattingToolbar
        let toolbar = NSHostingView(rootView: TextFormattingToolbar(
            onBold: { [weak self] in
                self?.toggleBold()
            },
            onItalic: { [weak self] in
                self?.toggleItalic()
            },
            onUnderline: { [weak self] in
                self?.toggleUnderline()
            },
            onLink: { [weak self] in
                self?.insertLink()
            },
            onTextColor: { [weak self] color in
                self?.applyTextColor(color)
            },
            onHighlight: { [weak self] color in
                // Convert SwiftUI Color to NSColor with proper color mapping
                let nsColor: NSColor
                switch color {
                    case .yellow: nsColor = .systemYellow.withAlphaComponent(0.3)
                    case .green: nsColor = .systemGreen.withAlphaComponent(0.3)
                    case .blue: nsColor = .systemBlue.withAlphaComponent(0.3)
                    case .pink: nsColor = .systemPink.withAlphaComponent(0.3)
                    case .purple: nsColor = .systemPurple.withAlphaComponent(0.3)
                    case .orange: nsColor = .systemOrange.withAlphaComponent(0.3)
                    case .clear: nsColor = .clear
                    default: nsColor = .clear
                }
                self?.setHighlightColor(nsColor)
            },
            onBulletList: { [weak self] in
                self?.toggleBulletList()
            },
            onTextStyleSelect: { [weak self] style in self?.applyTextStyle(style) },
            onAlignment: { [weak self] alignment in
                self?.applyAlignment(alignment)
            },
            onBookmark: { [weak self] in self?.toggleBookmark() },
            isBold: formatting.isBold,
            isItalic: formatting.isItalic,
            isUnderlined: formatting.isUnderlined,
            hasLink: formatting.hasLink,
            currentTextColor: formatting.textColor,
            currentHighlightColor: formatting.highlightColor,
            hasBulletList: formatting.hasBulletList,
            isBookmarked: formatting.isBookmarked,
            currentAlignment: formatting.textAlignment
        )) // REMOVE .environment modifier from here
        
        // Configure toolbar view for animations
        toolbar.wantsLayer = true
        toolbar.layer?.masksToBounds = true
        
        // Set the content view and position
        panel.contentView = toolbar
        formattingToolbarPanel = panel
        
        print("✅ Formatting toolbar setup complete")
    }

    func showFormattingToolbar() {
        print("🔍 Attempting to show formatting toolbar")
        
        guard let selectedRange = selectedRanges.first as? NSRange,
              let layoutManager = layoutManager,
              let textContainer = textContainer else {
            print("❌ Missing critical components to show toolbar")
            return
        }
        
        guard let window = self.window else {
            print("❌ No window available for toolbar")
            return
        }
        
        // If the toolbar panel doesn't exist yet, create it
        if formattingToolbarPanel == nil {
            print("🔧 Creating new formatting toolbar panel")
            setupFormattingToolbar()
        }
        
        guard let panel = formattingToolbarPanel else {
            print("❌ Failed to create formatting toolbar panel")
            return
        }
        
        // Calculate position above selection
        let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Convert the bounding rect to window coordinates
        let localPoint = NSPoint(
            x: boundingRect.midX + textContainerOrigin.x,
            y: boundingRect.minY + textContainerOrigin.y
        )
        let windowPoint = convert(localPoint, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        
        // Position panel above the selection
        let spacing: CGFloat = 8
        let panelX = screenPoint.x - (panel.frame.width / 2)
        let panelY = screenPoint.y + spacing
        
        if !panel.isVisible {
            print("✅ Showing formatting toolbar")
            
            // Get current formatting
            let formatting = getCurrentFormatting()
            
            // Create a fresh toolbar view each time to ensure default state
            let toolbar = NSHostingView(rootView: TextFormattingToolbar(
                onBold: { [weak self] in
                    print("Bold button pressed")
                    self?.toggleBold()
                },
                onItalic: { [weak self] in
                    print("Italic button pressed")
                    self?.toggleItalic()
                },
                onUnderline: { [weak self] in
                    print("Underline button pressed")
                    self?.toggleUnderline()
                },
                onLink: { [weak self] in
                    print("Link button pressed")
                    self?.insertLink()
                },
                onTextColor: { [weak self] color in
                    print("Text color button pressed: \(color)")
                    self?.applyTextColor(color)
                },
                onHighlight: { [weak self] color in
                    print("Highlight button pressed: \(color)")
                    // Convert SwiftUI Color to NSColor with proper color mapping
                    let nsColor: NSColor
                    switch color {
                        case .yellow: nsColor = .systemYellow.withAlphaComponent(0.3)
                        case .green: nsColor = .systemGreen.withAlphaComponent(0.3)
                        case .blue: nsColor = .systemBlue.withAlphaComponent(0.3)
                        case .pink: nsColor = .systemPink.withAlphaComponent(0.3)
                        case .purple: nsColor = .systemPurple.withAlphaComponent(0.3)
                        case .orange: nsColor = .systemOrange.withAlphaComponent(0.3)
                        case .clear: nsColor = .clear
                        default: nsColor = .clear
                    }
                    self?.setHighlightColor(nsColor)
                },
                onBulletList: { [weak self] in
                    print("Bullet list button pressed")
                    self?.toggleBulletList()
                },
                onTextStyleSelect: { [weak self] style in self?.applyTextStyle(style) },
                onAlignment: { [weak self] alignment in
                    print("Alignment changed to: \(alignment)")
                    self?.applyAlignment(alignment)
                },
                onBookmark: { [weak self] in self?.toggleBookmark() },
                isBold: formatting.isBold,
                isItalic: formatting.isItalic,
                isUnderlined: formatting.isUnderlined,
                hasLink: formatting.hasLink,
                currentTextColor: formatting.textColor,
                currentHighlightColor: formatting.highlightColor,
                hasBulletList: formatting.hasBulletList,
                isBookmarked: formatting.isBookmarked,
                currentAlignment: formatting.textAlignment
            )) // REMOVE .environment modifier from here
            
            
            // Configure toolbar view for animations
            toolbar.wantsLayer = true
            toolbar.layer?.masksToBounds = true
            
            // Set the content view and position
            panel.contentView = toolbar
            panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
            
            // Add window without animation
            NSAnimationContext.runAnimationGroup({
                context in
                context.duration = 0 // Ensure no animation duration
            window.addChildWindow(panel, ordered: .above)
            })
            
            /* Animation code removed
            // Create spring animation for scale
            let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.95
            scaleAnim.toValue = 1.0
            scaleAnim.damping = 35
            scaleAnim.mass = 0.5
            scaleAnim.initialVelocity = 0
            scaleAnim.stiffness = 800
            scaleAnim.duration = scaleAnim.settlingDuration
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            toolbar.layer?.transform = CATransform3DIdentity
            toolbar.layer?.filters = []
            CATransaction.commit()
            
            toolbar.layer?.add(scaleAnim, forKey: "popupAnimation")
            */
        }
    }

    func hideFormattingToolbar() {
        if let panel = formattingToolbarPanel {
            // Remove window without animation
            NSAnimationContext.runAnimationGroup({
                context in
                context.duration = 0 // Ensure no animation duration
            if let parent = panel.parent {
                parent.removeChildWindow(panel)
            }
            panel.orderOut(nil)
            })
            print("🔽 Hiding formatting toolbar")
        }
    }

    // Helper to get current formatting at selection
    func getCurrentFormatting() -> TextFormatting {
        var formatting = TextFormatting()
        guard let textStorage = self.textStorage, selectedRange().location != NSNotFound else {
            // Return default if no text storage or selection
            return formatting
        }

        let range: NSRange
        if selectedRange().length > 0 {
            range = selectedRange()
        } else if selectedRange().location > 0 && selectedRange().location <= textStorage.length {
            // If no selection, use attributes of character before cursor, or first char if at doc start
            range = NSRange(location: max(0, selectedRange().location - 1), length: 1)
        } else if textStorage.length > 0 {
             // If at the very beginning of the document (location 0, length 0) and there's content
            range = NSRange(location: 0, length: 1)
        }
        else {
            return formatting // Empty document
        }
        
        // Ensure range is valid
        guard range.location + range.length <= textStorage.length else {
            return formatting
        }


        let attributes = textStorage.attributes(at: range.location, effectiveRange: nil)

        if let font = attributes[.font] as? NSFont {
            let traits = NSFontManager.shared.traits(of: font)
            formatting.isBold = traits.contains(.boldFontMask)
            formatting.isItalic = traits.contains(.italicFontMask)
        }

        formatting.isUnderlined = (attributes[.underlineStyle] as? Int) != nil && (attributes[.underlineStyle] as? Int) != 0
        formatting.hasLink = attributes[.link] != nil

        if let nsColor = attributes[.foregroundColor] as? NSColor {
            formatting.textColor = Color(nsColor)
        } else {
            // Determine default based on appearance
            let isDarkMode = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            formatting.textColor = isDarkMode ? .white : .black
        }
        
        // Check for custom highlight first, then standard background
        if let customHighlightColor = attributes[HighlightConstants.customHighlight] as? NSColor {
            formatting.highlightColor = Color(customHighlightColor)
        } else if let bgColor = attributes[.backgroundColor] as? NSColor, bgColor != .clear, bgColor.alphaComponent > 0.1 { // Heuristic for actual highlight
            formatting.highlightColor = Color(bgColor)
        }


        if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
            // Check for bullet list (prefix "•\\t" and specific indentation)
            let lineText = (textStorage.string as NSString).substring(with: (textStorage.string as NSString).paragraphRange(for: range))
            formatting.hasBulletList = (lineText.hasPrefix("•\\t") || lineText.hasPrefix("• ")) && paragraphStyle.headIndent > 0


            // Check for numbered list (prefix like "1.\\t" and specific indentation)
            // A more robust check might involve looking for a list style marker if you add one
            let numberPattern = "^\\\\d+\\\\.\\\\s"
             if let regex = try? NSRegularExpression(pattern: numberPattern),
               let match = regex.firstMatch(in: lineText, options: [], range: NSRange(location: 0, length: lineText.utf16.count)) {
                 if match.range.location == 0 && paragraphStyle.headIndent > 0 {
                    formatting.hasNumberedList = true
                 }
            }

            switch paragraphStyle.alignment {
            case .left, .natural:
                formatting.textAlignment = .leading
            case .center:
                formatting.textAlignment = .center
            case .right:
                formatting.textAlignment = .trailing
            default:
                formatting.textAlignment = .leading // Default
            }
        }
        
        // Check for bookmark attribute
        formatting.isBookmarked = attributes[NSAttributedString.Key.isBookmark] as? Bool ?? false


        return formatting
    }
    
    // MARK: - Formatting Methods
    
    // Add a helper method to preserve scroll position during formatting operations
    func performFormattingWithPreservedScroll(_ formattingAction: () -> Void) {
        // Store current visible rect before formatting
        let oldVisibleRect = visibleRect
        
        // Perform the formatting action
        formattingAction()
        
        // Restore scroll position
        scrollToVisible(oldVisibleRect)
    }
    
    func toggleBold() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        performFormattingWithPreservedScroll {
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selectedRange) { fontAttribute, subrange, _ in
            if let currentFont = fontAttribute as? NSFont {
                let traits = NSFontManager.shared.traits(of: currentFont)
                let isBold = traits.contains(.boldFontMask)
                
                // Use our utility method to ensure consistent font conversion
                let newFont = if isBold {
                    convertFont(currentFont, removeTrait: .boldFontMask)
                } else {
                    convertFont(currentFont, addTrait: .boldFontMask)
                }
                
                textStorage.addAttribute(.font, value: newFont, range: subrange)
            }
        }
        textStorage.endEditing()
        needsDisplay = true
        
        // Save changes
        if let coordinator = coordinator {
            coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
            }
        }
    }
    
    func toggleItalic() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        performFormattingWithPreservedScroll {
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selectedRange) { fontAttribute, subrange, _ in
            if let currentFont = fontAttribute as? NSFont {
                let traits = NSFontManager.shared.traits(of: currentFont)
                let isItalic = traits.contains(.italicFontMask)
                
                // Use our utility method to ensure consistent font conversion
                let newFont = if isItalic {
                    convertFont(currentFont, removeTrait: .italicFontMask)
                } else {
                    convertFont(currentFont, addTrait: .italicFontMask)
                }
                
                textStorage.addAttribute(.font, value: newFont, range: subrange)
                
                // Apply kerning (letter spacing) for italic text or remove it for non-italic
                if !isItalic {
                    // Adding italic, so add kerning of 0.4
                    textStorage.addAttribute(.kern, value: 0.4, range: subrange)
                } else {
                    // Removing italic, so remove kerning
                    textStorage.removeAttribute(.kern, range: subrange)
                }
            }
        }
        textStorage.endEditing()
        needsDisplay = true
        
        // Save changes
        if let coordinator = coordinator {
            coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
            }
        }
    }
    
    func toggleUnderline() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        performFormattingWithPreservedScroll {
            let isUnderlined = (textStorage.attribute(.underlineStyle, at: selectedRange.location, effectiveRange: nil) as? Int) != nil
        
        textStorage.beginEditing()
        if isUnderlined {
            textStorage.removeAttribute(.underlineStyle, range: selectedRange)
        } else {
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
        }
        textStorage.endEditing()
        needsDisplay = true
        
        // Save changes
        if let coordinator = coordinator {
            coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
            }
        }
    }
    
    func insertLink() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        let panel = NSAlert()
        panel.messageText = "Insert Link"
        panel.informativeText = "Enter the URL:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        panel.accessoryView = textField
        panel.addButton(withTitle: "OK")
        panel.addButton(withTitle: "Cancel")
        
        if panel.runModal() == .alertFirstButtonReturn {
            var urlString = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Don't proceed if the URL is empty
            guard !urlString.isEmpty else { return }
            
            // Add "https://" if the URL doesn't already have a scheme
            if !urlString.contains("://") {
                // If it starts with "www." or has a domain suffix like ".com", ".org", etc.
                // we'll assume it's a web URL and add https://
                urlString = "https://" + urlString
            }
            
            if let url = URL(string: urlString) {
                textStorage.beginEditing()
                textStorage.addAttribute(.link, value: url, range: selectedRange)
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
                textStorage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: selectedRange)
                textStorage.endEditing()
                needsDisplay = true
                
                // Save changes to ensure links persist
                if let coordinator = coordinator {
                    coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
                }
            }
        }
    }
    
    func applyTextColor(_ color: Color) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        performFormattingWithPreservedScroll {
        textStorage.beginEditing()
        
            // Convert SwiftUI Color to NSColor
            var nsColor: NSColor = .black
        if color == .clear {
                // Special case: explicitly set the appropriate default color based on appearance
            textStorage.removeAttribute(.foregroundColor, range: range)
                
                // Get the current appearance
                let isDarkMode = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                
                // Apply pure white for dark mode, pure black for light mode
                let defaultColor = isDarkMode ? NSColor.white : NSColor.black
                textStorage.addAttribute(.foregroundColor, value: defaultColor, range: range)
        } else {
                // Apply the selected color
                switch color {
                case .red: nsColor = .systemRed
                case .blue: nsColor = .systemBlue
                case .green: nsColor = .systemGreen
                case .orange: nsColor = .systemOrange
                case .purple: nsColor = .systemPurple
                case .pink: nsColor = .systemPink
                case .gray: nsColor = .systemGray
                case .brown: nsColor = .brown
                default: nsColor = .labelColor
                }
                
            textStorage.addAttribute(.foregroundColor, value: nsColor, range: range)
        }
        
        textStorage.endEditing()
        needsDisplay = true
        
        // Save changes
        if let coordinator = coordinator {
            coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
            }
        }
    }
    
    // MARK: Custom Text Highlighting
    
    // Custom method to apply highlight with visual adjustment (shorter from top, longer at bottom)
    func applyCustomHighlight(_ color: NSColor, range: NSRange) {
        guard let textStorage = textStorage,
              let layoutManager = layoutManager,
              let textContainer = textContainer else { return }
        
        performFormattingWithPreservedScroll {
            // Remove any existing highlight first
            textStorage.removeAttribute(.backgroundColor, range: range)
            
            // Remove any existing customHighlight attributes (both ways)
            textStorage.removeAttribute(HighlightConstants.customHighlight, range: range)
            textStorage.removeAttribute(NSAttributedString.Key("customHighlight"), range: range)
            
            // We'll use a custom attribute that our drawing code will recognize
            HighlightConstants.logHighlight("Applying customHighlight", range: range, color: color)
            textStorage.addAttribute(HighlightConstants.customHighlight, value: color, range: range)
            
            // Make sure layout is up to date
            layoutManager.ensureLayout(for: textContainer)
            
            // Force redraw
            needsDisplay = true
        }
    }
    
    // Update our highlight color method to use the custom implementation
    func setHighlightColor(_ color: NSColor) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        
        if color == NSColor.clear {
            // Just remove both standard and custom highlights
            textStorage?.removeAttribute(.backgroundColor, range: range)
            textStorage?.removeAttribute(HighlightConstants.customHighlight, range: range)
            textStorage?.removeAttribute(NSAttributedString.Key("customHighlight"), range: range)
            needsDisplay = true
            print("🧹 Removed highlight at range \(range)")
        } else {
            // Apply standard .backgroundColor for proper highlighting
            print("🖌️ Setting highlight color to \(color) at range \(range)")
            textStorage?.removeAttribute(HighlightConstants.customHighlight, range: range)
            textStorage?.addAttribute(.backgroundColor, value: color, range: range)
        }
        
        // Save changes
        if let coordinator = coordinator {
            coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
        }
    }
    
    func applyFontSize(_ size: CGFloat) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        performFormattingWithPreservedScroll {
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { fontAttribute, subrange, _ in
            if let currentFont = fontAttribute as? NSFont {
                let newFont = NSFont(descriptor: currentFont.fontDescriptor, size: size) ?? currentFont
                textStorage.addAttribute(.font, value: newFont, range: subrange)
            }
        }
        textStorage.endEditing()
        needsDisplay = true
        }
    }
    
    func applyAlignment(_ alignment: TextAlignment) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        performFormattingWithPreservedScroll {
            let nsString = string as NSString
            textStorage.beginEditing()
            
            // Create the paragraph style with the desired alignment
        let paragraphStyle = NSMutableParagraphStyle()
        switch alignment {
        case .leading:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .trailing:
            paragraphStyle.alignment = .right
        }
        
            // Apply alignment to all paragraphs in the selection range
            var location = range.location
            while location < range.location + range.length {
                // Get the paragraph range containing this location
                let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
                
                // Apply the style to this paragraph
                textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
                
                // Move to the next paragraph
                location = paragraphRange.location + paragraphRange.length
                
                // Safety check to avoid infinite loops if something goes wrong
                if paragraphRange.length == 0 {
                    break
                }
            }
            
        textStorage.endEditing()
        needsDisplay = true
        }
    }
    
    func toggleBulletList() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        performFormattingWithPreservedScroll {
            // Get the paragraph range containing the selection start
            let paragraphRange = (textStorage.string as NSString).paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
            let currentAttributes = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            let currentParagraphStyle = currentAttributes[.paragraphStyle] as? NSParagraphStyle ?? NSParagraphStyle.default

            // Check if the line already starts with a bullet and has list indentation
            let lineText = (textStorage.string as NSString).substring(with: paragraphRange)
            let isAlreadyBulletList = lineText.hasPrefix("•\t") || (lineText.hasPrefix("• ") && currentParagraphStyle.headIndent > 0)

            textStorage.beginEditing()

            if isAlreadyBulletList {
                // --- REMOVE BULLET LIST FORMATTING ---
                print("⚫️ Removing bullet list formatting")
                // 1. Remove the bullet prefix ("• " or "•\t")
                if lineText.hasPrefix("•\t") {
                    textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: 2))
                } else if lineText.hasPrefix("• ") {
                    textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: 2))
                }

                // 2. Apply default paragraph style (reset indentation)
                let defaultStyle = defaultParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                defaultStyle.headIndent = 0
                defaultStyle.firstLineHeadIndent = 0
                // Keep alignment
                defaultStyle.alignment = currentParagraphStyle.alignment
                // Adjust the range to account for the deleted characters if needed
                let adjustedParagraphRange = NSRange(location: paragraphRange.location, length: max(0, paragraphRange.length - 2))
                textStorage.addAttribute(.paragraphStyle, value: defaultStyle, range: adjustedParagraphRange)

            } else {
                // --- APPLY BULLET LIST FORMATTING ---
                print("⚫️ Applying bullet list formatting")
                // 1. Apply list paragraph style (indentation)
                let listStyle = currentParagraphStyle.mutableCopy() as! NSMutableParagraphStyle
                listStyle.headIndent = 30 // Indentation for the list item text
                listStyle.firstLineHeadIndent = 10 // Indentation before the bullet
                 // Add a tab stop for alignment after the bullet
                listStyle.tabStops = [NSTextTab(textAlignment: .left, location: 30)]
                listStyle.defaultTabInterval = 30 // Ensure default tab interval matches
                textStorage.addAttribute(.paragraphStyle, value: listStyle, range: paragraphRange)

                // 2. Insert the bullet prefix ("•\t" for proper alignment)
                let bulletPrefix = "•\t" // Use tab for alignment
                let bulletAttributes: [NSAttributedString.Key: Any] = [
                    .font: currentAttributes[.font] ?? NSFont.systemFont(ofSize: 15),
                    .paragraphStyle: listStyle // Ensure prefix has the list style
                ]
                let attributedBullet = NSAttributedString(string: bulletPrefix, attributes: bulletAttributes)
                textStorage.insert(attributedBullet, at: paragraphRange.location)
            }

            textStorage.endEditing()
            needsDisplay = true

            // Save changes
            if let coordinator = coordinator {
                coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
            }
        }
    }
    
    func toggleNumberedList() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        performFormattingWithPreservedScroll {
            // Get the paragraph range containing the selection start
            let paragraphRange = (textStorage.string as NSString).paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
            let currentAttributes = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            let currentParagraphStyle = currentAttributes[.paragraphStyle] as? NSParagraphStyle ?? NSParagraphStyle.default

            // Check if the line already starts with a number pattern (e.g., "1. ") and has list indentation
            let lineText = (textStorage.string as NSString).substring(with: paragraphRange)
            let numberPattern = "^\\d+\\.\\s" // Regex for "1. ", "2. ", etc. (Escaped backslashes)
            var numberPrefixLength = 0
            var isAlreadyNumberedList = false
            if let regex = try? NSRegularExpression(pattern: numberPattern),
               let match = regex.firstMatch(in: lineText, options: [], range: NSRange(location: 0, length: lineText.utf16.count)) {
                 if match.range.location == 0 && currentParagraphStyle.headIndent > 0 {
                    isAlreadyNumberedList = true
                    numberPrefixLength = match.range.length
                 }
            }


                textStorage.beginEditing()

            if isAlreadyNumberedList {
                // --- REMOVE NUMBERED LIST FORMATTING ---
                print("🔢 Removing numbered list formatting")
                // 1. Remove the number prefix (e.g., "1. ")
                 if numberPrefixLength > 0 {
                    textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: numberPrefixLength))
                }

                // 2. Apply default paragraph style (reset indentation)
                let defaultStyle = defaultParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                defaultStyle.headIndent = 0
                defaultStyle.firstLineHeadIndent = 0
                // Keep alignment
                defaultStyle.alignment = currentParagraphStyle.alignment
                // Adjust the range to account for the deleted characters
                let adjustedParagraphRange = NSRange(location: paragraphRange.location, length: max(0, paragraphRange.length - numberPrefixLength))
                textStorage.addAttribute(.paragraphStyle, value: defaultStyle, range: adjustedParagraphRange)

            } else {
                // --- APPLY NUMBERED LIST FORMATTING ---
                print("🔢 Applying numbered list formatting")
                 // 1. Apply list paragraph style (indentation)
                let listStyle = currentParagraphStyle.mutableCopy() as! NSMutableParagraphStyle
                listStyle.headIndent = 30 // Indentation for the list item text
                listStyle.firstLineHeadIndent = 10 // Indentation before the number
                 // Add a tab stop for alignment after the number
                listStyle.tabStops = [NSTextTab(textAlignment: .left, location: 30)]
                 listStyle.defaultTabInterval = 30 // Ensure default tab interval matches
                textStorage.addAttribute(.paragraphStyle, value: listStyle, range: paragraphRange)

                // 2. Insert the number prefix ("1.\t" for now, future improvement could track number)
                let numberPrefix = "1.\t" // Start with 1. Use tab for alignment
                 let numberAttributes: [NSAttributedString.Key: Any] = [
                    .font: currentAttributes[.font] ?? NSFont.systemFont(ofSize: 15),
                    .paragraphStyle: listStyle // Ensure prefix has the list style
                ]
                let attributedNumber = NSAttributedString(string: numberPrefix, attributes: numberAttributes)
                textStorage.insert(attributedNumber, at: paragraphRange.location)
            }

            textStorage.endEditing()
            needsDisplay = true

            // Save changes
            if let coordinator = coordinator {
                coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
            }
        }
    }
    
    // MARK: - Font Utility Methods
    
    /// Consistently convert fonts to maintain the Inter/InterTight font family while changing traits
    private func convertFont(_ font: NSFont, addTrait: NSFontTraitMask? = nil, removeTrait: NSFontTraitMask? = nil) -> NSFont {
        let currentTraits = NSFontManager.shared.traits(of: font)
        let size = font.pointSize
        
        // Determine which Inter font variant to use based on combined traits
        var finalTraits = currentTraits
        if let addTrait = addTrait {
            finalTraits.insert(addTrait)
        }
        if let removeTrait = removeTrait {
            finalTraits.remove(removeTrait)
        }
        
        // Map traits to specific font variants
        // Use Inter for regular/bold, InterTight for italic variants
        let fontName: String
        if finalTraits.contains(.boldFontMask) && finalTraits.contains(.italicFontMask) {
            fontName = "InterTight-BoldItalic" // Use InterTight for bold+italic
        } else if finalTraits.contains(.boldFontMask) {
            fontName = "Inter-Bold" // Use Inter for bold
        } else if finalTraits.contains(.italicFontMask) {
            fontName = "InterTight-Italic" // Use InterTight for italic
        } else {
            fontName = "Inter-Regular" // Use Inter for regular
        }
        
        // Try to create the font with the correct name
        if let newFont = NSFont(name: fontName, size: size) {
            return newFont
        } else {
            // Try alternate font names if the primary choice isn't available
            let alternativeFontName: String?
            if fontName == "InterTight-BoldItalic" {
                alternativeFontName = "InterTight-SemiBoldItalic" // Try semi-bold as fallback
            } else if fontName == "InterTight-Italic" {
                alternativeFontName = "InterTight-RegularItalic" // Try regular italic as fallback
            } else if fontName == "Inter-Bold" {
                alternativeFontName = "Inter-SemiBold" // Try semi-bold as fallback
            } else {
                alternativeFontName = nil
            }
            
            // Try the alternative name if one exists
            if let altName = alternativeFontName, let altFont = NSFont(name: altName, size: size) {
                print("📝 Using alternative font: \(altName) instead of \(fontName)")
                return altFont
            }
            
            // If all else fails, use the system font manager's conversion
            print("⚠️ Font \(fontName) not available, falling back to system conversion")
            var baseFont = font
            if let removeTrait = removeTrait {
                baseFont = NSFontManager.shared.convert(baseFont, toNotHaveTrait: removeTrait)
            }
            if let addTrait = addTrait {
                baseFont = NSFontManager.shared.convert(baseFont, toHaveTrait: addTrait)
            }
            return baseFont
        }
    }
    
    // Placeholder for applying text styles
    func applyTextStyle(_ styleName: String) {
        print("🎨 Applying text style: \(styleName)")
        
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        // Store current scroll position
        let savedVisibleRect = visibleRect
        
        var attributes: [NSAttributedString.Key: Any] = [:]
        let baseFontSize: CGFloat = 15 // Define base font size
        let defaultFont = NSFont(name: "Inter-Regular", size: baseFontSize) ?? NSFont.systemFont(ofSize: baseFontSize)
        
        // Special style behaviors
        var applyToParagraph = false
        var needsNewLine = false
        var isBlockStyle = false
        
        // Determine attributes based on style name
        switch styleName {
        case "Title":
            attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: baseFontSize * 2.2, weight: .regular) // Non-bold, 2.2x size
            attributes[NSAttributedString.Key.foregroundColor] = NSColor.labelColor // Explicitly set color for title
            let paragraphStyle = NSMutableParagraphStyle()
            // Add more spacing before and after titles
            paragraphStyle.paragraphSpacingBefore = baseFontSize * 1.2
            paragraphStyle.paragraphSpacing = baseFontSize * 1.0
            // Adjust line height to create appropriate visual spacing
            paragraphStyle.lineHeightMultiple = 1.2
            paragraphStyle.minimumLineHeight = baseFontSize * 2.5
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            needsNewLine = true
            isBlockStyle = true
            
        case "Heading":
            attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: baseFontSize * 1.7, weight: .semibold) // 1.7x size
            let paragraphStyle = NSMutableParagraphStyle()
            // Add proper spacing around headings
            paragraphStyle.paragraphSpacingBefore = baseFontSize * 1.0
            paragraphStyle.paragraphSpacing = baseFontSize * 0.8
            paragraphStyle.lineHeightMultiple = 1.1
            paragraphStyle.minimumLineHeight = baseFontSize * 2.0
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            needsNewLine = true
            isBlockStyle = true
            
        case "Strong":
            // Now using medium weight at 1.13x size instead of bold trait
            attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: baseFontSize * 1.13, weight: .medium)
            // Strong remains inline - does not apply to paragraph
            
        case "Body":
            attributes[NSAttributedString.Key.font] = defaultFont
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacingBefore = baseFontSize * 0.2
            paragraphStyle.paragraphSpacing = baseFontSize * 0.2
            paragraphStyle.lineHeightMultiple = 1.3
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            applyToParagraph = true // Body *should* apply to the entire paragraph
            
        case "Caption":
            attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: baseFontSize * 0.87, weight: .regular)
            // No color changes to respect user's color choices
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacingBefore = baseFontSize * 0.8
            paragraphStyle.paragraphSpacing = baseFontSize * 0.6
            paragraphStyle.lineHeightMultiple = 1.15
            paragraphStyle.minimumLineHeight = baseFontSize * 1.2
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            applyToParagraph = true // Apply to the entire paragraph
            needsNewLine = false // Keep the paragraph intact
            isBlockStyle = false // Don't treat as a block style
            
        default:
            attributes[NSAttributedString.Key.font] = defaultFont
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 1.3
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            applyToParagraph = true // Ensure default also applies paragraph-wide
        }
        
        // Begin editing
        textStorage.beginEditing()
        
        var finalRange = selectedRange
        var finalSelectionRange = selectedRange
        
        // Get text before and after selection
        let nsString = string as NSString
        _ = nsString.substring(with: selectedRange)
        
        // Check if we should create a new line
        if needsNewLine && selectedRange.length > 0 {
            // Get the paragraph range containing the selection
            let currentParagraphRange = nsString.paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
            
            // Check if selection is already its own paragraph
            let selectedTextIsFullParagraph = (currentParagraphRange.location == selectedRange.location &&
                                             currentParagraphRange.length == selectedRange.length)
            
            // If the selected text is not already its own paragraph, or if it already has a style we're changing
            let needsToAddLines = !selectedTextIsFullParagraph
            
            // Check if this text already has a block style that we're changing (to avoid duplicate linebreaks)
            if !needsToAddLines && isBlockStyle {
                // We'll reuse the existing paragraph structure but apply new style
                // No need to add additional lines
                finalRange = currentParagraphRange
            } else if needsToAddLines {
                // Create a mutable attributed string with the current text
                let mutableString = NSMutableAttributedString(attributedString: textStorage)
                var insertedChars = 0
                
                // ALWAYS insert a newline before the selection for Title/Heading
                // unless it's already at the very beginning of the document
                if selectedRange.location > 0 {
                    // Check if there's already a newline before
                    let hasNewlineBefore = selectedRange.location > 0 &&
                        nsString.substring(with: NSRange(location: selectedRange.location - 1, length: 1)) == "\n"
                    
                    // Only add if needed
                    if !hasNewlineBefore {
                        let newline = NSAttributedString(string: "\n", attributes: getBodyStyleAttributes())
                        mutableString.insert(newline, at: selectedRange.location)
                        insertedChars += 1
                    }
                }
                
                // Update the affected range after inserting the first newline
                finalRange = NSRange(location: selectedRange.location + insertedChars,
                                   length: selectedRange.length)
                
                // ALWAYS insert a newline after the selection for Title/Heading
                // unless it's already at the very end of the document
                if finalRange.location + finalRange.length < nsString.length {
                    // Check if there's already a newline after
                    let checkLocation = finalRange.location + finalRange.length
                    let hasNewlineAfter = checkLocation < nsString.length &&
                        nsString.substring(with: NSRange(location: checkLocation, length: 1)) == "\n"
                    
                    
                    // Only add if needed
                    if !hasNewlineAfter {
                        let newline = NSAttributedString(string: "\n", attributes: getBodyStyleAttributes())
                        mutableString.insert(newline, at: finalRange.location + finalRange.length)
                    }
                }
                
                // Apply all changes to the text storage
                textStorage.setAttributedString(mutableString)
                
                // Position cursor at the end of the styled text
                finalSelectionRange = NSRange(location: finalRange.location + finalRange.length, length: 0)
            }
        } else if applyToParagraph {
            // For paragraph styles, process all paragraphs in the selection
            if selectedRange.length > 0 {
                // When multiple paragraphs are selected, handle each paragraph separately
                let nsString = string as NSString
                var paragraphRanges: [NSRange] = []
                
                // Start with the paragraph containing the selection start
                var currentParagraphStart = selectedRange.location
                let selectionEnd = NSMaxRange(selectedRange)
                
                // Collect all paragraph ranges within the selection
                while currentParagraphStart < selectionEnd {
                    let paraRange = nsString.paragraphRange(for: NSRange(location: currentParagraphStart, length: 0))
                    paragraphRanges.append(paraRange)
                    
                    // Move to the next paragraph if there is one
                    let nextParagraphStart = NSMaxRange(paraRange)
                    if nextParagraphStart <= currentParagraphStart {
                        // Safety check to prevent infinite loop
                        break
                    }
                    currentParagraphStart = nextParagraphStart
                }
                
                // Apply styles to each paragraph
                for range in paragraphRanges {
                    // Apply attributes to this paragraph
                    for (key, value) in attributes {
                        // Skip foregroundColor as we handle it separately
                        if key != NSAttributedString.Key.foregroundColor {
                            textStorage.addAttribute(key, value: value, range: range)
                        }
                    }
                    
                    // Always use the labelColor for proper dark/light mode support
                    textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.labelColor, range: range)
                }
                
                // Keep the original selection
                finalRange = selectedRange
            } else {
                // Single insertion point, just format the current paragraph
            finalRange = getParagraphRange(for: selectedRange.location)
            }
        }
        
        // Apply the style attributes
        if !attributes.isEmpty {
            // Use explicit full opacity color based on appearance for proper dark/light mode support
            let isDarkMode = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let fullOpacityColor = isDarkMode ? NSColor.white : NSColor.black
            
            // Apply all attributes including explicit color for text
            var styleWithColor = attributes
            styleWithColor[NSAttributedString.Key.foregroundColor] = fullOpacityColor
            
            for (key, value) in styleWithColor {
                textStorage.addAttribute(key, value: value, range: finalRange)
            }
        }
        
        textStorage.endEditing()
        
        // Set final selection
        setSelectedRange(finalSelectionRange)
        
        // Restore scroll position and ensure cursor is visible
        scrollToVisible(savedVisibleRect)
        scrollRangeToVisible(selectedRange)
        
        // Ensure layout and display update
        layoutManager?.ensureLayout(for: textContainer!)
        needsDisplay = true
        
        // Ensure text colors are correctly applied for all text
        if let textStorage = self.textStorage {
            // Apply full opacity color to all text to ensure consistent appearance
            let isDarkMode = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let fullOpacityColor = isDarkMode ? NSColor.white : NSColor.black
            
            let fullRange = NSRange(location: 0, length: textStorage.length)
            textStorage.addAttribute(.foregroundColor, value: fullOpacityColor, range: fullRange)
        }
        
        // Trigger text change notification to update binding and save
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: self)
    }
    
    // Helper method to get the range of the entire paragraph containing a location
    func getParagraphRange(for location: Int) -> NSRange {
        let nsString = string as NSString
        
        // Create an explicit range object for the location
        let locationRange = NSRange(location: location, length: 0)
        
        // Find the paragraph range
        return nsString.paragraphRange(for: locationRange)
    }
    
    // Helper method to check if a location is at the start of a paragraph
   func isAtStartOfParagraph(_ location: Int) -> Bool {
        // Always treat the beginning of the document as a paragraph start
        if location == 0 {
            return true
        }
        
        // Check if the character immediately before the location is a newline
        let nsString = self.string as NSString
        let previousLocation = location - 1
        
        // Safety check - make sure previousLocation is valid
        guard previousLocation >= 0 && previousLocation < nsString.length else {
            return false
        }
        
        // Check the previous character
        let characterRange = NSRange(location: previousLocation, length: 1)
        let previousChar = nsString.substring(with: characterRange)
        return previousChar == "\n"
    }
    
    // Helper to get Body style attributes
    func getBodyStyleAttributes() -> [NSAttributedString.Key: Any] {
        let baseFontSize: CGFloat = 15 // Consistent 15pt font size
        let defaultFont = NSFont(name: "Inter-Regular", size: baseFontSize) ?? .systemFont(ofSize: baseFontSize)
        
        // Create a consistent paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = baseFontSize * 0.2
        paragraphStyle.paragraphSpacing = baseFontSize * 0.2
        paragraphStyle.lineHeightMultiple = 1.3 // Consistent line height multiple
        
        // Ensure default alignment and indentation
        paragraphStyle.alignment = .natural
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.headIndent = 0
        
        // Always use NSColor.labelColor for correct appearance in both light and dark modes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: defaultFont,
            .paragraphStyle: paragraphStyle,
            .kern: 0, // No kerning for natural letter spacing
            .foregroundColor: NSColor.labelColor
        ]
        
        return attributes
    }
    
    // Add the resetParagraphIndentation method
    func resetParagraphIndentation() {
        // Create a clean paragraph style with zero indentation
        let cleanStyle = NSMutableParagraphStyle()
        cleanStyle.firstLineHeadIndent = 0
        cleanStyle.headIndent = 0
        cleanStyle.tailIndent = 0
        
        // Preserve other paragraph style attributes from default style
        cleanStyle.lineSpacing = NSParagraphStyle.default.lineSpacing
        cleanStyle.paragraphSpacing = NSParagraphStyle.default.paragraphSpacing
        cleanStyle.defaultTabInterval = NSParagraphStyle.default.defaultTabInterval
        cleanStyle.alignment = .natural
        cleanStyle.lineHeightMultiple = 1.3  // Changed from 1.2 to 1.3
        
        // Apply to entire text or to typing attributes if empty
        if string.isEmpty {
            typingAttributes[.paragraphStyle] = cleanStyle
        } else {
            // Only reset if we have text storage and not in the middle of editing
            if let textStorage = self.textStorage, window?.firstResponder === self {
                textStorage.beginEditing()
                
                // IMPROVED: Selectively reset only non-scripture paragraphs
                textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: textStorage.length), options: []) { (value, range, stop) in
                    if let paragraphStyle = value as? NSParagraphStyle {
                        // COMPREHENSIVE SCRIPTURE DETECTION: Check all possible indicators
                        let isScripture = paragraphStyle.headIndent == 60 || paragraphStyle.headIndent == 40 || 
                                          paragraphStyle.headIndent == 120 || paragraphStyle.firstLineHeadIndent == 60 || 
                                          paragraphStyle.firstLineHeadIndent == 40 || paragraphStyle.paragraphSpacing == 120 || 
                                          paragraphStyle.paragraphSpacingBefore == 10 ||
                                          (paragraphStyle.headIndent == 120 && paragraphStyle.firstLineHeadIndent == 40) ||
                                          (paragraphStyle.tabStops.count >= 3 && 
                                           paragraphStyle.tabStops.contains(where: { $0.location >= 80 && $0.location <= 85 }) &&
                                           paragraphStyle.tabStops.contains(where: { $0.location >= 95 && $0.location <= 100 }) &&
                                           paragraphStyle.tabStops.contains(where: { $0.location >= 115 && $0.location <= 125 })) ||
                                          paragraphStyle.lineHeightMultiple >= 1.1 // Also check line height
                        
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
                            
                            print("📜 Preserving scripture formatting with line height \(scriptureStyle.lineHeightMultiple) in resetParagraphIndentation()")
                        }
                    }
                }
                
                textStorage.endEditing()
            }
        }
        
        // Force text container inset to exact value
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        if let container = textContainer {
            container.lineFragmentPadding = 0
        }
        
        // Force layout refresh
        layoutManager?.ensureLayout(for: textContainer!)
        needsDisplay = true
    }
}

#endif
