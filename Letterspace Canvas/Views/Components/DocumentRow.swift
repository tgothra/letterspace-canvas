import SwiftUI

struct DocumentRow: View {
    let document: Letterspace_CanvasDocument
    let isSelected: Bool
    let isSelectionMode: Bool
    let isHovering: Bool
    let pinnedDocuments: Set<String>
    let wipDocuments: Set<String>
    let calendarDocuments: Set<String>
    let visibleColumns: Set<String>
    let onOpen: () -> Void
    let onShowDetails: () -> Void
    let onLongPress: () -> Void
    let onCalendarAction: (Letterspace_CanvasDocument) -> Void
    
    @Environment(\.themeColors) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendarContext = false
    
    // Use ColorManager from the app to get consistent tag colors
    private let colorManager = TagColorManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Status indicators and action buttons
            ZStack {
                if isHovering {
                    VStack(spacing: 2) {
                        // Top row
                        HStack(spacing: 2) {
                            // Pin button
                            Button(action: {}) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(pinnedDocuments.contains(document.id) ? .green : theme.primary.opacity(0.7))
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .help("Pin Document")
                            
                            // WIP button
                            Button(action: {}) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(wipDocuments.contains(document.id) ? .orange : theme.primary.opacity(0.7))
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .help("Mark as Work in Progress")
                        }
                        
                        // Bottom row
                        HStack(spacing: 2) {
                            Button(action: {
                                onCalendarAction(document)
                            }) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                    .foregroundStyle(calendarDocuments.contains(document.id) ? .blue : theme.primary.opacity(0.7))
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .help("Add to Calendar")
                            
                            // Empty space to maintain grid
                            Color.clear
                                .frame(width: 16, height: 16)
                        }
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    )
                    .frame(width: 40)
                
                    // Non-hover indicators
                    if pinnedDocuments.contains(document.id) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    if wipDocuments.contains(document.id) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    }
                    if calendarDocuments.contains(document.id) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                } else {
                    // Non-hover indicators
                    if pinnedDocuments.contains(document.id) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    if wipDocuments.contains(document.id) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    }
                    if calendarDocuments.contains(document.id) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .frame(width: 110)
            .padding(.leading, 12)

            // Selection checkbox
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? theme.accent : theme.secondary)
                    .frame(width: 24)
            }
            
            // Name and Tags columns
            HStack(spacing: 0) {
                // Document Icon and Title
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .frame(width: 24, height: 24)
                        .background(theme.secondary.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 16)
                
                // Tags
                if visibleColumns.contains("tags") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            if let tags = document.tags {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 11))
                                        .foregroundStyle(theme.primary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(tagColor(for: tag).opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 200)
                }
            }
            .padding(.horizontal, 8)
            
            // Details button
            HStack {
                if isHovering && !isSelectionMode {
                    Button(action: onShowDetails) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("View Details")
                }
            }
            .frame(width: 60)  // Reserve consistent space for the button
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onLongPressGesture(minimumDuration: 0.5, perform: onLongPress)
    }
    
    private func tagColor(for tag: String) -> Color {
        return colorManager.color(for: tag)
    }
} 