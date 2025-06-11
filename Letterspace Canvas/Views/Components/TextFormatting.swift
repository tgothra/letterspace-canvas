import SwiftUI

// Add TextFormatting struct
struct TextFormatting {
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderlined: Bool = false
    var hasLink: Bool = false
    var textColor: Color? = nil
    var highlightColor: Color? = nil
    var hasBulletList: Bool = false
    var hasNumberedList: Bool = false
    var isBookmarked: Bool = false // Add bookmark state
    var textAlignment: TextAlignment? = nil // Add text alignment state
}
