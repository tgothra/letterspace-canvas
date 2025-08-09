import SwiftUI

struct AllDocumentsBottomSheet: View {
    @Binding var documents: [Letterspace_CanvasDocument]
    @Binding var selectedDocuments: Set<String>
    @Binding var selectedTags: Set<String>
    @Binding var selectedFilterColumn: String?
    @Binding var selectedFilterCategory: String
    @Binding var sheetDetent: PresentationDetent
    
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
    let onClose: () -> Void
    
    // NEW: Sheet trigger callbacks
    let onShowPinnedSheet: () -> Void
    let onShowWIPSheet: () -> Void
    let onShowScheduleSheet: () -> Void
    let onShowMorphMenu: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    @State private var searchText: String = ""
    @State private var isSearchFocused: Bool = false
    @State private var isExpanded: Bool = false
    @State private var selectedTabMode: TabMode = .all
    @FocusState private var searchFieldFocused: Bool
    
    enum TabMode: String, CaseIterable {
        case all = "All Docs"
        case pinned = "Pinned"
        case wip = "Work in Progress"
        case schedule = "Schedule"
        
        var displayName: String {
            switch self {
            case .all: return "Docs"
            case .pinned: return "Pinned"
            case .wip: return "WIP"
            case .schedule: return "Calendar"
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "doc.on.doc"
            case .pinned: return "pin.fill"
            case .wip: return "clock.badge.checkmark"
            case .schedule: return "calendar"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .primary
            case .pinned: return .green
            case .wip: return .orange
            case .schedule: return .blue
            }
        }
    }
    
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
    
    // Filtered documents based on current filters and search
    private var filteredDocuments: [Letterspace_CanvasDocument] {
        var filtered = documents
        
        // Apply tab mode filter first
        switch selectedTabMode {
        case .all:
            break // Show all documents
        case .pinned:
            filtered = filtered.filter { pinnedDocuments.contains($0.id) }
        case .wip:
            filtered = filtered.filter { wipDocuments.contains($0.id) }
        case .schedule:
            filtered = filtered.filter { calendarDocuments.contains($0.id) }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { document in
                document.title.localizedCaseInsensitiveContains(searchText) ||
                document.subtitle.localizedCaseInsensitiveContains(searchText)
            }
        }
        
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
        VStack(spacing: 0) {
            // NEW: Grab bar at the very top
            grabBar
                .padding(.top, 8)
                .padding(.bottom, 8)
            
            ZStack {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 12) {
                        // Show filter section when expanded
                        if isExpanded {
                            filterSection
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                        }
                        
                        // Documents list
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, sheetDetent == .large ? 120 : 20) // More space when floating bar is visible
                }
            .safeAreaInset(edge: .top, spacing: 0) {
                // This is the "collapsed state" - always visible header bar
                headerBar
                    .frame(height: 80)
                    .padding(.top, 5)
            }
            

            

        }
        .animation(.interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0), value: searchFieldFocused)
        .animation(.interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0), value: isExpanded)
        .overlay(alignment: .bottomTrailing) {
            // Floating menu button - hide when in large detent (floating bar available)
            if sheetDetent != .large {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            onShowMorphMenu()
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(theme.primary, in: .circle)
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, -20)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Floating bottom bar - only show when in large detent
            if sheetDetent == .large {
                floatingBottomBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: searchFieldFocused) { oldValue, newValue in
            // Expand sheet when search is focused, or stay at medium when not focused
            sheetDetent = newValue ? .large : .height(350)
        }
        .onChange(of: sheetDetent) { oldValue, newValue in
            // Track if we're in expanded state
            isExpanded = newValue == .height(350) || newValue == .large
        }
        }
    }
    
    // MARK: - NEW: Grab Bar
    
    private var grabBar: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.secondary.opacity(0.5))
            .frame(width: 36, height: 5)
    }
    
    // MARK: - Header Bar (Always Visible)
    
    private var headerBar: some View {
        HStack(spacing: 16) {
            // Left side: Large bold header
            if !searchFieldFocused {
                Text(selectedTabMode.displayName)
                    .font(.custom("InterTight-Bold", size: 28))
                    .foregroundColor(.primary)
                    .onTapGesture {
                        if sheetDetent == .height(350) {
                            // Expand to large when tapped from medium
                            sheetDetent = .large
                        } else {
                            // Focus search when already at large
                            searchFieldFocused = true
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Search field when focused
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Search \(selectedTabMode.rawValue.lowercased())...", text: $searchText)
                        .focused($searchFieldFocused)
                        .transition(.opacity)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            {
                                #if os(iOS)
                                return Color(UIColor { trait in
                                    trait.userInterfaceStyle == .dark ? .systemGray5 : .systemGray6
                                })
                                #else
                                // macOS fallback tints
                                let dark = NSColor.windowBackgroundColor.blended(withFraction: 0.2, of: .black) ?? .windowBackgroundColor
                                let light = NSColor.separatorColor.withAlphaComponent(0.6)
                                return Color(colorScheme == .dark ? dark : light)
                                #endif
                            }()
                        )
                )
            }
            
            Spacer()
            
            // Right side: iOS 26 Grouped Tab Buttons
            if !searchFieldFocused {
                HStack(spacing: 4) {
                    // All Documents button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTabMode = .all
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTabMode == .all ? theme.primary : Color.clear)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selectedTabMode == .all ? .white : theme.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Visual separator
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 1, height: 20)
                    
                    // Pinned button with badge
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTabMode = .pinned
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTabMode == .pinned ? Color.green : Color.clear)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "pin.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selectedTabMode == .pinned ? .white : .green)
                            
                            // Badge overlay
                            if pinnedDocuments.count > 0 {
                                Text("\(pinnedDocuments.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 14, y: -14)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // WIP button with badge
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTabMode = .wip
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTabMode == .wip ? Color.orange : Color.clear)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selectedTabMode == .wip ? .white : .orange)
                            
                            // Badge overlay
                            if wipDocuments.count > 0 {
                                Text("\(wipDocuments.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 14, y: -14)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Schedule button with badge
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTabMode = .schedule
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTabMode == .schedule ? Color.blue : Color.clear)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "calendar")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selectedTabMode == .schedule ? .white : .blue)
                            
                            // Badge overlay
                            if calendarDocuments.count > 0 {
                                Text("\(calendarDocuments.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 14, y: -14)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background {
                    // iOS 26 Liquid Glass Group Background
                    RoundedRectangle(cornerRadius: 26)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.08),
                                            Color.clear,
                                            Color.black.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.02), radius: 1, x: 0, y: 1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                // Close search button when search is focused
                Button {
                    searchFieldFocused = false
                    searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: .circle)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
    
    // MARK: - Filter Section
    
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
                
                // Clear button
                if !selectedTags.isEmpty || selectedFilterColumn != nil {
                    Button("Clear") {
                        selectedTags.removeAll()
                        selectedFilterColumn = nil
                        selectedFilterCategory = "Filter"
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.primary, lineWidth: 1)
                    )
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
    
    // MARK: - iOS 26 Liquid Glass Toolbar (Appears When Expanded)
    
    private var floatingBottomBar: some View {
        HStack(spacing: 0) {
            // New document - prominent style
            Button(action: {
                // Add new document action
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("New")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            // Flexible space
            Spacer()
                .frame(width: 12)
            
            // Search button
            Button(action: {
                searchFieldFocused = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                    Text("Search")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.primary)
            }
            
            // Flexible space
            Spacer()
                .frame(width: 12)
            
            // Filter button
            Button(action: {
                selectedFilterCategory = selectedFilterCategory == "Filter" ? "Tags" : "Filter"
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                    Text("Filter")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.primary)
            }
            
            // Flexible space
            Spacer()
                .frame(width: 12)
            
            // Close button - close style
            Button(action: onClose) {
                VStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                    Text("Close")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background {
            // iOS 26 Liquid Glass Effect
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                    Color.black.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
}
