import SwiftUI

struct SeriesListItem: View {
    let item: (title: String, date: String, isActive: Bool)
    let selectedSeries: String?
    let onOpen: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top) {
                // Document indicator - green for active, black/white for others
                Circle()
                    .fill(item.isActive ? Color(hex: "#22c27d") : theme.primary)
                    .frame(width: 6, height: 6)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Inter-Medium", size: 12))
                        .foregroundColor(theme.primary)
                        .lineLimit(1)
                    
                    if !item.date.isEmpty {
                        Text(item.date)
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(theme.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97)) :
                        Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SeriesSearchView: View {
    @Binding var seriesSearchText: String
    let recentSeries: [String]
    let shouldShowCreateNew: Bool
    let onAttach: (String) -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool
    @State private var isHovered: String? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Search or create new series", text: $seriesSearchText)
                .font(.custom("Inter", size: 13))
                .textFieldStyle(.plain)
                .padding(8)
                .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                .cornerRadius(6)
                .padding(.horizontal, 16)
            
            if !recentSeries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Series")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .padding(.horizontal, 16)
                    
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(recentSeries.filter {
                                seriesSearchText.isEmpty || $0.localizedCaseInsensitiveContains(seriesSearchText)
                            }, id: \.self) { series in
                                Button(action: { onAttach(series) }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.secondary)
                                            .frame(width: 16)
                                        Text(series)
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isHovered == series ?
                                                (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97)) :
                                                Color.clear)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    isHovered = hovering ? series : nil
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            if shouldShowCreateNew {
                Button(action: { onAttach(seriesSearchText) }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#22c27d"))
                        Text("Create \"\(seriesSearchText)\"")
                            .font(.custom("Inter", size: 13))
                            .foregroundStyle(Color(hex: "#22c27d"))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "#22c27d").opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
}

struct VariationItem: View {
    let title: String
    let date: String
    let isOriginal: Bool
    let action: () -> Void
    let onDelete: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @State private var showMenu = false
    @State private var isOpenHovered = false
    @State private var isDeleteHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isOriginal ? Color(hex: "#22c27d") : theme.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primary)
                    Text(date)
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondary)
                }
                Spacer()
                
                // Context menu button that appears on hover
                if isHovered || showMenu {
                    Button(action: { showMenu = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                        VStack(spacing: 0) {
                            Button(action: {
                                action()
                                showMenu = false
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 12))
                                    Text("Open")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(theme.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93))
                                    .opacity(isOpenHovered ? 1 : 0)
                            )
                            .onHover { isOpenHovered = $0 }
                            
                            Divider()
                            
                            Button(action: {
                                onDelete()
                                showMenu = false
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                    Text("Delete")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93))
                                    .opacity(isDeleteHovered ? 1 : 0)
                            )
                            .onHover { isDeleteHovered = $0 }
                        }
                        .frame(width: 120)
                        .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : .white)
                        .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((isHovered || showMenu) ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93)) :
                        Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Helper Components for Series Section

// Helper for Recent Series
// Helper for Selected Series
struct SelectedSeriesView: View {
    let seriesName: String
    let items: [(title: String, date: String, isActive: Bool)]
    @Binding var isDateSortAscending: Bool
    let onRemoveSeries: () -> Void
    let onOpenItem: ((title: String, date: String, isActive: Bool)) -> Void
    
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Series title and remove button
            HStack {
                Text(seriesName)
                    .font(.custom("Inter-Medium", size: 16))
                    .foregroundColor(theme.primary)
                Spacer()
                Button(action: onRemoveSeries) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Column headers
            HStack {
                Text("Name")
                    .font(.custom("Inter-Medium", size: 11))
                    .foregroundColor(theme.secondary)
                Spacer()
                Button(action: {
                    withAnimation {
                        isDateSortAscending.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Presented On")
                            .font(.custom("Inter-Medium", size: 11))
                            .foregroundColor(theme.secondary)
                        Image(systemName: isDateSortAscending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(theme.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Series items list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(items, id: \.title) { item in
                        SeriesListItem(
                            item: item,
                            selectedSeries: seriesName,
                            onOpen: { onOpenItem(item) }
                        )
                    }
                }
            }
        }
    }
}

struct RecentSeriesList: View {
    let recentSeries: [String]
    @Binding var hoveredSeriesItem: String?
    var onSelect: (String) -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Series")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            ForEach(recentSeries.prefix(3), id: \.self) { series in
                let isHovering = hoveredSeriesItem == series
                let backgroundColor = colorScheme == .dark ?
                    Color(.sRGB, white: 0.2, opacity: isHovering ? 1 : 0) :
                    Color(.sRGB, white: 0.95, opacity: isHovering ? 1 : 0)
                
                Button(action: {
                    onSelect(series)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                        Text(series)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(backgroundColor)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredSeriesItem = hovering ? series : nil
                }
            }
        }
    }
}
struct SeriesDropdownView: View {
    let matchingSeries: [String]
    let shouldShowCreateNew: Bool
    let seriesSearchText: String
    let formatSeries: (String) -> String
    @Binding var hoveredSeriesItem: String?
    var onSelect: (String) -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Matching Series")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)
            
            Divider()
                .padding(.horizontal, 8)
            
            // Matching series suggestions
            ForEach(matchingSeries.prefix(5), id: \.self) { series in
                Button(action: {
                    onSelect(series)
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                        Text(series)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(hoveredSeriesItem == series ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) :
                        Color.clear)
                }
                .buttonStyle(.plain)
                .onHover(perform: { hovering in
                    hoveredSeriesItem = hovering ? series : nil
                })
                
                if series != matchingSeries.prefix(5).last {
                    Divider()
                        .padding(.leading, 12)
                }
            }
            
            // Option to create a new series if it doesn't exist
            if shouldShowCreateNew {
                Divider()
                    .padding(.horizontal, 8)
                
                Button(action: {
                    let formattedSeries = formatSeries(seriesSearchText)
                    onSelect(formattedSeries)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Create \"\(formatSeries(seriesSearchText))\"")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(hoveredSeriesItem == "create" ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) :
                        Color.clear)
                }
                .buttonStyle(.plain)
                .onHover(perform: { hovering in
                    hoveredSeriesItem = hovering ? "create" : nil
                })
            }
        }
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
        .cornerRadius(8)
        .frame(width: 250)
        .fixedSize(horizontal: false, vertical: true)
        // Add shadow to create visual separation instead of a border
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}
