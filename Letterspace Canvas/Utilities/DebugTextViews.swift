//
// DebugTextViews.swift
// Created by debug script
//

#if os(macOS)
import AppKit

// Call this function early in your app initialization to enable debug visualization
func enableTextViewDebugging() {
    if UserDefaults.standard.bool(forKey: "com.letterspace.enableDebugBorders") {
        // Register for text view appearance notifications
        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let textView = notification.object as? NSTextView {
                // Only add debug visuals if they haven't been added yet
                if textView.layer?.borderWidth != 2.0 {
                    textView.addDebugBorder()
                    
                    if UserDefaults.standard.bool(forKey: "com.letterspace.showInsetMarkers") {
                        textView.showInsetDebugInfo()
                    }
                    
                    if UserDefaults.standard.bool(forKey: "com.letterspace.showPositionGrid") {
                        textView.addPositionGrid()
                    }
                }
            }
        }
        
        // Also find existing text views in the app
        findAndDebugExistingTextViews()
    }
}

// Find all current text views and add debug visuals
private func findAndDebugExistingTextViews() {
    // Get all windows
    for window in NSApplication.shared.windows {
        debugTextViewsInView(window.contentView)
    }
}

// Recursively find and debug text views in a view hierarchy
private func debugTextViewsInView(_ view: NSView?) {
    guard let view = view else { return }
    
    // Check if this is a text view
    if let textView = view as? NSTextView {
        textView.addDebugBorder()
        
        if UserDefaults.standard.bool(forKey: "com.letterspace.showInsetMarkers") {
            textView.showInsetDebugInfo()
        }
        
        if UserDefaults.standard.bool(forKey: "com.letterspace.showPositionGrid") {
            textView.addPositionGrid()
        }
    }
    
    // Check all subviews
    for subview in view.subviews {
        debugTextViewsInView(subview)
    }
}

// Add a specific helper to add debug visuals to EditorTextView
extension EditorTextView {
    func enableDebugMode() {
        addDebugBorder()
        showInsetDebugInfo()
        addPositionGrid()
        
        // Monitor cursor position changes
        NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            // Create or update a label showing the cursor position
            var positionLabel = self.viewWithTag(8888) as? NSTextField
            if positionLabel == nil {
                positionLabel = NSTextField(labelWithString: "")
                positionLabel?.tag = 8888
                positionLabel?.drawsBackground = true
                positionLabel?.backgroundColor = NSColor.purple.withAlphaComponent(0.8)
                positionLabel?.textColor = NSColor.white
                positionLabel?.isBezeled = false
                positionLabel?.isEditable = false
                if let positionLabel = positionLabel {
                    self.addSubview(positionLabel)
                }
            }
            
            if let selectedRange = self.selectedRanges.first as? NSRange {
                positionLabel?.stringValue = "Cursor: \(selectedRange.location)"
                
                // Get cursor position in view coordinates
                if let layoutManager = self.layoutManager, let textContainer = self.textContainer {
                    let glyphIndex = layoutManager.glyphIndexForCharacter(at: selectedRange.location)
                    let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
                    let cursorPoint = NSPoint(x: glyphRect.minX + self.textContainerOrigin.x, y: glyphRect.minY + self.textContainerOrigin.y)
                    
                    // Update label position near the cursor
                    positionLabel?.frame = NSRect(x: cursorPoint.x, y: cursorPoint.y - 20, width: 100, height: 18)
                }
            }
        }
    }
}
#endif