import SwiftUI
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
        .background(theme.surface)
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
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(spacing: 12) {
            SearchFieldView(searchText: $searchText, searchTask: $searchTask, performSearch: performSearch)
            
            if searchText.isEmpty {
                SearchEmptyStateView()
            } else {
                SearchResultsView(
                    searchText: searchText,
                    searchResults: searchResults,
                    groupedResults: groupedResults,
                    document: $document,
                    sidebarMode: $sidebarMode,
                    activePopup: $activePopup
                )
            }
        }
    }
}

struct SearchFieldView: View {
    @Binding var searchText: String
    @Binding var searchTask: Task<Void, Never>?
    let performSearch: () async -> Void
    @Environment(\.themeColors) var theme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(theme.secondary)
            TextField("Search documents...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onChange(of: searchText) { oldValue, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await performSearch()
                    }
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.background)
        )
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
    @Environment(\.themeColors) var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if searchResults.isEmpty {
                    Text("No results found")
                        .font(.custom("InterTight-Regular", size: 13))
                        .foregroundColor(theme.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(groupedResults, id: \.0) { group in
                        SearchResultGroupView(
                            group: group,
                            searchText: searchText,
                            groupedResults: groupedResults,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            activePopup: $activePopup
                        )
                    }
                }
            }
        }
    }
}

struct SearchResultGroupView: View {
    let group: (String, [Letterspace_CanvasDocument])
    let searchText: String
    let groupedResults: [(String, [Letterspace_CanvasDocument])]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            Text(group.0)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 8)
            
            // Results in this category
            ForEach(group.1) { doc in
                SearchResultRowView(
                    doc: doc,
                    group: group,
                    searchText: searchText,
                    document: $document,
                    sidebarMode: $sidebarMode,
                    activePopup: $activePopup
                )
                
                if doc.id != group.1.last?.id {
                    Divider()
                }
            }
            
            if group.0 != groupedResults.last?.0 {
                Divider()
                    .padding(.vertical, 8)
            }
        }
    }
}

struct SearchResultRowView: View {
    let doc: Letterspace_CanvasDocument
    let group: (String, [Letterspace_CanvasDocument])
    let searchText: String
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: {
            document = doc
            sidebarMode = .details
            activePopup = .none
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // Document title
                Text(doc.title.isEmpty ? "Untitled" : doc.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.primary)
                
                // Show subtitle for non-content matches
                if !doc.subtitle.isEmpty {
                    Text(doc.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    @Environment(\.themeColors) var theme
    
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
        print("🔍 Starting search with text: '\(searchText)'")
        
        guard !searchText.isEmpty else {
            print("❌ Search text is empty, clearing results")
            await MainActor.run {
                searchResults = []
            }
            return
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        print("📂 Documents path: \(appDirectory)")
        
        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📄 Found \(fileURLs.count) canvas files")
            
            var results: [Letterspace_CanvasDocument] = []
            
            for url in fileURLs {
                guard !Task.isCancelled else { return }
                
                let fileName = url.lastPathComponent
                print("🔎 Processing file: \(fileName)")
                
                do {
                    let data = try Data(contentsOf: url)
                    if let document = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                        let titleMatch = document.title.localizedCaseInsensitiveContains(searchText)
                        let subtitleMatch = document.subtitle.localizedCaseInsensitiveContains(searchText)
                        let seriesMatch = document.series?.name.localizedCaseInsensitiveContains(searchText) ?? false
                        
                        // Improved content matching
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
                    print("❌ Error reading document at \(fileName): \(error)")
                    continue
                }
            }
            
            print("🏁 Search complete. Found \(results.count) matches out of \(fileURLs.count) files")
            
            await MainActor.run {
                searchResults = results
            }
        } catch {
            print("❌ Error searching documents: \(error)")
            await MainActor.run {
                searchResults = []
            }
        }
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
                performSearch: performSearch
            )
            .padding({
                #if os(macOS)
                return 12 // Tighter padding for macOS compact design
                #else
                return 16 // More spacious padding for iPad
                #endif
            }())
                                    }
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
