#if os(macOS)
import AppKit
import SwiftUI

extension DocumentTextView {
    // MARK: - Action Menu
    
    // Add method to show action menu - this is now called from text change handler
    internal func showActionMenu() {
        // Don't show the menu if we're already showing something
        if actionMenuPanel != nil || isScriptureSearchActive || scriptureSearchPanel != nil {
            return
        }
        
        print("📋 ACTION MENU: Creating action menu")
        
        // Create action menu items
        let selectedIndex = 0 // Default to Scripture (index 0)
        
        let menuItems = [
            ActionMenuItem(
                title: "Scripture",
                icon: "book.fill",
                action: { [weak self] in
                    print("📋 ACTION MENU: Selected Scripture option")
                    guard let self = self else { return }
                    
                    // First dismiss the menu
                    self.dismissActionMenu()
                    
                    // Then open scripture search with a slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("📋 ACTION MENU: Opening scripture search after delay")
                        self.openScriptureSearch()
                    }
                }
            ),
            ActionMenuItem(
                title: "Smart Study",
                icon: "sparkles",
                action: { [weak self] in
                    print("📋 ACTION MENU: Selected Smart Study option")
                    guard let self = self else { return }
                    
                    // First dismiss the menu
                    self.dismissActionMenu()
                    
                    // Then show smart study with a slight delay - via sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("📋 ACTION MENU: Showing Smart Study via sheet after delay")
                        // Just post notification to show the sheet, don't call showSmartStudy()
                        NotificationCenter.default.post(name: NSNotification.Name("ShowSmartStudyModal"), object: true)
                    }
                }
            )
        ]
        
        // Create panel with the right size for the menu items
        let itemHeight = 40 // Height of each menu item
        let dividerHeight = 1 // Height of each divider
        let totalHeight = (itemHeight * menuItems.count) + (dividerHeight * (menuItems.count - 1))
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: totalHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = true // Enable panel shadow
        panel.isMovableByWindowBackground = false
        panel.contentView?.wantsLayer = true
        
        // Hide standard window buttons
        panel.hideStandardButtons()
        
        // Add a visible border
        panel.contentView?.layer?.borderWidth = 0.5
        panel.contentView?.layer?.borderColor = NSColor.gray.withAlphaComponent(0.2).cgColor
        panel.contentView?.layer?.cornerRadius = 8
        panel.contentView?.layer?.masksToBounds = true
        
        // Create menu view
        let menuView = NSHostingView(
            rootView: ActionMenuView(
                selectedIndex: .constant(selectedIndex), // Always default to Scripture (index 0)
                items: menuItems,
                onDismiss: { [weak self] in
                    self?.dismissActionMenu()
                }
            )
        )
        
        // Ensure the hosting view has no border
        menuView.layer?.borderWidth = 0
        menuView.wantsLayer = true
        menuView.layer?.masksToBounds = true
        menuView.layer?.cornerRadius = 8
        
        // Set the frame to fill the entire panel
        menuView.frame = NSRect(x: 0, y: 0, width: 200, height: totalHeight)
        menuView.autoresizingMask = [.width, .height]
        
        panel.contentView = menuView
        
        // Position panel at cursor location - NEW APPROACH
        if let window = self.window {
            // Get the current selection range
            let selectedRange = self.selectedRange()
            
            // Get the layout manager and text container
            guard let layoutManager = self.layoutManager,
                  let textContainer = self.textContainer else {
                // Fallback if layout manager is not available
                window.addChildWindow(panel, ordered: .above)
                actionMenuPanel = panel
                return
            }
            
            // Convert character range to glyph range
            let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
            
            // Get the bounding rect for this glyph range
            let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            // Convert to view coordinates, accounting for text container insets
            let cursorPoint = NSPoint(
                x: boundingRect.maxX + textContainerOrigin.x,
                y: boundingRect.maxY + textContainerOrigin.y
            )
            
            // Convert to window coordinates
            let windowPoint = self.convert(cursorPoint, to: nil)
            
            // Convert to screen coordinates
            let screenPoint = window.convertPoint(toScreen: windowPoint)
            
            print("📋 ACTION MENU: Positioning menu at screen point: \(screenPoint)")
            
            // Position panel next to cursor with offsets to make it look good
            panel.setFrameOrigin(NSPoint(x: screenPoint.x + 5, y: screenPoint.y - panel.frame.height - 5))
            
            // Add panel to window and make it key
            window.addChildWindow(panel, ordered: .above)
            actionMenuPanel = panel
            
            // Force layout immediately
            panel.layoutIfNeeded()
        }
    }
    
    // Add method to dismiss action menu
    internal func dismissActionMenu() {
        print("📋 ACTION MENU: Dismissing action menu")
        
        if let panel = actionMenuPanel {
            if let parent = panel.parent {
                parent.removeChildWindow(panel)
            }
            panel.orderOut(nil)
            actionMenuPanel = nil
            
            // Make sure the text view regains focus
            if let window = self.window {
                window.makeFirstResponder(self)
            }
            
            // Remove the slash character if it's still there
            if slashCommandLocation >= 0 {
                print("📋 ACTION MENU: Removing slash character from position \(slashCommandLocation)")
                
                // Check if we're still in a valid state to remove the character
                if slashCommandLocation < string.count {
                    // Remove the slash character
                    textStorage?.beginEditing()
                    textStorage?.deleteCharacters(in: NSRange(location: slashCommandLocation, length: 1))
                    textStorage?.endEditing()
                    
                    // Adjust selection range to account for removed character
                    if selectedRange().location > slashCommandLocation {
                        setSelectedRange(NSRange(location: selectedRange().location - 1, length: selectedRange().length))
                    }
                }
            }
            
            // Complete state reset - critical for allowing "/" to work again
            forceResetAllState() // Use the comprehensive reset method instead of just setting the flag
            
            // Force redraw to ensure proper state
            needsDisplay = true
            
            print("📋 ACTION MENU: Menu dismissed and state completely reset")
        }
    }
    
    // Add method to navigate action menu
    internal func navigateActionMenu(direction: Int) {
        print("📋 ACTION MENU: Navigating menu, direction: \(direction)")
        
        guard let panel = actionMenuPanel,
              let menuView = panel.contentView as? NSHostingView<ActionMenuView> else { 
            print("📋 ACTION MENU: Cannot navigate, menu not available")
            return 
        }
        
        // Update the selected index
        let currentView = menuView.rootView
        let newIndex = max(0, min(currentView.items.count - 1, currentView.selectedIndex + direction))
        
        // Preserve the hovering states
        let hoveringStates = currentView.hoveringIndices
        
        // Create a new view with updated selection
        let updatedView = ActionMenuView(
            selectedIndex: .constant(newIndex),
            items: currentView.items,
            onDismiss: currentView.onDismiss
        )
        
        // After view creation, update its hover states
        DispatchQueue.main.async {
            if updatedView.hoveringIndices.count == hoveringStates.count {
                updatedView.hoveringIndices = hoveringStates
            }
        }
        
        // Replace the hosting view's root view
        menuView.rootView = updatedView
        
        print("📋 ACTION MENU: Selected index updated to \(newIndex)")
    }
    
    // Add method to activate selected action
    internal func activateSelectedAction() {
        print("📋 ACTION MENU: Activating selected action")
        
        guard let panel = actionMenuPanel,
              let menuView = panel.contentView as? NSHostingView<ActionMenuView> else { 
            print("📋 ACTION MENU: Cannot activate, menu not available")
            return 
        }
        
        // Get the selected index
        let selectedIndex = menuView.rootView.selectedIndex
        print("📋 ACTION MENU: Selected index is \(selectedIndex)")
        
        // Note: Slash character removal is now handled in dismissActionMenu
        
        // Store whether we need to run scripture search
        let shouldOpenScripture = selectedIndex == 0
        print("📋 ACTION MENU: Should open scripture? \(shouldOpenScripture)")
        
        // Trigger the action if valid
        if selectedIndex >= 0 && selectedIndex < menuView.rootView.items.count {
            let selectedItem = menuView.rootView.items[selectedIndex]
            print("📋 ACTION MENU: Executing action for item: \(selectedItem.title)")
            
            // Dismiss the menu first to ensure clean state
            dismissActionMenu()
            
            // Perform the action with a slight delay to ensure clean state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self else { return }
                print("📋 ACTION MENU: Executing delayed action for: \(selectedItem.title)")
                selectedItem.action()
                
                // Perform a complete state verification after action is executed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    
                    // Special handling for scripture - it should set isScriptureSearchActive=true
                    // So only warn and reset if it's false but we're showing a scripture panel
                    if shouldOpenScripture && !self.isScriptureSearchActive && self.scriptureSearchPanel != nil {
                        print("⚠️ WARNING: Scripture panel open but isScriptureSearchActive is false, fixing state")
                        self.isScriptureSearchActive = true
                    }
                    
                    // For non-scripture actions, make sure the flag is reset
                    if !shouldOpenScripture && self.isScriptureSearchActive {
                        print("⚠️ WARNING: Non-scripture action but isScriptureSearchActive is true, resetting")
                        self.isScriptureSearchActive = false
                    }
                    
                    print("✅ Post-action state verification complete")
                }
            }
            return
        }
        
        // If no action was performed, just dismiss the menu
        dismissActionMenu()
    }

    // This method seems to be called by dismissActionMenu but is not defined in the snippets.
    // It might be a new helper or a method that should also be moved.
    // For now, I will stub it here. If it exists in DocumentEditor.swift, it should be moved.
    // If it's a new requirement for the refactored code, its implementation will be needed.
    internal func forceResetAllState() {
        print("‼️ FORCE RESETTING ALL STATE")
        
        // Reset all state flags first
        isScriptureSearchActive = false
        slashCommandLocation = -1
        
        // Close all panels
        if let panel = scriptureSearchPanel {
            panel.orderOut(nil)
            scriptureSearchPanel = nil
        }
        
        if let panel = actionMenuPanel {
            if let parent = panel.parent {
                parent.removeChildWindow(panel)
            }
            panel.orderOut(nil)
            actionMenuPanel = nil
        }
        
        if let panel = formattingToolbarPanel {
            if let parent = panel.parent {
                parent.removeChildWindow(panel)
            }
            panel.orderOut(nil)
            // Note: We don't nil out formattingToolbarPanel as it's managed elsewhere and reused.
        }
        
        // Also ensure Smart Study panel is properly closed
        if let panel = smartStudyPanel {
            // Reset level to normal before closing
            panel.level = .normal
            if let parent = panel.parent {
                parent.removeChildWindow(panel)
            }
            panel.orderOut(nil)
            smartStudyPanel = nil // This implies smartStudyPanel needs to be accessible
        }
        
        // Ensure we regain focus
        if let window = self.window {
            window.makeFirstResponder(self)
            window.update()
        }
        
        // Force redraw
        needsDisplay = true
        
        // Add a double-check with slight delay to really ensure state is reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Second verification pass
            if self.isScriptureSearchActive {
                print("⚠️ WARNING: isScriptureSearchActive still true after reset, forcing to false")
                self.isScriptureSearchActive = false
            }
            
            if self.actionMenuPanel != nil {
                print("⚠️ WARNING: actionMenuPanel still exists after reset, forcing to nil")
                if let panel = self.actionMenuPanel {
                    if let parent = panel.parent {
                        parent.removeChildWindow(panel)
                    }
                    panel.orderOut(nil)
                }
                self.actionMenuPanel = nil
            }
            
            if self.scriptureSearchPanel != nil {
                print("⚠️ WARNING: scriptureSearchPanel still exists after reset, forcing to nil")
                if let panel = self.scriptureSearchPanel {
                    panel.orderOut(nil)
                }
                self.scriptureSearchPanel = nil
            }
             if self.smartStudyPanel != nil {
                print("⚠️ WARNING: smartStudyPanel still exists after reset, forcing to nil")
                if let panel = self.smartStudyPanel {
                    panel.orderOut(nil)
                }
                self.smartStudyPanel = nil
            }
            
            // Final verification message
            print("✅ State reset verification complete")
        }
        
        print("‼️ ALL STATE RESET COMPLETE")
    }
}
#endif 