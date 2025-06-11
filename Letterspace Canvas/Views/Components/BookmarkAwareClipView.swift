#if os(macOS)
import AppKit

// MARK: - Custom Clip View for Bookmark Navigation
class BookmarkAwareClipView: NSClipView {
    weak var textView: DocumentTextView? // Reference to the text view

    override func scroll(to newOrigin: NSPoint) {
        // Check if the text view exists and if bookmark navigation is active
        if let tv = textView, tv.isNavigatingToBookmark {
            // If navigating, ONLY allow scrolling if it's initiated internally by our bookmark methods
            if tv.internalScrollInProgress {
                print("🖱️ BookmarkAwareClipView: Allowing internal bookmark scroll to \(newOrigin)")
                super.scroll(to: newOrigin)
            } else {
                // Block other scrolls (likely automatic adjustments) during bookmark navigation
                print("🖱️ BookmarkAwareClipView: Blocking automatic scroll to \(newOrigin) during bookmark navigation.")
                // Do nothing, effectively blocking the scroll
            }
        } else {
            // If not navigating, allow all scrolls as normal
            // print("🖱️ BookmarkAwareClipView: Allowing normal scroll to \(newOrigin)") // Can be noisy
            super.scroll(to: newOrigin)
        }
    }
}
#endif
