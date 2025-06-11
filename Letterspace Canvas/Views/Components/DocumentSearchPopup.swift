import SwiftUI

struct DocumentSearchPopup: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var searchResults: [Letterspace_CanvasDocument] = []
    @State private var selectedDocument: Letterspace_CanvasDocument?
    @State private var searchTask: Task<Void, Never>?
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var onDocumentSelect: (Letterspace_CanvasDocument) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondary)
                TextField("Search documents...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .frame(width: 200)
            }
            .padding(8)
            .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
            
            Divider()
            
            // Search results
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if searchResults.isEmpty && !searchText.isEmpty {
                        Text("No results found")
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(searchResults, id: \.id) { document in
                            DocumentSearchResultRow(document: document) {
                                onDocumentSelect(document)
                                isPresented = false
                            }
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 280)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10)
        .onChange(of: searchText) { oldValue, newValue in
            // Cancel any existing search task
            searchTask?.cancel()
            
            // Start a new search task with debounce
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                if !Task.isCancelled {
                    await performSearch()
                }
            }
        }
    }
    
    private func performSearch() async {
        guard !searchText.isEmpty else {
            await MainActor.run {
                searchResults = []
            }
            return
        }
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            // Perform file operations on background thread
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            var results: [Letterspace_CanvasDocument] = []
            
            // Process each document
            for url in fileURLs {
                guard !Task.isCancelled else { return }
                
                let data = try Data(contentsOf: url)
                let document = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                
                // Search in title, subtitle, and content
                let titleMatch = document.title.localizedCaseInsensitiveContains(searchText)
                let subtitleMatch = document.subtitle.localizedCaseInsensitiveContains(searchText)
                let contentMatch = document.elements.contains { element in
                    element.content.localizedCaseInsensitiveContains(searchText)
                }
                
                if titleMatch || subtitleMatch || contentMatch {
                    results.append(document)
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                searchResults = results
            }
        } catch {
            print("Error searching documents: \(error)")
            await MainActor.run {
                searchResults = []
            }
        }
    }
}

struct DocumentSearchResultRow: View {
    let document: Letterspace_CanvasDocument
    let onSelect: () -> Void
    @Environment(\.themeColors) var theme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.primary)
                        .lineLimit(1)
                    if !document.subtitle.isEmpty {
                        Text(document.subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovered ? theme.surface : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
} 