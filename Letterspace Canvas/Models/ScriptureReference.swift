import Foundation

struct ScriptureReference: Identifiable, Codable, Hashable {
    let id = UUID()
    let book: String
    let chapter: Int
    let verse: String // Can be "1" or "1-3" for ranges
    let displayText: String
    
    // Computed property for full reference
    var fullReference: String {
        return "\(book) \(chapter):\(verse)"
    }
    
    // Helper to parse verse ranges
    var verseRange: ClosedRange<Int> {
        if verse.contains("-") {
            let parts = verse.split(separator: "-")
            if parts.count == 2,
               let start = Int(parts[0]),
               let end = Int(parts[1]) {
                return start...end
            }
        }
        
        if let singleVerse = Int(verse) {
            return singleVerse...singleVerse
        }
        
        return 1...1 // Fallback
    }
    
    // Helper to check if this reference contains a specific verse
    func containsVerse(_ verseNumber: Int) -> Bool {
        return verseRange.contains(verseNumber)
    }
    
    // Computed property for chapter key (book + chapter)
    var chapterKey: String {
        return "\(book) \(chapter)"
    }
    
    // Get all verse numbers covered by this reference
    var verseNumbers: [Int] {
        return Array(verseRange)
    }
}

// MARK: - Consolidated Chapter Reference
struct ConsolidatedChapterReference: Identifiable, Hashable {
    let id = UUID()
    let book: String
    let chapter: Int
    let highlightedVerses: Set<Int> // Verse numbers to highlight
    let originalReferences: [ScriptureReference] // Original references that were consolidated
    
    var displayText: String {
        if highlightedVerses.count == 1 {
            return "\(book) \(chapter):\(highlightedVerses.first!)"
        } else if highlightedVerses.count > 1 {
            let sortedVerses = highlightedVerses.sorted()
            if sortedVerses.count <= 3 {
                // Show up to 3 individual verses
                return "\(book) \(chapter):\(sortedVerses.map(String.init).joined(separator: ","))"
            } else {
                // For many verses, just show the chapter
                return "\(book) \(chapter)"
            }
        }
        return "\(book) \(chapter)"
    }
    
    var chapterKey: String {
        return "\(book) \(chapter)"
    }
}

// MARK: - Scripture Reference Consolidation Helper
extension Array where Element == ScriptureReference {
    
    /// Consolidates scripture references by chapter, combining multiple verses from the same chapter
    /// Returns consolidated chapter references that limit duplicate chapter buttons
    func consolidatedByChapter() -> [ConsolidatedChapterReference] {
        var chapterMap: [String: [ScriptureReference]] = [:]
        
        // Group references by chapter
        for reference in self {
            let key = reference.chapterKey
            if chapterMap[key] == nil {
                chapterMap[key] = []
            }
            chapterMap[key]?.append(reference)
        }
        
        // Convert to consolidated references
        return chapterMap.map { (chapterKey, references) in
            let firstRef = references.first!
            
            // Collect all highlighted verse numbers
            var allVerses: Set<Int> = []
            for ref in references {
                allVerses.formUnion(Set(ref.verseNumbers))
            }
            
            return ConsolidatedChapterReference(
                book: firstRef.book,
                chapter: firstRef.chapter,
                highlightedVerses: allVerses,
                originalReferences: references
            )
        }.sorted { left, right in
            // Sort by biblical order (book, then chapter)
            if left.book != right.book {
                return biblicalBookOrder(left.book) < biblicalBookOrder(right.book)
            }
            return left.chapter < right.chapter
        }
    }
}

// Helper function for biblical book ordering
private func biblicalBookOrder(_ book: String) -> Int {
    let books = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", 
                 "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
                 "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther",
                 "Job", "Psalm", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon",
                 "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
                 "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum",
                 "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
                 "Matthew", "Mark", "Luke", "John", "Acts",
                 "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", 
                 "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
                 "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", 
                 "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation"]
    
    return books.firstIndex(of: book) ?? 999
} 