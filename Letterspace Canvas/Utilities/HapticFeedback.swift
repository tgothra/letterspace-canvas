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
    
    #if os(iOS)
    // Pre-initialized generators to avoid first-time delays
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium) 
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // Pre-warm generators on first access
    private static let preparedGenerators: Void = {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
    }()
    #endif
    
    static func impact(_ style: Style) {
        #if os(iOS)
        // Ensure generators are prepared
        _ = preparedGenerators
        
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:
            generator = lightGenerator
        case .medium:
            generator = mediumGenerator
        case .heavy:
            generator = heavyGenerator
        }
        
        generator.impactOccurred()
        #endif
        // On macOS, haptic feedback is not available, so we do nothing
    }
    
    // Method to pre-warm all generators (call during app startup)
    static func prepareAll() {
        #if os(iOS)
        _ = preparedGenerators
        #endif
    }
} 