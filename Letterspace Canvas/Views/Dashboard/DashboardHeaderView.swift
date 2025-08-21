#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - Dashboard Header View
struct DashboardHeaderView: View {
    @Environment(\.themeColors) var theme
    @EnvironmentObject var colorTheme: ColorThemeManager
    
    // Filter and sort state
    @Binding var selectedFilterColumn: String?
    @Binding var selectedTags: Set<String>
    @Binding var isDateFilterExplicitlySelected: Bool
    @Binding var selectedSortColumn: String
    @Binding var isAscendingSortOrder: Bool
    @Binding var tableRefreshID: UUID
    @Binding var activeSheet: DashboardView.ActiveSheet?
    
    // Document data
    let allTags: [String]
    let colorManager: TagColorManager
    
    // Callbacks
    let onSearch: (() -> Void)?
    let onUpdateVisibleColumns: () -> Void
    let onUpdateDocumentSort: () -> Void
    
    var body: some View {
        // Only show the docs header section - greeting will be separate
        docsHeader
    }
    

    
    // NEW: Simple docs header that scrolls naturally
    private var docsHeader: some View {
        VStack(spacing: 16) {
            // Main header with icons
            HStack {
                Text("Documents")
                    .font(.custom("InterTight-Bold", size: 24))
                    .foregroundStyle(theme.primary)

                Spacer()
                
                // Control buttons
                HStack(spacing: 8) {
                    // Search Button (iOS only - macOS has it in sidebar)
                    #if os(iOS)
                    Button(action: {
                        // Trigger search sheet
                        onSearch?()
                        HapticFeedback.impact(.light)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                (colorTheme.gradients != nil
                                    ? AnyShapeStyle(colorTheme.gradients!.filterGradient)
                                    : AnyShapeStyle(colorTheme.currentTheme.headerButtons.filter)
                                ),
                                in: Circle()
                            )
                    }
                    #endif
                    
                    // Filter Dropdown (iOS only)
                    #if os(iOS)
                    Menu {
                        // Title and divider
                        Text("Filter Documents")
                            .font(.custom("InterTight-Bold", size: 14))
                            .foregroundStyle(theme.primary)
                        
                        Divider()
                        
                        ForEach(ListColumn.allColumns) { column in
                            if column.id != "name" && column.id != "date" && column.id != "createdDate" {
                                Button(action: {
                                    // Regular filter columns (dates are handled in Sort)
                                    selectedFilterColumn = selectedFilterColumn == column.id ? nil : column.id
                                    isDateFilterExplicitlySelected = false
                                    selectedTags.removeAll()
                                    onUpdateVisibleColumns()
                                    tableRefreshID = UUID()
                                    HapticFeedback.impact(.light)
                                }) {
                                    Label {
                                        Text(column.title)
                                    } icon: {
                                        Image(systemName: column.icon)
                                    }
                                }
                                .disabled({
                                    // Gray out (disable) the active filter to show it's selected
                                    let isActive = (column.id == "series" && selectedFilterColumn == "series") ||
                                                  (column.id == "location" && selectedFilterColumn == "location") ||
                                                  (column.id == "presentedDate" && selectedFilterColumn == "presentedDate")
                                    return isActive
                                }())
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            selectedFilterColumn = nil
                            selectedTags.removeAll()
                            isDateFilterExplicitlySelected = false
                            onUpdateVisibleColumns()
                            tableRefreshID = UUID()
                            HapticFeedback.impact(.light)
                        }) {
                            Label {
                                Text("Clear")
                            } icon: {
                                Image(systemName: "xmark.circle")
                            }
                        }
                        .disabled({
                            // Gray out Clear when it's the active state (no filters)
                            let isActive = selectedFilterColumn == nil && selectedTags.isEmpty && !isDateFilterExplicitlySelected
                            return isActive
                        }())
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16))
                            .foregroundStyle(.black)
                            .frame(width: 30, height: 30)
                            .background(
                                Group {
                                    if selectedFilterColumn != nil {
                                        Circle().fill(theme.accent)
                                    } else {
                                        Circle()
                                            .fill(Color.white)
                                            .overlay(
                                                Circle()
                                                    .fill(
                                                        colorTheme.gradients != nil
                                                            ? AnyShapeStyle(colorTheme.gradients!.filterGradient)
                                                            : AnyShapeStyle(colorTheme.currentTheme.headerButtons.filter)
                                                    )
                                            )
                                    }
                                }
                            )
                    }
                    #endif
                    
                    // Sort Dropdown  
                    Menu {
                        // Title and divider
                        Text("Sort Documents")
                            .font(.custom("InterTight-Bold", size: 14))
                            .foregroundStyle(theme.primary)
                        
                        Divider()
                        
                        Button(action: {
                            selectedSortColumn = "name"
                            onUpdateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: "textformat")
                                Text("Name")
                                if selectedSortColumn == "name" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedSortColumn = "dateModified"
                            onUpdateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                Text("Date Modified")
                                if selectedSortColumn == "dateModified" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }

                        Button(action: {
                            selectedSortColumn = "dateCreated"
                            onUpdateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Date Created")
                                if selectedSortColumn == "dateCreated" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedSortColumn = "status"
                            onUpdateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: "star")
                                Text("Status")
                                if selectedSortColumn == "status" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedSortColumn = "series"
                            onUpdateDocumentSort()
                        }) {
                            HStack {
                                Image(systemName: "square.stack")
                                Text("Series")
                                if selectedSortColumn == "series" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                        Button(action: {
                            selectedSortColumn = "location"
                            onUpdateDocumentSort()
                        }) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text("Location")
                                if selectedSortColumn == "location" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }

                        Divider()
                        
                        Button(action: {
                            isAscendingSortOrder.toggle()
                            onUpdateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: isAscendingSortOrder ? "arrow.up" : "arrow.down")
                                Text(isAscendingSortOrder ? "Ascending" : "Descending")
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    } label: {
                        #if os(macOS)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 14, weight: .medium))
                            Text("Sort By")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            (colorTheme.gradients != nil
                                ? AnyShapeStyle(colorTheme.gradients!.sortGradient)
                                : AnyShapeStyle(colorTheme.currentTheme.headerButtons.sort)
                            ),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        #else
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16))
                            .foregroundStyle(.black)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .overlay(
                                        Circle()
                                            .fill(
                                                colorTheme.gradients != nil
                                                    ? AnyShapeStyle(colorTheme.gradients!.sortGradient)
                                                    : AnyShapeStyle(colorTheme.currentTheme.headerButtons.sort)
                                            )
                                    )
                            )
                        #endif
                    }
                    
                    // Tags Dropdown
                    Menu {
                        // Title and divider
                        Text("Document Tags")
                            .font(.custom("InterTight-Bold", size: 14))
                            .foregroundStyle(theme.primary)
                        
                        Divider()
                        
                        if allTags.isEmpty {
                            Text("No tags available")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(allTags, id: \.self) { tag in
                                Button(action: {
                                    selectedFilterColumn = nil
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                    onUpdateVisibleColumns()
                                    tableRefreshID = UUID()
                                    HapticFeedback.impact(.light)
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(colorManager.color(for: tag))
                                            .frame(width: 8, height: 8)
                                        Text(tag)
                                        if selectedTags.contains(tag) {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.accent)
                                        }
                                    }
                                }
                            }
                            
                            if !selectedTags.isEmpty {
                                Divider()
                                Button("Clear All Tags") {
                                    selectedTags.removeAll()
                                    onUpdateVisibleColumns()
                                    tableRefreshID = UUID()
                                    HapticFeedback.impact(.light)
                                }
                            }
                            
                            Divider()
                            
                            Button(action: {
                                activeSheet = .tagManager
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Manage")
                                    Spacer()
                                }
                            }
                        }
                    } label: {
                        #if os(macOS)
                        HStack(spacing: 6) {
                            Image(systemName: "tag")
                                .font(.system(size: 14, weight: .medium))
                            Text("Tags")
                                .font(.system(size: 14, weight: .medium))
                            
                            // Badge for selected tags count
                            if !selectedTags.isEmpty {
                                Text("\(selectedTags.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Color.red, in: Circle())
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(!selectedTags.isEmpty ? theme.accent : colorTheme.currentTheme.headerButtons.tags, in: RoundedRectangle(cornerRadius: 8))
                        #else
                        Image(systemName: "tag")
                            .font(.system(size: 16))
                            .foregroundStyle(.black)
                            .frame(width: 30, height: 30)
                            .background(
                                Group {
                                    if !selectedTags.isEmpty {
                                        Circle().fill(theme.accent)
                                    } else {
                                        Circle()
                                            .fill(Color.white)
                                            .overlay(
                                                Circle()
                                                    .fill(
                                                        colorTheme.gradients != nil
                                                            ? AnyShapeStyle(colorTheme.gradients!.tagsGradient)
                                                            : AnyShapeStyle(colorTheme.currentTheme.headerButtons.tags)
                                                    )
                                            )
                                    }
                                }
                            )
                        #endif
                    }
                }
            }
            
            // Subheader with document count and help text
            HStack {
                Text("Long press on a document for details")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary.opacity(0.7))
                
                Spacer()
            }
            .padding(.top, 8)

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    

}

#endif
