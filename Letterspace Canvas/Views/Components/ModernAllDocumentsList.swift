import SwiftUI

struct ModernAllDocumentsList: View {
    @Binding var documents: [Letterspace_CanvasDocument]
    @Binding var selectedDocuments: Set<String>
    @Binding var selectedTags: Set<String>
    @Binding var selectedFilterColumn: String?
    @Binding var selectedFilterCategory: String
    
    let pinnedDocuments: Set<String>
    let wipDocuments: Set<String>
    let calendarDocuments: Set<String>
    let dateFilterType: DateFilterType
    
    let onPin: (Letterspace_CanvasDocument) -> Void
    let onWIP: (Letterspace_CanvasDocument) -> Void
    let onCalendar: (Letterspace_CanvasDocument) -> Void
    let onCalendarAction: (Letterspace_CanvasDocument) -> Void
    let onOpen: (Letterspace_CanvasDocument) -> Void
    let onShowDetails: (Letterspace_CanvasDocument) -> Void
    let onDelete: ([String]) -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    @State private var showFilterOptions = false
    
    // Computed property for all available tags
    private var allTags: [String] {
        let tagSet = Set(documents.compactMap { $0.tags }.flatMap { $0 })
        return Array(tagSet).sorted()
    }
    
    // Computed property for all available series
    private var allSeries: [String] {
        let seriesSet = Set(documents.compactMap { $0.series?.name }.filter { !$0.isEmpty })
        return Array(seriesSet).sorted()
    }
    
    // Computed property for all available locations
    private var allLocations: [String] {
        let locationSet = Set(documents.compactMap { $0.variations.first?.location }.filter { !$0.isEmpty })
        return Array(locationSet).sorted()
    }
    
    // Filtered documents based on current filters
    private var filteredDocuments: [Letterspace_CanvasDocument] {
        var filtered = documents
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { document in
                guard let documentTags = document.tags else { return false }
                let tagSet = Set(documentTags)
                return !tagSet.isDisjoint(with: selectedTags)
            }
        }
        
        // Apply column filter
        if let filterColumn = selectedFilterColumn {
            switch filterColumn {
            case "Series":
                if !allSeries.isEmpty {
                    filtered = filtered.filter { document in
                        return document.series?.name != nil && !document.series!.name.isEmpty
                    }
                }
            case "Location":
                if !allLocations.isEmpty {
                    filtered = filtered.filter { document in
                        return document.variations.first?.location != nil && !document.variations.first!.location!.isEmpty
                    }
                }
            default:
                break
            }
        }
        
        return filtered.sorted { doc1, doc2 in
            switch dateFilterType {
            case .modified:
                return doc1.modifiedAt > doc2.modifiedAt
            case .created:
                return doc1.createdAt > doc2.createdAt
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header section
            headerSection
            
            // Filter section
            filterSection
            
            // Documents list
            documentsSection
        }
        .padding(.horizontal, 8)
    }
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(theme.primary)
                    
                    Text("All Docs (\(filteredDocuments.count))")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            
            Spacer()
            
            Button(action: {
                selectedTags.removeAll()
                selectedFilterColumn = nil
                selectedFilterCategory = "Filter"
            }) {
                Text("Clear")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(theme.primary)
            .opacity(selectedTags.isEmpty && selectedFilterColumn == nil ? 0.5 : 1.0)
            .disabled(selectedTags.isEmpty && selectedFilterColumn == nil)
        }
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Filter category toggle
                HStack(spacing: 12) {
                    FilterPill(
                        title: "Filter",
                        isSelected: selectedFilterCategory == "Filter",
                        onTap: { selectedFilterCategory = "Filter" }
                    )
                    
                    FilterPill(
                        title: "Tags",
                        isSelected: selectedFilterCategory == "Tags",
                        onTap: { selectedFilterCategory = "Tags" }
                    )
                }
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 24)
                
                // Filter options based on category
                if selectedFilterCategory == "Filter" {
                    filterOptions
                } else {
                    tagOptions
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var filterOptions: some View {
        HStack(spacing: 12) {
            FilterPill(
                title: "Series",
                isSelected: selectedFilterColumn == "Series",
                onTap: {
                    selectedFilterColumn = selectedFilterColumn == "Series" ? nil : "Series"
                }
            )
            
            FilterPill(
                title: "Location",
                isSelected: selectedFilterColumn == "Location",
                onTap: {
                    selectedFilterColumn = selectedFilterColumn == "Location" ? nil : "Location"
                }
            )
        }
    }
    
    private var tagOptions: some View {
        HStack(spacing: 12) {
            ForEach(allTags, id: \.self) { tag in
                FilterPill(
                    title: tag,
                    isSelected: selectedTags.contains(tag),
                    onTap: {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                )
            }
        }
    }
    
    private var documentsSection: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                ForEach(filteredDocuments, id: \.id) { document in
                    ModernDocumentRow(
                        document: document,
                        onTap: { onOpen(document) },
                        onShowDetails: { onShowDetails(document) },
                        onPin: { onPin(document) },
                        onWIP: { onWIP(document) },
                        onCalendar: { onCalendar(document) },
                        onCalendarAction: { onCalendarAction(document) },
                        onDelete: { onDelete([document.id]) },
                        selectedTags: selectedTags,
                        selectedFilterColumn: selectedFilterColumn,
                        dateFilterType: dateFilterType
                    )
                    .environment(\.documentStatus, DocumentStatus(
                        isPinned: pinnedDocuments.contains(document.id),
                        isWIP: wipDocuments.contains(document.id),
                        isScheduled: calendarDocuments.contains(document.id)
                    ))
                }
            }
            .padding(.bottom, 100) // Space for bottom navigation
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    private var backgroundFillColor: Color {
        if colorScheme == .dark {
            #if os(iOS)
            return Color(.systemGray5)
            #else
            return Color(NSColor.controlBackgroundColor)
            #endif
        } else {
            #if os(iOS)
            return Color(.systemGray6)
            #else
            return Color(NSColor.controlColor)
            #endif
        }
    }
    
    private var strokeColor: Color {
        if colorScheme == .dark {
            #if os(iOS)
            return Color(.systemGray4)
            #else
            return Color(NSColor.separatorColor)
            #endif
        } else {
            #if os(iOS)
            return Color(.systemGray5)
            #else
            return Color(NSColor.controlBackgroundColor)
            #endif
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? theme.primary : backgroundFillColor)
                        .stroke(
                            isSelected ? Color.clear : strokeColor,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// Environment key for document status
struct DocumentStatusKey: EnvironmentKey {
    static let defaultValue = DocumentStatus(isPinned: false, isWIP: false, isScheduled: false)
}

extension EnvironmentValues {
    var documentStatus: DocumentStatus {
        get { self[DocumentStatusKey.self] }
        set { self[DocumentStatusKey.self] = newValue }
    }
}

struct DocumentStatus {
    let isPinned: Bool
    let isWIP: Bool
    let isScheduled: Bool
} 