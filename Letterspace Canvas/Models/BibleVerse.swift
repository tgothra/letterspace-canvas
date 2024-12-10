import Foundation
import SwiftUI

struct BibleVerse: Codable, Identifiable {
    let id: UUID
    let reference: String
    let text: String
    let translation: String
    let isFullPassage: Bool
    
    init(reference: String = "", text: String, translation: String = "KJV", isFullPassage: Bool = false) {
        self.id = UUID()
        self.reference = reference
        self.text = text
        self.translation = translation
        self.isFullPassage = isFullPassage
    }
} 