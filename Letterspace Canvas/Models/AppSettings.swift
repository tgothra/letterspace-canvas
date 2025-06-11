import SwiftUI

// Removed extension for ScriptureLayoutStyle from here

class AppSettings: ObservableObject {
    // Shared instance that can be accessed throughout the app
    static let shared = AppSettings()
    
    // --- Default settings keys for UserDefaults ---
    private let scriptureLineColorKey = "scriptureLineColorData"
    private let defaultLayoutKey = "defaultScriptureLayoutRawValue"
    
    // --- Published properties with UserDefaults persistence ---
    
    // Default color for the scripture line
    @Published var scriptureLineColor: Color {
        didSet {
            saveColor(scriptureLineColor, forKey: scriptureLineColorKey)
        }
    }
    
    // Default layout for scripture blocks
    @Published var defaultScriptureLayout: ScriptureLayoutStyle {
        didSet {
            UserDefaults.standard.set(defaultScriptureLayout.rawValue, forKey: defaultLayoutKey)
        }
    }

    // --- Initialization --- 
    init() {
        // Initialize properties with default values FIRST
        #if os(macOS)
        self.scriptureLineColor = Color(nsColor: NSColor(red: 0.13, green: 0.76, blue: 0.48, alpha: 0.9)) // Default color
        #elseif os(iOS)
        self.scriptureLineColor = Color(UIColor(red: 0.13, green: 0.76, blue: 0.48, alpha: 0.9)) // Default color
        #endif
        self.defaultScriptureLayout = .individualVerses // Default layout

        // NOW load persisted values and overwrite defaults if available
        if let loadedColor = loadColor(forKey: scriptureLineColorKey) {
            self.scriptureLineColor = loadedColor
        }
        
        let savedLayoutRawValue = UserDefaults.standard.integer(forKey: defaultLayoutKey)
        if let loadedLayout = ScriptureLayoutStyle(rawValue: savedLayoutRawValue) {
            self.defaultScriptureLayout = loadedLayout
        }
    }

    // --- Helper Methods for Color Persistence ---
    // Save Color to UserDefaults as Data
    private func saveColor(_ color: Color, forKey key: String) {
        #if os(macOS)
        let platformColor = NSColor(color)
        #elseif os(iOS)
        let platformColor = UIColor(color)
        #endif
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: platformColor, requiringSecureCoding: false)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Error saving color: \(error)")
        }
    }

    // Load Color from UserDefaults
    private func loadColor(forKey key: String) -> Color? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            #if os(macOS)
            if let nsColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return Color(nsColor)
            }
            #elseif os(iOS)
            if let uiColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
                return Color(uiColor)
            }
            #endif
        } catch {
            print("Error loading color: \(error)")
        }
        return nil
    }
    
    // --- Helper for accessing NSColor --- 
    // Convert SwiftUI Color to NSColor for AppKit contexts
    #if os(macOS)
    func scriptureLineNSColor() -> NSColor {
        return NSColor(scriptureLineColor)
    }
    #endif
} 