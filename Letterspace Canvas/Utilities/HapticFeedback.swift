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
    
    // Track preparation status to avoid multiple preparations
    private static var isPrepared = false
    private static let preparationQueue = DispatchQueue(label: "haptic.preparation", qos: .utility)
    
    // Pre-warm generators on first access
    private static let preparedGenerators: Void = {
        preparationQueue.async {
            lightGenerator.prepare()
            mediumGenerator.prepare()
            heavyGenerator.prepare()
            isPrepared = true
            print("✅ Haptic feedback generators prepared successfully")
        }
    }()
    #endif
    
    static func impact(_ style: Style) {
        #if os(iOS)
        // Check if haptics are available and enabled
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        
        // Ensure generators are prepared
        _ = preparedGenerators
        
        // Dispatch haptic feedback on a background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInteractive).async {
            let generator: UIImpactFeedbackGenerator
            switch style {
            case .light:
                generator = lightGenerator
            case .medium:
                generator = mediumGenerator
            case .heavy:
                generator = heavyGenerator
            }
            
            // Re-prepare if needed (defensive programming)
            if !isPrepared {
                generator.prepare()
            }
            
            generator.impactOccurred()
        }
        #endif
        // On macOS, haptic feedback is not available, so we do nothing
    }
    
    // Method to pre-warm all generators (call during app startup)
    static func prepareAll() {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        _ = preparedGenerators
        #endif
    }
    
    // Method to safely trigger haptic feedback with timeout protection
    static func safeTrigger(_ style: Style, timeout: TimeInterval = 0.1) {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        
        let workItem = DispatchWorkItem {
            impact(style)
        }
        
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem)
        
        // Cancel if it takes too long
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            workItem.cancel()
        }
        #endif
    }
} 