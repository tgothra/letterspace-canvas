import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// Add at the top of the file with other imports
struct Marker: Identifiable {
    let id = UUID()
    var title: String
    var page: Int
    var type: String    // Instead of color string
    var position: Int   // Instead of x,y coordinates
}

// MARK: - Helper Extensions
extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }
}

struct HoverPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Helper Models
struct Day: Identifiable {
    let id: UUID = UUID()
    let number: Int?  // Changed to optional
    let month: Int
    let year: Int
    let isCurrentMonth: Bool
    let isSelected: Bool
}

extension Calendar {
    func daysInMonth(year: Int, month: Int) -> [Day] {
        var days = [Day]()
        
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = self.date(from: dateComponents),
              let range = self.range(of: .day, in: .month, for: date),
              let firstWeekday = self.date(from: dateComponents)?.startOfMonth().weekday else {
            return []
        }
        
        // Add empty spaces for previous month
        let previousOffset = firstWeekday - 1
        if previousOffset > 0 {
            for _ in 0..<previousOffset {
                days.append(Day(
                    number: nil,  // Use nil to indicate empty space
                    month: month,
                    year: year,
                    isCurrentMonth: false,
                    isSelected: false
                ))
            }
        }
        
        // Add days from current month
        for day in range {
            days.append(Day(
                number: day,
                month: month,
                year: year,
                isCurrentMonth: true,
                isSelected: false
            ))
        }
        
        // Add empty spaces for next month (instead of actual dates)
        let remainingDays = 42 - days.count // 6 rows * 7 days = 42
        if remainingDays > 0 {
            for _ in 0..<remainingDays {
                days.append(Day(
                    number: nil,  // Use nil to indicate empty space
                    month: month,
                    year: year,
                    isCurrentMonth: false,
                    isSelected: false
                ))
            }
        }
        
        return days
    }
}

struct DocumentTag: Identifiable, Hashable {
    let id = UUID()
    let text: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum SeriesSortOrder: String, CaseIterable {
    case name = "Name"
    case date = "Date"
    case custom = "Custom"
}

// MARK: - Views
struct RightSidebar: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var isVisible: Bool
    @Binding var selectedElement: UUID?
    @Binding var scrollOffset: CGFloat
    @Binding var documentHeight: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var viewMode: ViewMode
    @Binding var isHeaderExpanded: Bool
    @Binding var isSubtitleVisible: Bool
    @State private var sidebarMode: SidebarMode = .details
    @State private var linkURL: String = ""
    @State private var linkTitle: String = ""
    @State private var isAddingLink: Bool = false
    @State private var searchText: String = ""
    @State private var isSelectingTags: Bool = false
    @State private var currentTag: String = ""
    @State private var currentVariations: [Letterspace_CanvasDocument] = []
    @State private var showTranslationModal: Bool = false
    @State private var hoveredSeriesItem: String? = nil
    
    // Liquid Glass touch tracking
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var hoveredButtonIndex: Int? = nil
    
    // Local environment values
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    private let colorManager = TagColorManager.shared
    
    // Add the missing series state property
    @State private var series: [DocumentSeries] = []
    
    // Add document cache
    @State private var documentCache: [String: Letterspace_CanvasDocument] = [:]
    
    // Add a flag to track if we've loaded variations for this document
    @State private var loadedForDocumentId: String = ""
    
    enum SidebarMode {
        case documents
        case details
        case settings
        case recentlyDeleted
        case series
        case tags
        case variations
        case bookmarks
        case links
        case search
        case allDocuments
    }
    
    @State private var isAnimating = false
    @State private var documentName: String = ""
    @State private var datePresented: String = ""
    @State private var location: String = ""
    @State private var tags: Set<String> = []
    
    @State private var seriesSearchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedSeries: String? = nil
    @State private var allSeries: [DocumentSeries] = []
    @State private var isDateSortAscending = true  // Add this line
    
    @State private var tagSearchText = ""
    @FocusState private var isTagSearchFocused: Bool
    @State private var showTagSuggestions = false
    @State private var documents: [Letterspace_CanvasDocument] = []
    @State private var showPresentationManager: Bool = false
    @State private var showPresentationTimeline: Bool = false
    @State private var isPresentationButtonHovered = false
    
    // Add a state variable to force refresh on notification
    @State private var refreshTrigger = UUID()
    
    // Add missing variables for links functionality
    @State private var newLinkTitle: String = ""
    @State private var newLinkURL: String = ""
    
    private var recentSeries: [String] {
        Array(Set(allSeries.map { $0.name })).sorted()
    }
    
    private func formatSeries(_ series: String) -> String {
        // Split by spaces and capitalize first letter of each word
        return series.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    private var matchingSeries: [String] {
        if seriesSearchText.isEmpty {
            return []
        }
        
        return recentSeries
            .filter { $0.localizedCaseInsensitiveContains(seriesSearchText) }
            .sorted { (series1: String, series2: String) -> Bool in
                // Exact matches first (case insensitive)
                let exactMatch1 = series1.localizedCaseInsensitiveCompare(seriesSearchText) == .orderedSame
                let exactMatch2 = series2.localizedCaseInsensitiveCompare(seriesSearchText) == .orderedSame
                if exactMatch1 != exactMatch2 {
                    return exactMatch1
                }
                
                // Starts with search text (case insensitive)
                let startsWith1 = series1.lowercased().hasPrefix(seriesSearchText.lowercased())
                let startsWith2 = series2.lowercased().hasPrefix(seriesSearchText.lowercased())
                if startsWith1 != startsWith2 {
                    return startsWith1
                }
                
                // Alphabetical order
                return series1.localizedCaseInsensitiveCompare(series2) == .orderedAscending
            }
    }
    
    private var shouldShowCreateNew: Bool {
        if seriesSearchText.isEmpty { return false }
        return !recentSeries.contains { $0.localizedCaseInsensitiveCompare(seriesSearchText) == .orderedSame }
    }
    
    private var shouldShowCreateNewTag: Bool {
        !tagSearchText.isEmpty && !(document.tags ?? []).contains(tagSearchText)
    }
    
    private var allTags: [String] {
        var tags: Set<String> = []
        for document in documents {
            if let documentTags = document.tags {
                tags.formUnion(documentTags)
            }
        }
        return Array(tags).sorted()
    }
    
    // Computed property for platform-specific background color
    private var backgroundColorForTagsSection: Color {
        #if os(macOS)
        return colorScheme == .dark ? Color(.windowBackgroundColor) : .white
        #elseif os(iOS)
        return colorScheme == .dark ? Color(.systemBackground) : .white
        #endif
    }
    
    private func formatTag(_ tag: String) -> String {
        // Split by spaces and capitalize first letter of each word
        return tag.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    private var matchingTags: [String] {
        if tagSearchText.isEmpty {
            return []
        }
        
        // Get all currently used tags
        var activeTags = Set<String>()
        for document in documents {
            if let documentTags = document.tags {
                activeTags.formUnion(documentTags)
            }
        }
        
        return Array(activeTags)
            .filter { $0.localizedCaseInsensitiveContains(tagSearchText) }
            .sorted { (tag1: String, tag2: String) -> Bool in
                // Exact matches first (case insensitive)
                let exactMatch1 = tag1.localizedCaseInsensitiveCompare(tagSearchText) == .orderedSame
                let exactMatch2 = tag2.localizedCaseInsensitiveCompare(tagSearchText) == .orderedSame
                if exactMatch1 != exactMatch2 {
                    return exactMatch1
                }
                
                // Starts with search text (case insensitive)
                let startsWith1 = tag1.lowercased().hasPrefix(tagSearchText.lowercased())
                let startsWith2 = tag2.lowercased().hasPrefix(tagSearchText.lowercased())
                if startsWith1 != startsWith2 {
                    return startsWith1
                }
                
                // Alphabetical order
                return tag1.localizedCaseInsensitiveCompare(tag2) == .orderedAscending
            }
    }
    
    private var filteredSeriesItems: [(title: String, date: String, isActive: Bool)] {
        guard let selectedSeries = selectedSeries else { return [] }
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        var items: [(title: String, date: String, isActive: Bool)] = []
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            // Add current document first if it belongs to the series
            if document.series?.name.lowercased() == selectedSeries.lowercased() {
                let dateStr: String
                if let presentedDate = document.variations.first?.datePresented {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d, yyyy"
                    dateStr = formatter.string(from: presentedDate)
                } else {
                    dateStr = "No date"
                }
                items.append((
                    title: document.title.isEmpty ? "Untitled" : document.title,
                    date: dateStr,
                    isActive: true
                ))
            }
            
            // Add other documents in the series
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if let series = doc.series,
                       series.name.lowercased() == selectedSeries.lowercased(),
                       doc.id != document.id {  // Skip current document as it's already added
                        
                        let dateStr: String
                        if let presentedDate = doc.variations.first?.datePresented {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "MMM d, yyyy"
                            dateStr = formatter.string(from: presentedDate)
                        } else {
                            dateStr = "No date"
                        }
                        
                        items.append((
                            title: doc.title.isEmpty ? "Untitled" : doc.title,
                            date: dateStr,
                            isActive: false
                        ))
                    }
                } catch {
                    print("Error reading document at \(url): \(error)")
                }
            }
            
            // Sort items
            return items.sorted { 
                // Handle "No date" cases
                if $0.date == "No date" { return !isDateSortAscending }
                if $1.date == "No date" { return isDateSortAscending }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                
                guard let date1 = formatter.date(from: $0.date),
                      let date2 = formatter.date(from: $1.date) else {
                    return false
                }
                
                return isDateSortAscending ? date1 < date2 : date1 > date2
            }
            
        } catch {
            print("Error accessing documents directory: \(error)")
            return []
        }
    }
    
    private func tagColor(for tag: String) -> Color {
        return colorManager.color(for: tag)
    }
    
    var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Details Section - Always visible
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    sidebarMode = .details
                }
            }) {
                SectionHeader(title: "Details", isExpanded: true, showChevron: false)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 16)
            
            VStack(spacing: 8) {
                EditableField(
                    placeholder: "Title",
                    text: Binding(
                        get: { document.title },
                        set: { newValue in
                            document.title = newValue
                            document.save()
                            print("✏️ Title updated to: \(newValue)")
                        }
                    ),
                    isDateField: false,
                    isLocationField: false,
                    suggestions: [],
                    isBold: true
                )
                if isSubtitleVisible {
                    EditableField(
                        placeholder: "Subtitle",
                        text: Binding(
                            get: { document.subtitle },
                            set: { newValue in
                                document.subtitle = newValue
                                document.save()
                                print("✏️ Subtitle updated to: \(newValue)")
                            }
                        ),
                        isDateField: false,
                        isLocationField: false,
                        suggestions: []
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                // Custom presentation button
                Button(action: {
                    showPresentationManager = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Document Calendar")
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondary)
                            
                            Text(getPresentationText())
                                .font(.system(size: 13))
                                .foregroundColor(theme.primary)
                        }
                        
                        Spacer()
                        
                        // Image(systemName: "calendar") // <-- Remove this and its modifiers
                        //     .font(.system(size: 12))
                        //     .foregroundColor(theme.secondary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? 
                                (isPresentationButtonHovered ? Color(.sRGB, white: 0.25) : Color(.sRGB, white: 0.2)) : 
                                (isPresentationButtonHovered ? Color(.sRGB, white: 0.92) : Color(.sRGB, white: 0.95)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isPresentationButtonHovered ? theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                    .scaleEffect(isPresentationButtonHovered ? 1.01 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPresentationButtonHovered)
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isPresentationButtonHovered = isHovered
                }
                .sheet(isPresented: $showPresentationManager) {
                    PresentationManager(document: document, isPresented: $showPresentationManager)
                }
                
                EditableField(
                    placeholder: "Location",
                    text: Binding(
                        get: { location },
                        set: { newValue in
                            location = newValue
                            // Update document's location
                            if var firstVariation = document.variations.first {
                                // Set location to nil if empty string
                                firstVariation.location = newValue.isEmpty ? nil : newValue
                                document.variations[0] = firstVariation
                                document.save()
                            } else {
                                // Create first variation if it doesn't exist
                                let variation = DocumentVariation(
                                    id: UUID(),
                                    name: "Original",
                                    documentId: document.id,
                                    parentDocumentId: document.id,
                                    createdAt: Date(),
                                    datePresented: nil,
                                    location: newValue
                                )
                                document.variations = [variation]
                                document.save()
                            }
                        }
                    ),
                    isDateField: false,
                    isLocationField: true,
                    suggestions: [],
                    onSelect: { selectedLocation in
                        location = selectedLocation
                        // Update document's location
                        if var firstVariation = document.variations.first {
                            // Set location to nil if empty string
                            firstVariation.location = selectedLocation.isEmpty ? nil : selectedLocation
                            document.variations[0] = firstVariation
                            document.save()
                        } else {
                            // Create first variation if it doesn't exist
                            let variation = DocumentVariation(
                                id: UUID(),
                                name: "Original",
                                documentId: document.id,
                                parentDocumentId: document.id,
                                createdAt: Date(),
                                datePresented: nil,
                                // Set location to nil if empty string
                                location: selectedLocation.isEmpty ? nil : selectedLocation
                            )
                            document.variations = [variation]
                            document.save()
                        }
                    }
                )
                
                Divider()
                    .padding(.vertical, 16)
                
                // Document Options
                VStack(spacing: 12) {
                    Text("Sections")
                        .font(.custom("Inter-Bold", size: 13))
                        .foregroundColor(theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isHeaderExpanded.toggle()
                                document.isHeaderExpanded = isHeaderExpanded
                                applyConsistentTextEditorStyling()
                                document.save()
                            }
                        }) {
                            Text("Header Image")
                                .font(.custom("Inter", size: 13))
                                .foregroundColor(theme.primary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isHeaderExpanded },
                            set: { newValue in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isHeaderExpanded = newValue
                                    document.isHeaderExpanded = newValue
                                    applyConsistentTextEditorStyling()
                                    document.save()
                                }
                            }
                        ))
                            .toggleStyle(GreenToggleStyle())
                            .scaleEffect(0.8)
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Button(action: {
                            isSubtitleVisible.toggle()
                            document.save()  // Save when subtitle visibility changes
                        }) {
                            Text("Subtitle")
                                .font(.custom("Inter", size: 13))
                                .foregroundColor(theme.primary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isSubtitleVisible },
                            set: { newValue in
                                isSubtitleVisible = newValue
                                document.save()  // Save when subtitle visibility changes
                            }
                        ))
                            .toggleStyle(GreenToggleStyle())
                            .scaleEffect(0.8)
                            .frame(width: 40)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSubtitleVisible)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Middle content area
            VStack(alignment: .leading, spacing: 0) {
                if sidebarMode == .details {
                    // Navigation buttons with Liquid Glass
                    GlassEffectContainer {
                        VStack(spacing: 16) {
                            navigationButton(title: "Series", icon: "square.stack.3d.up", mode: .series, index: 0)
                            navigationButton(title: "Tags", icon: "tag", mode: .tags, index: 1)
                            navigationButton(title: "Variations", icon: "square.on.square", mode: .variations, index: 2)
                            navigationButton(title: "Bookmarks", icon: "bookmark", mode: .bookmarks, index: 3)
                            navigationButton(title: "Links", icon: "link", mode: .links, index: 4)
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: isDragging ? 20 : 16)
                        )
                        .scaleEffect(isDragging ? 1.02 : 1.0)
                        .offset(
                            x: isDragging ? (dragLocation.x - 120) * 0.02 : 0,
                            y: isDragging ? (dragLocation.y - 100) * 0.02 : 0
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragLocation)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                                .onChanged { value in
                                    dragLocation = value.location
                                    isDragging = true
                                    
                                    // Calculate which button is being hovered
                                    let buttonHeight: CGFloat = 60 // Approximate button height with spacing
                                    let startY: CGFloat = 20 // top padding
                                    let adjustedY = value.location.y - startY
                                    
                                    let newButtonIndex = Int(adjustedY / buttonHeight)
                                    let validIndex = newButtonIndex >= 0 && newButtonIndex < 5 ? newButtonIndex : nil
                                    
                                    // Only update if index actually changed
                                    if validIndex != hoveredButtonIndex {
                                        hoveredButtonIndex = validIndex
                                        if validIndex != nil {
                                            HapticFeedback.selection()
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        isDragging = false
                                        hoveredButtonIndex = nil
                                        dragLocation = .zero
                                    }
                                }
                        )
                    }
                    .padding(.vertical, 24)
                } else if sidebarMode == .series {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Series", isExpanded: true, icon: "square.stack.3d.up")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    seriesContent
                } else if sidebarMode == .tags {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Tags", isExpanded: true, icon: "tag")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    tagsContent
                } else if sidebarMode == .variations {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Variations", isExpanded: true, icon: "square.on.square")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    variationsContent
                } else if sidebarMode == .bookmarks {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Bookmarks", isExpanded: true, icon: "bookmark")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    bookmarksContent
                } else if sidebarMode == .links {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Links", isExpanded: true, icon: "link")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    linksContent
                } else if sidebarMode == .search {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Search", isExpanded: true, icon: "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    searchContent
                } else if sidebarMode == .allDocuments {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "All Documents", isExpanded: true, icon: "folder")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    allDocumentsContent
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sidebarMode)
            
            Spacer()
        }
    }
    
    // Extract content views for cleaner organization
    var seriesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
                // Only show search and suggestions when no series is selected
                if selectedSeries == nil {
                // Search field with suggestions
                VStack(alignment: .leading, spacing: 0) {
                    Text("Add a series")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    
                    // Keep everything in a fixed position with proper alignment
                    ZStack(alignment: .topLeading) {
                        // Very small spacer that doesn't affect layout
                        Color.clear.frame(height: 0).allowsHitTesting(false)
                        // Text field
                        TextField("Search or create new series", text: $seriesSearchText)
                            .font(.system(size: 13))
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                            .cornerRadius(6)
                            .frame(height: 35) // Fixed height to prevent shifting
                            .padding(.horizontal, 16)
                            .focused($isSearchFocused)
                            .onChange(of: seriesSearchText) { oldValue, newValue in
                                if !seriesSearchText.isEmpty {
                                    isSearchFocused = true
                                }
                            }
                            .onSubmit {
                                if !seriesSearchText.isEmpty {
                                    let formattedSeries = formatSeries(seriesSearchText)
                                    attachToSeries(named: formattedSeries)
                                    seriesSearchText = ""
                                    isSearchFocused = false
                                }
                            }
                            .zIndex(1)
                        
                        // Use a proper popover for the dropdown menu
                        Text("")
                            .frame(width: 0, height: 0)
                            .padding(0)
                            .position(x: 150, y: 35) // Position at the bottom of the search field
                            .popover(isPresented: Binding<Bool>(
                                get: { isSearchFocused && !seriesSearchText.isEmpty },
                                set: { 
                                    if !$0 { 
                                        isSearchFocused = false
                                        seriesSearchText = ""  // Clear search text when dismissed without selection
                                    } 
                                }
                            ), arrowEdge: .bottom) {
                                VStack(spacing: 0) {
                                    SeriesDropdownView(
                                        matchingSeries: matchingSeries,
                                        shouldShowCreateNew: shouldShowCreateNew,
                                        seriesSearchText: seriesSearchText,
                                        formatSeries: formatSeries,
                                        hoveredSeriesItem: $hoveredSeriesItem,
                                        onSelect: { seriesName in
                                            attachToSeries(named: seriesName)
                                            seriesSearchText = ""
                                            isSearchFocused = false
                                        }
                                    )
                                }
                                .padding(8)
                                .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                                .cornerRadius(8)
                            }
                            .presentationCompactAdaptation(.popover)
                    }
                    // Remove dynamic height/padding that was moving the text field
                    
                    // Quick access recent series when no search
                    if seriesSearchText.isEmpty && !recentSeries.isEmpty {
                        VStack(spacing: 0) {
                            RecentSeriesList(
                                recentSeries: recentSeries,
                                hoveredSeriesItem: $hoveredSeriesItem,
                                onSelect: { series in
                                    attachToSeries(named: series)
                                    seriesSearchText = ""
                                    isSearchFocused = false
                                }
                            )
                            
                            // Small spacer for visual separation
                            Spacer().frame(height: 12)
                        }
                    }
                    
                                                                // Overlay to capture clicks outside dropdown
                    if isSearchFocused && !seriesSearchText.isEmpty {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isSearchFocused = false
                            }
                            .ignoresSafeArea()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .zIndex(1)
                    }
                    
                    // Add a small spacer to ensure input and Recent Series are close together
            Spacer().frame(height: 4)
                }
            }
            
            // Show current series if selected
            if let seriesName = selectedSeries {
                SelectedSeriesView(
                    seriesName: seriesName,
                    items: filteredSeriesItems,
                    isDateSortAscending: $isDateSortAscending,
                    onRemoveSeries: {
                        self.selectedSeries = nil
                        document.series = nil
                        document.save()
                        loadAllSeries()
                    },
                    onOpenItem: { openDocument(item: $0) }
                )
            }
        }
    }
    
    private func openDocument(item: (title: String, date: String, isActive: Bool)) {
        // Don't try to open if this is the active document
        if item.isActive {
            return
        }
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            // Find and open the matching document
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if doc.title == item.title {
                        print("Found matching document, opening: \(url.lastPathComponent)")
                        
                        // Update document directly
                        document = doc
                        sidebarMode = .details
                        return
                    }
                } catch {
                    print("Error reading document at \(url): \(error)")
                }
            }
            
            print("Could not find document with title: \(item.title) in series: \(selectedSeries ?? "unknown")")
            
        } catch {
            print("Error accessing documents directory: \(error)")
        }
    }
    
    // Add this new function to handle series attachment
    private func attachToSeries(named seriesName: String) {
        print("📂 Attaching document to series: \(seriesName)")
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📂 Found \(fileURLs.count) canvas files")
            
            // First find if this series already exists
            var existingSeriesId: UUID? = nil
            var existingDocumentIds = Set<String>()
            
            // First pass: collect all existing series information
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if let series = doc.series, series.name.lowercased() == seriesName.lowercased() {
                        existingSeriesId = series.id
                        existingDocumentIds.insert(doc.id)
                        existingDocumentIds.formUnion(Set(series.documents))
                    }
                } catch {
                    print("❌ Error reading document at \(url): \(error)")
                }
            }
            
            // Create or update the series object
            let seriesId = existingSeriesId ?? UUID()
            existingDocumentIds.insert(document.id)
            
            let newSeries = DocumentSeries(
                id: seriesId,
                name: seriesName,
                documents: Array(existingDocumentIds),
                order: 0
            )
            
            // Update current document first
            document.series = newSeries
            document.save()
            print("✅ Updated current document with series: \(seriesName)")
            
            // Second pass: update all other documents that should have this series
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    var doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Skip if this is the current document (already saved)
                    if doc.id == document.id {
                        continue
                    }
                    
                    // Update document if it's in the series or has matching series name
                    if existingDocumentIds.contains(doc.id) || 
                       (doc.series?.name.lowercased() == seriesName.lowercased()) {
                        doc.series = newSeries
                        let updatedData = try JSONEncoder().encode(doc)
                        try updatedData.write(to: url)
                        print("✅ Updated document \(doc.title) with series: \(seriesName)")
                    }
                } catch {
                    print("❌ Error updating document at \(url): \(error)")
                }
            }
            
            // Update UI state
            selectedSeries = seriesName
            seriesSearchText = ""
            
            // Reload series to refresh UI
            loadAllSeries()
            
            // Post notification that document list updated
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
            print("📣 Posted DocumentListDidUpdate notification")
            
        } catch {
            print("❌ Error accessing documents directory: \(error)")
        }
    }
    
    private func loadAllSeries() {
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            var seriesMap: [String: (id: UUID, documents: Set<String>)] = [:]
            
            // First pass: collect all series information
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if let series = doc.series {
                        let normalizedName = series.name.lowercased()
                        if let existing = seriesMap[normalizedName] {
                            var updatedDocs = existing.documents
                            updatedDocs.insert(doc.id)
                            updatedDocs.formUnion(Set(series.documents))
                            seriesMap[normalizedName] = (id: existing.id, documents: updatedDocs)
                        } else {
                            var docs = Set<String>()
                            docs.insert(doc.id)
                            docs.formUnion(Set(series.documents))
                            seriesMap[normalizedName] = (id: series.id, documents: docs)
                        }
                    }
                } catch {
                    print("Error reading document at \(url): \(error)")
                }
            }
            
            // Update UI state
            allSeries = seriesMap.map { (normalizedName, seriesInfo) in
                let originalName = fileURLs.compactMap { url -> String? in
                    guard let data = try? Data(contentsOf: url),
                          let doc = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data),
                          let series = doc.series,
                          series.name.lowercased() == normalizedName
                    else { return nil }
                    return series.name
                }.first ?? normalizedName
                
                return DocumentSeries(
                    id: seriesInfo.id,
                    name: originalName,
                    documents: Array(seriesInfo.documents),
                    order: 0
                )
            }
            
            // Update selected series based on current document
            if let currentSeries = document.series {
                selectedSeries = currentSeries.name
            } else {
                selectedSeries = nil
            }
            
        } catch {
            print("Error accessing documents directory: \(error)")
        }
    }
    
    var tagsContent: some View {
        VStack(spacing: 8) {
            // Search field with suggestions
            VStack(alignment: .leading, spacing: 0) {
                TextField("Add Tag", text: $tagSearchText)
                    .font(.custom("Inter", size: 13))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .padding(.horizontal, 16)
                    .focused($isTagSearchFocused)
                    .onChange(of: tagSearchText) { oldValue, newValue in
                        // Keep suggestions visible while typing
                        if !tagSearchText.isEmpty {
                            isTagSearchFocused = true
                            loadDocuments()
                        }
                    }
                    .onSubmit {
                        if !tagSearchText.isEmpty {
                            var updatedTags = document.tags ?? []
                            let formattedTag = formatTag(tagSearchText)
                            if !updatedTags.contains(where: { $0.localizedCaseInsensitiveCompare(formattedTag) == .orderedSame }) {
                                updatedTags.append(formattedTag)
                                document.tags = updatedTags
                                document.save()
                            }
                            tagSearchText = ""
                        }
                    }
                
                // Tag suggestions popover
                if isTagSearchFocused && !tagSearchText.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        // Show matching tags
                        ForEach(matchingTags.prefix(5), id: \.self) { tag in
                            Button(action: {
                                var updatedTags = document.tags ?? []
                                if !updatedTags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
                                    updatedTags.append(tag)
                                    document.tags = updatedTags
                                    document.save()
                                }
                                tagSearchText = ""
                                isTagSearchFocused = false
                            }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .stroke(tagColor(for: tag), lineWidth: 1.5)
                                        .background(
                                            Circle()
                                                .fill(Color(colorScheme == .dark ? .black : .white).opacity(0.1))
                                        )
                                        .frame(width: 6, height: 6)
                                    Text(tag)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(theme.primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if tag != matchingTags.last {
                                Divider()
                            }
                        }
                        
                        // Show create option if no exact match exists
                        if shouldShowCreateNewTag {
                            if !matchingTags.isEmpty {
                                Divider()
                            }
                            Button(action: {
                                var updatedTags = document.tags ?? []
                                let formattedTag = formatTag(tagSearchText)
                                if !updatedTags.contains(where: { $0.localizedCaseInsensitiveCompare(formattedTag) == .orderedSame }) {
                                    updatedTags.append(formattedTag)
                                    document.tags = updatedTags
                                    document.save()
                                }
                                tagSearchText = ""
                                isTagSearchFocused = false
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#22c27d"))
                                    Text("Create \"\(formatTag(tagSearchText))\"")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color(hex: "#22c27d"))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(backgroundColorForTagsSection)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                }
            }
            
            // Show existing tags
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(document.tags ?? [], id: \.self) { tag in
                        HStack {
                            Circle()
                                .stroke(tagColor(for: tag), lineWidth: 1.5)
                                .background(
                                    Circle()
                                        .fill(Color(colorScheme == .dark ? .black : .white).opacity(0.1))
                                )
                                .frame(width: 6, height: 6)
                            Text(tag)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.primary)
                            Spacer()
                            Button(action: {
                                var updatedTags = document.tags ?? []
                                updatedTags.removeAll { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }
                                document.tags = updatedTags
                                document.save()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(.bottom, 16)
    }
    
    var variationsContent: some View {
        VStack(spacing: 8) {
            // Show Original section first
            if document.isVariation, let parentId = document.parentVariationId, let originalDoc = loadDocument(id: parentId) {
                Text("Original")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                VariationItem(
                    title: originalDoc.title.isEmpty ? "Untitled" : originalDoc.title,
                    date: formatDate(originalDoc.modifiedAt),
                    isOriginal: true,
                    action: { 
                        document = originalDoc
                        // Post notification that document has loaded
                        NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                    },
                    onDelete: { deleteVariation(originalDoc) }
                )
                
                if !currentVariations.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            } else if !document.isVariation {
                // If this is the original document, show it at the top
                Text("Original")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                VariationItem(
                    title: document.title.isEmpty ? "Untitled" : document.title,
                    date: formatDate(document.modifiedAt),
                    isOriginal: true,
                    action: {
                        // Already viewing this document, no action needed
                    },
                    onDelete: { /* Cannot delete the original */ }
                )
                
                if !currentVariations.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
            
            // Show variations section if there are any
            if !currentVariations.isEmpty {
                HStack {
                    Text("Variations")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        showTranslationModal = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text("Translate")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#7662E9"))
                        .padding(.horizontal, 10) // Changed from 12 to 10
                        .padding(.vertical, 4)
                        .background(Color(hex: "#7662E9").opacity(0.1))
                        .cornerRadius(4)
                        .frame(minWidth: 90) // Keep the minimum width
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    
                    Button(action: {
                        createNewVariation()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                            Text("New")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#22c27d"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#22c27d").opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                
                ForEach(currentVariations, id: \.id) { variation in
                    // Skip the current document if it's the original to avoid duplication
                    if variation.id != document.id {
                        VariationItem(
                            title: variation.title.isEmpty ? "Untitled" : variation.title,
                            date: formatDate(variation.modifiedAt),
                            isOriginal: false,
                            action: { 
                                document = variation
                                // Post notification that document has loaded
                                NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                            },
                            onDelete: { deleteVariation(variation) }
                        )
                    }
                }
            } else {
                // Show the New button even if there are no variations yet
                HStack {
                    Text("Variations")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        showTranslationModal = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text("Translate")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#7662E9"))
                        .padding(.horizontal, 10) // Changed from 12 to 10
                        .padding(.vertical, 4)
                        .background(Color(hex: "#7662E9").opacity(0.1))
                        .cornerRadius(4)
                        .frame(minWidth: 90) // Keep the minimum width
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    
                    Button(action: {
                        createNewVariation()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                            Text("New")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#22c27d"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#22c27d").opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                
                Text("No variations")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
        }
        .onAppear {
            refreshVariations()
        }
        .onChange(of: document.id) { _, _ in
            refreshVariations()
        }
        .sheet(isPresented: $showTranslationModal) {
            TranslationPreviewView(document: $document, isPresented: $showTranslationModal)
        }
    }
    
    private func refreshVariations() {
        // Only reload if we haven't loaded for this document yet
        if loadedForDocumentId != document.id {
            // Use DispatchQueue.main.async to defer state updates until after the current view update cycle
            DispatchQueue.main.async {
                self.currentVariations = self.loadVariations()
                self.loadedForDocumentId = self.document.id
            }
        }
    }
    
    private func deleteVariation(_ variationDoc: Letterspace_CanvasDocument) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        let trashDirectory = appDirectory.appendingPathComponent(".trash", isDirectory: true)
        let sourceURL = appDirectory.appendingPathComponent("\(variationDoc.id).canvas")
        let destinationURL = trashDirectory.appendingPathComponent("\(variationDoc.id).canvas")
        
        do {
            // Create trash directory if it doesn't exist
            try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // If destination file exists, remove it first
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Move the file to trash
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            
            // Set the modification date to track when it was moved to trash
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: destinationURL.path)
            
            // Remove from cache
            documentCache.removeValue(forKey: variationDoc.id)
            
            // If we're deleting the current document, switch to the parent
            if variationDoc.id == document.id, let parentId = document.parentVariationId,
               let parentDoc = loadDocument(id: parentId) {
                // Schedule state update for the next run loop to avoid modifying state during view update
                DispatchQueue.main.async {
                    self.document = parentDoc
                    // Post notification that document has loaded
                    NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                }
            }
            
            // Directly update the currentVariations array by removing the deleted variation
            withAnimation {
                // Filter out the deleted variation from the current list
                currentVariations.removeAll { $0.id == variationDoc.id }
                
                // Also remove it from the parent document's variations list if it's a variation
                if let parentId = variationDoc.parentVariationId, 
                   var parentDoc = documentCache[parentId] ?? loadDocument(id: parentId) {
                    parentDoc.variations.removeAll { $0.documentId == variationDoc.id }
                    parentDoc.save()
                    
                    // Update the parent in cache
                    if documentCache[parentId] != nil {
                        documentCache[parentId] = parentDoc
                    }
                    
                    // If we're viewing the parent, update our document reference
                    if document.id == parentId {
                        // Schedule state update for the next run loop to avoid modifying state during view update
                        DispatchQueue.main.async {
                            self.document = parentDoc
                        }
                    }
                }
            }
            
            // Notify that documents have been updated
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        } catch {
            print("Error moving variation to trash: \(error)")
        }
    }
    
    // Format helper for dates
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    // Helper to get presentation text for the button
    private func getPresentationText() -> String {
        let now = Date()
        
        // Priority 1: Find the soonest upcoming scheduled presentation
        let upcomingSchedule = document.presentations
            .filter { $0.status == .scheduled && $0.datetime >= now }
            .sorted { $0.datetime < $1.datetime }
            .first
        
        if let nextSchedule = upcomingSchedule {
            return "Upcoming Date: \(formatDate(nextSchedule.datetime))"
        }
        
        // Priority 2: Find the most recent past presentation
        let lastPresented = document.presentations
            .filter { $0.status == .presented && $0.datetime < now }
            .sorted { $0.datetime > $1.datetime } // Note: Sort descending for most recent
            .first
            
        if let last = lastPresented {
            return "Most Recent: \(formatDate(last.datetime))"
        }
        
        // Fallback: Check the legacy datePresented field (if still relevant)
        // Consider removing if `presentations` array is the sole source of truth
        if let legacyDate = document.variations.first?.datePresented {
            if legacyDate < now { // Only show if it's actually in the past
                 return "Most Recent: \(formatDate(legacyDate))"
            } else {
                 // If legacyDate is future, it should be in presentations array
                 // Treat as unscheduled if somehow only legacy date exists and is future
            }
        }
        
        // Default text if neither scheduled nor presented found
        return "Schedule or Log Presentation"
    }
    
    private func loadDocument(id: String) -> Letterspace_CanvasDocument? {
        // Check cache first
        if let cachedDoc = documentCache[id] {
            return cachedDoc
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        let fileURL = appDirectory.appendingPathComponent("\(id).canvas")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedDoc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
            
            // Cache the document - defer to main thread to avoid state updates during view cycles
            DispatchQueue.main.async {
                self.documentCache[id] = loadedDoc
            }
            
            return loadedDoc
        } catch {
            print("Error loading document \(id): \(error)")
            return nil
        }
    }
    
    private func loadVariations() -> [Letterspace_CanvasDocument] {
        // If the document has variations metadata, use that instead of scanning the directory
        if !document.variations.isEmpty {
            return document.variations.compactMap { variation -> Letterspace_CanvasDocument? in
                // Skip if this is the current document to avoid duplication
                if variation.documentId == document.id {
                    return nil
                }
                return loadDocument(id: variation.documentId)
            }
        }
        
        // Fall back to directory scanning if needed
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            return fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                // Extract document ID from filename
                let filename = url.deletingPathExtension().lastPathComponent
                
                // Skip if this is the current document to avoid duplication
                if filename == document.id {
                    return nil
                }
                
                // Check cache first
                if let cachedDoc = documentCache[filename], cachedDoc.parentVariationId == document.id {
                    return cachedDoc
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Cache the document
                    documentCache[doc.id] = doc
                    
                    // Only return documents that are variations of the current document
                    if doc.parentVariationId == document.id {
                        return doc
                    }
                    return nil
                } catch {
                    print("Error loading document at \(url): \(error)")
                    return nil
                }
            }
        } catch {
            print("Error accessing documents directory: \(error)")
            return []
        }
    }
    
    var bookmarksContent: some View {
        // Log marker counts every time this view is computed
        let _ = print("📚 RightSidebar.bookmarksContent: Total markers = \(document.markers.count)")
        let bookmarkedMarkers = document.markers.filter { $0.type == "bookmark" }
        let _ = print("📚 RightSidebar.bookmarksContent: Filtered bookmarks = \(bookmarkedMarkers.count)")

        // --- DEBUGGING: Log details of filtered markers ---
        let _ = print("📚 RightSidebar.bookmarksContent: Filtered Marker Details: [")
        for marker in bookmarkedMarkers {
            let _ = print("  - ID: \(marker.id.uuidString), Title: \"\(marker.title)\", Type: \(marker.type), Pos: \(marker.position)")
        }
        let _ = print("]")
        // --- END DEBUGGING ---

        return VStack(alignment: .leading, spacing: 16) {
            // Filter markers to only include bookmarks
            // let bookmarkedMarkers = document.markers.filter { $0.type == "bookmark" } // Filtered above for logging

            if bookmarkedMarkers.isEmpty {
                Text("No bookmarks added yet")
                    .font(.custom("Inter-Regular", size: 13))
                    .foregroundColor(theme.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                // Add bookmark timeline visualization
                // BookmarkTimelineView(bookmarks: bookmarkedMarkers) { position in
                //     scrollToBookmark(position: position)
                // }
                // .padding(.horizontal, 16)
                // .padding(.bottom, 8)
                
                // // Removed divider between timeline and list
                // Divider()
                //     .padding(.horizontal, 16)
                //     .padding(.bottom, 8)
                
                // Iterate over the filtered bookmarks using indices
                // Restore Original ForEach logic
                ForEach(Array(bookmarkedMarkers.enumerated()), id: \.element.id) { index, bookmark in
                    let bookmark = bookmarkedMarkers[index]
                    if let originalIndex = document.markers.firstIndex(where: { $0.id == bookmark.id }) {
                        HStack(spacing: 12) {
                            // Navigate to bookmark button - larger and more obvious
                            Button(action: {
                                scrollToBookmark(position: bookmark.position)
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(Color(hex: "#007AFF"))
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Go to bookmark")
                            
                            // Make this section clickable for editing  
                            VStack(alignment: .leading, spacing: 2) {
                                TextField("Bookmark Title", text: Binding(
                                    get: { 
                                        // Safe access to bookmark title
                                        guard document.markers.indices.contains(originalIndex) else { return "" } 
                                        return document.markers[originalIndex].title 
                                    },
                                    set: { newValue in
                                        // Update the original marker in the document
                                        // Check index validity before accessing
                                        if document.markers.indices.contains(originalIndex) {
                                            document.markers[originalIndex].title = newValue
                                            document.save()
                                        }
                                    }
                                ))
                                .font(.custom("Inter-Regular", size: 13))
                                .foregroundColor(theme.primary)
                                .textFieldStyle(.plain)
                                
                                // Show bookmark line number
                                Text("Line \(bookmark.position)") // Changed to show Line number
                                    .font(.custom("Inter-Regular", size: 10))
                                    .foregroundColor(theme.secondary)
                            }
                            
                            Spacer()
                            
                            // Button to remove the bookmark using the original index
                            Button(action: {
                                // Check index validity before removing
                                if document.markers.indices.contains(originalIndex) {
                                    document.markers.remove(at: originalIndex)
                                    document.save()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    private func markerColor(for type: String) -> Color {
        switch type {
        case "highlight": return Color(hex: "#22c27d")
        case "comment": return Color(hex: "#FF6B6B")
        case "bookmark": return Color(hex: "#4ECDC4")
        default: return Color(hex: "#96CEB4")
        }
    }
    
    var linksContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Link inputs
            VStack(alignment: .leading, spacing: 8) {
                TextField("Link Title", text: $newLinkTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .onSubmit {
                        // If URL is empty, move focus to URL field
                        if !newLinkTitle.isEmpty && newLinkURL.isEmpty {
                            // Focus will move to the URL field automatically
                        } 
                        // If both fields are filled, add the link
                        else if !newLinkTitle.isEmpty && !newLinkURL.isEmpty {
                            addLink()
                        }
                    }
                
                TextField("Link URL", text: $newLinkURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .onSubmit {
                        // Call the same addLink function when Enter is pressed
                        if !newLinkTitle.isEmpty && !newLinkURL.isEmpty {
                            addLink()
                        }
                    }
                
                Button(action: addLink) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Link")
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(newLinkTitle.isEmpty || newLinkURL.isEmpty)
                .opacity(newLinkTitle.isEmpty || newLinkURL.isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Links list
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    if document.links.isEmpty {
                        Text("No links attached yet")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(document.links) { link in
                            LinkItemView(link: link) {
                                removeLink(link)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func addLink() {
        guard !newLinkTitle.isEmpty, !newLinkURL.isEmpty else { return }
        
        var updatedDoc = document
        let newLink = DocumentLink(
            id: UUID().uuidString,
            title: newLinkTitle,
            url: newLinkURL,
            createdAt: Date()
        )
        updatedDoc.links.append(newLink)
        document = updatedDoc
        document.save()
        
        // Clear input fields
        newLinkTitle = ""
        newLinkURL = ""
    }
    
    private func removeLink(_ link: DocumentLink) {
        var updatedDoc = document
        updatedDoc.links.removeAll { $0.id == link.id }
        document = updatedDoc
        document.save()
    }
    
    var searchContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Search documents...", text: .constant(""))
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 13))
                .padding(8)
                .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                .cornerRadius(6)
            
            // Search results would go here
            Text("No results found")
                .font(.system(size: 13))
                .foregroundColor(theme.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        }
    }
    
    var allDocumentsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Document list would go here
            Text("No documents found")
                .font(.system(size: 13))
                .foregroundColor(theme.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 48)
            
            // Wrap mainContent in a ScrollView with animation
            ScrollView {
                mainContent
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: sidebarMode)
        }
        // --- Add Notification Listener ---
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentListDidUpdate"))) { _ in
            print("📬 RightSidebar received DocumentListDidUpdate notification. Triggering refresh.")
            refreshTrigger = UUID() // Change state to force view update
        }
        // --- End Notification Listener ---
        .frame(width: 260, alignment: .leading)
        .offset(x: viewMode == .minimal ? 260 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewMode)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, -20)
                .padding(.vertical, -20)
                .onTapGesture {
                    #if os(macOS)
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    #elseif os(iOS)
                    // On iOS, dismiss the keyboard by ending editing
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
        )
        .onAppear {
            // Initialize selectedSeries only if document has one
            if let documentSeries = document.series {
                selectedSeries = documentSeries.name
            } else {
                selectedSeries = nil  // Explicitly clear selected series if document has none
            }
            
            // Load all series from documents
            loadAllSeries()
            
            // Reset fields
            resetFields()
            
            loadDocuments()
        }
        .onChange(of: document.id) { oldValue, newValue in
            // Reset fields when document changes
            resetFields()
            
            // Update selected series based on new document
            if let documentSeries = document.series {
                selectedSeries = documentSeries.name
            } else {
                selectedSeries = nil  // Explicitly clear selected series if document has none
            }
            
            // Reload series when document changes
            loadAllSeries()
        }
    }
    
    private func resetFields() {
        // Initialize other fields if needed
        if let firstVariation = document.variations.first {
            if let datePresented = firstVariation.datePresented {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy h:mm a"
                self.datePresented = formatter.string(from: datePresented)
            } else {
                self.datePresented = ""
            }
            self.location = firstVariation.location ?? ""
        } else {
            self.datePresented = ""
            self.location = ""
        }
        
        // Initialize tags
        if let documentTags = document.tags {
            self.tags = Set(documentTags)
        } else {
            self.tags = []
        }
    }
    
    private func loadDocuments() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            documents = fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                do {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                } catch {
                    print("Error loading document at \(url): \(error)")
                    return nil
                }
            }
        } catch {
            print("Error accessing documents directory: \(error)")
        }
    }

    private func cleanupUnusedTags() {
        // Get all currently used tags
        var activeTags = Set<String>()
        for document in documents {
            if let documentTags = document.tags {
                activeTags.formUnion(documentTags)
            }
        }
        
        // Remove color preferences for unused tags
        let unusedTags = Set(colorManager.colorPreferences.keys).subtracting(activeTags)
        for tag in unusedTags {
            colorManager.colorPreferences.removeValue(forKey: tag)
        }
    }
    
    // Helper function to generate a unique variation title with proper numbering
    private func generateVariationTitle(baseTitle: String) -> String {
        // Get all existing variations
        let existingVariations = loadVariations()
        
        // Extract all variation titles
        let existingTitles = existingVariations.map { $0.title }
        
        // Start with (2) and increment if needed
        var counter = 2
        var newTitle = "\(baseTitle) (\(counter))"
        
        // Keep incrementing until we find an unused number
        while existingTitles.contains(newTitle) {
            counter += 1
            newTitle = "\(baseTitle) (\(counter))"
        }
        
        return newTitle
    }
    
    // Helper function to find the next available variation number
    private func getNextVariationNumber(for baseTitle: String) -> Int {
        // Get all existing variations
        let variations = loadVariations()
        
        // Extract numbers from existing variation titles with the same base name
        var usedNumbers = Set<Int>()
        let pattern = "^(.*?)\\s*\\((\\d+)\\)$"
        
        for variation in variations {
            if let range = variation.title.range(of: pattern, options: .regularExpression) {
                let titleMatch = variation.title[range]
                if let numberRange = titleMatch.range(of: "\\((\\d+)\\)", options: .regularExpression) {
                    let numberString = titleMatch[numberRange]
                    if let number = Int(numberString.dropFirst().dropLast()) {
                        usedNumbers.insert(number)
                    }
                }
            }
        }
        
        // Find the next available number starting from 2
        var nextNumber = 2
        while usedNumbers.contains(nextNumber) {
            nextNumber += 1
        }
        
        return nextNumber
    }
    
    // Helper function to create a new variation with proper title
    private func createNewVariation() {
        // Get the next available variation number
        let nextNumber = getNextVariationNumber(for: document.title)
        let newTitle = "\(document.title) (\(nextNumber))"
        
        // Create a new variation record for the parent document
        let newVariation = DocumentVariation(
            id: UUID(),
            name: "Original",
            documentId: UUID().uuidString,  // Generate the ID first so we can use it in both places
            parentDocumentId: document.id,
            createdAt: Date(),
            datePresented: document.variations.first?.datePresented,
            location: document.variations.first?.location
        )
        
        // Create a new document as a variation, copying all properties from the original
        let newDoc = Letterspace_CanvasDocument(
            title: newTitle,
            subtitle: document.subtitle,
            elements: document.elements,  // Copy all elements including content
            id: newVariation.documentId,  // Use the same ID we generated above
            markers: document.markers,
            series: document.series,
            variations: [newVariation],
            isVariation: true,
            parentVariationId: document.id,
            tags: document.tags,
            isHeaderExpanded: document.isHeaderExpanded,
            isSubtitleVisible: document.isSubtitleVisible,
            links: document.links
        )
        
        // Save the new document
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // First, update the parent document's variations list
            var updatedParentDoc = document
            updatedParentDoc.variations.append(newVariation)
            
            // Save the updated parent document
            let parentData = try JSONEncoder().encode(updatedParentDoc)
            let parentFileURL = appDirectory.appendingPathComponent("\(updatedParentDoc.id).canvas")
            try parentData.write(to: parentFileURL)
            
            // Then save the new variation document
            let newDocData = try JSONEncoder().encode(newDoc)
            let newDocFileURL = appDirectory.appendingPathComponent("\(newDoc.id).canvas")
            try newDocData.write(to: newDocFileURL)
            
            // Switch to the new document
            document = newDoc
            
            // Post notification that document has loaded
            NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
        } catch {
            print("Error creating variation: \(error)")
        }
    }
    
    // Add a function to ensure consistent text editor styling
    private func applyConsistentTextEditorStyling() {
        #if os(macOS)
        // Allow layout to update first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Find all text views in the view hierarchy and ensure they have consistent styling
            if let hostingWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "documentWindow" }) {
                // Define the recursive function properly
                func findTextViews(in views: [NSView]) -> [NSTextView] {
                    var textViews: [NSTextView] = []
                    for view in views {
                        if let textView = view as? NSTextView {
                            textViews.append(textView)
                        }
                        textViews.append(contentsOf: findTextViews(in: view.subviews))
                    }
                    return textViews
                }
                
                // Process text views
                for textView in findTextViews(in: hostingWindow.contentView?.subviews ?? []) {
                    // Apply consistent settings
                    textView.textContainerInset = NSSize(width: 17, height: textView.textContainerInset.height)
                    
                    // Clear any custom formatting
                    let style = NSMutableParagraphStyle()
                    textView.defaultParagraphStyle = style
                    
                    // Apply consistent font
                    textView.font = NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
                    
                    // Apply simpler layout manager settings
                    if let layoutManager = textView.layoutManager {
                        layoutManager.showsInvisibleCharacters = false
                        layoutManager.showsControlCharacters = false
                    }
                    
                    // Update text container settings
                    if let container = textView.textContainer {
                        container.widthTracksTextView = true
                    }
                }
            }
        }
        #endif
        // On iOS, this function does nothing since it's AppKit-specific
    }
    
    // Function to scroll to a bookmark position
    private func scrollToBookmark(position: Int) {
        // We need to find the text view and scroll to the position
        // First, post a notification that other views can observe
        print("📚 Attempting to scroll to bookmark at line: \(position)")
        
        // Look for the bookmark in the document markers to get additional metadata
        if let bookmark = document.markers.first(where: { $0.position == position && $0.type == "bookmark" }) {
            // Create a notification with enhanced position info
            var userInfo: [String: Any] = ["lineNumber": position]
            
            // Add character position metadata if available
            if let metadata = bookmark.metadata {
                if let charPosition = metadata["charPosition"], 
                   let charLength = metadata["charLength"] {
                    userInfo["charPosition"] = Int(charPosition)
                    userInfo["charLength"] = Int(charLength)
                    print("📚 Found character position metadata: \(charPosition), length: \(charLength)")
                }
            }
            
            // Post notification with all available data
            NotificationCenter.default.post(
                name: NSNotification.Name("ScrollToBookmark"), 
                object: nil, 
                userInfo: userInfo
            )
        } else {
            // Fallback to just using line number if metadata isn't available
            let userInfo: [String: Any] = ["lineNumber": position]
            NotificationCenter.default.post(
                name: NSNotification.Name("ScrollToBookmark"), 
                object: nil, 
                userInfo: userInfo
            )
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(x: bounds.minX + result.positions[index].x,
                              y: bounds.minY + result.positions[index].y)
            subview.place(at: point, proposal: .init(result.sizes[index]))
        }
    }
    
    private struct FlowResult {
        var positions: [CGPoint]
        var sizes: [CGSize]
        var size: CGSize
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var sizes: [CGSize] = []
            
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            var rowMaxY: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && !positions.isEmpty {
                    x = 0
                    y = rowMaxY + spacing
                }
                
                positions.append(CGPoint(x: x, y: y))
                sizes.append(size)
                
                rowHeight = max(rowHeight, size.height)
                rowMaxY = y + rowHeight
                x += size.width + spacing
            }
            
            self.positions = positions
            self.sizes = sizes
            self.size = CGSize(width: maxWidth, height: rowMaxY)
        }
    }
}

// Add this struct before RightSidebar
struct GreenToggleStyle: ToggleStyle {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    private var inactiveColor: Color {
        #if os(macOS)
        return Color(NSColor.tertiaryLabelColor)
        #elseif os(iOS)
        return Color(UIColor.tertiaryLabel)
        #endif
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Rectangle()
                .foregroundColor(configuration.isOn ? Color(hex: "#22c27d") : inactiveColor)
                .frame(width: 40, height: 24)
                .overlay(
                    Circle()
                        .foregroundColor(.white)
                        .padding(2)
                        .offset(x: configuration.isOn ? 8 : -8)
                )
            .clipShape(Capsule())
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}

// Add this new button style definition near other helper types
struct SeriesItemButtonStyle: ButtonStyle {
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? 
                          Color.white.opacity(isHovering ? 0.1 : 0) : 
                          Color.black.opacity(isHovering ? 0.05 : 0))
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

// MARK: - RightSidebar Extension for Liquid Glass
extension RightSidebar {
    // MARK: - Liquid Glass Navigation Button
    @ViewBuilder
    private func navigationButton(title: String, icon: String, mode: SidebarMode, index: Int) -> some View {
        Button(action: { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                sidebarMode = mode
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(hoveredButtonIndex == index && isDragging ? theme.accent.opacity(0.3) : Color.clear)
            )
            .scaleEffect(hoveredButtonIndex == index && isDragging ? 1.05 : 1.0)
            .brightness(hoveredButtonIndex == index && isDragging ? 0.1 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: hoveredButtonIndex == index && isDragging)
        }
        .buttonStyle(.plain)
    }
}

