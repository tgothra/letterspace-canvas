import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - iOS 26 Enhanced Haptic Feedback
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
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    
    // Track preparation status to avoid multiple preparations
    private static var isPrepared = false
    private static let preparationQueue = DispatchQueue(label: "haptic.preparation", qos: .utility)
    
    // Pre-warm generators on first access
    private static let preparedGenerators: Void = {
        preparationQueue.async {
            lightGenerator.prepare()
            mediumGenerator.prepare()
            heavyGenerator.prepare()
            selectionGenerator.prepare()
            isPrepared = true
            print("✅ iOS 26 Enhanced haptic feedback generators prepared successfully")
        }
    }()
    #endif
    
    // iOS 26 Enhancement: Impact with intensity control
    static func impact(_ style: Style, intensity: Double = 1.0) {
        #if os(iOS)
        // Check if haptics are available and enabled
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        
        // Ensure generators are prepared
        _ = preparedGenerators
        
        // Clamp intensity between 0.0 and 1.0
        let clampedIntensity = max(0.0, min(1.0, intensity))
        
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
            
            // iOS 26 Enhancement: Use intensity if available
            if #available(iOS 13.0, *) {
                generator.impactOccurred(intensity: CGFloat(clampedIntensity))
            } else {
                generator.impactOccurred()
            }
        }
        #endif
        // On macOS, haptic feedback is not available, so we do nothing
    }
    
    // iOS 26 Enhancement: Legacy method for backwards compatibility
    static func impact(_ style: Style) {
        impact(style, intensity: 1.0)
    }
    
    // iOS 26 Enhancement: Selection feedback
    static func selection() {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        
        // Ensure generators are prepared
        _ = preparedGenerators
        
        DispatchQueue.global(qos: .userInteractive).async {
            if !isPrepared {
                selectionGenerator.prepare()
            }
            selectionGenerator.selectionChanged()
        }
        #endif
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