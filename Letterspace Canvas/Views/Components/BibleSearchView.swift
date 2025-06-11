#if os(macOS)
import SwiftUI
import AppKit

// Define a direct NSTextField representable right here in the file
struct BibleSearchTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onAction: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.isBordered = false
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.bezelStyle = .roundedBezel
        
        // Make it become first responder immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = textField.window {
                window.makeFirstResponder(textField)
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: BibleSearchTextField
        
        init(_ parent: BibleSearchTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            // Do nothing on end editing
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onAction()
                return true
            }
            return false
        }
    }
}

struct BibleSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [BibleVerse] = []
    @State private var selectedTranslation = "KJV"
    @State private var hoveredIcon: String? = nil
    @State private var activeMode: BibleSearchMode = .reference
    @State private var currentPage = 1
    @State private var totalResults = 0
    @State private var hasMoreResults = false
    @Environment(\.colorScheme) var colorScheme
    
    var onVerseSelect: (DocumentElement) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            resultsSection
        }
        .frame(width: 600)
        .preferredColorScheme(.light)
        .background(Color.white)
        .onAppear {
            // Clear any previous state when the view appears
            searchText = ""
            searchResults = []
            totalResults = 0
            hasMoreResults = false
            currentPage = 1
            
            // Focus the search field immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApplication.shared.keyWindow,
                   let firstResponder = window.firstResponder as? NSTextField {
                    window.makeFirstResponder(firstResponder)
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                Text("Scripture")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                
                HStack(spacing: 8) {
                    searchBar
                    translationButtons
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.gray.opacity(0.2))
        }
        .background(Color.white)
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            searchModeButtons
            searchField
        }
        .padding(6)
        .background(Color(.white))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var searchModeButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                searchText = ""
                activeMode = .reference
            }) {
                Image(systemName: "book")
                    .foregroundColor(activeMode == .reference ? .blue : .gray)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(hoveredIcon == "book" ? 0.1 : 0))
                    )
            }
            .buttonStyle(.plain)
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.1)) {
                    hoveredIcon = isHovered ? "book" : nil
                }
            }
            .scaleEffect(hoveredIcon == "book" ? 1.1 : 1.0)
            
            Button(action: {
                searchText = ""
                activeMode = .keyword
            }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(activeMode == .keyword ? .blue : .gray)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(hoveredIcon == "magnifyingglass" ? 0.1 : 0))
                    )
            }
            .buttonStyle(.plain)
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.1)) {
                    hoveredIcon = isHovered ? "magnifyingglass" : nil
                }
            }
            .scaleEffect(hoveredIcon == "magnifyingglass" ? 1.1 : 1.0)
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 8) {
            searchModeButtons
            
            BibleSearchTextField(
                text: $searchText,
                placeholder: getPlaceholderText(),
                onAction: { searchBibleVerses(query: searchText) }
            )
            .id(activeMode)
            
            Button(action: {
                searchBibleVerses(query: searchText)
            }) {
                Text("Search")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(searchText.isEmpty)
        }
    }
    
    private var translationButtons: some View {
        Menu {
            ForEach(["KJV", "ASV", "WEB", "YLT"], id: \.self) { translation in
                Button(action: {
                    selectedTranslation = translation
                    if !searchText.isEmpty {
                        searchBibleVerses(query: searchText)
                    }
                }) {
                    HStack {
                        Text(translation)
                        if selectedTranslation == translation {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(selectedTranslation)
                .foregroundColor(.blue)
                .font(.system(size: 12))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.1))
                )
        }
        .menuStyle(.borderlessButton)
        .frame(width: 45)
    }
    
    private var resultsSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                if activeMode == .keyword && !searchResults.isEmpty {
                    resultCountHeader
                }
                
                if searchResults.count > 1 && activeMode == .reference {
                    multiVerseHeader
                }
                
                resultsList
            }
            .padding(.vertical, 16)
            .padding(.top, 24)
        }
        .background(Color.white)
    }
    
    private var resultCountHeader: some View {
        HStack {
            Text("\(totalResults) results found")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
    
    private var multiVerseHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Text("\(searchResults[0].reference)-\(searchResults.last?.reference.split(separator: ":").last ?? "")")
                    .font(.system(size: 16, weight: .semibold))
                Text("·")
                    .foregroundStyle(.secondary)
                Text("King James Version")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(6)
            
            Spacer()
            
            Button("Insert Full Passage") {
                let reference = "\(searchResults[0].reference)-\(searchResults.last?.reference.split(separator: ":").last ?? "")"
                
                // Format verses with their numbers
                let formattedVerses = searchResults.enumerated().map { _, verse in
                    let verseNum = verse.reference.split(separator: ":").last ?? ""
                    let cleanedText = verse.text
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    return "[\(verseNum)] \(cleanedText)"
                }.joined(separator: "\n")
                
                // Create a document element with formatted text
                var element = DocumentElement(type: .scripture)
                element.content = "\(reference)|\(selectedTranslation)|\(formattedVerses)"
                
                onVerseSelect(element)
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
    
    private var resultsList: some View {
        VStack(spacing: activeMode == .keyword ? 24 : 20) {
            ForEach(searchResults) { verse in
                verseRow(verse)
            }
            
            if hasMoreResults {
                loadMoreButton
            }
        }
        .padding(.top, activeMode == .reference && searchResults.count > 1 ? 0 : 24)
    }
    
    private func verseRow(_ verse: BibleVerse) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: {
                // Create a document element with formatted text
                var element = DocumentElement(type: .scripture)
                let verseNum = verse.reference.split(separator: ":").last ?? ""
                let cleanedText = verse.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                let formattedText = "[\(verseNum)] \(cleanedText)"
                element.content = "\(verse.reference)|\(verse.translation)|\(formattedText)"
                
                onVerseSelect(element)
            }) {
                Image(systemName: "plus")
                    .foregroundStyle(.white)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(verse.reference)
                        .font(.system(size: 13, weight: .semibold))
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(verse.translation)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                Text(verse.text)
                    .font(.system(size: 12))
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
    }
    
    private var loadMoreButton: some View {
        Button(action: loadMoreResults) {
            Text("Load More Results")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.blue)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
    
    private func searchBibleVerses(query: String) {
        Task {
            do {
                let result = try await BibleAPI.searchVerses(
                    query: query,
                    translation: selectedTranslation,
                    mode: activeMode,
                    page: 1
                )
                await MainActor.run {
                    searchResults = result.verses
                    totalResults = result.total
                    currentPage = 1
                    hasMoreResults = result.hasMore
                }
            } catch {
                print("Search error: \(error)")
            }
        }
    }
    
    private func loadMoreResults() {
        Task {
            do {
                let result = try await BibleAPI.searchVerses(
                    query: searchText,
                    translation: selectedTranslation,
                    mode: activeMode,
                    page: currentPage + 1
                )
                await MainActor.run {
                    searchResults.append(contentsOf: result.verses)
                    currentPage += 1
                    hasMoreResults = result.hasMore
                }
            } catch {
                print("Load more error: \(error)")
            }
        }
    }
    
    private func highlightedText(_ text: String, keyword: String) -> Text {
        guard !keyword.isEmpty else { 
            return Text(text)
        }
        
        var finalText = Text("")
        let words = text.components(separatedBy: " ")
        
        for (index, word) in words.enumerated() {
            if word.lowercased().contains(keyword.lowercased()) {
                if index > 0 {
                    finalText = finalText + Text(" ")
                }
                finalText = finalText + Text(word).bold().foregroundColor(.blue)
            } else {
                if index > 0 {
                    finalText = finalText + Text(" ")
                }
                finalText = finalText + Text(word)
            }
        }
        
        return finalText
    }
    
    private func getPlaceholderText() -> String {
        switch activeMode {
        case .reference:
            return "Enter verse reference (e.g. John 3:16)"
        case .keyword:
            return "Search by word, phrase, or part of a verse..."
        case .strongs:
            return "Enter Strong's number (e.g. H1254)"
        }
    }
    
    private func cleanVerseText(_ text: String, reference: String) -> String {
        // Split into lines and get only the content after the reference line
        let lines = text.components(separatedBy: .newlines)
        
        // Find the index of the line containing the reference
        if let referenceIndex = lines.firstIndex(where: { $0.contains(reference) }) {
            // Take only the lines after the reference
            let contentLines = Array(lines.suffix(from: referenceIndex + 1))
            return contentLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Fallback: just return the cleaned text without the reference
        return text
            .replacingOccurrences(of: reference, with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

// Custom pill-shaped button style
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.blue)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
#endif 