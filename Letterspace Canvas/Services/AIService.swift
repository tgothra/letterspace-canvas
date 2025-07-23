import Foundation
import SwiftUI
import Security

enum AIServiceError: Error {
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    case keychainError
}

class AIService {
    static let shared = AIService()
    
    // Use this for development only
    private let defaultApiKey = "AIzaSyDhe1rhvsYUm7yEtFbrWlHtZ4Zh3DR9yH4" // Your Gemini API key
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    var apiKey: String {
        // Try to get from keychain first
        if let storedKey = getApiKeyFromKeychain(), !storedKey.isEmpty {
            return storedKey
        }
        // Fall back to default
        return defaultApiKey
    }
    
    private init() {
        // Attempt to save default key to keychain if no key exists
        if getApiKeyFromKeychain() == nil {
            _ = saveApiKeyToKeychain(defaultApiKey)
        }
        // UserLibraryService instance - can be injected or instantiated if appropriate
        // For simplicity here, assuming it can be accessed, e.g. as a shared instance or passed in.
        // This might need adjustment based on your project structure.
        // let userLibraryService = UserLibraryService() 
    }
    
    // Unified method for Smart Study, incorporating scope and library search
    func generateSmartStudyResponse(
        prompt: String, 
        scope: SearchScope, // Pass the scope
        userQuery: String, // Original user query for vector search if needed
        userLibraryService: UserLibraryService, // Pass the library service instance
        completion: @escaping (Result<(text: String, searchQueries: [String], sourceDocumentTitle: String?), Error>) -> Void
    ) {
        // Estimate token count (approximate 1 token per 4 characters)
        var estimatedTokens = prompt.count / 4 + 800 // Base for general query
        var modifiedPrompt = prompt
        var toolsPayload: [[String: Any]]? = nil
        var retrievedLibraryContext = ""
        var firstSourceDocumentTitle: String? = nil // To store the title of the first source document

        // 1. Determine if Library Search is needed and perform it
        if scope == .libraryOnly || scope == .allSources {
            generateEmbeddings(textChunks: [userQuery]) { result in
                switch result {
                case .success(let queryEmbeddingArray):
                    guard let queryVector = queryEmbeddingArray.first else {
                        print("⚠️ Could not generate embedding for the user query. Proceeding without library search.")
                        self.executeAISmartStudyCall(modifiedPrompt, tools: toolsPayload, estimatedTokens: estimatedTokens, sourceDocumentTitle: nil, completion: completion)
                        return
                    }
                    
                    let relevantChunkResults = userLibraryService.searchLibraryByVector(queryVector: queryVector, topN: 3)
                    if !relevantChunkResults.isEmpty {
                        // Store the title of the first relevant document
                        firstSourceDocumentTitle = relevantChunkResults.first?.sourceItemTitle
                        
                        retrievedLibraryContext = "\n\n--- Relevant information from your Library ---\n"
                        relevantChunkResults.forEach { result in
                            // Include the source title with each chunk for the AI's context
                            retrievedLibraryContext += "\nDocument: \(result.sourceItemTitle)\nChunk: \(result.chunk.text)\n---"
                        }
                        retrievedLibraryContext += "\n--- End of Library Information ---\n\n"
                        
                        // Add specific instruction to NOT include source information in the answer
                        retrievedLibraryContext += "IMPORTANT: DO NOT mention or reference the source document in your answer. The source is already being displayed separately. Focus only on providing a direct answer to the question based on the information above.\n\n"
                        
                        // Add instruction to indicate when using library content
                        retrievedLibraryContext += "EXTREMELY IMPORTANT: Only include the marker '[LIBRARY_CONTENT_USED]' at the very end of your response if you DIRECTLY QUOTED or SPECIFICALLY REFERENCED UNIQUE INFORMATION from the library documents above to answer the question. DO NOT include this marker if:\n"
                        retrievedLibraryContext += "1. You answered from general knowledge about the Bible, Christianity, or scripture\n"
                        retrievedLibraryContext += "2. The question is about spiritual or religious topics that don't require the specific document\n"
                        retrievedLibraryContext += "3. You could have answered the question completely without the library documents\n"
                        retrievedLibraryContext += "Only use this marker when the specific PDF document was essential to your answer.\n\n"
                        
                        retrievedLibraryContext += "Additionally, if this is a Bible-related question that you're answering from Biblical knowledge (not from library documents), please format all scripture references consistently as: [Book Chapter:Verse] (e.g., [Genesis 1:1], [Matthew 5:3-4], [Revelation 21:4]). This helps with reference extraction.\n\n"
                        
                        retrievedLibraryContext += "IMPORTANT: A Bible question like 'tell me about Noah' or 'explain Pentecost' should be answered from general Biblical knowledge, NOT from library documents about church giving or other topics. Only use library documents if they contain specific relevant information that directly answers the question.\n\n"
                        
                        modifiedPrompt = retrievedLibraryContext + prompt 
                        estimatedTokens += retrievedLibraryContext.count / 4
                        print("📚 Added \(relevantChunkResults.count) library chunks to the prompt from document(s) like '\(firstSourceDocumentTitle ?? "N/A")'.")
                    } else {
                        print("📚 No relevant chunks found in the library for this query.")
                    }
                    
                    if scope == .internetOnly || scope == .allSources {
                        toolsPayload = [["googleSearchRetrieval": [:]]]
                        estimatedTokens += 400
                    }
                    
                    self.executeAISmartStudyCall(modifiedPrompt, tools: toolsPayload, estimatedTokens: estimatedTokens, sourceDocumentTitle: firstSourceDocumentTitle, completion: completion)
                    
                case .failure(let error):
                    print("⚠️ Failed to generate embeddings for user query: \(error). Proceeding without library search.")
                    if scope == .libraryOnly {
                        completion(.failure(AIServiceError.apiError("Could not search library: failed to process your query.")))
                        return
                    }
                    self.executeAISmartStudyCall(modifiedPrompt, tools: toolsPayload, estimatedTokens: estimatedTokens, sourceDocumentTitle: nil, completion: completion)
                }
            }
        } else {
            if scope == .internetOnly {
                toolsPayload = [["googleSearchRetrieval": [:]]]
                estimatedTokens += 400
            }
            self.executeAISmartStudyCall(modifiedPrompt, tools: toolsPayload, estimatedTokens: estimatedTokens, sourceDocumentTitle: nil, completion: completion)
        }
    }

    // Keep the old generateTextWithSearch for now if other parts of the app use it directly,
    // or refactor them to use generateSmartStudyResponse.
    // For this example, I'm assuming we're focusing on SmartStudyView.
    /*
    func generateTextWithSearch(prompt: String, completion: @escaping (Result<(String, [String]), Error>) -> Void) {
        ...
    }
    */

    func generateText(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Estimate token count (approximate 1 token per 4 characters)
        let estimatedTokens = prompt.count / 4 + 800
        
        // Check if enough tokens are available
        if !TokenUsageService.shared.canUseTokens(estimatedTokens) {
            completion(.failure(AIServiceError.apiError("Monthly token limit reached. Please upgrade your subscription for more tokens.")))
            return
        }
        
        callGemini(prompt: prompt, maxTokens: 800, estimatedTokens: estimatedTokens, completion: completion)
    }
    
    func generateText(prompt: String, maxTokens: Int, completion: @escaping (Result<String, Error>) -> Void) {
        // Estimate token count (approximate 1 token per 4 characters)
        let estimatedTokens = prompt.count / 4 + maxTokens
        
        // Check if enough tokens are available
        if !TokenUsageService.shared.canUseTokens(estimatedTokens) {
            completion(.failure(AIServiceError.apiError("Monthly token limit reached. Please upgrade your subscription for more tokens.")))
            return
        }
        
        callGemini(prompt: prompt, maxTokens: maxTokens, estimatedTokens: estimatedTokens, completion: completion)
    }
    
    // MARK: - Keychain Management
    
    private func saveApiKeyToKeychain(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.yourcompany.letterspacecanvas",
            kSecAttrAccount as String: "geminiApiKey",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete any existing key before saving
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getApiKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.yourcompany.letterspacecanvas",
            kSecAttrAccount as String: "geminiApiKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let retrievedData = dataTypeRef as? Data {
            return String(data: retrievedData, encoding: .utf8)
        }
        
        return nil
    }
    
    // MARK: - API Calls
    
    private func callGemini(prompt: String, maxTokens: Int, estimatedTokens: Int, completion: @escaping (Result<String, Error>) -> Void) {
        // Create URL with API key as query parameter
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            completion(.failure(AIServiceError.invalidResponse))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create payload according to Gemini API format
        let payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": maxTokens
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(AIServiceError.networkError(error)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(AIServiceError.invalidResponse))
                    return
                }
                
                // Print raw response for debugging
                // if let rawString = String(data: data, encoding: .utf8) {
                //     print("--- Gemini API Response ---")
                //     print(rawString)
                //     print("-------------------------")
                // }
                
                do {
                    // Parse Gemini API response
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        
                        // Extract actual token usage from API response
                        var actualTokensUsed = estimatedTokens // Fallback to estimate
                        if let usageMetadata = json["usageMetadata"] as? [String: Any] {
                            let promptTokens = usageMetadata["promptTokenCount"] as? Int ?? 0
                            let responseTokens = usageMetadata["candidatesTokenCount"] as? Int ?? 0
                            let totalTokens = usageMetadata["totalTokenCount"] as? Int ?? (promptTokens + responseTokens)
                            
                            actualTokensUsed = totalTokens
                        }
                        
                        // Record actual token usage instead of estimate
                        TokenUsageService.shared.recordTokenUsage(actualTokensUsed)
                        
                        completion(.success(text))
                    } else {
                        // If response doesn't match expected format, try to extract error
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            completion(.failure(AIServiceError.apiError(message)))
                        } else {
                            completion(.failure(AIServiceError.invalidResponse))
                        }
                    }
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }

    // Function to generate embeddings for text chunks
    func generateEmbeddings(textChunks: [String], completion: @escaping (Result<[[Double]], AIServiceError>) -> Void) {
        let embeddingURLString = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:batchEmbedContents?key=\(apiKey)"
        guard let url = URL(string: embeddingURLString) else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Create requests payload for batch embedding
        let requests = textChunks.map { chunk in
            ["model": "models/text-embedding-004",
             "content": ["parts": [["text": chunk]]]]
        }
        let payload: [String: Any] = ["requests": requests]
        
        // Estimate token cost (input only for embeddings)
        // Note: Actual token count might be returned by the API, but we estimate here for simplicity.
        let estimatedTokens = textChunks.reduce(0) { $0 + ($1.count / 4) }

        // Check token limit (optional for embeddings, depending on policy)
        // If you want to gate embedding based on tokens:
        // guard TokenUsageService.shared.canUseTokens(estimatedTokens) else {
        //     completion(.failure(.apiError("Token limit reached. Cannot process document embedding.")))
        //     return
        // }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                guard let data = data else {
                    completion(.failure(.invalidResponse))
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let embeddingsArray = json["embeddings"] as? [[String: Any]] {
                        
                        let vectors = embeddingsArray.compactMap { $0["values"] as? [Double] }
                        
                        // Ensure we got the expected number of vectors
                        if vectors.count == textChunks.count {
                            // Record embedding token usage
                            // Use the actual count from API if available, else use estimate
                            // For now, using estimate:
                            TokenUsageService.shared.recordEmbeddingUsage(estimatedTokens)
                            completion(.success(vectors))
                        } else {
                            print("Embedding count mismatch. Expected \(textChunks.count), got \(vectors.count)")
                            completion(.failure(.invalidResponse))
                        }
                    } else {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorDict = json["error"] as? [String: Any],
                           let message = errorDict["message"] as? String {
                            completion(.failure(.apiError(message)))
                        } else {
                            completion(.failure(.invalidResponse))
                        }
                    }
                } catch {
                    completion(.failure(.networkError(error)))
                }
            }.resume()
        } catch {
            completion(.failure(.networkError(error)))
        }
    }

    // MARK: - API Calls with Google Search (Now a more general execution method)
    
    private func executeAISmartStudyCall(_ prompt: String, tools: [[String: Any]]?, estimatedTokens: Int, sourceDocumentTitle: String?, completion: @escaping (Result<(text: String, searchQueries: [String], sourceDocumentTitle: String?), Error>) -> Void) {
        // Create URL with API key as query parameter
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            completion(.failure(AIServiceError.invalidResponse))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create payload with Google Search enabled - use simpler format
        let payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "tools": tools, // Use the passed-in tools payload (can be nil)
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": estimatedTokens
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(AIServiceError.networkError(error)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(AIServiceError.invalidResponse))
                    return
                }
                
                // Print raw response for debugging
                if let rawString = String(data: data, encoding: .utf8) {
                    print("--- Gemini API Response with Search ---")
                    print(rawString)
                    print("-------------------------")
                }
                
                do {
                    // Parse Gemini API response with groundingMetadata
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        
                        // Extract search suggestion queries if available
                        var searchQueries: [String] = []
                        if let groundingMetadata = firstCandidate["groundingMetadata"] as? [String: Any],
                           let webSearchQueriesRaw = groundingMetadata["webSearchQueries"] {
                            // Handle both array of strings and array of dictionaries
                            if let webSearchQueries = webSearchQueriesRaw as? [String] {
                                searchQueries = webSearchQueries
                            } else if let webSearchQueriesDict = webSearchQueriesRaw as? [[String: Any]] {
                                // Extract text from dictionary format if needed
                                searchQueries = webSearchQueriesDict.compactMap { $0["text"] as? String }
                            }
                            print("📚 Found \(searchQueries.count) search queries")
                        }
                        
                        // Extract actual token usage from API response
                        var actualTokensUsed = estimatedTokens // Fallback to estimate
                        if let usageMetadata = json["usageMetadata"] as? [String: Any] {
                            let promptTokens = usageMetadata["promptTokenCount"] as? Int ?? 0
                            let responseTokens = usageMetadata["candidatesTokenCount"] as? Int ?? 0
                            let totalTokens = usageMetadata["totalTokenCount"] as? Int ?? (promptTokens + responseTokens)
                            
                            actualTokensUsed = totalTokens
                        }
                        
                        // Record actual token usage instead of estimate
                        TokenUsageService.shared.recordTokenUsage(actualTokensUsed)
                        
                        // Check if the response actually used library content
                        var finalSourceDocument: String? = nil
                        var cleanedText = text
                        
                        if text.contains("[LIBRARY_CONTENT_USED]") {
                            // Additional validation: Check if the content is actually related to the source document
                            // If it's a Bible/spiritual question with common religious terms but no specific document reference,
                            // it's likely the AI is providing general knowledge, not document-specific information
                            let bibleTerms = ["scripture", "bible", "gospel", "holy spirit", "jesus", "christ", "pentecost", 
                                             "disciples", "apostles", "church", "faith", "prayer", "worship"]
                            
                            let containsBibleTerms = bibleTerms.contains { text.lowercased().contains($0) }
                            let containsExplicitSourceReference = text.contains(sourceDocumentTitle ?? "") || 
                                                                  text.contains("document") || 
                                                                  text.contains("library") ||
                                                                  text.contains("PDF")
                            
                            if containsBibleTerms && !containsExplicitSourceReference {
                                // This appears to be a Bible/faith answer without specific document references
                                print("📚 [LIBRARY_CONTENT_USED] marker found but content appears to be general Bible knowledge")
                                finalSourceDocument = nil
                            } else {
                                // The AI used library content, so we should show the source
                                finalSourceDocument = sourceDocumentTitle
                                print("📚 Using library document source: \(sourceDocumentTitle ?? "unknown")")
                            }
                            
                            // Remove the marker from the text
                            cleanedText = text.replacingOccurrences(of: "[LIBRARY_CONTENT_USED]", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        
                        completion(.success((cleanedText, searchQueries, finalSourceDocument)))
                    } else {
                        // Check for error details
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let error = json["error"] as? [String: Any],
                               let message = error["message"] as? String {
                                print("🚨 API Error Message: \(message)")
                                completion(.failure(AIServiceError.apiError(message)))
                            } else if let error = json["error"] as? String {
                                print("🚨 API Error: \(error)")
                                completion(.failure(AIServiceError.apiError(error)))
                            } else {
                                print("🚨 Unexpected JSON format: \(json)")
                                completion(.failure(AIServiceError.invalidResponse))
                            }
                        } else {
                            print("🚨 Could not parse JSON response")
                            completion(.failure(AIServiceError.invalidResponse))
                        }
                    }
                } catch {
                    print("🚨 JSON Parsing Error: \(error)")
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Scripture Reference Extraction
    
    func extractScriptureReferences(from text: String) -> [ScriptureReference] {
        var references: [ScriptureReference] = []
        
        // Pattern 1: [Book Chapter:Verse] format (bracketed)
        let bracketedPattern = #"\[([^]]+)\s+(\d+):(\d+(?:-\d+)?)\]"#
        
        // Pattern 2: Book Chapter:Verse format (unbracketed) - more common in natural text
        let unbracketedPattern = #"\b([A-Za-z0-9\s]+)\s+(\d+):(\d+(?:-\d+)?)\b"#
        
        // Pattern 3: Common Bible book abbreviations (e.g., Gen. 1:1, Rom. 8:28)
        let abbreviationPattern = #"\b([A-Za-z]+\.)\s+(\d+):(\d+(?:-\d+)?)\b"#
        
        let patterns = [bracketedPattern, unbracketedPattern, abbreviationPattern]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsString = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                for match in matches {
                    if match.numberOfRanges >= 4 {
                        let bookRange = match.range(at: 1)
                        let chapterRange = match.range(at: 2)
                        let verseRange = match.range(at: 3)
                        
                        let book = nsString.substring(with: bookRange).trimmingCharacters(in: .whitespaces)
                        let chapter = nsString.substring(with: chapterRange)
                        let verse = nsString.substring(with: verseRange)
                        
                        // Handle abbreviations by expanding them
                        var normalizedBook = book
                        if book.hasSuffix(".") {
                            // Convert abbreviation to full name
                            normalizedBook = expandBibleBookAbbreviation(book)
                        }
                        
                        // Validate that this looks like a real Bible book
                        if isBibleBook(normalizedBook) {
                            let reference = ScriptureReference(
                                book: normalizedBook,
                                chapter: Int(chapter) ?? 1,
                                verse: verse,
                                displayText: "\(normalizedBook) \(chapter):\(verse)"
                            )
                            
                            // Avoid duplicates
                            if !references.contains(where: { $0.fullReference == reference.fullReference }) {
                                references.append(reference)
                            }
                        }
                    }
                }
            } catch {
                print("Error parsing scripture references with pattern \(pattern): \(error)")
            }
        }
        
        return references
    }
    
    // Helper function to expand common Bible book abbreviations
    private func expandBibleBookAbbreviation(_ abbreviation: String) -> String {
        let abbr = abbreviation.lowercased().trimmingCharacters(in: .punctuationCharacters)
        
        // Dictionary of common Bible book abbreviations
        let abbreviations: [String: String] = [
            "gen": "Genesis",
            "exo": "Exodus",
            "lev": "Leviticus",
            "num": "Numbers",
            "deut": "Deuteronomy",
            "josh": "Joshua",
            "judg": "Judges",
            "ruth": "Ruth",
            "1 sam": "1 Samuel",
            "2 sam": "2 Samuel",
            "1 kgs": "1 Kings",
            "2 kgs": "2 Kings",
            "1 chr": "1 Chronicles",
            "2 chr": "2 Chronicles",
            "ezra": "Ezra",
            "neh": "Nehemiah",
            "est": "Esther",
            "job": "Job",
            "ps": "Psalms",
            "psa": "Psalms",
            "prov": "Proverbs",
            "eccl": "Ecclesiastes",
            "song": "Song of Solomon",
            "isa": "Isaiah",
            "jer": "Jeremiah",
            "lam": "Lamentations",
            "ezek": "Ezekiel",
            "dan": "Daniel",
            "hos": "Hosea",
            "joel": "Joel",
            "amos": "Amos",
            "obad": "Obadiah",
            "jonah": "Jonah",
            "mic": "Micah",
            "nah": "Nahum",
            "hab": "Habakkuk",
            "zeph": "Zephaniah",
            "hag": "Haggai",
            "zech": "Zechariah",
            "mal": "Malachi",
            "matt": "Matthew",
            "mark": "Mark",
            "luke": "Luke",
            "john": "John",
            "acts": "Acts",
            "rom": "Romans",
            "1 cor": "1 Corinthians",
            "2 cor": "2 Corinthians",
            "gal": "Galatians",
            "eph": "Ephesians",
            "phil": "Philippians",
            "col": "Colossians",
            "1 thess": "1 Thessalonians",
            "2 thess": "2 Thessalonians",
            "1 tim": "1 Timothy",
            "2 tim": "2 Timothy",
            "titus": "Titus",
            "phlm": "Philemon",
            "heb": "Hebrews",
            "jas": "James",
            "1 pet": "1 Peter",
            "2 pet": "2 Peter",
            "1 john": "1 John",
            "2 john": "2 John",
            "3 john": "3 John",
            "jude": "Jude",
            "rev": "Revelation"
        ]
        
        return abbreviations[abbr] ?? abbreviation
    }
    
    // Helper function to validate Bible book names
    private func isBibleBook(_ bookName: String) -> Bool {
        let bibleBooks = [
            "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
            "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
            "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther",
            "Job", "Psalm", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Song of Songs",
            "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
            "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum",
            "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
            "Matthew", "Mark", "Luke", "John", "Acts",
            "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
            "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
            "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
            "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation"
        ]
        
        return bibleBooks.contains { $0.lowercased() == bookName.lowercased() }
    }
} 