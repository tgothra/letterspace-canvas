#if os(iOS)
import Foundation
import UIKit
import SwiftUI
import NaturalLanguage

// MARK: - iOS 26 Enhanced Text Editing Service
@available(iOS 26.0, *)
@Observable
class iOS26TextEditingService: NSObject {
    static let shared = iOS26TextEditingService()
    
    var isAnalyzing = false
    var suggestions: [TextSuggestion] = []
    var smartSelectionEnabled = true
    var markdownPreviewEnabled = true
    
    // iOS 26 Enhancement: Natural Language Processing
    private let languageRecognizer = NLLanguageRecognizer()
    private let tokenizer = NLTokenizer(unit: .word)
    private let sentenceTokenizer = NLTokenizer(unit: .sentence)
    
    private override init() {
        super.init()
        setupLanguageProcessing()
    }
    
    // MARK: - iOS 26 Smart Text Selection
    func performSmartSelection(in textView: UITextView, at location: Int) -> NSRange {
        guard smartSelectionEnabled else {
            return NSRange(location: location, length: 0)
        }
        
        let text = textView.text ?? ""
        let nsString = text as NSString
        
        // iOS 26 Enhancement: Intelligent content recognition
        return intelligentContentSelection(text: nsString, location: location)
    }
    
    private func intelligentContentSelection(text: NSString, location: Int) -> NSRange {
        guard location < text.length else {
            return NSRange(location: location, length: 0)
        }
        
        // Use iOS 26's enhanced NLP for context-aware selection
        tokenizer.string = text as String
        
        // Check if we're in a scripture reference pattern
        if let scriptureRange = detectScriptureReference(text: text, location: location) {
            print("📖 iOS 26: Detected scripture reference selection")
            HapticFeedback.impact(.light, intensity: 0.6)
            return scriptureRange
        }
        
        // Check if we're in a markdown element
        if let markdownRange = detectMarkdownElement(text: text, location: location) {
            print("📝 iOS 26: Detected markdown element selection")
            HapticFeedback.impact(.light, intensity: 0.7)
            return markdownRange
        }
        
        // Check if we're in a sentence
        if let sentenceRange = detectSentence(text: text, location: location) {
            print("💬 iOS 26: Detected sentence selection")
            HapticFeedback.selection()
            return sentenceRange
        }
        
        // Default to word selection
        let wordRange = detectWord(text: text, location: location)
        print("🔤 iOS 26: Default word selection")
        HapticFeedback.selection()
        return wordRange
    }
    
    private func detectScriptureReference(text: NSString, location: Int) -> NSRange? {
        // Enhanced scripture reference detection with iOS 26 NLP
        let patterns = [
            #"\b[1-3]?\s?[A-Z][a-z]+\s+\d+:\d+(-\d+)?\b"#,  // John 3:16, 1 Corinthians 13:4-8
            #"\b[A-Z][a-z]+\s+\d+\b"#                        // Psalms 23
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
                
                for match in matches {
                    if NSLocationInRange(location, match.range) {
                        return match.range
                    }
                }
            } catch {
                print("⚠️ iOS 26: Regex error in scripture detection: \(error)")
            }
        }
        
        return nil
    }
    
    private func detectMarkdownElement(text: NSString, location: Int) -> NSRange? {
        let markdownPatterns = [
            #"\*\*[^*]+\*\*"#,      // **bold**
            #"\*[^*]+\*"#,          // *italic*
            #"`[^`]+`"#,            // `code`
            #"\[[^\]]+\]\([^)]+\)"#, // [link](url)
            #"#{1,6}\s+[^\n]+"#     // # Headers
        ]
        
        for pattern in markdownPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
                
                for match in matches {
                    if NSLocationInRange(location, match.range) {
                        return match.range
                    }
                }
            } catch {
                print("⚠️ iOS 26: Regex error in markdown detection: \(error)")
            }
        }
        
        return nil
    }
    
    private func detectSentence(text: NSString, location: Int) -> NSRange? {
        let string = text as String
        sentenceTokenizer.string = string
        
        // Convert NSRange to Range<String.Index>
        guard let stringRange = Range(NSRange(location: 0, length: text.length), in: string) else {
            return nil
        }
        
        let sentenceRanges = sentenceTokenizer.tokens(for: stringRange)
        
        for range in sentenceRanges {
            let nsRange = NSRange(range, in: string)
            if NSLocationInRange(location, nsRange) {
                return nsRange
            }
        }
        
        return nil
    }
    
    private func detectWord(text: NSString, location: Int) -> NSRange {
        let string = text as String
        tokenizer.string = string
        
        // Convert NSRange to Range<String.Index>
        guard let stringRange = Range(NSRange(location: 0, length: text.length), in: string) else {
            // Fallback to character-based selection
            return NSRange(location: location, length: min(1, text.length - location))
        }
        
        let wordRanges = tokenizer.tokens(for: stringRange)
        
        for range in wordRanges {
            let nsRange = NSRange(range, in: string)
            if NSLocationInRange(location, nsRange) {
                return nsRange
            }
        }
        
        // Fallback to character-based selection
        return NSRange(location: location, length: min(1, text.length - location))
    }
    
    // MARK: - iOS 26 Markdown Enhancement
    func enhanceMarkdown(text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        if markdownPreviewEnabled {
            applyMarkdownStyling(to: attributedString)
        }
        
        return attributedString
    }
    
    private func applyMarkdownStyling(to attributedString: NSMutableAttributedString) {
        // iOS 26 Enhancement: Live markdown preview with spring animations
        
        // Bold text **text**
        applyMarkdownPattern(
            pattern: #"\*\*([^*]+)\*\*"#,
            attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 16)],
            to: attributedString
        )
        
        // Italic text *text*
        applyMarkdownPattern(
            pattern: #"\*([^*]+)\*"#,
            attributes: [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: 16)],
            to: attributedString
        )
        
        // Code text `text`
        applyMarkdownPattern(
            pattern: #"`([^`]+)`"#,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                .backgroundColor: UIColor.systemGray5
            ],
            to: attributedString
        )
        
        // Headers # text
        applyMarkdownPattern(
            pattern: #"^#{1,6}\s+(.+)$"#,
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.systemBlue
            ],
            to: attributedString,
            options: [.anchorsMatchLines]
        )
    }
    
    private func applyMarkdownPattern(
        pattern: String,
        attributes: [NSAttributedString.Key: Any],
        to attributedString: NSMutableAttributedString,
        options: NSRegularExpression.Options = []
    ) {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let matches = regex.matches(
                in: attributedString.string,
                options: [],
                range: NSRange(location: 0, length: attributedString.length)
            )
            
            // Apply in reverse order to maintain ranges
            for match in matches.reversed() {
                if match.numberOfRanges > 1 {
                    // Apply to captured group
                    let range = match.range(at: 1)
                    attributedString.addAttributes(attributes, range: range)
                } else {
                    // Apply to entire match
                    attributedString.addAttributes(attributes, range: match.range)
                }
            }
        } catch {
            print("⚠️ iOS 26: Markdown pattern error: \(error)")
        }
    }
    
    // MARK: - iOS 26 AI-Powered Writing Assistance
    func analyzeText(_ text: String, completion: @escaping ([TextSuggestion]) -> Void) {
        guard !text.isEmpty else {
            completion([])
            return
        }
        
        isAnalyzing = true
        
        Task {
            let suggestions = await generateTextSuggestions(for: text)
            
            await MainActor.run {
                self.isAnalyzing = false
                self.suggestions = suggestions
                completion(suggestions)
                
                // iOS 26 Enhancement: Subtle haptic feedback for suggestions
                if !suggestions.isEmpty {
                    HapticFeedback.impact(.light, intensity: 0.5)
                }
            }
        }
    }
    
    private func generateTextSuggestions(for text: String) async -> [TextSuggestion] {
        var suggestions: [TextSuggestion] = []
        
        // Language detection
        languageRecognizer.processString(text)
        let dominantLanguage = languageRecognizer.dominantLanguage ?? NLLanguage.english
        
        // Grammar and style suggestions
        if let grammarSuggestions = await analyzeGrammar(text: text, language: dominantLanguage) {
            suggestions.append(contentsOf: grammarSuggestions)
        }
        
        // Scripture enhancement suggestions
        if let scriptureSuggestions = await suggestScriptureEnhancements(text: text) {
            suggestions.append(contentsOf: scriptureSuggestions)
        }
        
        // Markdown formatting suggestions
        if let markdownSuggestions = await suggestMarkdownImprovements(text: text) {
            suggestions.append(contentsOf: markdownSuggestions)
        }
        
        return suggestions
    }
    
    private func analyzeGrammar(text: String, language: NLLanguage) async -> [TextSuggestion]? {
        // iOS 26 Enhancement: Use system grammar checking on main actor
        return await MainActor.run {
            let checker = UITextChecker()
            var suggestions: [TextSuggestion] = []
            
            // Check for misspelled words
            var offset = 0
            while offset < text.count {
                let misspelledRange = checker.rangeOfMisspelledWord(
                    in: text,
                    range: NSRange(location: offset, length: text.count - offset),
                    startingAt: offset,
                    wrap: false,
                    language: language.rawValue
                )
                
                if misspelledRange.location == NSNotFound {
                    break
                }
                
                let guesses = checker.guesses(
                    forWordRange: misspelledRange,
                    in: text,
                    language: language.rawValue
                ) ?? []
                
                if let firstGuess = guesses.first {
                    let suggestion = TextSuggestion.createiOS26Suggestion(
                        type: .spelling,
                        originalText: String(text[Range(misspelledRange, in: text)!]),
                        suggestedText: firstGuess,
                        reason: "Spelling correction"
                    )
                    suggestions.append(suggestion)
                }
                
                offset = misspelledRange.location + misspelledRange.length
            }
            
            return suggestions.isEmpty ? nil : suggestions
        }
    }
    
    private func suggestScriptureEnhancements(text: String) async -> [TextSuggestion]? {
        // Look for incomplete scripture references
        let incompletePatterns = [
            #"\b[A-Z][a-z]+\s+\d+(?!\s*:)"#,  // "John 3" without verse
            #"\bPsalm\s+\d+(?!\s*:)"#         // "Psalm 23" without verse
        ]
        
        var suggestions: [TextSuggestion] = []
        
        for pattern in incompletePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    let matchedText = String(text[Range(match.range, in: text)!])
                    
                    let suggestion = TextSuggestion.createiOS26Suggestion(
                        type: .scripture,
                        originalText: matchedText,
                        suggestedText: "\(matchedText):1", // Suggest adding verse 1
                        reason: "Complete scripture reference"
                    )
                    suggestions.append(suggestion)
                }
            } catch {
                print("⚠️ iOS 26: Scripture pattern error: \(error)")
            }
        }
        
        return suggestions.isEmpty ? nil : suggestions
    }
    
    private func suggestMarkdownImprovements(text: String) async -> [TextSuggestion]? {
        var suggestions: [TextSuggestion] = []
        
        // Suggest markdown formatting for emphasis words
        let emphasisWords = ["important", "note", "remember", "key", "warning"]
        
        for word in emphasisWords {
            let pattern = "\\b\(word)\\b"
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    let matchedText = String(text[Range(match.range, in: text)!])
                    
                    let suggestion = TextSuggestion.createiOS26Suggestion(
                        type: .formatting,
                        originalText: matchedText,
                        suggestedText: "**\(matchedText)**",
                        reason: "Emphasize key word"
                    )
                    suggestions.append(suggestion)
                }
            } catch {
                print("⚠️ iOS 26: Markdown pattern error: \(error)")
            }
        }
        
        return suggestions.isEmpty ? nil : suggestions
    }
    
    // MARK: - Setup
    private func setupLanguageProcessing() {
        languageRecognizer.languageHints = [NLLanguage.english: 1.0]
        print("🧠 iOS 26 Enhanced Text Editing Service initialized")
    }
    
    // MARK: - Public API
    func applyTextSuggestion(_ suggestion: TextSuggestion, to textView: UITextView) {
        // Find the range of the original text in the text view
        guard let range = textView.text.range(of: suggestion.originalText) else { 
            print("⚠️ iOS 26: Could not find text '\(suggestion.originalText)' in text view")
            return 
        }
        
        // iOS 26 Enhancement: Smooth text replacement with spring animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            textView.text.replaceSubrange(range, with: suggestion.suggestedText)
        }
        
        // iOS 26 Enhancement: Success haptic feedback
        HapticFeedback.impact(.light, intensity: 0.8)
        
        // Remove the applied suggestion
        if let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
            suggestions.remove(at: index)
        }
        
        print("✅ iOS 26: Applied text suggestion - \(suggestion.reason)")
    }
    
    func enableSmartSelection(_ enabled: Bool) {
        smartSelectionEnabled = enabled
        print("🎯 iOS 26: Smart selection \(enabled ? "enabled" : "disabled")")
    }
    
    func enableMarkdownPreview(_ enabled: Bool) {
        markdownPreviewEnabled = enabled
        print("📝 iOS 26: Markdown preview \(enabled ? "enabled" : "disabled")")
    }
}

// MARK: - iOS 26 TextSuggestion Extensions
extension TextSuggestion {
    // iOS 26 Enhancement: Calculate range based on text
    var estimatedRange: NSRange {
        return NSRange(location: 0, length: originalText.count)
    }
    
    // iOS 26 Enhancement: Extended suggestion types mapping
    enum iOS26SuggestionType {
        case spelling
        case scripture
        case formatting
        case markdown
        
        // Convert to existing SuggestionType
        var legacyType: SuggestionType {
            switch self {
            case .spelling:
                return .grammar
            case .scripture:
                return .vocabulary
            case .formatting, .markdown:
                return .style
            }
        }
        
        var icon: String {
            switch self {
            case .spelling:
                return "textformat.abc"
            case .scripture:
                return "book.bible"
            case .formatting:
                return "bold.italic.underline"
            case .markdown:
                return "doc.richtext"
            }
        }
    }
    
    // iOS 26 Enhancement: Convenience initializer for iOS 26 suggestions
    static func createiOS26Suggestion(
        type: iOS26SuggestionType,
        originalText: String,
        suggestedText: String,
        reason: String
    ) -> TextSuggestion {
        return TextSuggestion(
            originalText: originalText,
            suggestedText: suggestedText,
            reason: reason,
            type: type.legacyType
        )
    }
}

#endif 