#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - Document Header View
struct DocumentHeaderView: View {
    // Data and state bindings
    let documents: [Letterspace_CanvasDocument]
    @Binding var selectedFilterColumn: String?
    @Binding var selectedTags: Set<String>
    @Binding var isDateFilterExplicitlySelected: Bool
    @Binding var selectedSortColumn: String
    @Binding var isAscendingSortOrder: Bool
    @Binding var tableRefreshID: UUID
    @Binding var activeSheet: DashboardView.ActiveSheet?
    @Binding var allDocumentsPosition: DashboardView.AllDocumentsPosition
    
    // Layout data
    let allTags: [String]
    let colorManager: TagColorManager
    
    // Callbacks
    let onSearch: () -> Void
    let onUpdateVisibleColumns: () -> Void
    let onUpdateDocumentSort: () -> Void
    
    // Environment
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #else
        let isPhone = false
        #endif
        
        return Group {
            if isPhone {
                // iPhone: Tall header with stacked rows
                iPhoneDocumentHeader
            } else {
                // iPad/macOS: Original horizontal layout, but now with matching horizontal padding
                iPadMacDocumentHeader
            }
        }
    }
    
    // iPhone-specific header with stacked rows
    private var iPhoneDocumentHeader: some View {
        VStack(spacing: 0) {
            // Grab bar for swipe gestures
            GrabBar()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Toggle between default and expanded on tap
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if allDocumentsPosition == .expanded {
                            allDocumentsPosition = .default
                        } else {
                            allDocumentsPosition = .expanded
                        }
                    }
                    // Add haptic feedback
                    HapticFeedback.impact(.light)
                }
            
            VStack(spacing: 10) { // Increased spacing for better breathing room
                // Title row - matching carousel header style
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12)) // Match carousel icon size
                        .foregroundStyle(theme.primary)
                    Text("All Docs (\(filteredDocuments.count))")
                        .font(.custom("InterTight-Medium", size: 14)) // Match carousel header font size
                        .foregroundStyle(theme.primary)
                    Spacer()
                    
                    // Search button
                    Button(action: onSearch) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accent.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16) // Match carousel padding
                .padding(.top, 8) // Reduced spacing
                
                // Filter and Sort Row - Simplified for iPhone
                VStack(spacing: 8) {
                    // Filter controls
                    HStack(spacing: 8) {
                        // Filter by dropdown (first)
                        Menu {
                            Button("All") {
                                selectedFilterColumn = nil
                                isDateFilterExplicitlySelected = false
                                tableRefreshID = UUID()
                            }
                            Divider()
                            Button("Series") {
                                selectedFilterColumn = "series"
                                isDateFilterExplicitlySelected = false
                                tableRefreshID = UUID()
                            }
                            Button("Location") {
                                selectedFilterColumn = "location"
                                isDateFilterExplicitlySelected = false
                                tableRefreshID = UUID()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(selectedFilterColumn != nil ? theme.accent : theme.secondary)
                                Text(selectedFilterColumn?.capitalized ?? "Filter")
                                    .font(.custom("InterTight-Medium", size: 11)) // Smaller font for iPhone
                                    .foregroundStyle(selectedFilterColumn != nil ? theme.accent : theme.secondary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundStyle(theme.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(selectedFilterColumn != nil ? theme.accent.opacity(0.1) : theme.secondary.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Tags button
                        Button(action: {
                            activeSheet = .tagManager
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                    .font(.system(size: 11))
                                    .foregroundStyle(!selectedTags.isEmpty ? theme.accent : theme.secondary)
                                Text(!selectedTags.isEmpty ? "\(selectedTags.count)" : "Tags")
                                    .font(.custom("InterTight-Medium", size: 11))
                                    .foregroundStyle(!selectedTags.isEmpty ? theme.accent : theme.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(!selectedTags.isEmpty ? theme.accent.opacity(0.1) : theme.secondary.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Sort controls
                    HStack(spacing: 8) {
                        Text("Sort by:")
                            .font(.custom("InterTight-Medium", size: 11))
                            .foregroundStyle(theme.secondary)
                        
                        Menu {
                            Button("Name") {
                                selectedSortColumn = "name"
                                onUpdateDocumentSort()
                            }
                            Button("Series") {
                                selectedSortColumn = "series"
                                onUpdateDocumentSort()
                            }
                            Button("Location") {
                                selectedSortColumn = "location"
                                onUpdateDocumentSort()
                            }
                            Button("Date Modified") {
                                selectedSortColumn = "date"
                                onUpdateDocumentSort()
                            }
                            Button("Date Created") {
                                selectedSortColumn = "createdDate"
                                onUpdateDocumentSort()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sortDisplayName)
                                    .font(.custom("InterTight-Medium", size: 11))
                                    .foregroundStyle(theme.accent)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundStyle(theme.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(theme.accent.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        // Sort direction toggle
                        Button(action: {
                            isAscendingSortOrder.toggle()
                            onUpdateDocumentSort()
                        }) {
                            Image(systemName: isAscendingSortOrder ? "arrow.up" : "arrow.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.accent)
                                .padding(6)
                                .background(theme.accent.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 16) // Match carousel padding
            }
            
            // Selected tags display
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.custom("InterTight-Medium", size: 10))
                                    .foregroundStyle(.white)
                                
                                Button(action: {
                                    selectedTags.remove(tag)
                                    tableRefreshID = UUID()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(colorManager.color(for: tag))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 4)
            }
            
            // Clear both filters button (only show if filters are active)
            if selectedFilterColumn != nil || !selectedTags.isEmpty {
                HStack {
                    Button("Clear All Filters") {
                        selectedFilterColumn = nil
                        selectedTags.removeAll()
                        isDateFilterExplicitlySelected = false
                        tableRefreshID = UUID()
                    }
                    .font(.custom("InterTight-Medium", size: 11))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.accent.opacity(0.1))
                    .cornerRadius(8)
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

        }
    }
    
    // iPad/macOS header (original layout)
    private var iPadMacDocumentHeader: some View {
        #if os(iOS)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        #else
        let isIPad = false
        #endif
        
        return VStack(spacing: 0) {
            // iPad-specific grab bar at the top of the header
            if isIPad {
                GeometryReader { geometry in
                    HStack {
                        Spacer()
                        
                        // Centered grab bar
                        GrabBar()
                            .frame(width: min(60, geometry.size.width * 0.15)) // Responsive width, max 60pt
                        
                        Spacer()
                    }
                    .contentShape(Rectangle()) // Make entire area tappable
                    .onTapGesture {
                        // Toggle between default and expanded on tap
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if allDocumentsPosition == .expanded {
                                allDocumentsPosition = .default
                            } else {
                                allDocumentsPosition = .expanded
                            }
                        }
                        // Add haptic feedback
                        HapticFeedback.impact(.light)
                    }
                }
                .frame(height: 12) // Fixed height for grab bar area
                .padding(.bottom, 8) // Space between grab bar and content
            }
            
            // Main header content
            VStack(spacing: 12) {
                // Title and search row
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                            .foregroundStyle(theme.primary)
                        Text("All Docs (\(filteredDocuments.count))")
                            .font(.custom("InterTight-Medium", size: isIPad ? 16 : 14))
                            .foregroundStyle(theme.primary)
                    }
                    
                    Spacer()
                    
                    // Search button
                    Button(action: onSearch) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: isIPad ? 13 : 11, weight: .medium))
                                .foregroundStyle(theme.secondary)
                        }
                        .padding(.horizontal, isIPad ? 12 : 8)
                        .padding(.vertical, isIPad ? 6 : 4)
                        .background(theme.accent.opacity(0.1))
                        .cornerRadius(isIPad ? 8 : 6)
                    }
                    .buttonStyle(.plain)
                }
                
                // Filters and controls row
                HStack(spacing: 12) {
                    // Filter by dropdown
                    Menu {
                        Button("All") {
                            selectedFilterColumn = nil
                            isDateFilterExplicitlySelected = false
                            tableRefreshID = UUID()
                        }
                        Divider()
                        Button("Series") {
                            selectedFilterColumn = "series"
                            isDateFilterExplicitlySelected = false
                            tableRefreshID = UUID()
                        }
                        Button("Location") {
                            selectedFilterColumn = "location"
                            isDateFilterExplicitlySelected = false
                            tableRefreshID = UUID()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: isIPad ? 13 : 11))
                                .foregroundStyle(selectedFilterColumn != nil ? theme.accent : theme.secondary)
                            Text(selectedFilterColumn?.capitalized ?? "Filter")
                                .font(.custom("InterTight-Medium", size: isIPad ? 13 : 11))
                                .foregroundStyle(selectedFilterColumn != nil ? theme.accent : theme.secondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: isIPad ? 10 : 8))
                                .foregroundStyle(theme.secondary)
                        }
                        .padding(.horizontal, isIPad ? 12 : 8)
                        .padding(.vertical, isIPad ? 8 : 6)
                        .background(selectedFilterColumn != nil ? theme.accent.opacity(0.1) : theme.secondary.opacity(0.05))
                        .cornerRadius(isIPad ? 8 : 6)
                    }
                    .buttonStyle(.plain)
                    
                    // Tags button
                    Button(action: {
                        activeSheet = .tagManager
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "tag")
                                .font(.system(size: isIPad ? 13 : 11))
                                .foregroundStyle(!selectedTags.isEmpty ? theme.accent : theme.secondary)
                            Text(!selectedTags.isEmpty ? "\(selectedTags.count) Tags" : "Tags")
                                .font(.custom("InterTight-Medium", size: isIPad ? 13 : 11))
                                .foregroundStyle(!selectedTags.isEmpty ? theme.accent : theme.secondary)
                        }
                        .padding(.horizontal, isIPad ? 12 : 8)
                        .padding(.vertical, isIPad ? 8 : 6)
                        .background(!selectedTags.isEmpty ? theme.accent.opacity(0.1) : theme.secondary.opacity(0.05))
                        .cornerRadius(isIPad ? 8 : 6)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Sort controls
                    HStack(spacing: 8) {
                        Text("Sort:")
                            .font(.custom("InterTight-Medium", size: isIPad ? 13 : 11))
                            .foregroundStyle(theme.secondary)
                        
                        Menu {
                            Button("Name") {
                                selectedSortColumn = "name"
                                onUpdateDocumentSort()
                            }
                            Button("Series") {
                                selectedSortColumn = "series"
                                onUpdateDocumentSort()
                            }
                            Button("Location") {
                                selectedSortColumn = "location"
                                onUpdateDocumentSort()
                            }
                            Button("Date Modified") {
                                selectedSortColumn = "date"
                                onUpdateDocumentSort()
                            }
                            Button("Date Created") {
                                selectedSortColumn = "createdDate"
                                onUpdateDocumentSort()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sortDisplayName)
                                    .font(.custom("InterTight-Medium", size: isIPad ? 13 : 11))
                                    .foregroundStyle(theme.accent)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: isIPad ? 10 : 8))
                                    .foregroundStyle(theme.secondary)
                            }
                            .padding(.horizontal, isIPad ? 12 : 8)
                            .padding(.vertical, isIPad ? 8 : 6)
                            .background(theme.accent.opacity(0.1))
                            .cornerRadius(isIPad ? 8 : 6)
                        }
                        .buttonStyle(.plain)
                        
                        // Sort direction
                        Button(action: {
                            isAscendingSortOrder.toggle()
                            onUpdateDocumentSort()
                        }) {
                            Image(systemName: isAscendingSortOrder ? "arrow.up" : "arrow.down")
                                .font(.system(size: isIPad ? 13 : 11, weight: .medium))
                                .foregroundStyle(theme.accent)
                                .padding(isIPad ? 8 : 6)
                                .background(theme.accent.opacity(0.1))
                                .cornerRadius(isIPad ? 8 : 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Selected tags display
                if !selectedTags.isEmpty {
                    HStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedTags), id: \.self) { tag in
                                    HStack(spacing: 6) {
                                        Text(tag)
                                            .font(.custom("InterTight-Medium", size: isIPad ? 12 : 10))
                                            .foregroundStyle(.white)
                                        
                                        Button(action: {
                                            selectedTags.remove(tag)
                                            tableRefreshID = UUID()
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: isIPad ? 10 : 8, weight: .medium))
                                                .foregroundStyle(.white)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, isIPad ? 10 : 8)
                                    .padding(.vertical, isIPad ? 6 : 4)
                                    .background(colorManager.color(for: tag))
                                    .cornerRadius(isIPad ? 14 : 12)
                                }
                            }
                        }
                        Spacer()
                    }
                }
                
                // Clear filters button
                if selectedFilterColumn != nil || !selectedTags.isEmpty {
                    HStack {
                        Button("Clear All Filters") {
                            selectedFilterColumn = nil
                            selectedTags.removeAll()
                            isDateFilterExplicitlySelected = false
                            tableRefreshID = UUID()
                        }
                        .font(.custom("InterTight-Medium", size: isIPad ? 13 : 11))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, isIPad ? 16 : 12)
                        .padding(.vertical, isIPad ? 8 : 6)
                        .background(theme.accent.opacity(0.1))
                        .cornerRadius(isIPad ? 10 : 8)
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, {
            #if os(macOS)
            return 28
            #else
            return isIPad ? 24 : 72
            #endif
        }())
        .padding(.top, isIPad ? 20 : 12)
        .padding(.bottom, isIPad ? 16 : 8)
    }
    
    // MARK: - Helper Properties
    private var sortDisplayName: String {
        switch selectedSortColumn {
        case "name": return "Name"
        case "series": return "Series"
        case "location": return "Location"
        case "date": return "Modified"
        case "createdDate": return "Created"
        default: return "Name"
        }
    }
    
    private var filteredDocuments: [Letterspace_CanvasDocument] {
        var filtered = documents
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { doc in
                guard let docTags = doc.tags else { return false }
                return !selectedTags.isDisjoint(with: docTags)
            }
        }
        
        // Apply column filter
        if let filterColumn = selectedFilterColumn {
            switch filterColumn {
            case "series":
                filtered = filtered.filter { doc in
                    return doc.series != nil && !doc.series!.name.isEmpty
                }
            case "location":
                filtered = filtered.filter { doc in
                    return doc.variations.first?.location != nil && !doc.variations.first!.location!.isEmpty
                }
            default:
                break
            }
        }
        
        return filtered
    }
}

// MARK: - Supporting Types
// Note: AllDocumentsPosition enum is defined in DashboardView

#endif
