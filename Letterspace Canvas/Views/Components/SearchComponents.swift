import SwiftUI

// Extension for batching arrays to improve search performance
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
import Foundation

// Helper views for SearchPopupContent
struct SearchHeaderView: View {
    @Binding var activePopup: ActivePopup
    @Environment(\.themeColors) var theme
    
    var body: some View {
        HStack {
            Text("Search Documents")
                .font(.system(size: {
                    #if os(macOS)
                    return 13 // Smaller font for macOS compact design
                    #else
                    return 15 // Larger font for iPad touch-friendly design
                    #endif
                }(), weight: .medium))
                .foregroundStyle(theme.primary)
            Spacer()
        }
        .padding(.horizontal, {
            #if os(macOS)
            return 12 // Tighter padding for macOS
            #else
            return 16 // More spacious padding for iPad
            #endif
        }())
        .padding(.vertical, {
            #if os(macOS)
            return 8 // Smaller vertical padding for macOS
            #else
            return 12 // More padding for iPad
            #endif
        }())
        .background(theme.surface) // Use theme surface color for search header
    }
}

struct SearchContentView: View {
    @Binding var searchText: String
    @Binding var searchResults: [Letterspace_CanvasDocument]
    @Binding var searchTask: Task<Void, Never>?
    let groupedResults: [(String, [Letterspace_CanvasDocument])]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    let performSearch: () async -> Void
    var onDismiss: (() -> Void)? = nil
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(spacing: 20) {
            SearchFieldView(searchText: $searchText, searchTask: $searchTask, performSearch: performSearch)
            
            if searchText.isEmpty {
                SearchEmptyStateView()
                    .onAppear {
                        print("🔍 Showing empty state view")
                    }
            } else {
                SearchResultsView(
                    searchText: searchText,
                    searchResults: searchResults,
                    groupedResults: groupedResults,
                    document: $document,
                    sidebarMode: $sidebarMode,
                    activePopup: $activePopup,
                    onDismiss: onDismiss
                )
                .onAppear {
                    print("🔍 Showing results view with \(searchResults.count) results for search: '\(searchText)'")
                }
            }
        }
    }
}

struct SearchFieldView: View {
    @Binding var searchText: String
    @Binding var searchTask: Task<Void, Never>?
    let performSearch: () async -> Void
    @Environment(\.themeColors) var theme
    
    // Add focus state for immediate keyboard appearance on iPhone
    #if os(iOS)
    @FocusState private var isSearchFieldFocused: Bool
    #endif
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(theme.secondary)
            TextField("Search documents...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                #if os(iOS)
                .focused($isSearchFieldFocused)
                #endif
                .onChange(of: searchText) { oldValue, newValue in
                    print("🔍 SearchFieldView: Text changed from '\(oldValue)' to '\(newValue)'")
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        print("🔍 SearchFieldView: About to perform search for '\(newValue)'")
                        await performSearch()
                    }
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                )
        )
        #if os(iOS)
        .onAppear {
            // Auto-focus search field on iPhone for immediate keyboard
            if UIDevice.current.userInterfaceIdiom == .phone {
                print("🔍 SearchFieldView onAppear - attempting immediate focus")
                // Try immediate focus first
                isSearchFieldFocused = true
                
                // Backup with slight delay in case immediate doesn't work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    print("🔍 SearchFieldView - backup focus attempt")
                    isSearchFieldFocused = true
                }
                
                // Final fallback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🔍 SearchFieldView - final focus attempt")
                    isSearchFieldFocused = true
                }
            }
        }
        #endif
    }
}

struct SearchEmptyStateView: View {
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack {
            Text("Type to search through your documents")
                .font(.system(size: 12))
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
            Spacer()
        }
    }
}

struct SearchResultsView: View {
    let searchText: String
    let searchResults: [Letterspace_CanvasDocument]
    let groupedResults: [(String, [Letterspace_CanvasDocument])]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    var onDismiss: (() -> Void)? = nil
    @Environment(\.themeColors) var theme
    
    // Get all content matches with multiple instances per document
    private var allContentMatches: [(document: Letterspace_CanvasDocument, matches: [ContentMatch])] {
        var documentMatches: [(document: Letterspace_CanvasDocument, matches: [ContentMatch])] = []
        
        for doc in searchResults {
            var matches: [ContentMatch] = []
            
            // Find all instances of the search term in this document's textBlock elements
            let textBlockElements = doc.elements.filter { $0.type == .textBlock }
            
            for element in textBlockElements {
                let elementText: String
                if let attributedContent = element.attributedContent {
                    elementText = attributedContent.string
                } else {
                    elementText = element.content
                }
                
                // Find all occurrences of the search term in this element
                var searchStartIndex = elementText.startIndex
                while searchStartIndex < elementText.endIndex {
                    if let range = elementText.range(of: searchText, options: .caseInsensitive, range: searchStartIndex..<elementText.endIndex) {
                        let match = ContentMatch(
                            elementId: element.id,
                            text: elementText,
                            matchRange: range
                        )
                        matches.append(match)
                        
                        // Move search start to after this match
                        searchStartIndex = range.upperBound
                    } else {
                        break
                    }
                }
            }
            
            if !matches.isEmpty {
                documentMatches.append((document: doc, matches: matches))
            }
        }
        
        return documentMatches
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if searchResults.isEmpty {
                    Text("No results found")
                        .font(.custom("InterTight-Regular", size: 13))
                        .foregroundColor(theme.secondary)
                        .padding(.vertical, 8)
                } else {
                    // Section 1: Documents with thumbnails/icons
                    DocumentsSection(
                        searchText: searchText,
                        documents: searchResults,
                        document: $document,
                        sidebarMode: $sidebarMode,
                        activePopup: $activePopup,
                        onDismiss: onDismiss
                    )
                    
                    // Separator line between sections
                    if !allContentMatches.isEmpty {
                        Divider()
                            .background(theme.secondary.opacity(0.3))
                            .padding(.horizontal, 8)
                    }
                    
                    // Section 2: Content matches with larger snippets
                    if !allContentMatches.isEmpty {
                        ContentMatchesSection(
                            searchText: searchText,
                            contentMatches: allContentMatches,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            activePopup: $activePopup,
                            onDismiss: onDismiss
                        )
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
}

// Structure to represent a content match
struct ContentMatch {
    let elementId: UUID
    let text: String
    let matchRange: Range<String.Index>
}

// Documents section with thumbnails
struct DocumentsSection: View {
    let searchText: String
    let documents: [Letterspace_CanvasDocument]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    var onDismiss: (() -> Void)? = nil
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Documents")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Text("(\(documents.count))")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            
            // Document list
            VStack(spacing: 8) {
                ForEach(documents) { doc in
                    DocumentThumbnailRow(
                        doc: doc,
                        searchText: searchText,
                        document: $document,
                        sidebarMode: $sidebarMode,
                        activePopup: $activePopup,
                        onDismiss: onDismiss
                    )
                }
            }
        }
    }
}

// Content matches section with larger snippets
struct ContentMatchesSection: View {
    let searchText: String
    let contentMatches: [(document: Letterspace_CanvasDocument, matches: [ContentMatch])]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    var onDismiss: (() -> Void)? = nil
    @Environment(\.themeColors) var theme
    
    private var totalMatches: Int {
        contentMatches.reduce(0) { $0 + $1.matches.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Content")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Text("(\(totalMatches) matches)")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            
            // Content matches
            VStack(spacing: 16) {
                ForEach(contentMatches, id: \.document.id) { docWithMatches in
                    ContentMatchGroup(
                        document: docWithMatches.document,
                        matches: docWithMatches.matches,
                        searchText: searchText,
                        boundDocument: $document,
                        sidebarMode: $sidebarMode,
                        activePopup: $activePopup,
                        onDismiss: onDismiss
                    )
                }
            }
        }
    }
}

// Document row with thumbnail/icon
struct DocumentThumbnailRow: View {
    let doc: Letterspace_CanvasDocument
    let searchText: String
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    var onDismiss: (() -> Void)? = nil
    @Environment(\.themeColors) var theme
    
    #if os(macOS)
    @State private var headerImage: NSImage?
    #elseif os(iOS)
    @State private var headerImage: UIImage?
    #endif
    
    var body: some View {
        Button(action: {
            document = doc
            sidebarMode = .details
            activePopup = .none
            onDismiss?()
        }) {
            HStack(spacing: 12) {
                // Thumbnail or document icon
                Group {
                    if let headerImage = headerImage {
                        #if os(macOS)
                        Image(nsImage: headerImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        #elseif os(iOS)
                        Image(uiImage: headerImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        #endif
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.secondary)
                            .frame(width: 40, height: 40)
                            .background(theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                // Document title and subtitle with highlighting
                VStack(alignment: .leading, spacing: 2) {
                    let title = doc.title.isEmpty ? "Untitled" : doc.title
                    let titleMatches = title.localizedCaseInsensitiveContains(searchText)
                    
                    if titleMatches {
                        let titleContext = getMatchContext(content: title, searchText: searchText)
                        HighlightedText(
                            text: titleContext.0,
                            highlightRange: titleContext.1,
                            font: .system(size: 14, weight: .medium),
                            textColor: theme.primary,
                            highlightColor: Color.yellow.opacity(0.4)
                        )
                        .lineLimit(1)
                    } else {
                        Text(title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.primary)
                            .lineLimit(1)
                    }
                    
                    if !doc.subtitle.isEmpty {
                        let subtitleMatches = doc.subtitle.localizedCaseInsensitiveContains(searchText)
                        
                        if subtitleMatches {
                            let subtitleContext = getMatchContext(content: doc.subtitle, searchText: searchText)
                            HighlightedText(
                                text: subtitleContext.0,
                                highlightRange: subtitleContext.1,
                                font: .system(size: 12),
                                textColor: theme.secondary,
                                highlightColor: Color.yellow.opacity(0.3)
                            )
                            .lineLimit(1)
                        } else {
                            Text(doc.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            loadHeaderImage()
        }
    }
    
    private func loadHeaderImage() {
        guard let headerElement = doc.elements.first(where: { $0.type == .headerImage }),
              !headerElement.content.isEmpty,
              let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            return
        }
        
        let documentPath = appDirectory.appendingPathComponent("\(doc.id)")
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
        
        #if os(macOS)
        if let image = NSImage(contentsOf: imageUrl) {
            headerImage = image
        }
        #elseif os(iOS)
        if let image = UIImage(contentsOfFile: imageUrl.path) {
            headerImage = image
        }
        #endif
    }
    
    private func getMatchContext(content: String, searchText: String) -> (String, Range<String.Index>?) {
        guard let range = content.range(of: searchText, options: .caseInsensitive) else {
            return (content, nil)
        }
        return (content, range)
    }
}

// Content match group for a specific document
struct ContentMatchGroup: View {
    let document: Letterspace_CanvasDocument
    let matches: [ContentMatch]
    let searchText: String
    @Binding var boundDocument: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    var onDismiss: (() -> Void)? = nil
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Document header
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary)
                
                Text(document.title.isEmpty ? "Untitled" : document.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                
                if !document.subtitle.isEmpty {
                    Text("•")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.secondary)
                    
                    Text(document.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text("\(matches.count) match\(matches.count == 1 ? "" : "es")")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 8)
            
            // Individual matches
            VStack(spacing: 6) {
                ForEach(Array(matches.enumerated()), id: \.offset) { index, match in
                    ContentMatchRow(
                        match: match,
                        matchIndex: index,
                        totalMatches: matches.count,
                        document: document,
                        searchText: searchText,
                        boundDocument: $boundDocument,
                        sidebarMode: $sidebarMode,
                        activePopup: $activePopup,
                        onDismiss: onDismiss
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .background(theme.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// Individual content match row with larger snippet
struct ContentMatchRow: View {
    let match: ContentMatch
    let matchIndex: Int
    let totalMatches: Int
    let document: Letterspace_CanvasDocument
    let searchText: String
    @Binding var boundDocument: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    var onDismiss: (() -> Void)? = nil
    @Environment(\.themeColors) var theme
    
    private var expandedContext: (preview: String, highlightRange: Range<String.Index>?) {
        let content = match.text
        let matchRange = match.matchRange
        
        // Create a mapping between original content positions and cleaned content positions
        var originalToCleanedMapping: [String.Index: String.Index] = [:]
        var cleanedContent = ""
        var cleanedIndex = cleanedContent.startIndex
        
        // Build cleaned content while maintaining position mapping
        var i = content.startIndex
        while i < content.endIndex {
            let char = content[i]
            originalToCleanedMapping[i] = cleanedContent.endIndex
            
            if char == "\n" {
                // Replace newline with space
                cleanedContent += " "
            } else if char.isWhitespace {
                // Handle multiple whitespace - only add space if last char wasn't space
                if cleanedContent.isEmpty || !cleanedContent.last!.isWhitespace {
                    cleanedContent += " "
                }
            } else {
                cleanedContent += String(char)
            }
            
            i = content.index(after: i)
        }
        
        // Map the end index too
        originalToCleanedMapping[content.endIndex] = cleanedContent.endIndex
        
        // Trim whitespace and adjust mapping
        cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the cleaned positions for our match
        guard let cleanedMatchStart = originalToCleanedMapping[matchRange.lowerBound],
              let cleanedMatchEnd = originalToCleanedMapping[matchRange.upperBound],
              cleanedMatchStart < cleanedContent.endIndex else {
            print("❌ Could not map match range to cleaned content")
            return (cleanedContent, nil)
        }
        
        // Ensure we don't go beyond cleaned content bounds
        let matchStart = min(cleanedMatchStart, cleanedContent.endIndex)
        let matchEnd = min(cleanedMatchEnd, cleanedContent.endIndex)
        
        let originalMatchText = String(content[matchRange])
        print("🔍 Original match text: '\(originalMatchText)'")
        print("🔍 Match position in cleaned content: \(cleanedContent.distance(from: cleanedContent.startIndex, to: matchStart))")
        
        // Create snippet around THIS specific match position
        let contextChars = 60
        
        // Calculate snippet start (60 chars before match, or beginning of content)
        let snippetStart: String.Index
        if let index = cleanedContent.index(matchStart, offsetBy: -contextChars, limitedBy: cleanedContent.startIndex) {
            snippetStart = index
        } else {
            snippetStart = cleanedContent.startIndex
        }
        
        // Calculate snippet end (60 chars after match, or end of content)  
        let snippetEnd: String.Index
        if let index = cleanedContent.index(matchEnd, offsetBy: contextChars, limitedBy: cleanedContent.endIndex) {
            snippetEnd = index
        } else {
            snippetEnd = cleanedContent.endIndex
        }
        
        // Extract the snippet
        let snippet = String(cleanedContent[snippetStart..<snippetEnd])
        
        // Add ellipsis if we're not at the boundaries
        let prefix = snippetStart > cleanedContent.startIndex ? "..." : ""
        let suffix = snippetEnd < cleanedContent.endIndex ? "..." : ""
        let fullSnippet = prefix + snippet + suffix
        
        // Calculate highlight range within the snippet
        let prefixLength = prefix.count
        let matchStartInSnippet = cleanedContent.distance(from: snippetStart, to: matchStart) + prefixLength
        let matchEndInSnippet = matchStartInSnippet + originalMatchText.count
        
        guard matchStartInSnippet < fullSnippet.count && matchEndInSnippet <= fullSnippet.count else {
            print("❌ Highlight range out of bounds")
            return (fullSnippet, nil)
        }
        
        let snippetHighlightRange = fullSnippet.index(fullSnippet.startIndex, offsetBy: matchStartInSnippet)..<fullSnippet.index(fullSnippet.startIndex, offsetBy: matchEndInSnippet)
        
        print("🔍 Final snippet: '\(fullSnippet)'")
        print("🔍 Highlight range: \(matchStartInSnippet)-\(matchEndInSnippet)")
        
        return (fullSnippet, snippetHighlightRange)
    }
    
    var body: some View {
        Button(action: {
            boundDocument = document
            sidebarMode = .details
            activePopup = .none
            onDismiss?()
            
            // Navigate to specific match
            highlightSpecificMatch()
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // Match number for all matches when there are multiple
                if totalMatches > 1 {
                    HStack {
                        Text("Match \(matchIndex + 1)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.secondary)
                        Spacer()
                    }
                }
                
                // Larger content snippet with highlighting
                let context = expandedContext
                HighlightedText(
                    text: context.preview,
                    highlightRange: context.highlightRange,
                    font: .system(size: 12),
                    textColor: theme.primary,
                    highlightColor: Color.yellow.opacity(0.4)
                )
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func highlightSpecificMatch() {
        print("🔍 Highlighting specific match in document")
        
        // Build the complete document text to find exact position
        let textBlockElements = document.elements.filter { $0.type == .textBlock }
        var completeText = ""
        var elementPositions: [(elementId: UUID, startPos: Int, endPos: Int)] = []
        
        for element in textBlockElements {
            let startPos = completeText.count
            
            let elementText: String
            if let attributedContent = element.attributedContent {
                elementText = attributedContent.string
            } else {
                elementText = element.content
            }
            
            completeText += elementText
            let endPos = completeText.count
            
            elementPositions.append((elementId: element.id, startPos: startPos, endPos: endPos))
        }
        
        // Find our specific match in the complete text
        guard let matchElementPos = elementPositions.first(where: { $0.elementId == match.elementId }) else {
            print("❌ Could not find element position for match")
            return
        }
        
        // Calculate the absolute position of our match
        let elementStartInDocument = matchElementPos.startPos
        let matchStartInElement = match.text.distance(from: match.text.startIndex, to: match.matchRange.lowerBound)
        let absolutePosition = elementStartInDocument + matchStartInElement
        let matchLength = match.text.distance(from: match.matchRange.lowerBound, to: match.matchRange.upperBound)
        
        print("🔍 Found match at absolute position \(absolutePosition), length \(matchLength)")
        
        // Navigate to the match with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            #if os(macOS)
            // On macOS, collapse header first
            NotificationCenter.default.post(
                name: NSNotification.Name("CollapseHeaderOnly"),
                object: nil
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SearchHighlight"),
                    object: nil,
                    userInfo: [
                        "charPosition": absolutePosition,
                        "charLength": matchLength,
                        "searchTerm": searchText
                    ]
                )
            }
            #else
            // On iOS
            NotificationCenter.default.post(
                name: NSNotification.Name("SearchHighlight"),
                object: nil,
                userInfo: [
                    "charPosition": absolutePosition,
                    "charLength": matchLength,
                    "searchTerm": searchText
                ]
            )
            #endif
        }
    }
}

// Component for displaying text with highlighted ranges
struct HighlightedText: View {
    let text: String
    let highlightRange: Range<String.Index>?
    let font: Font
    let textColor: Color
    let highlightColor: Color
    
    var body: some View {
        if let range = highlightRange {
            // Use AttributedString for proper text flow and highlighting
            let beforeHighlight = String(text[..<range.lowerBound])
            let highlighted = String(text[range])
            let afterHighlight = String(text[range.upperBound...])
            
            // Create the full attributed string
            let fullAttributedString = createAttributedString(
                beforeText: beforeHighlight,
                highlightedText: highlighted,
                afterText: afterHighlight,
                font: font,
                textColor: textColor,
                highlightColor: highlightColor
            )
            
            Text(fullAttributedString)
        } else {
            Text(text)
                .font(font)
                .foregroundColor(textColor)
        }
    }
    
    private func createAttributedString(
        beforeText: String,
        highlightedText: String,
        afterText: String,
        font: Font,
        textColor: Color,
        highlightColor: Color
    ) -> AttributedString {
        var attributedString = AttributedString(beforeText)
        
        var highlightedPart = AttributedString(highlightedText)
        highlightedPart.backgroundColor = highlightColor
        
        var afterPart = AttributedString(afterText)
        
        attributedString.append(highlightedPart)
        attributedString.append(afterPart)
        
        // Set the font and color for the entire string
        attributedString.font = font
        attributedString.foregroundColor = textColor
        
        return attributedString
    }
}


struct SearchPopupContent: View {
    @State private var searchText = ""
    @State private var searchResults: [Letterspace_CanvasDocument] = []
    @State private var searchTask: Task<Void, Never>?
    @Binding var activePopup: ActivePopup
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    var onDismiss: (() -> Void)? = nil
    @Environment(\.themeColors) var theme
    
    // Lazy initialization flag to prevent heavy work on first load
    @State private var isSearchSystemInitialized = false
    
    private func getMatchContext(content: String, searchText: String) -> (String, Range<String.Index>?) {
        guard let range = content.range(of: searchText, options: .caseInsensitive) else {
            return (content, nil)
        }
        
        let preContext = content[..<range.lowerBound].suffix(30)
        let postContext = content[range.upperBound...].prefix(30)
        let fullContext = "..." + preContext + content[range] + postContext + "..."
        
        // Calculate the range of the search term in the full context string
        let preContextCount = preContext.count + 3 // +3 for the "..." prefix
        let searchTermStart = fullContext.index(fullContext.startIndex, offsetBy: preContextCount)
        let searchTermEnd = fullContext.index(searchTermStart, offsetBy: content[range].count)
        
        return (fullContext, searchTermStart..<searchTermEnd)
    }
    
    private func performSearch() async {
        print("🔍 SearchPopupContent.performSearch() called with text: '\(searchText)'")
        
        guard !searchText.isEmpty else {
            print("❌ Search text is empty, clearing results")
            await MainActor.run {
                searchResults = []
            }
            return
        }
        
        // Initialize search system lazily only when first search is performed
        if !isSearchSystemInitialized {
            print("🔍 First search - initializing search system")
            isSearchSystemInitialized = true
        }
        
        // Perform search on background thread to avoid blocking UI
        await Task.detached(priority: .userInitiated) {
            guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
                print("❌ Could not access documents directory")
                return
            }
            
            do {
                try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
                
                let allFiles = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                let fileURLs = allFiles.filter { $0.pathExtension == "canvas" }
                print("📄 Found \(fileURLs.count) canvas files for search")
                
                var results: [Letterspace_CanvasDocument] = []
                
                // Process files in batches to avoid blocking
                let batchSize = 10
                for batch in fileURLs.chunked(into: batchSize) {
                    guard !Task.isCancelled else { return }
                    
                    for url in batch {
                        guard !Task.isCancelled else { return }
                        
                        do {
                            let data = try Data(contentsOf: url)
                            if let document = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                                let titleMatch = document.title.localizedCaseInsensitiveContains(searchText)
                                let subtitleMatch = document.subtitle.localizedCaseInsensitiveContains(searchText)
                                let seriesMatch = document.series?.name.localizedCaseInsensitiveContains(searchText) ?? false
                                
                                // Fast content matching - stop at first match per document
                                var contentMatch = false
                                for element in document.elements {
                                    if element.content.localizedCaseInsensitiveContains(searchText) {
                                        contentMatch = true
                                        break
                                    }
                                }
                                
                                if titleMatch || subtitleMatch || seriesMatch || contentMatch {
                                    results.append(document)
                                }
                            }
                        } catch {
                            continue // Skip corrupted files silently
                        }
                    }
                    
                    // Small yield to prevent UI blocking
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
                
                print("🏁 Search complete. Found \(results.count) matches out of \(fileURLs.count) files")
                
                await MainActor.run {
                    searchResults = results
                    print("✅ Updated UI with \(results.count) search results")
                }
            } catch {
                print("❌ Error searching documents: \(error)")
                await MainActor.run {
                    searchResults = []
                }
            }
        }.value
    }
    
    var groupedResults: [(String, [Letterspace_CanvasDocument])] {
        var groups: [(String, [Letterspace_CanvasDocument])] = []
        
        // Group by title/subtitle matches
        let titleMatches = searchResults.filter { doc in
            doc.title.localizedCaseInsensitiveContains(searchText) ||
            doc.subtitle.localizedCaseInsensitiveContains(searchText)
        }
        if !titleMatches.isEmpty {
            groups.append(("Document Names", titleMatches))
        }
        
        // Group by series matches
        let seriesMatches = searchResults.filter { doc in
            doc.series?.name.localizedCaseInsensitiveContains(searchText) ?? false
        }
        if !seriesMatches.isEmpty {
            groups.append(("Sermon Series", seriesMatches))
        }
        
        // Group by content matches
        let contentMatches = searchResults.filter { doc in
            doc.elements.contains { element in
                element.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !contentMatches.isEmpty {
            groups.append(("Document Content", contentMatches))
        }
        
        return groups
    }
    
    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            // Only show header on iPad - macOS uses system popup title
            SearchHeaderView(activePopup: $activePopup)
            
            Divider()
                .foregroundStyle(theme.secondary.opacity(0.2))
            #endif
            
            SearchContentView(
                searchText: $searchText,
                searchResults: $searchResults,
                searchTask: $searchTask,
                groupedResults: groupedResults,
                document: $document,
                sidebarMode: $sidebarMode,
                activePopup: $activePopup,
                performSearch: performSearch,
                onDismiss: onDismiss
            )
            .padding({
                #if os(macOS)
                return 12 // Tighter padding for macOS compact design
                #else
                return 16 // More spacious padding for iPad
                #endif
            }())
        }
        .background(theme.surface)
    }
    
    private func findFirstMatchingElement(in document: Letterspace_CanvasDocument, searchText: String) -> (content: String, element: DocumentElement)? {
        for element in document.elements {
            if element.content.localizedCaseInsensitiveContains(searchText) {
                return (element.content, element)
            }
        }
        return nil
    }
}

// SearchView for iPhone modal presentation
struct SearchView: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    let onDismiss: () -> Void
    @State private var activePopup: ActivePopup = .search
    @State private var document = Letterspace_CanvasDocument(title: "", subtitle: "", elements: [], id: "", markers: [], series: nil, variations: [], isVariation: false, parentVariationId: nil, createdAt: Date(), modifiedAt: Date(), tags: nil, isHeaderExpanded: false, isSubtitleVisible: true, links: [])
    @State private var sidebarMode: RightSidebar.SidebarMode = .allDocuments
    @State private var isRightSidebarVisible = false
    
    // Track if view has been initialized to avoid multiple onAppear calls
    @State private var hasInitialized = false
    
    // Optimized loading: delay heavy content until after initial render
    @State private var contentReady = false
    
    // Add focus state at SearchView level for more direct control
    #if os(iOS)
    @FocusState private var isSearchFocused: Bool
    #endif
    
    var body: some View {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #endif
        
        Group {
            #if os(iOS)
            if isPhone {
                // iPhone: Use NavigationView like Bible Reader search modal
                NavigationView {
                    if contentReady {
                        SearchPopupContent(
                            activePopup: $activePopup,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            isRightSidebarVisible: $isRightSidebarVisible,
                            onDismiss: onDismiss
                        )
                    } else {
                        // Minimal loading view with immediate search field
                        VStack(spacing: 20) {
                            // Immediate search field for instant keyboard focus
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.secondary)
                                TextField("Search documents...", text: .constant(""))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    #if os(iOS)
                                    .focused($isSearchFocused)
                                    #endif
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(theme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            
                            Text("Loading search...")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondary)
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(theme.surface)
                    }
                    .navigationTitle("Search Documents")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: 
                        Button("Done") {
                            onDismiss()
                        }
                        .foregroundColor(.blue)
                    )
                    .background(theme.surface)
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .background(theme.surface)
            } else {
                // iPad: Use regular VStack
                VStack(spacing: 0) {
                    searchViewBody
                }
            }
            #else
            // macOS: Use regular VStack
            VStack(spacing: 0) {
                searchViewBody
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Ensure we only initialize once to avoid performance issues
            guard !hasInitialized else { return }
            hasInitialized = true
            
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                print("🔍 SearchView appeared on iPhone - immediate keyboard focus and delayed content loading")
                
                // Immediate keyboard focus attempts on loading view
                isSearchFocused = true
                
                // Force keyboard appearance at UIKit level - immediate
                DispatchQueue.main.async {
                    // Find and focus the first text field in the hierarchy
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.subviews.first?.findFirstTextField()?.becomeFirstResponder()
                    }
                    print("🔍 SearchView - UIKit focus attempt")
                }
                
                // Quick focus backups
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    isSearchFocused = true
                    print("🔍 SearchView - 10ms focus attempt")
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    isSearchFocused = true
                    print("🔍 SearchView - 20ms focus attempt")
                }
                
                // Load heavy content after keyboard is focused and view is rendered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🔍 SearchView - loading full search content")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        contentReady = true
                    }
                }
            }
            #endif
        }
    }
    
    private var searchViewBody: some View {
        Group {
            // Header
            HStack {
                Text("Search Documents")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
            
            // Search content
            SearchPopupContent(
                activePopup: $activePopup,
                document: $document,
                sidebarMode: $sidebarMode,
                isRightSidebarVisible: $isRightSidebarVisible,
                onDismiss: onDismiss
            )
        }
    }
}
