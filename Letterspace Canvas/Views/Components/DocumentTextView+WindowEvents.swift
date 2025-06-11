#if os(macOS)
import AppKit
import ObjectiveC

extension DocumentTextView {
    // MARK: - Window Event Handling

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        
        // Remove observer from old window
        if let oldWindow = window {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didUpdateNotification, object: oldWindow)
        }
        
        // Add observer to new window
        if let newWindow = newWindow {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidUpdate(_:)),
                name: NSWindow.didUpdateNotification,
                object: newWindow
            )
        }
    }
    
    @objc internal func windowDidUpdate(_ notification: Notification) {
        // Only update layout if we actually have focus to avoid unnecessary refreshes
        if window?.firstResponder === self && isEditable {
            // Reset paragraph indentation if needed
            if string.isEmpty {
            resetParagraphIndentation() // This method is in DocumentTextView+Formatting
            }
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if self.window != nil {
            // Setup appearance observer when view is added to a window
            print("🖼️ View did move to window. Appearance will be handled by viewDidChangeEffectiveAppearance.")
            // setupAppearanceObserver() // This method is in DocumentTextView+LayoutAndDrawing -- REMOVED
        }
        
        // Add notification observer for window becoming main
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        
        // Add notification observer for window resigning main
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignMain(_:)),
            name: NSWindow.didResignMainNotification,
            object: nil
        )
        
        // Register for bookmark navigation notifications when the view appears
        registerForBookmarkNavigation() // This method is in DocumentTextView+BookmarkNavigation
    }
    
    @objc internal func windowDidBecomeMain(_ notification: Notification) {
        // Check if it's our window
        if let window = self.window, notification.object as? NSWindow == window {
            // This is a good time to double-check our state
            print("🔍 Window became main, checking state - isScriptureSearchActive: \(isScriptureSearchActive)")
            
            // If scripture search panel doesn't exist but flag is true, reset it
            if scriptureSearchPanel == nil && isScriptureSearchActive {
                print("⚠️ Inconsistent state detected - forcing complete state reset")
                forceResetAllState() // This method is in DocumentTextView+ActionMenu
            }
            
            // Also check for action menu inconsistency
            if actionMenuPanel == nil && slashCommandLocation >= 0 {
                print("⚠️ Inconsistent action menu state detected - forcing complete state reset")
                forceResetAllState() // This method is in DocumentTextView+ActionMenu
            }
        }
    }
    
    @objc internal func windowDidResignMain(_ notification: Notification) {
        // When window loses focus, it's a good time to reset state
        if let window = self.window, notification.object as? NSWindow == window {
            print("🔍 Window resigned main, checking state")
            
            // Force reset state if needed
            if (scriptureSearchPanel == nil && isScriptureSearchActive) || 
               (actionMenuPanel == nil && slashCommandLocation >= 0) {
                print("⚠️ Inconsistent state detected on window resign - forcing complete state reset")
                forceResetAllState() // This method is in DocumentTextView+ActionMenu
            }
        }
    }
}
#endif 