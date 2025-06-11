#if os(macOS)
import AppKit
import SwiftUI

extension DocumentTextView {
    // MARK: - Selection Change Handling
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity = .downstream, stillSelecting: Bool = false) {
        // Call the original implementation first
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)

        // Handle toolbar visibility based on selection length
        let hasSelection = charRange.length > 0
        print("📍 Selection changed: length=\(charRange.length), location=\(charRange.location)")
        if hasSelection {
            print("📢 Selection detected - showing formatting toolbar")
            DispatchQueue.main.async { [weak self] in
                self?.showFormattingToolbar()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.hideFormattingToolbar()
            }
        }

        // --- FIX ---
        // After super call and toolbar logic, explicitly call our controlled scroll method.
        // This ensures *our* logic (which prevents scrolling if already visible)
        // is the last thing to run regarding scrolling for this selection change.
        print("🖱️ Explicitly calling scrollRangeToVisible from setSelectedRange override...")
        self.scrollRangeToVisible(charRange)
        // --- END FIX ---

        // Update toolbar with current formatting if it exists AND there is still a selection
        if let panel = formattingToolbarPanel, panel.isVisible, self.selectedRange().length > 0 {
            let formatting = getCurrentFormatting()

            // Create a new toolbar view
            let newToolbar = NSHostingView(rootView: TextFormattingToolbar(
                onBold: { [weak self] in self?.toggleBold() },
                onItalic: { [weak self] in self?.toggleItalic() },
                onUnderline: { [weak self] in self?.toggleUnderline() },
                onLink: { [weak self] in self?.insertLink() },
                onTextColor: { [weak self] color in self?.applyTextColor(color) },
                onHighlight: { [weak self] color in
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
                onBulletList: { [weak self] in self?.toggleBulletList() },
                onTextStyleSelect: { [weak self] style in self?.applyTextStyle(style) },
                onAlignment: { [weak self] alignment in self?.applyAlignment(alignment) },
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

            // Configure the new toolbar view
            newToolbar.wantsLayer = true
            newToolbar.layer?.masksToBounds = true

            // Update the panel's content view
            panel.contentView = newToolbar
        } else if let panel = formattingToolbarPanel, panel.isVisible, self.selectedRange().length == 0 {
            // If panel is visible but selection length became 0, hide it immediately.
            // This prevents updating the content just before hiding.
             hideFormattingToolbar()
        }
        
        // --- FIX for lingering selection --- 
        // After everything, mark the view as needing display to clean up potential rendering artifacts
        // like the lingering selection sliver.
        self.setNeedsDisplay(self.bounds) // Use bounds instead of true
        // --- END FIX ---
    }
    
    override func didChangeText() {
        super.didChangeText()
        print("📝 Text changed to: \\(string)")
        
        // --- REMOVE THIS CALL --- Likely causing scroll jump on newline
        // resetParagraphIndentation()
        
        // Clear scripture line rectangle cache when text changes
        cachedScriptureLineRects.removeAll()
        
        // Only post notification if not in scripture search
        if !isScriptureSearchActive {
            NotificationCenter.default.post(name: NSText.didChangeNotification, object: self)
        }
        
        // Apply proper indentation to scripture blocks
        fixScriptureIndentation()
        
        // EMERGENCY COLOR OVERRIDE: Force text color based on current appearance
        forceTextColorForCurrentAppearance()
        
        // Force redraw to ensure highlights and colors are visible
        needsDisplay = true
        displayIfNeeded()
    }

    @objc func selectionDidChange(_ notification: Notification) {
        print("🅾️ SELECTION DID CHANGE (Notification)")
        // This method is called by NotificationCenter. NSTextView.setSelectedRange is called for direct changes.

        let currentSelectedRange = self.selectedRange()
        let hasSelection = currentSelectedRange.length > 0

        if hasSelection {
            print("📢 Selection detected (Notification) - showing formatting toolbar")
            DispatchQueue.main.async { [weak self] in
                self?.showFormattingToolbar()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.hideFormattingToolbar()
            }
        }

        // Update toolbar with current formatting if it exists AND there is still a selection
        if let panel = formattingToolbarPanel, panel.isVisible, hasSelection {
            let formatting = getCurrentFormatting()

            // Create a new toolbar view
            let newToolbar = NSHostingView(rootView: TextFormattingToolbar(
                onBold: { [weak self] in self?.toggleBold() },
                onItalic: { [weak self] in self?.toggleItalic() },
                onUnderline: { [weak self] in self?.toggleUnderline() },
                onLink: { [weak self] in self?.insertLink() },
                onTextColor: { [weak self] color in self?.applyTextColor(color) },
                onHighlight: { [weak self] color in
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
                onBulletList: { [weak self] in self?.toggleBulletList() },
                onTextStyleSelect: { [weak self] style in self?.applyTextStyle(style) },
                onAlignment: { [weak self] alignment in self?.applyAlignment(alignment) },
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
            ))

            newToolbar.wantsLayer = true
            newToolbar.layer?.masksToBounds = true
            panel.contentView = newToolbar
        } else if let panel = formattingToolbarPanel, panel.isVisible, !hasSelection {
            hideFormattingToolbar()
        }
        
        self.setNeedsDisplay(self.bounds)
    }
}
#endif 