#if os(macOS)
import SwiftUI
import AppKit
import Combine
import ObjectiveC


// MARK: - Document Text View
class DocumentTextView: NSTextView {
    var document: Letterspace_CanvasDocument?
    weak var coordinator: DocumentEditorView.Coordinator? // Add reference to coordinator
    var formattingToolbarPanel: NSPanel?
    internal var isScriptureSearchActive = false // Changed from private
    internal var scriptureSearchPanel: NSPanel? // Changed from private
    internal var actionMenuPanel: NSPanel? // Changed from private
    internal var placeholderAttributedString: NSAttributedString?
    var colorScheme: ColorScheme = .light { // Default to light, will be updated
        didSet {
            if oldValue != colorScheme {
                self.needsDisplay = true
                print("🎨 Color scheme changed, triggering redraw")
            }
        }
    }
    var isHeaderImageCurrentlyExpanded: Bool = false // Added to track header state
    
    // Custom attribute for marking non-editable regions like scripture blocks
    static let nonEditableAttribute = NSAttributedString.Key("nonEditable")
    
    // Custom attribute for marking scripture blocks that need a vertical line
    static let isScriptureBlockQuote = NSAttributedString.Key("isScriptureBlockQuote")
    
    // --- Bookmark Navigation Flags --- (MOVED to DocumentTextView+BookmarkNavigation.swift)
    // var isNavigatingToBookmark = false 
    // var internalScrollInProgress = false 
    // private var lastBookmarkRange: NSRange? 
    // private var lastTopMarginPercentage: CGFloat? 
    // private var bookmarkMaintenanceTimer: Timer? 
    // --- End Bookmark Navigation Flags ---
    
    // Add property to track the position of the slash character
    internal var slashCommandLocation: Int = -1
    
    
    // Add a static variable to track the next layout to use (MOVED to DocumentTextView+Scripture.swift)
    // internal static var nextScriptureLayout: ScriptureLayoutStyle?
    
    // Observer for bookmark navigation (MOVED to DocumentTextView+BookmarkNavigation.swift)
    // private var bookmarkScrollObserver: NSObjectProtocol?
    
    override init(frame: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()  // Call setup to initialize the text view and toolbar
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()  // Call setup to initialize the text view and toolbar
    }
    
    // New method to scroll to an exact character position and highlight it (MOVED to DocumentTextView+BookmarkNavigation.swift)
    /*
    private func scrollToCharacterPosition(_ position: Int, length: Int) {
        // ... (content of scrollToCharacterPosition)
    }
    */
    
    // Add new method to maintain bookmark position after layout changes (MOVED to DocumentTextView+BookmarkNavigation.swift)
    /*
    private func setupBookmarkMaintenanceTimer() {
        // ... (content of setupBookmarkMaintenanceTimer)
    }
    */

    // Counter for maintenance checks (MOVED to DocumentTextView+BookmarkNavigation.swift)
    // private var maintenanceChecksCount = 0
    
    // Add a cleanup for the maintenance timer
    deinit {
        // bookmarkMaintenanceTimer?.invalidate() // Original line
        // bookmarkMaintenanceTimer = nil // Original line
        cleanupBookmarkNavigation() // Call the method in the extension
    }
    
    // Remove the explicit reset of isNavigatingToBookmark from scrollToCharacterPosition
    // since the timer will handle this
    // (MOVED to DocumentTextView+BookmarkNavigation.swift)
    /*
    private func registerForBookmarkNavigation() {
        // ... (content of registerForBookmarkNavigation)
    }
    */
    
    // Helper method to process bookmark navigation after potential header animation (MOVED to DocumentTextView+BookmarkNavigation.swift)
    /*
    private func processBookmarkNavigation(notification: Notification) {
        // ... (content of processBookmarkNavigation)
    }
    */
    
    // Function to scroll to a specific line number (MOVED to DocumentTextView+BookmarkNavigation.swift)
    /*
    private func scrollToLine(_ lineNumber: Int) {
        // ... (content of scrollToLine)
    }
    */
    
    // MARK: - Selection Change Handling
    
    // Helper method to fix scripture indentation
    /* MOVED TO DocumentTextView+TextHandling.swift
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
    */
    
    // Add method to show action menu - this is now called from text change handler
    /* MOVED TO DocumentTextView+ActionMenu.swift
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
    */
    
    // Add method to dismiss action menu
    /* MOVED TO DocumentTextView+ActionMenu.swift
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
    */
    
    // Add method to navigate action menu
    /* MOVED TO DocumentTextView+ActionMenu.swift
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
    */
    
    // Add method to activate selected action
    /* MOVED TO DocumentTextView+ActionMenu.swift
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
    */
    
    // Use this method to open the scripture search (MOVED to DocumentTextView+ScriptureSearch.swift)
    /*
    internal func openScriptureSearch() {
        // ... (content of openScriptureSearch)
    }
    */
    
    // Add a property to track Smart Study panel state
    internal var smartStudyPanel: NSPanel?
    
    /* MOVED TO DocumentTextView+SmartStudy.swift
    private func showSmartStudy() {
        print("💡 Opening Smart Study")
        
        // Update MainLayout's state for blurring background
        NotificationCenter.default.post(name: NSNotification.Name("ShowSmartStudyModal"), object: true)
        
        // First force this text view to resign first responder
        if let window = self.window, window.firstResponder == self {
            window.makeFirstResponder(nil)
        }
        
        // Create a panel for the Smart Study interface
            let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            // Configure the panel
            panel.isFloatingPanel = true
        panel.level = .floating // Changed from modalPanel to floating to reduce focus conflicts
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
            panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentView?.wantsLayer = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary] // Add fullScreenAuxiliary
        
        // Hide standard window buttons (close, minimize, maximize)
        panel.hideStandardButtons()
        
        // Set behavior to avoid stealing focus from main window
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        // Remove invalid property settings
        // Use styleMask to control window behavior instead
        panel.styleMask = [.titled, .closable, .utilityWindow, .nonactivatingPanel]
        
        // Save reference to the panel
        smartStudyPanel = panel
        
        // Add as child window to ensure it closes when main window closes
        if let window = self.window {
            window.addChildWindow(panel, ordered: .above)
            
            // Keep main window as key window to prevent gray buttons
            window.makeKey()
        }
        
        // Register for main window will close notification
        let willCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: self.window,
            queue: .main
        ) { [weak panel] _ in
            // Ensure panel is closed when main window closes
            panel?.close()
        }
        
        // Store the observer for later removal
        objc_setAssociatedObject(
            panel,
            "willCloseObserver",
            willCloseObserver,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
            
            // Center the panel on the screen
            if let window = self.window,
               let screen = window.screen {
                
                let screenFrame = screen.visibleFrame
                
                // Calculate center position
                let panelX = screenFrame.midX - (panel.frame.width / 2)
                let panelY = screenFrame.midY - (panel.frame.height / 2)
                
                // Set the panel position at the center of the screen
                panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
            }
            
        // Create the Smart Study view with proper dismissal behavior
        let smartStudyView = SmartStudyView(
            onDismiss: { [weak self, weak panel] in
                // Update MainLayout's state to remove blur
                NotificationCenter.default.post(name: NSNotification.Name("ShowSmartStudyModal"), object: false)
                
                // Close the panel
                if let panel = panel {
                    if let parentWindow = panel.parent {
                        parentWindow.removeChildWindow(panel)
                    }
                    panel.orderOut(nil)
                }
                
                // Clear reference to the panel
                self?.smartStudyPanel = nil
                
                // Make sure the text view regains focus
                if let self = self, let window = self.window {
                    window.makeFirstResponder(self)
                }
            }
        )
            
            // Create hosting view for SwiftUI
        let hostingView = NSHostingView(rootView: smartStudyView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 800, height: 500) // Ensure correct size
        hostingView.autoresizingMask = NSView.AutoresizingMask([.width, .height]) // Explicitly qualify
        
        // Make sure hosting view can receive key events
        hostingView.allowedTouchTypes = NSTouch.TouchTypeMask([.indirect]) // Explicitly qualify
            
            // Add to panel and show
            panel.contentView = hostingView
            
            // Set the panel's frame explicitly AFTER setting content view
            panel.setFrame(hostingView.frame, display: false)
            
            // Center the panel on the SCREEN using the panel's final frame
            if let screen = NSScreen.main { // Use main screen for centering
                let screenFrame = screen.visibleFrame
                let panelSize = panel.frame.size
                
                // Calculate center position on the screen
                let panelX = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
                let panelY = screenFrame.origin.y + (screenFrame.height - panelSize.height) / 2
                
                // Set the panel position
                panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
            }
        
        // Show the panel
        panel.orderFront(nil)
        
        // Ensure main window stays key window
        if let mainWindow = self.window {
            mainWindow.makeKey()
        }
        
        // Focus on the text field after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak panel, weak hostingView, weak self] in
            guard let panel = panel, let hostingView = hostingView else { return }
            
            // Function to recursively find the first NSTextField
            func findTextField(in view: NSView) -> NSTextField? {
                for subview in view.subviews {
                    if let textField = subview as? NSTextField {
                        return textField
                    }
                    if let found = findTextField(in: subview) {
                        return found
                    }
                }
                return nil
            }
            
            // Use the inline function to find the text field
            if let firstTextField = findTextField(in: hostingView) {
                panel.makeFirstResponder(firstTextField)
                firstTextField.becomeFirstResponder()
                
                // Keep main window as key window even after focusing the text field
                if let mainWindow = self?.window {
                    mainWindow.makeKey()
                }
            }
        }
        
        // Don't reset state here - it causes issues with focus
    }
    */
    
    // Replace the old closeScripturePanel method (MOVED to DocumentTextView+ScriptureSearch.swift)
    /*
    internal func closeScripturePanel() {
        // ... (content of closeScripturePanel)
    }
    */
    
    // Add a method to force reset all state - useful for recovering from errors
    /* MOVED TO DocumentTextView+ActionMenu.swift
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
        }
        
        // Also ensure Smart Study panel is properly closed
        if let panel = smartStudyPanel {
            // Reset level to normal before closing
            panel.level = .normal
            if let parent = panel.parent {
                parent.removeChildWindow(panel)
            }
            panel.orderOut(nil)
            smartStudyPanel = nil
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
            
            // Final verification message
            print("✅ State reset verification complete")
        }
        
        print("‼️ ALL STATE RESET COMPLETE")
    }
    */
    
    // Track if header is being collapsed
    // private var isCollapsingHeader = false // Commenting out as it appears unused
    
    /* MOVED TO DocumentTextView+Interaction.swift
    // Add method to force enable editing
    private func forceEnableEditing() {
        isEditable = true
        isSelectable = true
        isScriptureSearchActive = false
        
        if let window = self.window {
            window.makeKey()
            window.makeMain()
            window.makeFirstResponder(self)
        }
        needsDisplay = true
    }
    */
    
    // Add the resetParagraphIndentation method
    /* MOVED TO DocumentTextView+Formatting.swift
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
        cleanStyle.lineHeightMultiple = 1.2  // Changed from 1.0 to 1.2
        
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
    */
    
    // MARK: - Add window observer to prevent text shifting
    /* MOVED TO DocumentTextView+WindowEvents.swift
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
    
    @objc private func windowDidUpdate(_ notification: Notification) {
        // Only update layout if we actually have focus to avoid unnecessary refreshes
        if window?.firstResponder === self && isEditable {
            // Reset paragraph indentation if needed
            if string.isEmpty {
            resetParagraphIndentation()
            }
        }
    }
    */
    
    // Helper method to insert scripture (MOVED to DocumentTextView+Scripture.swift)
    /*
    internal func insertScripture(_ scripture: ScriptureElement) {
        // ... (content of insertScripture)
    }
    */
    
    // Helper method to insert scripture with a specific layout (MOVED to DocumentTextView+Scripture.swift)
    /*
    internal func insertScripture(_ scripture: ScriptureElement, layout: ScriptureLayoutStyle) {
        // ... (content of insertScripture with layout)
    }
    */
    
    // Format scripture as individual verses (each verse on its own line with reference) (MOVED to DocumentTextView+Scripture.swift)
    /*
    private func formatIndividualVerses(_ scripture: ScriptureElement, _ scriptureText: NSMutableAttributedString) {
        // ... (content of formatIndividualVerses)
    }
    */
    
    // Format scripture as continuous paragraph with verse numbers in brackets (MOVED to DocumentTextView+Scripture.swift)
    /*
    private func formatParagraph(_ scripture: ScriptureElement, _ scriptureText: NSMutableAttributedString) {
        // ... (content of formatParagraph)
    }
    */
    
    // Format scripture in two-column layout with references on left (MOVED to DocumentTextView+Scripture.swift)
    /*
    private func formatReference(_ scripture: ScriptureElement, _ scriptureText: NSMutableAttributedString) {
        // ... (content of formatReference)
    }
    */
    
    // Add a window-based event handler to catch mouse events outside our control
    /* MOVED TO DocumentTextView+WindowEvents.swift
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
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
        registerForBookmarkNavigation()
    }
    
    @objc private func windowDidBecomeMain(_ notification: Notification) {
        // Check if it's our window
        if let window = self.window, notification.object as? NSWindow == window {
            // This is a good time to double-check our state
            print("🔍 Window became main, checking state - isScriptureSearchActive: \(isScriptureSearchActive)")
            
            // If scripture search panel doesn't exist but flag is true, reset it
            if scriptureSearchPanel == nil && isScriptureSearchActive {
                print("⚠️ Inconsistent state detected - forcing complete state reset")
                forceResetAllState()
            }
            
            // Also check for action menu inconsistency
            if actionMenuPanel == nil && slashCommandLocation >= 0 {
                print("⚠️ Inconsistent action menu state detected - forcing complete state reset")
                forceResetAllState()
            }
        }
    }
    
    @objc private func windowDidResignMain(_ notification: Notification) {
        // When window loses focus, it's a good time to reset state
        if let window = self.window, notification.object as? NSWindow == window {
            print("🔍 Window resigned main, checking state")
            
            // Force reset state if needed
            if (scriptureSearchPanel == nil && isScriptureSearchActive) || 
               (actionMenuPanel == nil && slashCommandLocation >= 0) {
                print("⚠️ Inconsistent state detected on window resign - forcing complete state reset")
                forceResetAllState()
            }
        }
    }
    */
    
    // MARK: - Paste Handling
    /* MOVED TO DocumentTextView+Paste.swift
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
            
            // Insert the modified attributed string
            if shouldChangeText(in: selectedRange(), replacementString: mutableString.string) {
                insertText(mutableString, replacementRange: selectedRange())
                didChangeText()
            }
        } else if let plainText = pasteboard.string(forType: .string) {
            // Fallback to plain text if no rich text is available
            if shouldChangeText(in: selectedRange(), replacementString: plainText) {
                insertText(plainText, replacementRange: selectedRange())
                didChangeText()
            }
        } else {
            // Use default paste as last resort
            super.paste(sender)
        }
    }
    */
    
    /* MOVED TO DocumentTextView+BookmarkToggle.swift
    @objc internal func toggleBookmark() {
        print("🔖📣 ENTERED toggleBookmark() FUNCTION")
        
        guard let selectedRange = selectedRanges.first as? NSRange,
              selectedRange.length > 0, // Only allow bookmarking on actual selection
              let textStorage = textStorage,
              let coordinator = coordinator else {
            print("🔖❌ toggleBookmark() GUARD CHECK FAILED")
            return 
        }

        self.isNavigatingToBookmark = true // Prevent other scroll interference
        print("🚩 Setting isNavigatingToBookmark = true for bookmark toggle feedback")
        // let savedSelectionRange = self.selectedRange() // Should be same as selectedRange // This was unused

        // Store original selection attributes to restore them later
        let originalSelectedTextAttributes = self.selectedTextAttributes

        // Core bookmark logic (operates on textStorage)
        textStorage.beginEditing()
        let currentAttributes = textStorage.attributes(at: selectedRange.location, effectiveRange: nil)
        let existingBookmarkID = currentAttributes[NSAttributedString.Key.isBookmark] as? String
        let isAdding: Bool

        if let bookmarkID = existingBookmarkID, let uuid = UUID(uuidString: bookmarkID) {
            isAdding = false
            print("🔖 Removing bookmark attribute with ID: \(bookmarkID) at range: \(selectedRange)")
            textStorage.removeAttribute(NSAttributedString.Key.isBookmark, range: selectedRange)
            
            print("📚 Removing marker from document.markers array")
            var doc = coordinator.parent.document
            doc.removeMarker(id: uuid)
            coordinator.parent.document = doc
        } else {
            isAdding = true
            let uuid = UUID()
            let bookmarkID = uuid.uuidString
            print("🔖 Adding bookmark attribute with ID: \(bookmarkID) at range: \(selectedRange)")
            textStorage.addAttribute(NSAttributedString.Key.isBookmark, value: bookmarkID, range: selectedRange)
            
            let snippet = (textStorage.string as NSString).substring(with: selectedRange)
                           .trimmingCharacters(in: .whitespacesAndNewlines)
            let title = snippet.isEmpty ? "Bookmark" : String(snippet.prefix(30))
            let fullText = textStorage.string
            let textUpToCursor = (fullText as NSString).substring(to: selectedRange.location)
            let lineNumber = textUpToCursor.components(separatedBy: .newlines).count
            
            var doc = coordinator.parent.document
            doc.addMarker(
                id: uuid, 
                title: title, 
                type: "bookmark", 
                position: lineNumber,
                metadata: [
                    "charPosition": selectedRange.location,
                    "charLength": selectedRange.length,
                    "snippet": snippet
                ]
            )
            coordinator.parent.document = doc
            print("📚 Document marker prepared for saving - markers count: \(coordinator.parent.document.markers.count)")
        }
        textStorage.endEditing()
        
        // Determine feedback color and duration
        let feedbackColor: NSColor = isAdding ? NSColor.systemGreen.withAlphaComponent(0.4) : NSColor.systemGray.withAlphaComponent(0.3) // Adjusted alpha for visibility
        let feedbackDuration: TimeInterval = isAdding ? 0.7 : 0.4 // Slightly shorter durations

        // Apply visual feedback by temporarily changing selection attributes
        var tempSelectedAttributes = originalSelectedTextAttributes
        tempSelectedAttributes[NSAttributedString.Key.backgroundColor] = feedbackColor
        self.selectedTextAttributes = tempSelectedAttributes
        self.needsDisplay = true // Redraw with new selection appearance

        // Schedule restoration of original selection attributes
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration) { [weak self] in
            guard let self = self else { return }
            // Restore original selection attributes
            self.selectedTextAttributes = originalSelectedTextAttributes
            self.isNavigatingToBookmark = false // Release the flag
            print("🚩 Setting isNavigatingToBookmark = false after bookmark feedback")
            self.needsDisplay = true // Redraw with original selection appearance
        }
    }
    */

    // MARK: - Initialization & Setup

    /* MOVED TO DocumentTextView+ContextMenu.swift
    // Override to customize the context menu
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Format", action: nil, keyEquivalent: "")
        // Add more standard items or custom items as needed
        return menu
    }
    */
    
    // Add any other necessary overrides or methods for DocumentTextView here...

}

// MARK: - NSView Extensions for Finding Subviews
extension NSView {
    func firstSubview<T: NSView>(ofType type: T.Type) -> T? {
        // Check if this view is of the desired type
        if let view = self as? T {
            return view
        }
        
        // Check all subviews recursively
        for subview in subviews {
            if let found = subview.firstSubview(ofType: type) {
                return found
            }
        }
        
        return nil
    }
}

// MARK: - Undo/Redo Functionality

// A simpler, more targeted approach to fixing undo/redo without breaking scripture functionality
extension DocumentTextView {
    // Use a stable undo manager to prevent crashes and inconsistent behavior
    private static let sharedUndoManager = UndoManager()
    
    // Override undoManager to return our stable instance
    override var undoManager: UndoManager? {
        return Self.sharedUndoManager
    }
    
    // NSTextStorageDelegate method for handling text storage editing
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        // No super call needed as this is a delegate method, not an override
        
        // Check if we have character edits
        guard editedMask.contains(.editedCharacters) else {
            return
        }
        
        // Only process if we have an undo manager
        guard let um = undoManager else { return }
        
        // Use the provided editedRange instead of getting it from textStorage
        let range = editedRange
        
        // Get the text before changes
        let oldString = NSAttributedString(attributedString: textStorage.attributedSubstring(from: range))
        
        // Register undo action - using non-grouped approach to avoid corrupting undo stack
        um.registerUndo(withTarget: self) { [weak self] undoOperationTarget in // undoOperationTarget is the non-optional target from UndoManager
            guard let strongSelf = self, let ts = strongSelf.textStorage else { return } // Unwrap [weak self]
            
            // Don't register a new undo while performing an undo
            if !um.isUndoing {
                // Save current state for redo
                let redoRange = NSRange(location: range.location, length: min(range.length, ts.length - range.location))
                if redoRange.location < ts.length {
                    let currentString = NSAttributedString(attributedString: ts.attributedSubstring(from: redoRange))
                    
                    // Register redo operation, passing strongSelf as the target
                    um.registerUndo(withTarget: strongSelf) { [weak self] redoOperationTargetForInner in // redoOperationTargetForInner is non-optional
                        guard let strongSelfForRedo = self, let storage = strongSelfForRedo.textStorage else { return } // Unwrap [weak self] for inner closure
                        
                        // Apply the saved content with all attributes
                        storage.replaceCharacters(in: redoRange, with: currentString.string)
                        currentString.enumerateAttributes(in: NSRange(location: 0, length: currentString.length), options: []) { (attrs, subrange, stop) in
                            let targetRange = NSRange(location: redoRange.location + subrange.location, length: subrange.length)
                            for (key, value) in attrs {
                                storage.addAttribute(key, value: value, range: targetRange)
                            }
                        }
                    }
                }
            }
            
            // Apply the saved original content with all attributes preserved using ts from strongSelf
            ts.replaceCharacters(in: range, with: oldString.string)
            oldString.enumerateAttributes(in: NSRange(location: 0, length: oldString.length), options: []) { (attrs, subrange, stop) in
                let targetRange = NSRange(location: range.location + subrange.location, length: subrange.length)
                for (key, value) in attrs {
                    ts.addAttribute(key, value: value, range: targetRange)
                }
            }
        }
    }
}

// Extension to safely extract substrings
extension String {
    func substring(with nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else { return nil }
        return String(self[range])
    }
}

#endif
