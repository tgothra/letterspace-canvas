import Foundation
import SwiftUI

public struct BibleVerse: Codable, Identifiable, Equatable {
    public let id: UUID
    public let reference: String
    public let text: String
    public let translation: String
    public let isFullPassage: Bool
    public let fullPassageText: String?
    
    public init(reference: String = "", text: String, translation: String = "KJV", isFullPassage: Bool = false, fullPassageText: String? = nil) {
        self.id = UUID()
        self.reference = reference
        self.text = text
        self.translation = translation
        self.isFullPassage = isFullPassage
        self.fullPassageText = fullPassageText
    }
    
    // Implement Equatable conformance
    public static func == (lhs: BibleVerse, rhs: BibleVerse) -> Bool {
        return lhs.id == rhs.id &&
               lhs.reference == rhs.reference &&
               lhs.text == rhs.text &&
               lhs.translation == rhs.translation &&
               lhs.isFullPassage == rhs.isFullPassage &&
               lhs.fullPassageText == rhs.fullPassageText
    }
} 