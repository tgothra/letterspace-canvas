import SwiftUI
import Foundation

// MARK: - iOS 26 Native Text Service
@available(iOS 26.0, *)
@MainActor
@Observable
class iOS26NativeTextService {
    static let shared = iOS26NativeTextService()
    
    private init() {}
    
    // MARK: - Text Formatting Actions
    
    /// Apply bold formatting to selected text
    func toggleBold(text: inout AttributedString, selection: inout AttributedTextSelection) {
        print("🔥 iOS26NativeTextService.toggleBold called")
        print("🔥 AttributedString length: \(text.characters.count)")
        print("🔥 Selection: \(selection)")
        
        let indices = selection.indices(in: text)
        print("🔥 Selection indices: \(indices)")
        
        guard case .ranges(let ranges) = indices, !ranges.isEmpty else { 
            print("❌ iOS26NativeTextService.toggleBold: guard failed - no ranges or empty ranges")
            return 
        }
        
        print("🔥 iOS26NativeTextService.toggleBold: proceeding with ranges: \(ranges)")
        
        text.transform(updating: &selection) { text in
            // Check if current text has bold formatting
            let runs = text[ranges].runs
            let isBold = runs.contains { run in
                if let font = run.font {
                    return font == .system(size: 16, weight: .bold)
                }
                return false
            }
            
            // Toggle bold
            if isBold {
                text[ranges].font = .system(size: 16, weight: .regular)
            } else {
                text[ranges].font = .system(size: 16, weight: .bold)
            }
        }
    }
    
    /// Apply italic formatting to selected text
    func toggleItalic(text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else { return }
        
        text.transform(updating: &selection) { text in
            // Check if current text has italic formatting
            let runs = text[ranges].runs
            let isItalic = runs.contains { run in
                if let font = run.font {
                    return font == .system(size: 16).italic()
                }
                return false
            }
            
            // Toggle italic
            if isItalic {
                text[ranges].font = .system(size: 16, design: .default)
            } else {
                text[ranges].font = .system(size: 16, design: .default).italic()
            }
        }
    }
    
    /// Apply underline formatting to selected text
    func toggleUnderline(text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else { return }
        
        text.transform(updating: &selection) { text in
            if text[ranges].underlineStyle == .single {
                text[ranges].underlineStyle = .none
            } else {
                text[ranges].underlineStyle = .single
            }
        }
    }
    
    /// Apply text color to selected text
    func applyTextColor(_ color: Color, text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else { return }
        
        text.transform(updating: &selection) { text in
            text[ranges].foregroundColor = color
        }
    }
    
    /// Apply background color (highlight) to selected text
    func applyHighlight(_ color: Color, text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else { return }
        
        text.transform(updating: &selection) { text in
            text[ranges].backgroundColor = color
        }
    }
    
    /// Apply text alignment to paragraph containing selection
    func applyAlignment(_ alignment: TextAlignment, text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else { return }
        
        text.transform(updating: &selection) { text in
            // Apply alignment to selected ranges
            // Note: AttributedString automatically expands to paragraph boundaries for alignment
            let attributedAlignment = textAlignment(from: alignment)
            text[ranges].alignment = attributedAlignment
        }
    }
    
    /// Insert or update link for selected text
    func insertLink(linkText: String, linkURL: String, text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard let url = URL(string: linkURL) else { return }
        
        if case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty {
            // Apply link to selected text
            text.transform(updating: &selection) { text in
                text[ranges].link = url
            }
        } else if case .insertionPoint(let point) = selection.indices(in: text) {
            // Insert new link text at cursor
            let linkAttributedText = AttributedString(linkText)
            var newText = linkAttributedText
            newText.link = url
            
            text.transform(updating: &selection) { text in
                text.characters.insert(contentsOf: newText.characters, at: point)
            }
        }
    }
    
    /// Toggle bullet list for paragraphs containing selection
    func toggleBulletList(text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else { return }
        
        text.transform(updating: &selection) { text in
            for range in ranges.ranges {
                // Find the start of the line for this range
                let lineStart = findLineStart(in: text, for: range.lowerBound)
                
                // Check if line already starts with bullet
                let lineEnd = findLineEnd(in: text, for: range.lowerBound)
                let lineRange = lineStart..<lineEnd
                let lineText = String(text[lineRange].characters)
                
                if lineText.hasPrefix("• ") {
                    // Remove bullet point
                    let bulletRange = lineStart..<text.characters.index(lineStart, offsetBy: 2)
                    text.characters.removeSubrange(bulletRange)
                } else {
                    // Add bullet point at start of line
                    let bulletText = AttributedString("• ")
                    text.characters.insert(contentsOf: bulletText.characters, at: lineStart)
                }
            }
        }
    }
    
    /// Apply text style (heading, body, etc.)
    func applyTextStyle(_ style: String, text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else { return }
        
        let font: Font = {
            switch style.lowercased() {
            case "title": return .largeTitle
            case "heading": return .title
            case "subheading": return .title2
            case "body": return .body
            case "caption": return .caption
            default: return .body
            }
        }()
        
        text.transform(updating: &selection) { text in
            text[ranges].font = font
        }
    }
    
    // MARK: - Sermon-Specific Features
    
    /// Highlight text as scripture reference
    func highlightAsScripture(text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else { return }
        
        text.transform(updating: &selection) { text in
            text[ranges].foregroundColor = .blue
            text[ranges].backgroundColor = Color.blue.opacity(0.1)
            text[ranges].font = .system(size: 16, weight: .medium, design: .default)
        }
    }
    
    /// Create bookmark for selected text
    func toggleBookmark(text: inout AttributedString, selection: inout AttributedTextSelection) {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else { return }
        
        text.transform(updating: &selection) { text in
            // Add bookmark indicator
            text[ranges].backgroundColor = Color.yellow.opacity(0.3)
        }
    }
    
    // MARK: - Formatting State Detection
    
    /// Get current formatting state for selection
    func getCurrentFormatting(text: AttributedString, selection: AttributedTextSelection) -> FormattingState {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else {
            return FormattingState()
        }
        
        let selectedText = text[ranges]
        let firstRun = selectedText.runs.first
        
        let isBold = firstRun?.font == .system(size: 16, weight: .bold)
        let isItalic = firstRun?.font == .system(size: 16).italic()
        
        let alignment: TextAlignment = {
            switch firstRun?.alignment {
            case .left: return .leading
            case .center: return .center
            case .right: return .trailing
            default: return .leading
            }
        }()
        
        return FormattingState(
            isBold: isBold,
            isItalic: isItalic,
            isUnderlined: firstRun?.underlineStyle == .single,
            hasLink: firstRun?.link != nil,
            textColor: firstRun?.foregroundColor,
            backgroundColor: firstRun?.backgroundColor,
            alignment: alignment
        )
    }
    
    // MARK: - Helper Functions
    
    private func textAlignment(from alignment: TextAlignment) -> AttributedString.TextAlignment {
        switch alignment {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        @unknown default: return .left
        }
    }
    
    private func findLineStart(in text: AttributedString, for index: AttributedString.Index) -> AttributedString.Index {
        var currentIndex = index
        while currentIndex > text.startIndex {
            let previousIndex = text.characters.index(before: currentIndex)
            if text.characters[previousIndex] == "\n" {
                return currentIndex
            }
            currentIndex = previousIndex
        }
        return text.startIndex
    }
    
    private func findLineEnd(in text: AttributedString, for index: AttributedString.Index) -> AttributedString.Index {
        var currentIndex = index
        while currentIndex < text.endIndex {
            if text.characters[currentIndex] == "\n" {
                return currentIndex
            }
            currentIndex = text.characters.index(after: currentIndex)
        }
        return text.endIndex
    }
}

// MARK: - Formatting State
struct FormattingState {
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let hasLink: Bool
    let textColor: Color?
    let backgroundColor: Color?
    let alignment: TextAlignment
    
    init(
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        hasLink: Bool = false,
        textColor: Color? = nil,
        backgroundColor: Color? = nil,
        alignment: TextAlignment = .leading
    ) {
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.hasLink = hasLink
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.alignment = alignment
    }
}
