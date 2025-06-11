//
// TextSubsystemReset.swift
// Created by cache clearing script
//

import SwiftUI

#if os(macOS)
import AppKit

// This extension adds a method to detect and handle text subsystem reset requests
extension NSApplication {
    @objc func resetTextSubsystem() {
        print("🧹 Resetting text subsystem...")
        
        // Reset text view defaults
        UserDefaults.standard.removeObject(forKey: "NSFontPanelAttributes")
        UserDefaults.standard.removeObject(forKey: "NSTextViewFindPanelKey")
        UserDefaults.standard.removeObject(forKey: "NSFontAttributesForToolTip")
        
        // Note: NSLayoutManager doesn't have a defaultManager
        // Instead, we'll just set up a flag that our views can detect
        // to recreate their layout managers on next initialization
        UserDefaults.standard.set(true, forKey: "com.letterspace.forceReinitializeTextViews")
        
        // Reset shared font manager
        NSFontManager.shared.setSelectedFont(NSFont.systemFont(ofSize: NSFont.systemFontSize), isMultiple: false)
        NSFontManager.shared.setSelectedAttributes([:], isMultiple: false)
        
        // Reset flag
        UserDefaults.standard.set(false, forKey: "com.letterspace.resetTextSubsystem")
        UserDefaults.standard.synchronize()
        
        print("✅ Text subsystem reset complete")
    }
}

// Register for reset notification
extension AppDelegate {
    func checkForTextSubsystemReset() {
        if UserDefaults.standard.bool(forKey: "com.letterspace.resetTextSubsystem") {
            NSApplication.shared.resetTextSubsystem()
        }
    }
}
#endif