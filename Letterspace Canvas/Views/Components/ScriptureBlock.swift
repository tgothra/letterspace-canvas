import SwiftUI
import Foundation

enum SearchMode: String, CaseIterable {
    case reference = "Reference"
    case word = "Word"
    case topic = "Topic"
    case strongs = "Strong's"
    
    var icon: String {
        switch self {
        case .reference: return "book"
        case .word: return "magnifyingglass"
        case .topic: return "tag"
        case .strongs: return "number"
        }
    }
    
    var placeholder: String {
        switch self {
        case .reference: return "Enter verse reference (e.g. acts 2:38)"
        case .word: return "Enter word to search (e.g. love)"
        case .topic: return "Enter topic (e.g. salvation)"
        case .strongs: return "Enter Strong's number (e.g. G26)"
        }
    }
}

// Update enum for layout styles
enum VerseLayout {
    case individual   // Current style with individual verses
    case reference   // References on left with vertical line
    case compact     // Individual verses with just verse numbers
    case paragraph   // True paragraph style with no breaks
}

// Add text size enum
private enum TextSize: Int, CaseIterable {
    case small = 1     // 12pt
    case medium = 2    // 13pt
    case large = 3     // 14pt
    case xlarge = 4    // 15pt
    case xxlarge = 5   // 16pt
    
    var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 13
        case .large: return 14
        case .xlarge: return 15
        case .xxlarge: return 16
        }
    }
    
    var referenceFontSize: CGFloat {
        fontSize
    }
    
    var label: String {
        "A\(rawValue)"
    }
    
    mutating func cycle() {
        self = TextSize.allCases[(TextSize.allCases.firstIndex(of: self)! + 1) % TextSize.allCases.count]
    }
}

struct ScriptureBlock: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var content: String
    @Binding var element: DocumentElement
    @State private var searchText = ""
    @State private var searchResults: [BibleVerse] = []
    @State private var selectedTranslation: String = "KJV"
    @State private var searchMode: SearchMode = .reference
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedVerse: BibleVerse?
    @State private var isTextSelected = false
    @State private var isFocused = false
    @State private var verseLayout: VerseLayout = .reference
    @State private var isHovering = false
    @State private var layoutButtonHover = false
    @State private var duplicateButtonHover = false
    @State private var editButtonHover = false
    @State private var selectedRange: NSRange?
    @State private var showFormattingTooltip = false
    @State private var tooltipPosition: CGPoint = .zero
    @State private var textSize: TextSize = .medium  // Start at 13pt
    @Environment(\.colorScheme) var colorScheme
    
    private let availableTranslations = ["KJV", "ASV", "WEB", "YLT"]
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.15, opacity: 1) : Color(.sRGB, white: 0.98, opacity: 1)
    }
    
    private var searchFieldBackground: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.2, opacity: 1) : Color(.sRGB, white: 0.95, opacity: 1)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.white : Color(.sRGB, white: 0.2, opacity: 1)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.7, opacity: 1) : Color(.sRGB, white: 0.3, opacity: 1)
    }
    
    private var dividerColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.4, opacity: 1) : Color(.sRGB, white: 0.85, opacity: 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if content.isEmpty {
                searchView
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                verseView
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(8)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: content.isEmpty)
    }
    
    private var searchView: some View {
        VStack(alignment: .leading, spacing: 16) {
            searchControls
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if !searchResults.isEmpty {
                searchResultsContent
            }
        }
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(8)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var searchControls: some View {
        HStack(spacing: 8) {
            searchModeButtons
            searchField
            translationButtons
        }
    }
    
    private var searchModeButtons: some View {
        ForEach(SearchMode.allCases, id: \.self) { mode in
            SearchBarButton(
                icon: mode.icon,
                isSelected: searchMode == mode,
                action: {
                    searchMode = mode
                }
            )
        }
    }
    
    private var searchField: some View {
        TextField(searchMode.placeholder, text: $searchText)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .onSubmit {
                searchBibleVerse()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(searchFieldBackground)
            .cornerRadius(6)
    }
    
    private var translationButtons: some View {
        ForEach(availableTranslations, id: \.self) { translation in
            SearchBarButton(
                text: translation,
                isSelected: selectedTranslation == translation,
                action: {
                    selectedTranslation = translation
                }
            )
        }
    }
    
    private struct SearchBarButton: View {
        let icon: String?
        let text: String?
        let isSelected: Bool
        let action: () -> Void
        @State private var isHovering = false
        
        init(icon: String? = nil, text: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
            self.icon = icon
            self.text = text
            self.isSelected = isSelected
            self.action = action
        }
        
        var body: some View {
            Button(action: action) {
                Group {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 15))
                    } else if let text = text {
                        Text(text)
                            .font(.system(size: 13))
                    }
                }
                .frame(width: text != nil ? nil : 32, height: 32)
                .padding(.horizontal, text != nil ? 8 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color(.sRGB, white: 0.9, opacity: 1) : 
                              isHovering ? Color(.sRGB, white: 0.95, opacity: 1) : Color.clear)
                )
                .foregroundStyle(
                    isSelected || isHovering ? 
                        Color(.sRGB, white: 0.2, opacity: 1) : 
                        Color(.sRGB, white: 0.4, opacity: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
        }
    }
    
    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func errorView(_ error: String) -> some View {
        Text(error)
            .font(.system(size: 14))
            .foregroundStyle(.red)
            .padding(.vertical, 8)
    }
    
    private var searchResultsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fullPassage = searchResults.first(where: { $0.isFullPassage }) {
                fullPassageView(fullPassage)
            }
            individualVersesView
        }
        .padding(.top, 8)
    }
    
    private func fullPassageView(_ passage: BibleVerse) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(passage.reference)
                        .font(.system(size: 14, weight: .medium))
                    Text("·")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text(passage.translation)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                selectVerse(passage)
            }) {
                Text("Insert Full Passage")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(searchFieldBackground)
        .cornerRadius(6)
    }
    
    private var individualVersesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(searchResults.filter { !$0.isFullPassage }) { verse in
                    individualVerseRow(verse)
                }
            }
        }
        .frame(maxHeight: 250)
    }
    
    private func individualVerseRow(_ verse: BibleVerse) -> some View {
        HStack(spacing: 16) {
            Button(action: {
                selectVerse(verse)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.white)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verse.reference)
                        .font(.system(size: verse.isFullPassage ? 11 : 13, weight: .medium))
                    Text("·")
                        .font(.system(size: verse.isFullPassage ? 11 : 13))
                        .foregroundStyle(.secondary)
                    Text(verse.translation)
                        .font(.system(size: verse.isFullPassage ? 11 : 13))
                        .foregroundStyle(.secondary)
                }
                Text(verse.text)
                    .font(.system(size: verse.isFullPassage ? 11 : 13))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .padding(.leading, 32)
        .background(searchFieldBackground)
        .cornerRadius(6)
    }
    
    private var verseView: some View {
        Group {
            if let verse = selectedVerse {
                VStack(alignment: .leading, spacing: verse.isFullPassage ? 8 : 2) {
                    HStack(spacing: 8) {
                        Text(verse.reference)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                        Text("·")
                            .font(.system(size: 15))
                            .foregroundStyle(secondaryTextColor)
                        Text(verse.translation)
                            .font(.system(size: 12))
                            .foregroundStyle(secondaryTextColor)
                        
                        Spacer()
                        
                        headerButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    if verse.isFullPassage {
                        switch verseLayout {
                        case .individual:
                            individualVerseLayout
                                .padding(.top, 8)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        case .reference:
                            referenceLayout
                                .padding(.top, 8)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        case .compact:
                            compactVerseLayout
                                .padding(.top, 8)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        case .paragraph:
                            paragraphLayout
                                .padding(.top, 8)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }
                    } else {
                        Text(content)
                            .font(.system(size: textSize.fontSize))
                            .foregroundStyle(textColor)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
                .background(backgroundColor)
                .cornerRadius(8)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                EmptyView()
                    .padding(.vertical, 6)
                    .background(backgroundColor)
                    .cornerRadius(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var individualVerseLayout: some View {
        let verses = content.components(separatedBy: "\n\n")
        return VStack(alignment: .leading, spacing: 24) {
            ForEach(verses, id: \.self) { verseText in
                let parts = verseText.components(separatedBy: "\n")
                if parts.count == 2 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(parts[0])
                            .font(.system(size: textSize.referenceFontSize, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                        Text(parts[1])
                            .font(.system(size: textSize.fontSize))
                            .foregroundStyle(textColor)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    private var referenceLayout: some View {
        let verses = content.components(separatedBy: "\n\n")
        return VStack(alignment: .leading, spacing: 20) {
            ForEach(verses.indices, id: \.self) { index in
                let parts = verses[index].components(separatedBy: "\n")
                if parts.count == 2 {
                    HStack(alignment: .top, spacing: 0) {
                        Text(parts[0])
                            .font(.system(size: textSize.referenceFontSize, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                            .frame(width: 100, alignment: .trailing)
                            .padding(.trailing, 24)
                        
                        Rectangle()
                            .fill(dividerColor)
                            .frame(width: 1)
                            .padding(.vertical, 2)
                        
                        Text(parts[1])
                            .font(.system(size: textSize.fontSize))
                            .foregroundStyle(textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 24)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var compactVerseLayout: some View {
        let verses = content.components(separatedBy: "\n\n")
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(verses.indices, id: \.self) { index in
                let parts = verses[index].components(separatedBy: "\n")
                if parts.count == 2 {
                    let verseNumber = parts[0].components(separatedBy: ":").last ?? ""
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("[\(verseNumber)]")
                            .font(.system(size: 10))
                            .foregroundStyle(secondaryTextColor)
                        Text(parts[1])
                            .font(.system(size: textSize.fontSize))
                            .foregroundStyle(textColor)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    private var paragraphLayout: some View {
        let verses = content.components(separatedBy: "\n\n")
        var fullText = Text("")
        
        for (_, verse) in verses.enumerated() {
            let parts = verse.components(separatedBy: "\n")
            if parts.count == 2 {
                let verseNumber = parts[0].components(separatedBy: ":").last ?? ""
                let verseText = parts[1]
                
                // Add verse number
                fullText = fullText + 
                    Text("[\(verseNumber)]")
                        .font(.system(size: 10))
                        .foregroundStyle(secondaryTextColor) +
                    Text(" ") +
                    Text(verseText)
                        .font(.system(size: textSize.fontSize))
                        .foregroundStyle(textColor) +
                    Text(" ")
            }
        }
        
        return fullText
            .lineSpacing(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
    
    private func formatVerseNumber(_ number: String) -> Text {
        Text("[\(number)]")
            .font(.system(size: 9))
            .foregroundStyle(Color(.sRGB, white: 0.3, opacity: 1))
    }
    
    private var formattingTooltip: some View {
        Group {
            if showFormattingTooltip {
                HStack(spacing: 12) {
                    Button(action: { applyFormatting(.bold) }) {
                        Image(systemName: "bold")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.sRGB, white: 0.3, opacity: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { applyFormatting(.italic) }) {
                        Image(systemName: "italic")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.sRGB, white: 0.3, opacity: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Menu {
                        ForEach([Color.blue, Color.red, Color.green, Color.purple], id: \.self) { color in
                            Button(action: { applyFormatting(.underline(color)) }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    } label: {
                        Image(systemName: "underline")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.sRGB, white: 0.3, opacity: 1))
                    }
                    .menuStyle(.borderlessButton)
                    
                    Menu {
                        ForEach([Color.blue, Color.red, Color.green, Color.purple], id: \.self) { color in
                            Button(action: { applyFormatting(.textColor(color)) }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    } label: {
                        Image(systemName: "textformat.size")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.sRGB, white: 0.3, opacity: 1))
                    }
                    .menuStyle(.borderlessButton)
                    
                    Menu {
                        ForEach([
                            Color.yellow.opacity(0.3),
                            Color.green.opacity(0.3),
                            Color.blue.opacity(0.3),
                            Color.pink.opacity(0.3)
                        ], id: \.self) { color in
                            Button(action: { applyFormatting(.highlight(color)) }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    } label: {
                        Image(systemName: "highlighter")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.sRGB, white: 0.3, opacity: 1))
                    }
                    .menuStyle(.borderlessButton)
                    
                    Menu {
                        Button(action: { applyFormatting(.circle) }) {
                            Image(systemName: "circle")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.sRGB, white: 0.3, opacity: 1))
                        }
                        Button(action: { applyFormatting(.rectangle) }) {
                            Image(systemName: "rectangle")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.sRGB, white: 0.3, opacity: 1))
                        }
                    } label: {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.sRGB, white: 0.3, opacity: 1))
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .position(x: tooltipPosition.x, y: tooltipPosition.y)
            }
        }
    }
    
    private enum FormattingOption {
        case bold
        case italic
        case underline(Color)
        case textColor(Color)
        case highlight(Color)
        case circle
        case rectangle
    }
    
    private func applyFormatting(_ option: FormattingOption) {
        guard let selectedRange = selectedRange,
              let textView = findTextView() else { return }
        
        let storage = textView.textStorage!
        
        switch option {
        case .bold:
            storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 13), range: selectedRange)
            
        case .italic:
            let italicFont = NSFontManager.shared.convert(
                NSFont.systemFont(ofSize: 13),
                toHaveTrait: .italicFontMask
            )
            storage.addAttribute(.font, value: italicFont, range: selectedRange)
            
        case .underline(let color):
            storage.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: NSColor(color)
            ], range: selectedRange)
            
        case .textColor(let color):
            storage.addAttribute(.foregroundColor, value: NSColor(color), range: selectedRange)
            
        case .highlight(let color):
            storage.addAttribute(.backgroundColor, value: NSColor(color), range: selectedRange)
            
        case .circle:
            // Create a circle annotation
            let text = storage.attributedSubstring(from: selectedRange).string
            let size = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)])
            let path = NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size.width + 8, height: size.height + 4))
            path.lineWidth = 1
            
            let attachment = NSTextAttachment()
            attachment.bounds = NSRect(x: 0, y: -2, width: size.width + 8, height: size.height + 4)
            
            // Draw the circle in an image
            let image = NSImage(size: NSSize(width: size.width + 8, height: size.height + 4))
            image.lockFocus()
            NSColor.clear.set()
            NSRect(origin: .zero, size: image.size).fill()
            NSColor.systemGray.set()
            path.stroke()
            image.unlockFocus()
            
            attachment.image = image
            
            // Insert the circle around the text
            let attributedString = NSAttributedString(attachment: attachment)
            storage.insert(attributedString, at: selectedRange.location)
            
        case .rectangle:
            // Create a rectangle annotation
            let text = storage.attributedSubstring(from: selectedRange).string
            let size = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)])
            let path = NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width + 8, height: size.height + 4))
            path.lineWidth = 1
            
            let attachment = NSTextAttachment()
            attachment.bounds = NSRect(x: 0, y: -2, width: size.width + 8, height: size.height + 4)
            
            // Draw the rectangle in an image
            let image = NSImage(size: NSSize(width: size.width + 8, height: size.height + 4))
            image.lockFocus()
            NSColor.clear.set()
            NSRect(origin: .zero, size: image.size).fill()
            NSColor.systemGray.set()
            path.stroke()
            image.unlockFocus()
            
            attachment.image = image
            
            // Insert the rectangle around the text
            let attributedString = NSAttributedString(attachment: attachment)
            storage.insert(attributedString, at: selectedRange.location)
        }
        
        // Hide the tooltip after applying formatting
        showFormattingTooltip = false
    }
    
    private func handleTextSelection(_ range: NSRange, position: CGPoint) {
        selectedRange = range
        tooltipPosition = position
        showFormattingTooltip = true
    }
    
    private func findTextView() -> NSTextView? {
        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else {
            return nil
        }
        
        func searchForTextView(in view: NSView) -> NSTextView? {
            if let textView = view as? NSTextView {
                return textView
            }
            
            for subview in view.subviews {
                if let textView = searchForTextView(in: subview) {
                    return textView
                }
            }
            
            return nil
        }
        
        return searchForTextView(in: contentView)
    }
    
    private func selectVerse(_ verse: BibleVerse) {
        withAnimation {
            if verse.isFullPassage {
                // For full passage, format all individual verses
                let individualVerses = searchResults.filter({ !$0.isFullPassage })
                let formattedText = individualVerses
                    .map { "\($0.reference)\n\($0.text)" }
                    .joined(separator: "\n\n")
                content = formattedText
            } else {
                // For single verse
                content = verse.text
            }
            
            // Update the current element's state
            selectedVerse = verse
            searchResults = []
            errorMessage = nil
        }
    }
    
    private func searchBibleVerse() {
        guard !searchText.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let verses = try await BibleAPI.searchVerses(
                    query: searchText,
                    translation: selectedTranslation
                )
                await MainActor.run {
                    withAnimation {
                        searchResults = verses
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        errorMessage = error.localizedDescription
                        isLoading = false
                    }
                }
            }
        }
    }
    
    private var headerButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    textSize.cycle()
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9))
                    Text(textSize.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(secondaryTextColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            
            if selectedVerse?.isFullPassage == true {
                Menu {
                    ForEach([
                        ("Individual Verses", VerseLayout.individual),
                        ("Reference Layout", VerseLayout.reference),
                        ("Compact Verses", VerseLayout.compact),
                        ("Paragraph", VerseLayout.paragraph)
                    ], id: \.0) { name, layout in
                        Button(action: { verseLayout = layout }) {
                            HStack {
                                Text(name)
                                    .font(.system(size: 13))
                                Spacer()
                                if verseLayout == layout {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.blue)
                                }
                            }
                            .foregroundStyle(.primary)
                            .padding(.vertical, 4)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Layout")
                            .font(.system(size: 11))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(secondaryTextColor)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            
            Button(action: {
                // Comparison functionality to be added
            }) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                withAnimation {
                    content = ""
                    selectedVerse = nil
                    searchResults = []
                    errorMessage = nil
                }
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SelectableTextView: NSViewRepresentable {
    let text: String
    let font: NSFont
    let textColor: NSColor
    let onSelection: (NSRange, CGPoint) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.isRichText = true
        textView.allowsUndo = true
        
        // Configure scroll view
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        
        // Set up paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.alignment = .left
        
        // Set up the text with attributes
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        textView.textStorage?.setAttributedString(attributedString)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Set up paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.alignment = .left
        
        // Update the text with attributes
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        textView.textStorage?.setAttributedString(attributedString)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: SelectableTextView
        
        init(_ parent: SelectableTextView) {
            self.parent = parent
            super.init()
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  textView.selectedRange().length > 0 else {
                return
            }
            
            // Calculate position for tooltip (above the selection)
            let range = textView.selectedRange()
            let glyphRange = textView.layoutManager?.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            if let glyphRange = glyphRange {
                let boundingRect = textView.layoutManager?.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!)
                if let rect = boundingRect {
                    let point = CGPoint(x: rect.midX, y: rect.minY - 10)
                    let windowPoint = textView.convert(point, to: nil)
                    DispatchQueue.main.async {
                        self.parent.onSelection(range, windowPoint)
                    }
                }
            }
        }
    }
} 
