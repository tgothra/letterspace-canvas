import Foundation

public struct ScriptureElement: Codable, Identifiable {
    public var id: String { reference + translation } // Conform to Identifiable for lists
    public let reference: String
    public let translation: String
    public let text: String
    
    public var cleanedReference: String {
        if let pipeIndex = reference.firstIndex(of: "|") {
            return String(reference[..<pipeIndex]).trimmingCharacters(in: .whitespaces)
        }
        return reference
    }
    
    public var cleanedText: String {
        // This logic seems to be more for parsing specific import formats rather than general cleaning.
        // Keeping it as is for now, but might need review based on how text is actually stored.
        if let lastPipeIndex = text.lastIndex(of: "|") {
            let startIndex = text.index(after: lastPipeIndex)
            return String(text[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var fullTranslation: String {
        switch translation {
        case "KJV": return "King James Version"
        case "ESV": return "English Standard Version"
        case "NIV": return "New International Version"
        case "NASB": return "New American Standard Bible"
        case "NKJV": return "New King James Version"
        default: return translation
        }
    }
    
    // Initializer if needed, especially if properties become non-public or have defaults
    public init(reference: String, translation: String, text: String) {
        self.reference = reference
        self.translation = translation
        self.text = text
    }
} 