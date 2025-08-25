import SwiftUI

struct BibleGlobalSearchModal: View {
    @State private var searchText = ""
    @State private var jumpReference = ""
    @State private var searchResults: [BibleVerse] = []
    @State private var isSearching = false
    @State private var errorMessage: String? = nil
    @FocusState private var isJumpFieldFocused: Bool
    
    let onSelectReference: (String, Int, Int) -> Void
    let onSelectPassage: ((ScriptureReference) -> Void)?
    let onDismiss: () -> Void
    
    init(onSelectReference: @escaping (String, Int, Int) -> Void, onSelectPassage: ((ScriptureReference) -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.onSelectReference = onSelectReference
        self.onSelectPassage = onSelectPassage
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        // iOS 26 exclusive - use NavigationStack directly
            #if os(iOS)
                NavigationStack {
                    searchContentView
                        .navigationTitle("Bible Search")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done", action: onDismiss)
                    }
                }
            }
            #else
        // macOS: Use NavigationStack (macOS 13.0+)
                NavigationStack {
                    searchContentView
                        .navigationTitle("Bible Search")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done", action: onDismiss)
                            }
                        }
        }
        .onAppear {
            isJumpFieldFocused = true
        }
        #endif
    }
    
    private var searchContentView: some View {
            VStack(spacing: 0) {
                // Jump-to-Reference
                HStack {
                    TextField("Jump to reference (e.g. John 3:16)", text: $jumpReference, onCommit: jumpToReference)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        #endif
                        .focused($isJumpFieldFocused)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    Button(action: jumpToReference) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing, 12)
                }
                #if os(iOS)
                .background(Color(.secondarySystemBackground))
                #else
                .background(Color(NSColor.controlBackgroundColor))
                #endif
                .cornerRadius(10)
                .padding(.top, 20)
                .padding(.horizontal, 16)
                
                Divider().padding(.vertical, 8)
                
                // Global Search
                VStack(spacing: 16) {
                    TextField("Search the Bible...", text: $searchText, onCommit: performSearch)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        #endif
                        .padding(.horizontal, 16)
                    
                    if isSearching {
                        ProgressView("Searching...")
                            .padding()
                    } else if let errorMessage = errorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else if !searchResults.isEmpty {
                        if let passageRef = computedPassageReference(from: searchResults), onSelectPassage != nil {
                            HStack {
                                Text("Passage: \(passageRef.displayText)")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    onSelectPassage?(passageRef)
                                    onDismiss()
                                } label: {
                                    Label("Attach Passage", systemImage: "plus")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.horizontal, 16)
                            
                            Divider()
                                .padding(.horizontal, 16)
                        }
                        
                        List(searchResults, id: \.reference) { verse in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verse.reference)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(verse.text)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectVerse(verse)
                            }
                            .padding(.vertical, 4)
                        }
                        #if os(iOS)
                        .listStyle(PlainListStyle())
                        #endif
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Text("Search the Bible")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 8) {
                                Text("• Jump to reference: John 3:16")
                                Text("• Search keywords: love, faith, hope")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        Spacer()
                    }
                }
        }
    }
    
    private func jumpToReference() {
        guard !jumpReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await BibleAPI.searchVerses(
                    query: jumpReference.trimmingCharacters(in: .whitespacesAndNewlines),
                    translation: "KJV",
                    mode: .reference
                )
                
                await MainActor.run {
                    searchResults = result.verses
                    isSearching = false
                    
                    // If we found exactly one verse, auto-select it
                    if result.verses.count == 1 {
                        selectVerse(result.verses[0])
                    }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = error.localizedDescription
                    searchResults = []
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await BibleAPI.searchVerses(
                    query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
                    translation: "KJV",
                    mode: .keyword
                )
                
                await MainActor.run {
                    searchResults = result.verses
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = error.localizedDescription
                    searchResults = []
                }
            }
        }
    }
    
    private func selectVerse(_ verse: BibleVerse) {
        if let (book, chapter, verseNum) = parseReference(verse.reference) {
            onSelectReference(book, chapter, verseNum)
        }
    }
    
    private func computedPassageReference(from verses: [BibleVerse]) -> ScriptureReference? {
        guard verses.count > 1 else { return nil }
        guard let first = verses.first, let last = verses.last else { return nil }
        guard let firstParsed = parseReference(first.reference),
              let lastParsed = parseReference(last.reference) else { return nil }
        let (book1, chapter1, v1) = firstParsed
        let (book2, chapter2, v2) = lastParsed
        guard book1 == book2, chapter1 == chapter2 else { return nil }
        
        let verseString = v1 == v2 ? "\(v1)" : "\(v1)-\(v2)"
        let display = "\(book1) \(chapter1):\(verseString)"
        return ScriptureReference(book: book1, chapter: chapter1, verse: verseString, displayText: display)
    }
    
    private func parseReference(_ reference: String) -> (String, Int, Int)? {
        // Improved reference parsing
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle formats like "John 3:16", "1 Corinthians 13:4", "Psalms 23:1"
        let pattern = #"^(\d?\s?\w+)\s+(\d+):(\d+)$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            if let match = regex.firstMatch(in: trimmed, options: [], range: nsRange) {
                if let bookRange = Range(match.range(at: 1), in: trimmed),
                   let chapterRange = Range(match.range(at: 2), in: trimmed),
                   let verseRange = Range(match.range(at: 3), in: trimmed) {
                    
                    let book = String(trimmed[bookRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let chapter = Int(String(trimmed[chapterRange])) ?? 1
                    let verse = Int(String(trimmed[verseRange])) ?? 1
                    
                    return (book, chapter, verse)
                }
            }
        }
        
        // Fallback to simple parsing
        let components = trimmed.components(separatedBy: " ")
        guard components.count >= 2 else { return nil }
        
        let book = components.dropLast().joined(separator: " ")
        let chapterVerse = components.last?.components(separatedBy: ":") ?? []
        
        guard chapterVerse.count == 2,
              let chapter = Int(chapterVerse[0]),
              let verse = Int(chapterVerse[1]) else { return nil }
        
        return (book, chapter, verse)
    }
}