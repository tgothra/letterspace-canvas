import SwiftUI

// Shared preference keys used across multiple views

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Shared notification names used across multiple views

extension Notification.Name {
    static let showPresentationManager = Notification.Name("ShowPresentationManager")
    static let openVariation = Notification.Name("OpenVariation")
    static let newVariationCreated = Notification.Name("NewVariationCreated")
    static let translateDocument = Notification.Name("TranslateDocument")
    static let jumpToLine = Notification.Name("JumpToLine")
} 