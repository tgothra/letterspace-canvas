import Foundation

// Add this new struct near the top of the file, after the ScriptureElement struct
public enum ScriptureLayoutStyle: Int, CaseIterable, Identifiable {
    case individualVerses = 0   // Each verse with its own reference line
    case paragraph = 1          // Continuous paragraph with verse numbers in brackets
    case reference = 2          // Two-column layout with references on left
    
    public var id: Int { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .individualVerses: return "Individual Verses"
        case .paragraph: return "Paragraph"
        case .reference: return "Reference"
        }
    }
}

// Replace the layoutToInt helper function at the bottom of the file
public func layoutToInt(_ layout: ScriptureLayoutStyle) -> Int {
    // Force explicit conversion to ensure correct raw values
    let explicitValue: Int
    switch layout {
    case .individualVerses: explicitValue = 0
    case .paragraph: explicitValue = 1
    case .reference: explicitValue = 2
    }
    print("📊 LAYOUT CONVERSION: Enum \\(layout) converted to explicit value \\(explicitValue)")
    return explicitValue
} 