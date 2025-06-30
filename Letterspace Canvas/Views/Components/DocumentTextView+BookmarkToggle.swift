#if os(macOS)
import AppKit
import ObjectiveC // For associated objects if any were needed, and for UUID

extension DocumentTextView {
    // MARK: - Bookmark Toggle

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
        let existingBookmarkID = currentAttributes[.isBookmark] as? String
        let isAdding: Bool

        if let bookmarkID = existingBookmarkID, let uuid = UUID(uuidString: bookmarkID) {
            isAdding = false
            print("🔖 Removing bookmark attribute with ID: \(bookmarkID) at range: \(selectedRange)")
            textStorage.removeAttribute(.isBookmark, range: selectedRange)
            
            print("📚 Removing marker from document.markers array")
            var doc = coordinator.parent.document
            doc.removeMarker(id: uuid)
            coordinator.parent.document = doc
            // Save document asynchronously to prevent main thread hangs
            DispatchQueue.global(qos: .userInitiated).async {
                coordinator.parent.document.save()
            }
            print("📚 Document saved after removing bookmark")
        } else {
            isAdding = true
            let uuid = UUID()
            let bookmarkID = uuid.uuidString
            print("🔖 Adding bookmark attribute with ID: \(bookmarkID) at range: \(selectedRange)")
            textStorage.addAttribute(.isBookmark, value: bookmarkID, range: selectedRange)
            
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
            // Save document asynchronously to prevent main thread hangs
            DispatchQueue.global(qos: .userInitiated).async {
                coordinator.parent.document.save()
            }
            print("📚 Document saved after adding bookmark - markers count: \(coordinator.parent.document.markers.count)")
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
}
#endif 