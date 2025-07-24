import SwiftUI

// Color scheme options for the app
enum AppColorScheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
}

// Appearance Controller for managing app-wide color scheme
@Observable
class AppearanceController {
    static let shared = AppearanceController()
    
    var selectedScheme: AppColorScheme {
        didSet {
            UserDefaults.standard.set(selectedScheme.rawValue, forKey: "preferredColorScheme")
            UserDefaults.standard.synchronize()
            setAppearance()
        }
    }
    
    init() {
        // Load saved preference or default to system
        let savedScheme = UserDefaults.standard.string(forKey: "preferredColorScheme") ?? AppColorScheme.system.rawValue
        self.selectedScheme = AppColorScheme(rawValue: savedScheme) ?? .system
    }
    
    var colorScheme: ColorScheme? {
        switch selectedScheme {
        case .system:
            return nil // Let system decide
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    func setAppearance() {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        switch selectedScheme {
        case .system:
            window.overrideUserInterfaceStyle = .unspecified
        case .light:
            window.overrideUserInterfaceStyle = .light
        case .dark:
            window.overrideUserInterfaceStyle = .dark
        }
        #elseif os(macOS)
        // For macOS, we'll use the preferredColorScheme modifier since overrideUserInterfaceStyle isn't available
        // The main app will handle this through the colorScheme computed property
        #endif
    }
}

// Removed extension for ScriptureLayoutStyle from here

@Observable
class AppSettings {
    // Shared instance that can be accessed throughout the app
    static let shared = AppSettings()
    
    // --- Default settings keys for UserDefaults ---
    private let scriptureLineColorKey = "scriptureLineColorData"
    private let defaultLayoutKey = "defaultScriptureLayoutRawValue"
    
    // --- Observable properties with UserDefaults persistence ---
    
    // Default color for the scripture line
    var scriptureLineColor: Color {
        didSet {
            saveColor(scriptureLineColor, forKey: scriptureLineColorKey)
        }
    }
    
    // Default layout for scripture blocks
    var defaultScriptureLayout: ScriptureLayoutStyle {
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