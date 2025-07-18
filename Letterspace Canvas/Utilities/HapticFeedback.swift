import SwiftUI

#if os(iOS)
import UIKit
import os.log
#endif

struct HapticFeedback {
    enum Style {
        case light
        case medium
        case heavy
    }
    
    #if os(iOS)
    // Track if haptic system is available
    private static var isHapticSystemAvailable = true
    
    // Lazy initialization with error handling
    private static var lightGenerator: UIImpactFeedbackGenerator? = {
        guard isHapticSystemAvailable else { return nil }
        return UIImpactFeedbackGenerator(style: .light)
    }()
    
    private static var mediumGenerator: UIImpactFeedbackGenerator? = {
        guard isHapticSystemAvailable else { return nil }
        return UIImpactFeedbackGenerator(style: .medium)
    }()
    
    private static var heavyGenerator: UIImpactFeedbackGenerator? = {
        guard isHapticSystemAvailable else { return nil }
        return UIImpactFeedbackGenerator(style: .heavy)
    }()
    #endif
    
    static func impact(_ style: Style) {
        #if os(iOS)
        guard isHapticSystemAvailable else { return }
        
        // Perform haptic feedback on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInteractive).async {
            let generator: UIImpactFeedbackGenerator?
            switch style {
            case .light:
                generator = lightGenerator
            case .medium:
                generator = mediumGenerator
            case .heavy:
                generator = heavyGenerator
            }
            
            // Safely trigger haptic feedback with timeout protection
            guard let generator = generator else { return }
            
            // Use a timeout to prevent hanging
            let semaphore = DispatchSemaphore(value: 0)
            var completed = false
            
            DispatchQueue.global(qos: .userInteractive).async {
                generator.impactOccurred()
                if !completed {
                    completed = true
                    semaphore.signal()
                }
            }
            
            // Timeout after 100ms to prevent blocking
            _ = semaphore.wait(timeout: .now() + 0.1)
            if !completed {
                os_log("Haptic feedback timed out, disabling haptic system", log: .default, type: .error)
                isHapticSystemAvailable = false
            }
        }
        #endif
        // On macOS, haptic feedback is not available, so we do nothing
    }
    
    // Method to pre-warm all generators (call during app startup)
    static func prepareAll() {
        #if os(iOS)
        guard isHapticSystemAvailable else { return }
        
        // Prepare generators asynchronously to avoid blocking app startup
        DispatchQueue.global(qos: .utility).async {
            do {
                // Try to prepare each generator with timeout protection
                let preparationQueue = DispatchQueue.global(qos: .userInitiated)
                let timeout: DispatchTime = .now() + 2.0 // 2 second timeout
                
                let group = DispatchGroup()
                
                // Prepare each generator in parallel with timeout
                [lightGenerator, mediumGenerator, heavyGenerator].forEach { generator in
                    guard let generator = generator else { return }
                    group.enter()
                    preparationQueue.async {
                        generator.prepare()
                        group.leave()
                    }
                }
                
                // Wait for completion or timeout
                let result = group.wait(timeout: timeout)
                if result == .timedOut {
                    os_log("Haptic preparation timed out, disabling haptic system", log: .default, type: .error)
                    isHapticSystemAvailable = false
                }
            }
        }
        #endif
    }
} 