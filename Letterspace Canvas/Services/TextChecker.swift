import Foundation

class TextChecker {
    static let shared = TextChecker()
    
    private init() {}
    
    func checkText(_ text: String, completion: @escaping (Result<[TextSuggestion], Error>) -> Void) {
        // Skip if text is too short
        if text.count < 20 {
            completion(.success([]))
            return
        }
        
        // Check token availability before making the call
        let estimatedTokens = text.count / 4 + 800 // Rough estimate
        if !TokenUsageService.shared.canUseTokens(estimatedTokens) {
            completion(.failure(NSError(domain: "TextChecker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Token limit reached. Please purchase more tokens."])))
            return
        }

        // AI-based grammar and style checking
        let apiService = AIService.shared
        
        let prompt = """
        Analyze the following text for grammar and style issues.
        Provide corrections in the format: [original text] -> [corrected text] (reason)
        Only include actual errors or style improvements, don't comment on valid text.
        Limit to the most important issues (maximum 5).
        
        Text to analyze:
        "\(text.prefix(1000))"
        """
        
        apiService.generateText(prompt: prompt) { result in
            switch result {
            case .success(let response):
                // Parse the response to extract suggestions
                let suggestions = self.parseSuggestions(from: response)
                completion(.success(suggestions))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func parseSuggestions(from response: String) -> [TextSuggestion] {
        // Parse the AI response to extract suggestions
        var suggestions: [TextSuggestion] = []
        
        // Regex-based parsing
        let pattern = #"\[(.*?)\] -> \[(.*?)\] \((.*?)\)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        if let regex = regex {
            let nsString = response as NSString
            let matches = regex.matches(in: response, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges == 4 {
                    let originalText = nsString.substring(with: match.range(at: 1))
                    let correctedText = nsString.substring(with: match.range(at: 2))
                    let reason = nsString.substring(with: match.range(at: 3))
                    
                    // Determine if this is grammar or style
                    let type: TextSuggestion.SuggestionType = 
                        reason.lowercased().contains("grammar") || 
                        reason.lowercased().contains("spelling") || 
                        reason.lowercased().contains("punctuation") ? 
                            .grammar : .style
                    
                    suggestions.append(TextSuggestion(
                        originalText: originalText,
                        suggestedText: correctedText,
                        reason: reason,
                        type: type
                    ))
                }
            }
        }
        
        return suggestions
    }
    
    func enhanceVocabulary(in text: String, completion: @escaping (Result<[TextSuggestion], Error>) -> Void) {
        // Skip if text is too short
        if text.count < 30 {
            completion(.success([]))
            return
        }
        
        // Check token availability before making the call
        let estimatedTokens = text.count / 4 + 800 // Rough estimate
        if !TokenUsageService.shared.canUseTokens(estimatedTokens) {
            completion(.failure(NSError(domain: "TextChecker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Token limit reached. Please purchase more tokens."])))
            return
        }
        
        let apiService = AIService.shared
        
        let prompt = """
        Analyze the following text and suggest more sophisticated or precise vocabulary alternatives.
        Focus only on words that could be enhanced with more specific, vivid, or elegant alternatives.
        Format each suggestion as: [original word] -> [suggested word] (reason)
        Limit to the most impactful 5 suggestions only.
        
        Text to analyze:
        \(text.prefix(1000))
        """
        
        apiService.generateText(prompt: prompt) { result in
            switch result {
            case .success(let response):
                // Parse suggestions using the same pattern as grammar checking
                let suggestions = self.parseSuggestions(from: response)
                    .map { suggestion in
                        // Make sure all suggestions are marked as vocabulary type
                        TextSuggestion(
                            originalText: suggestion.originalText,
                            suggestedText: suggestion.suggestedText,
                            reason: suggestion.reason,
                            type: .vocabulary
                        )
                    }
                completion(.success(suggestions))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
} 