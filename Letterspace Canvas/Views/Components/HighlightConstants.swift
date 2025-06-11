#if os(macOS)
import AppKit

// Define constants for text highlighting
struct HighlightConstants {
    static let customHighlight = NSAttributedString.Key("customHighlight")
    
    static func logHighlight(_ message: String, range: NSRange, color: NSColor) {
        print("🖌️ \(message) at range \(range) with color \(color)")
    }
}
#endif
