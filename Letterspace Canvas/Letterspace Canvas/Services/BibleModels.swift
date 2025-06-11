import Foundation

enum BibleSearchMode {
    case reference   // book icon - for verse references
    case keyword    // magnifying glass - for keyword search
    case strongs    // number - for Strong's concordance numbers
}

struct BibleAPIResponse: Codable {
    let reference: String
    let text: String
    let translation_id: String?
    let translation_name: String?
    let translation_note: String?
    let verses: [BibleAPIVerse]?
}

struct BibleAPIVerse: Codable {
    let book_id: String?
    let book_name: String?
    let chapter: Int?
    let verse: Int?
    let text: String
} 