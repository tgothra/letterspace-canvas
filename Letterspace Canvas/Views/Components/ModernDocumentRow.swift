import SwiftUI

struct ModernDocumentRow: View {
    let document: Letterspace_CanvasDocument
    let onTap: () -> Void
    let onShowDetails: () -> Void
    let onPin: () -> Void
    let onWIP: () -> Void
    let onCalendar: () -> Void
    let onCalendarAction: () -> Void
    let onDelete: () -> Void
    let selectedTags: Set<String>
    let selectedFilterColumn: String?
    let dateFilterType: DateFilterType
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    @Environment(\.documentStatus) var documentStatus
    
    @State private var isHovered = false
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let date = dateFilterType == .created ? document.createdAt : document.modifiedAt
        let prefix = dateFilterType == .created ? "Created" : "Last modified"
        return "\(prefix): \(formatter.string(from: date))"
    }
    
    private var primaryFilter: String? {
        // Only show badge if there's an active filter or selected tags
        if !selectedTags.isEmpty {
            // Show the first matching tag from selected tags
            if let docTags = document.tags {
                for selectedTag in selectedTags {
                    if docTags.contains(selectedTag) {
                        return selectedTag
                    }
                }
            }
        }
        
        if let filterColumn = selectedFilterColumn {
            switch filterColumn {
            case "series":
                if let series = document.series?.name, !series.isEmpty {
                    return series
                }
            case "location":
                if let location = document.variations.first?.location, !location.isEmpty {
                    return location
                }
            default:
                break
            }
        }
        
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // First line: Name • Subtitle
            HStack(alignment: .center, spacing: 8) {
                // Document icon or header image thumbnail
                if let headerImage = loadHeaderImage() {
                    // Header image thumbnail
                    #if os(macOS)
                    Image(nsImage: headerImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    #else
                    Image(uiImage: headerImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    #endif
                } else {
                    // Default document icon
                    Image(systemName: "doc.text")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                
                // Name
                Text(document.title.isEmpty ? "Untitled" : document.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(1)
                
                if !document.subtitle.isEmpty {
                    // Bullet separator
                    Text("•")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // Subtitle
                    Text(document.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Action menu button
                Button(action: onShowDetails) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
            
            // Second line: Last modified • Filter
            HStack(alignment: .center, spacing: 8) {
                // Invisible placeholder to align with icon above
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 20, height: 20)
                
                // Date (modified or created based on dateFilterType)
                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                // Primary filter/tag (only show if there's an active filter)
                if let filter = primaryFilter {
                    // Bullet separator
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text(filter)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.primary.opacity(0.1))
                        )
                }
                
                Spacer()
                
                // Status icons at end of second row
                HStack(spacing: 4) {
                    if documentStatus.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    
                    if documentStatus.isWIP {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    if documentStatus.isScheduled {
                        Image(systemName: "calendar.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("View Details") { onShowDetails() }
            Divider()
            Button(documentStatus.isPinned ? "Unpin" : "Pin") { onPin() }
            Button(documentStatus.isWIP ? "Remove from WIP" : "Add to WIP") { onWIP() }
            Button(documentStatus.isScheduled ? "Remove from Calendar" : "Add to Calendar") { onCalendar() }
            Button("Schedule Presentation") { onCalendarAction() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
    
    #if os(macOS)
    private func loadHeaderImage() -> NSImage? {
        guard let headerElement = document.elements.first(where: { $0.type == .headerImage }),
              !headerElement.content.isEmpty,
              let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            return nil
        }
        
        let documentPath = appDirectory.appendingPathComponent("\(document.id)")
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
        
        return NSImage(contentsOf: imageUrl)
    }
    #else
    private func loadHeaderImage() -> UIImage? {
        guard let headerElement = document.elements.first(where: { $0.type == .headerImage }),
              !headerElement.content.isEmpty,
              let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            return nil
        }
        
        let documentPath = appDirectory.appendingPathComponent("\(document.id)")
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
        
        return UIImage(contentsOfFile: imageUrl.path)
    }
    #endif

} 
