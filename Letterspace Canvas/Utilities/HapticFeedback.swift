import SwiftUI

#if os(iOS)
import UIKit
#endif

struct HapticFeedback {
    enum Style {
        case light
        case medium
        case heavy
    }
    
    static func impact(_ style: Style) {
        #if os(iOS)
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light:
            feedbackStyle = .light
        case .medium:
            feedbackStyle = .medium
        case .heavy:
            feedbackStyle = .heavy
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: feedbackStyle)
        impactFeedback.impactOccurred()
        #endif
        // On macOS, haptic feedback is not available, so we do nothing
    }
} 