import Foundation

struct BookmarkItem: Identifiable, Equatable {
    let id: String // Unique identifier (UUID string) stored in the attribute
    let range: NSRange // The range of the bookmarked text in the NSTextStorage
    let snippet: String // A short preview of the bookmarked text
    // let creationDate: Date // Optional: Could add later if needed for sorting/timeline

    // Equatable conformance based on ID
    static func == (lhs: BookmarkItem, rhs: BookmarkItem) -> Bool {
        lhs.id == rhs.id
    }
} 