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
        // Use NavigationStack for iOS 16+ and NavigationView for older versions
        Group {
            #if os(iOS)
            if #available(iOS 16.0, *) {
                NavigationStack {
                    searchContentView
                        .navigationTitle("Bible Search")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: {
                                #if os(iOS)
                                .navigationBarTrailing
                                #else
                                .automatic
                                #endif
                            }()) {
                                Button("Done", action: onDismiss)
                            }
                        }
                }
            } else {
                // Fallback for iOS 15 and below: Use simple VStack to avoid NavigationView delays
                VStack(spacing: 0) {
                    // Simple header for older iOS
                    HStack {
                        Text("Bible Search")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Button("Done", action: onDismiss)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    #if os(iOS)
                    .background(Color(.systemBackground))
                    #else
                    .background(Color(NSColor.windowBackgroundColor))
                    #endif
                    
                    Divider()
                    
                    searchContentView
                }
            }
            #else
            // macOS: Use NavigationStack or NavigationView as appropriate
            if #available(macOS 13.0, *) {
                NavigationStack {
                    searchContentView
                        .navigationTitle("Bible Search")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done", action: onDismiss)
                            }
                        }
                }
            } else {
        NavigationView {
                    searchContentView
                        .navigationTitle("Bible Search")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done", action: onDismiss)
                            }
                        }
                }
            }
            #endif
        }
        .onAppear {
            isJumpFieldFocused = true
        }
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