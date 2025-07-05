import SwiftUI

struct SeriesListItem: View {
    let item: (title: String, date: String, isActive: Bool)
    let selectedSeries: String
    let onOpen: () -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                Circle()
                    .fill(item.isActive ? Color(hex: "#22c27d") : theme.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(item.isActive ? Color(hex: "#22c27d") : theme.primary)
                    Text(item.date)
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93)) :
                        Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SeriesSearchView: View {
    @Binding var searchText: String
    @FocusState var isSearchFocused: Bool
    let onSubmit: () -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(theme.secondary)
            
            TextField("Search series...", text: $searchText)
                            .font(.system(size: 13))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit(onSubmit)
                .foregroundColor(theme.primary)
                    }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSearchFocused ? theme.accent : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            isSearchFocused = true
        }
    }
}
