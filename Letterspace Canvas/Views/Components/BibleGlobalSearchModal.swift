import SwiftUI

struct BibleGlobalSearchModal: View {
    @State private var searchText = ""
    @State private var jumpReference = ""
    @State private var searchResults: [BibleVerse] = []
    @State private var isSearching = false
    @State private var errorMessage: String? = nil
    @FocusState private var isJumpFieldFocused: Bool
    
    let onSelectReference: (String, Int, Int) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
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
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    } else if !searchResults.isEmpty {
                        List(searchResults, id: \.reference) { verse in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verse.reference)
                                    .font(.headline)
                                Text(verse.text)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .onTapGesture {
                                selectVerse(verse)
                            }
                        }
                        #if os(iOS)
                        .listStyle(PlainListStyle())
                        #endif
                    } else {
                        Text("Enter a search term to find verses")
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle("Bible Search")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done", action: onDismiss))
            #else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            #endif
        }
        .onAppear {
            isJumpFieldFocused = true
        }
    }
    
    private func jumpToReference() {
        // Parse the reference and call the callback
        if let (book, chapter, verse) = parseReference(jumpReference) {
            onSelectReference(book, chapter, verse)
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        // TODO: Implement actual Bible search
        // For now, just clear results
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSearching = false
            searchResults = []
            errorMessage = "Search functionality not yet implemented"
        }
    }
    
    private func selectVerse(_ verse: BibleVerse) {
        if let (book, chapter, verseNum) = parseReference(verse.reference) {
            onSelectReference(book, chapter, verseNum)
        }
    }
    
    private func parseReference(_ reference: String) -> (String, Int, Int)? {
        // Simple reference parsing - should be improved
        let components = reference.components(separatedBy: " ")
        guard components.count >= 2 else { return nil }
        
        let book = components[0]
        let chapterVerse = components[1].components(separatedBy: ":")
        guard chapterVerse.count == 2,
              let chapter = Int(chapterVerse[0]),
              let verse = Int(chapterVerse[1]) else { return nil }
        
        return (book, chapter, verse)
    }
} 