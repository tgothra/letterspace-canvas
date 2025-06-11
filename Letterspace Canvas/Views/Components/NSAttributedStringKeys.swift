#if os(macOS)
import AppKit

// Define custom attribute key for bookmarks
extension NSAttributedString.Key {
    static let isBookmark = NSAttributedString.Key("isBookmark")
}

// Define custom attribute key for non-editable scripture
extension NSAttributedString.Key {
    static let nonEditable = NSAttributedString.Key("nonEditable")
}

// Define custom attribute key for scripture block quote line
extension NSAttributedString.Key {
    static let isScriptureBlockQuote = NSAttributedString.Key("isScriptureBlockQuote")
}

extension NSAttributedString.Key {
    static let fixedWidth = NSAttributedString.Key("fixedWidth")
}

#endif
