import Foundation

struct SearchResult {
    let verses: [BibleVerse]
    let total: Int
    let hasMore: Bool
}

// MARK: - Chapter Result for full chapter display
struct ChapterResult {
    let book: String
    let chapter: Int
    let verses: [BibleVerse]
    let translation: String
    let focusedVerses: [Int] // Verse numbers to highlight
}

struct BibleAPI {
    private static let baseURL = "https://bible-api.com"
    private static let apiBibleKey = "c188be8322a8a1d53c2e47fb09a0f658"
    private static let versesPerPage = 20
    
    // MARK: - New function to fetch full chapter
    static func fetchChapter(book: String, chapter: Int, translation: String = "KJV", focusedVerses: [Int] = []) async throws -> ChapterResult {
        let bookFormatted = book.replacingOccurrences(of: " ", with: "%20")
        let translationFormatted = translation.lowercased()
        let endpoint = "\(baseURL)/\(bookFormatted)%20\(chapter)?translation=\(translationFormatted)"
        
        print("📖 Fetching chapter from: \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Log response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("📖 HTTP Status: \(httpResponse.statusCode)")
                
                // Handle HTTP errors explicitly
                if httpResponse.statusCode != 200 {
                    if httpResponse.statusCode == 404 {
                        throw NSError(domain: "BibleAPI", code: 404, userInfo: [
                            NSLocalizedDescriptionKey: "Chapter \(book) \(chapter) not found. Please check the book name and chapter number."
                        ])
                    } else if httpResponse.statusCode == 400 {
                        throw NSError(domain: "BibleAPI", code: 400, userInfo: [
                            NSLocalizedDescriptionKey: "Translation '\(translation)' not available for \(book) \(chapter). Try a different translation."
                        ])
                    } else {
                        throw NSError(domain: "BibleAPI", code: httpResponse.statusCode, userInfo: [
                            NSLocalizedDescriptionKey: "Server error (HTTP \(httpResponse.statusCode)). The Bible API may be temporarily unavailable."
                        ])
                    }
                }
            }
            
            // Try to decode and handle different response formats
            do {
                let apiResponse = try JSONDecoder().decode(BibleAPIResponse.self, from: data)
                print("📖 Successfully decoded API response")
                
                return try parseChapterResponse(apiResponse, book: book, chapter: chapter, translation: translation, focusedVerses: focusedVerses)
                
            } catch let decodeError {
                print("📖 JSON decode error: \(decodeError)")
                
                // If JSON parsing fails, check for specific error response formats
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📖 Raw response: \(responseString.prefix(200))")
                    
                    // Check if it's an error message in JSON format
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? String {
                        throw NSError(domain: "BibleAPI", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "API Error: \(errorMessage)"
                        ])
                    }
                }
                
                // If it's a 404 or similar, provide a more helpful error
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    throw NSError(domain: "BibleAPI", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "Chapter \(book) \(chapter) not found. Please check the book name and chapter number."
                    ])
                }
                
                throw NSError(domain: "BibleAPI", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to parse data for \(book) \(chapter). Translation '\(translation)' may not be available."
                ])
            }
        } catch let networkError as URLError {
            // Handle network errors
            let errorMessage: String
            switch networkError.code {
            case .notConnectedToInternet:
                errorMessage = "You are not connected to the internet. Please check your connection."
            case .timedOut:
                errorMessage = "The request timed out. Please try again."
            default:
                errorMessage = "Network error: \(networkError.localizedDescription)"
            }
            
            throw NSError(domain: "BibleAPI", code: -2, userInfo: [
                NSLocalizedDescriptionKey: errorMessage
            ])
        } catch {
            // Rethrow if already handled above
            throw error
        }
    }
    
    private static func parseChapterResponse(_ response: BibleAPIResponse, book: String, chapter: Int, translation: String, focusedVerses: [Int]) throws -> ChapterResult {
        var verses: [BibleVerse] = []
        
        if let apiVerses = response.verses, !apiVerses.isEmpty {
            // API returned structured verse data
            print("📖 Processing \(apiVerses.count) verses from structured response")
            verses = apiVerses.compactMap { verse in
                guard let verseNum = verse.verse, verseNum > 0 else { return nil }
                
                let reference = "\(book) \(chapter):\(verseNum)"
                let formattedText = verse.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                
                return BibleVerse(
                    reference: reference,
                    text: formattedText,
                    translation: translation,
                    isFullPassage: false,
                    fullPassageText: nil
                )
            }
        } else if !response.text.isEmpty {
            // Parse the full text response
            print("📖 Processing text response, length: \(response.text.count)")
            verses = try parseTextResponse(response.text, book: book, chapter: chapter, translation: translation)
        } else {
            throw NSError(domain: "BibleAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No verse data found in the response."])
        }
        
        if verses.isEmpty {
            throw NSError(domain: "BibleAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No verses could be parsed from \(book) \(chapter)."])
        }
        
        print("📖 Successfully parsed \(verses.count) verses")
        
        return ChapterResult(
            book: book,
            chapter: chapter,
            verses: verses,
            translation: translation,
            focusedVerses: focusedVerses
        )
    }
    
    private static func parseTextResponse(_ fullText: String, book: String, chapter: Int, translation: String) throws -> [BibleVerse] {
        let cleanText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        var verses: [BibleVerse] = []
        
        // Split by verse patterns (looking for verse numbers at start of lines or inline)
        let lines = cleanText.components(separatedBy: .newlines)
        var currentVerse = 1
        var currentText = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // Check if line starts with a verse number (e.g., "1 In the beginning..." or "1. In the beginning...")
            if let match = trimmedLine.range(of: #"^(\d+)[\.\s]+"#, options: .regularExpression) {
                // Save previous verse if we have text
                if !currentText.isEmpty && currentVerse > 0 {
                    let reference = "\(book) \(chapter):\(currentVerse)"
                    verses.append(BibleVerse(
                        reference: reference,
                        text: currentText.trimmingCharacters(in: .whitespacesAndNewlines),
                        translation: translation,
                        isFullPassage: false,
                        fullPassageText: nil
                    ))
                }
                
                // Extract verse number and text
                let verseNumberStr = String(trimmedLine[match]).replacingOccurrences(of: #"[\.\s]+"#, with: "", options: .regularExpression)
                currentVerse = Int(verseNumberStr) ?? currentVerse + 1
                currentText = String(trimmedLine[match.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // Continue current verse text
                if !currentText.isEmpty {
                    currentText += " "
                }
                currentText += trimmedLine
            }
        }
        
        // Add the last verse
        if !currentText.isEmpty && currentVerse > 0 {
            let reference = "\(book) \(chapter):\(currentVerse)"
            verses.append(BibleVerse(
                reference: reference,
                text: currentText.trimmingCharacters(in: .whitespacesAndNewlines),
                translation: translation,
                isFullPassage: false,
                fullPassageText: nil
            ))
        }
        
        // If we still don't have verses, try a different approach
        if verses.isEmpty {
            // Fallback: treat entire text as verse 1
            verses.append(BibleVerse(
                reference: "\(book) \(chapter):1",
                text: cleanText,
                translation: translation,
                isFullPassage: true,
                fullPassageText: nil
            ))
        }
        
        return verses
    }
    
    static func searchVerses(query: String, translation: String, mode: BibleSearchMode, page: Int = 1) async throws -> SearchResult {
        let formattedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        switch mode {
        case .reference:
            let endpoint = "\(baseURL)/\(formattedQuery)?translation=\(translation.lowercased())"
            guard let url = URL(string: endpoint) else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(BibleAPIResponse.self, from: data)
            
            if let verses = response.verses {
                let fullPassageText = verses.count > 1 ? response.text.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                
                let formattedVerses = verses.map { verse -> BibleVerse in
                    let reference = if let bookName = verse.book_name, let chapter = verse.chapter, let verseNum = verse.verse {
                        "\(bookName) \(chapter):\(verseNum)"
                    } else {
                        response.reference
                    }
                    
                    let formattedText = verse.text
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: " ")
                        .replacingOccurrences(of: "  ", with: " ")
                    
                    return BibleVerse(
                        reference: reference,
                        text: formattedText,
                        translation: translation,
                        isFullPassage: verses.count > 1,
                        fullPassageText: fullPassageText
                    )
                }
                
                return SearchResult(verses: formattedVerses, total: verses.count, hasMore: false)
            } else {
                let cleanedText = response.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .filter { !$0.contains(response.reference) }
                    .joined(separator: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                
                let verse = BibleVerse(
                    reference: response.reference,
                    text: cleanedText,
                    translation: translation,
                    isFullPassage: false,
                    fullPassageText: nil
                )
                return SearchResult(verses: [verse], total: 1, hasMore: false)
            }
            
        case .keyword:
            let endpoint = "https://api.scripture.api.bible/v1/bibles/de4e12af7f28f599-02/search?query=\(formattedQuery)&limit=\(versesPerPage)&offset=\((page - 1) * versesPerPage)"
            guard let url = URL(string: endpoint) else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.setValue(apiBibleKey, forHTTPHeaderField: "api-key")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            struct SearchResponse: Codable {
                struct Verse: Codable {
                    let reference: String
                    let text: String
                }
                let data: SearchData
                struct SearchData: Codable {
                    let query: String
                    let total: Int
                    let verses: [Verse]
                }
            }
            
            let response = try JSONDecoder().decode(SearchResponse.self, from: data)
            let verses = response.data.verses.map { verse in
                let cleanedText = verse.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .filter { !$0.contains(verse.reference) }
                    .joined(separator: " ")
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                
                return BibleVerse(
                    reference: verse.reference,
                    text: cleanedText,
                    translation: "KJV",
                    isFullPassage: false,
                    fullPassageText: nil
                )
            }
            
            let hasMore = (page * versesPerPage) < response.data.total
            return SearchResult(verses: verses, total: response.data.total, hasMore: hasMore)
            
        case .strongs:
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Strong's concordance search is not yet implemented"])
        }
    }
} 