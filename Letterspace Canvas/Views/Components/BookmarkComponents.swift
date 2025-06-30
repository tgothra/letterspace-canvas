import SwiftUI

// Add Bookmark Timeline View
struct BookmarkTimelineView: View {
    let bookmarks: [DocumentMarker]
    let onBookmarkTap: (Int) -> Void
    @Environment(\.themeColors) var theme
    @State private var hoveredBookmarkId: UUID? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Timeline")
                .font(.custom("Inter-Medium", size: 12))
                .foregroundColor(theme.secondary)
                .padding(.bottom, 4)
            
            // Calculate relative positions for visualization
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Timeline line
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 2)
                    
                    // Bookmark dots
                    ForEach(bookmarks.sorted(by: { $0.position < $1.position })) { bookmark in
                        BookmarkDot(
                            bookmark: bookmark,
                            isHovered: hoveredBookmarkId == bookmark.id,
                            onTap: { onBookmarkTap(bookmark.position) }
                        )
                        .position(
                            x: calculateXPosition(for: bookmark, in: geo.size.width),
                            y: 0
                        )
                        .onHover { isHovered in
                            if isHovered {
                                hoveredBookmarkId = bookmark.id
                            } else if hoveredBookmarkId == bookmark.id {
                                hoveredBookmarkId = nil
                            }
                        }
                    }
                }
            }
            .frame(height: 24)
        }
    }
    
    private func calculateXPosition(for bookmark: DocumentMarker, in width: CGFloat) -> CGFloat {
        let sortedPositions = bookmarks.map { $0.position }.sorted()
        guard let minPosition = sortedPositions.first,
              let maxPosition = sortedPositions.last,
              minPosition != maxPosition else {
            return width / 2 // Center if only one bookmark or all at same position
        }
        
        // Calculate relative position on timeline
        let range = maxPosition - minPosition
        let relativePosition = CGFloat(bookmark.position - minPosition) / CGFloat(range)
        
        // Add padding on both sides (10% of width)
        let padding = width * 0.1
        let availableWidth = width - (padding * 2)
        
        return padding + (relativePosition * availableWidth)
    }
}

struct BookmarkDot: View {
    let bookmark: DocumentMarker
    let isHovered: Bool
    let onTap: () -> Void
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(spacing: 2) {
            // Tooltip with title if hovered
            if isHovered {
                Text(bookmark.title.isEmpty ? "Bookmark" : bookmark.title)
                    .font(.custom("Inter-Regular", size: 10))
                    .foregroundColor(theme.background)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.9))
                    )
                    .offset(y: -20)
                    .transition(.opacity)
            }
            
            // Bookmark dot
            Circle()
                .fill(markerColor(for: bookmark.type))
                .frame(width: isHovered ? 10 : 8, height: isHovered ? 10 : 8)
                .animation(.spring(response: 0.2), value: isHovered)
                .contentShape(Rectangle().size(CGSize(width: 20, height: 20)))
                .onTapGesture {
                    onTap()
                }
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private func markerColor(for type: String) -> Color {
        switch type {
        case "highlight": return Color(hex: "#22c27d")
        case "comment": return Color(hex: "#FF6B6B")
        case "bookmark": return Color(hex: "#4ECDC4")
        default: return Color(hex: "#96CEB4")
        }
    }
}
