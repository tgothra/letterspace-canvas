#if os(macOS)
import AppKit
import SwiftUI

extension DocumentTextView {
    // MARK: - Scripture Search Panel Methods
    // Use this method to open the scripture search
    internal func openScriptureSearch() {
        print("📜 Opening scripture search, setting isScriptureSearchActive = true")
        
            isScriptureSearchActive = true
            
        // Update MainLayout's state for blurring background
        NotificationCenter.default.post(name: NSNotification.Name("ShowScriptureSearchModal"), object: true)
        
        // Reset any action states
        slashCommandLocation = -1
        
        // Force the text view to regain focus when the scripture search is dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isScriptureSearchActive = true
            print("📜 Scripture search opened, confirming isScriptureSearchActive: \(self.isScriptureSearchActive)")
        }
    }

    // Replace the old closeScripturePanel method
    internal func closeScripturePanel() {
        print("📜 Closing scripture search, FORCING isScriptureSearchActive = false")
        
        // CRITICAL: Reset the flag FIRST, before anything else
        isScriptureSearchActive = false
        slashCommandLocation = -1
        
        // Update MainLayout's state to remove blur
        NotificationCenter.default.post(name: NSNotification.Name("ShowScriptureSearchModal"), object: false)
            
            // Ensure we regain focus
            if let window = self.window {
                window.makeFirstResponder(self)
                
                // Force the window to update
                window.update()
            }
            
            // Force the text view to refresh
            needsDisplay = true
            
        print("📝 Scripture search closed, DOUBLE-CHECKING isScriptureSearchActive: \(isScriptureSearchActive)")
    }

    // MARK: - ScriptureSearchPanelDelegate Methods

    // Ensure this method is present if it was part of the delegate, otherwise remove
    /*
    func didSelectScripture(_ scripture: ScriptureElement) {
        // Implementation for selecting scripture
        insertScripture(scripture)
        closeScripturePanel()
    }

    func didCancelScriptureSearch() {
        // Implementation for canceling scripture search
        closeScripturePanel()
    }

    func didChangeLayout(to layout: ScriptureLayoutStyle) {
        // Implementation for changing layout
        // This might involve re-inserting or re-formatting scripture
        // For now, we'll just store it for the next insertion
        DocumentTextView.nextScriptureLayout = layout
        
        // Optionally, you could close and re-open the search with the new layout
        // or apply it immediately if a scripture is already selected/previewed
    }
    */
}
#endif 