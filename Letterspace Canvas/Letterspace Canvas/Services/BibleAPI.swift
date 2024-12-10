import Foundation

enum BibleAPIError: Error {
    case invalidURL
    case networkError(String)
    case decodingError(Error)
    case invalidResponse
    case noResults
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid verse reference"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let error):
            return "Error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .noResults:
            return "No verses found"
        }
    }
}

class BibleAPI {
    private static func cleanText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }

    static func searchVerses(query: String, translation: String = "KJV") async throws -> [BibleVerse] {
        // Format query for API (e.g., "John 3:16" or "John 3:16-18")
        let components = query.lowercased().components(separatedBy: CharacterSet(charactersIn: " "))
        guard components.count >= 2,
              let book = components[safe: 0],
              let reference = components[safe: 1] else {
            throw BibleAPIError.invalidURL
        }
        
        // Check if this is a verse range by looking for a hyphen
        let isVerseRange = reference.contains("-")
        
        // Handle verse ranges (e.g., "3:16-18")
        let urlString = "https://bible-api.com/\(book)+\(reference)?translation=kjv"
        guard let url = URL(string: urlString) else {
            throw BibleAPIError.invalidURL
        }
        
        print("Requesting URL: \(urlString)")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BibleAPIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            struct BibleAPIResponse: Codable {
                let reference: String
                let text: String
                let translation_name: String
                let verses: [VerseDetail]?
                
                struct VerseDetail: Codable {
                    let book_name: String
                    let chapter: Int
                    let verse: Int
                    let text: String
                }
            }
            
            do {
                let response = try JSONDecoder().decode(BibleAPIResponse.self, from: data)
                var results: [BibleVerse] = []
                
                // If we have individual verses, return them separately
                if let verses = response.verses {
                    // Only add the full passage option if this is a verse range
                    if isVerseRange && verses.count > 1 {
                        results.append(BibleVerse(
                            reference: response.reference,
                            text: cleanText(response.text),
                            translation: response.translation_name,
                            isFullPassage: true
                        ))
                    }
                    
                    // Then add individual verses
                    results.append(contentsOf: verses.map { verse in
                        BibleVerse(
                            reference: "\(verse.book_name) \(verse.chapter):\(verse.verse)",
                            text: cleanText(verse.text),
                            translation: response.translation_name,
                            isFullPassage: false
                        )
                    })
                    return results
                }
                
                // Fallback to using the full text if verses array is not available
                let verse = BibleVerse(
                    reference: response.reference,
                    text: cleanText(response.text),
                    translation: response.translation_name,
                    isFullPassage: isVerseRange
                )
                return [verse]
            } catch {
                print("Decoding error: \(error)")
                throw BibleAPIError.decodingError(error)
            }
            
        case 404:
            throw BibleAPIError.noResults
        default:
            throw BibleAPIError.networkError("HTTP \(httpResponse.statusCode)")
        }
    }
    
    static func getAvailableTranslations() -> [String] {
        return ["KJV"]
    }
}

// Helper extension for safe array access
private extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 