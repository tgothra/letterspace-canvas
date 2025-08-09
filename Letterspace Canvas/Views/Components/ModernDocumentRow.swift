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
    
    // Platform-aware sizing to make macOS rows a bit larger for readability
    private var iconDimension: CGFloat {
        #if os(macOS)
        return 24
        #else
        return 20
        #endif
    }
    private var documentIconFontSize: CGFloat {
        #if os(macOS)
        return 20
        #else
        return 16
        #endif
    }
    private var titleFontSize: CGFloat {
        #if os(macOS)
        return 16
        #else
        return 14
        #endif
    }
    private var subtitleFontSize: CGFloat {
        #if os(macOS)
        return 13
        #else
        return 12
        #endif
    }
    private var bulletFontSize: CGFloat {
        #if os(macOS)
        return 13
        #else
        return 12
        #endif
    }
    private var metaFontSize: CGFloat {
        #if os(macOS)
        return 12
        #else
        return 11
        #endif
    }
    private var statusIconFontSize: CGFloat {
        #if os(macOS)
        return 11
        #else
        return 10
        #endif
    }
    private var rowVerticalPadding: CGFloat {
        #if os(macOS)
        return 14
        #else
        return 12
        #endif
    }

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
    
    // macOS: Always-visible badges next to date
    #if os(macOS)
    private var seriesName: String? {
        if let name = document.series?.name, !name.isEmpty { return name }
        return nil
    }
    private var locationName: String? {
        if let loc = document.variations.first?.location, !loc.isEmpty { return loc }
        return nil
    }
    #endif
    
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
                        .frame(width: iconDimension, height: iconDimension)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    #else
                    Image(uiImage: headerImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: iconDimension, height: iconDimension)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    #endif
                } else {
                    // Default document icon
                    Image(systemName: "doc.text")
                        .font(.system(size: documentIconFontSize, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: iconDimension, height: iconDimension)
                }
                
                // Name
                Text(document.title.isEmpty ? "Untitled" : document.title)
                    .font(.system(size: titleFontSize, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(1)
                
                if !document.subtitle.isEmpty {
                    // Bullet separator
                    Text("•")
                        .font(.system(size: bulletFontSize, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // Subtitle
                    Text(document.subtitle)
                        .font(.system(size: subtitleFontSize))
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
                    .font(.system(size: metaFontSize))
                    .foregroundColor(.secondary)
                
                // macOS: Show Series and Location badges next to the date
                #if os(macOS)
                if let series = seriesName {
                    Text("•")
                        .font(.system(size: metaFontSize))
                        .foregroundColor(.secondary)
                    Text(series)
                        .font(.system(size: metaFontSize, weight: .medium))
                        .foregroundColor(theme.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.primary.opacity(0.1))
                        )
                }
                if let loc = locationName {
                    Text("•")
                        .font(.system(size: metaFontSize))
                        .foregroundColor(.secondary)
                    Text(loc)
                        .font(.system(size: metaFontSize, weight: .medium))
                        .foregroundColor(theme.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.primary.opacity(0.1))
                        )
                }
                #endif
                
                // Primary filter/tag (only show if there's an active filter)
                if let filter = primaryFilter {
                    // Bullet separator
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text(filter)
                        .font(.system(size: metaFontSize, weight: .medium))
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
                        Image(systemName: "star.fill")
                            .font(.system(size: statusIconFontSize, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    
                    if documentStatus.isWIP {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: statusIconFontSize, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    if documentStatus.isScheduled {
                        Image(systemName: "calendar.circle.fill")
                            .font(.system(size: statusIconFontSize, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowVerticalPadding)
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
            Button(action: onShowDetails) {
                Text("View Details")
            }
            Divider()
            Button(action: onPin) {
                Text(documentStatus.isPinned ? "Unstar" : "Star")
            }
            Button(action: onWIP) {
                Text(documentStatus.isWIP ? "Remove from WIP" : "Add to WIP")
            }
            Button(action: onCalendar) {
                Text(documentStatus.isScheduled ? "Remove from Calendar" : "Add to Calendar")
            }
            Button(action: onCalendarAction) {
                Text("Schedule Presentation")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Text("Delete")
            }
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
