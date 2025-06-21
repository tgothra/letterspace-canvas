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
        
        // PERFORMANCE: Reduce print statements that cause console overhead
        if hasSelection {
            DispatchQueue.main.async { [weak self] in
                self?.showFormattingToolbar()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.hideFormattingToolbar()
            }
        }

        // PERFORMANCE FIX: Only scroll if the selection is not currently visible
        // This prevents unnecessary scrolling that causes jitter
        if hasSelection {
            let visibleRect = self.visibleRect
            let selectionRect = self.firstRect(forCharacterRange: charRange, actualRange: nil)
            
            // Only scroll if selection is outside visible area
            if !visibleRect.intersects(selectionRect) {
                self.scrollRangeToVisible(charRange)
            }
        }

        // PERFORMANCE: Batch toolbar updates to reduce frequency
        if hasSelection, let panel = formattingToolbarPanel, panel.isVisible {
            // Debounce toolbar updates to prevent excessive recreation
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateToolbarContent), object: nil)
            self.perform(#selector(updateToolbarContent), with: nil, afterDelay: 0.05)
        } else if let panel = formattingToolbarPanel, panel.isVisible, charRange.length == 0 {
            hideFormattingToolbar()
        }
        
        // PERFORMANCE: Optimize display updates - only update specific rect
        if hasSelection {
            let selectionRect = self.firstRect(forCharacterRange: charRange, actualRange: nil)
            self.setNeedsDisplay(selectionRect)
        } else {
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    @objc private func updateToolbarContent() {
        guard let panel = formattingToolbarPanel, 
              panel.isVisible, 
              self.selectedRange().length > 0 else { return }
        
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

        // Configure the new toolbar view
        newToolbar.wantsLayer = true
        newToolbar.layer?.masksToBounds = true

        // Update the panel's content view
        panel.contentView = newToolbar
    }
    
    override func didChangeText() {
        super.didChangeText()
        
        // PERFORMANCE: Reduce excessive print statements
        // print("📝 Text changed to: \\(string)")
        
        // Clear scripture line rectangle cache when text changes
        cachedScriptureLineRects.removeAll()
        
        // Only post notification if not in scripture search
        if !isScriptureSearchActive {
            NotificationCenter.default.post(name: NSText.didChangeNotification, object: self)
        }
        
        // PERFORMANCE: Batch these operations to reduce frequency
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performBatchedTextUpdates), object: nil)
        self.perform(#selector(performBatchedTextUpdates), with: nil, afterDelay: 0.02)
    }
    
    @objc private func performBatchedTextUpdates() {
        // Apply proper indentation to scripture blocks
        fixScriptureIndentation()
        
        // EMERGENCY COLOR OVERRIDE: Force text color based on current appearance
        forceTextColorForCurrentAppearance()
        
        // PERFORMANCE: Use more efficient display update
        self.needsDisplay = true
    }

    @objc func selectionDidChange(_ notification: Notification) {
        // PERFORMANCE: Reduce excessive logging
        // print("🅾️ SELECTION DID CHANGE (Notification)")

        let currentSelectedRange = self.selectedRange()
        let hasSelection = currentSelectedRange.length > 0

        if hasSelection {
            DispatchQueue.main.async { [weak self] in
                self?.showFormattingToolbar()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.hideFormattingToolbar()
            }
        }

        // PERFORMANCE: Use debounced toolbar updates
        if hasSelection, let panel = formattingToolbarPanel, panel.isVisible {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateToolbarContent), object: nil)
            self.perform(#selector(updateToolbarContent), with: nil, afterDelay: 0.05)
        } else if let panel = formattingToolbarPanel, panel.isVisible, !hasSelection {
            hideFormattingToolbar()
        }
        
        // PERFORMANCE: Optimize display updates
        if hasSelection {
            let selectionRect = self.firstRect(forCharacterRange: currentSelectedRange, actualRange: nil)
            self.setNeedsDisplay(selectionRect)
        } else {
            self.setNeedsDisplay(self.bounds)
        }
    }
}
#endif 