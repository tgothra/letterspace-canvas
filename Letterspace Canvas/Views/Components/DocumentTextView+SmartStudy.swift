#if os(macOS)
import AppKit
import SwiftUI
import ObjectiveC

extension DocumentTextView {
    // MARK: - Smart Study Panel
    
    internal func showSmartStudy() {
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
}
#endif 