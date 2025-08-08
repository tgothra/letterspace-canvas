import SwiftUI

struct SermonJournalEntriesList: View {
    @ObservedObject private var service = SermonJournalService.shared
    let onSelect: (SermonJournalEntry) -> Void
    let onDismiss: () -> Void
    
    @Environment(\.themeColors) var theme
    
    var body: some View {
        NavigationView {
            List {
                ForEach(service.entries()) { entry in
                    EntryRow(entry: entry) { onSelect(entry) }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Journal Entries")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done", action: onDismiss) }
            }
        }
    }
    
    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Row
private struct EntryRow: View {
    let entry: SermonJournalEntry
    let onTap: () -> Void
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                thumbnail
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(sermonTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.primary)
                        .lineLimit(1)
                    Text(formatted(entry.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    
    private var sermonTitle: String {
        Letterspace_CanvasDocument.load(id: entry.sermonId)?.title ?? "Untitled Sermon"
    }
    
    @ViewBuilder
    private var thumbnail: some View {
        if let headerImage = loadHeaderImage() {
            PlatformImageView(platformImage: headerImage)
        } else {
            Image(systemName: "rectangle.and.text.magnifyingglass")
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
        }
    }
    
    private func loadHeaderImage() -> PlatformImage? {
        guard let document = Letterspace_CanvasDocument.load(id: entry.sermonId) else { return nil }
        #if os(macOS)
        if let headerElement = document.elements.first(where: { $0.type == .headerImage }), !headerElement.content.isEmpty,
           let imagesPath = Letterspace_CanvasDocument.getAppDocumentsDirectory()?.appendingPathComponent("Images"),
           let image = NSImage(contentsOf: imagesPath.appendingPathComponent(headerElement.content)) {
            return image
        }
        #else
        if let headerElement = document.elements.first(where: { $0.type == .headerImage }), !headerElement.content.isEmpty,
           let imagesPath = Letterspace_CanvasDocument.getAppDocumentsDirectory()?.appendingPathComponent("Images"),
           let data = try? Data(contentsOf: imagesPath.appendingPathComponent(headerElement.content)),
           let image = UIImage(data: data) {
            return image
        }
        #endif
        return nil
    }
    
    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
