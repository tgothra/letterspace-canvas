import SwiftUI

struct ReflectionSelectionView: View {
    let documents: [Letterspace_CanvasDocument]
    let onSelectDocument: (Letterspace_CanvasDocument) -> Void
    let onDismiss: () -> Void
    var allowCustom: Bool = false
    var onSelectNone: (() -> Void)? = nil
    
    @Environment(\.themeColors) var theme
    @State private var query: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Native iOS/macOS searchable field
                    #if os(iOS)
                    TextField("Search sermons", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)
                    #else
                    TextField("Search sermons", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)
                    #endif
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "book.pages.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose a Sermon")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.primary)
                                
                                Text("Select which sermon you'd like to reflect on")
                                    .font(.subheadline)
                                    .foregroundColor(theme.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Optional: Create custom (no sermon) entry
                    if allowCustom, let onSelectNone = onSelectNone {
                        Button(action: onSelectNone) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.pencil")
                                Text("Create custom entry (no sermon)")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }

                    // Recent sermons list
                    ForEach(filteredDocuments, id: \.id) { document in
                        ReflectionSelectionCard(
                            document: document,
                            onTap: {
                                onSelectDocument(document)
                            }
                        )
                    }
                    
                    if filteredDocuments.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 48))
                                .foregroundColor(theme.secondary.opacity(0.5))
                            
                            VStack(spacing: 8) {
                                Text("No Recent Sermons")
                                    .font(.headline)
                                    .foregroundColor(theme.primary)
                                
                                Text("Sermons that have been preached will appear here for reflection")
                                    .font(.subheadline)
                                    .foregroundColor(theme.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Add Reflection")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel", action: onDismiss)
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Cancel", action: onDismiss)
                }
                #endif
            }
        }
    }

    private var filteredDocuments: [Letterspace_CanvasDocument] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return documents }
        return documents.filter { doc in
            doc.title.localizedCaseInsensitiveContains(trimmed) ||
            doc.subtitle.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

struct ReflectionSelectionCard: View {
    let document: Letterspace_CanvasDocument
    let onTap: () -> Void
    @Environment(\.themeColors) var theme
    
    private var lastPreachedDate: Date? {
        document.variations.compactMap { $0.datePresented }.max()
    }
    
    private var timeSincePreached: String {
        guard let date = lastPreachedDate else { return "Not preached yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var preachingLocation: String? {
        document.variations.first { $0.datePresented != nil }?.location
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Left indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(.purple)
                    .frame(width: 4)
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Title and subtitle
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.primary)
                            .multilineTextAlignment(.leading)
                        
                        if !document.subtitle.isEmpty {
                            Text(document.subtitle)
                                .font(.subheadline)
                                .foregroundColor(theme.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    // Metadata
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(timeSincePreached)
                                .font(.caption)
                        }
                        .foregroundColor(theme.secondary)
                        
                        if let location = preachingLocation {
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .font(.caption)
                                Text(location)
                                    .font(.caption)
                            }
                            .foregroundColor(theme.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .stroke(.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

#Preview {
    ReflectionSelectionView(
        documents: [
            Letterspace_CanvasDocument(
                title: "The Power of Faith",
                subtitle: "Finding Strength in Uncertain Times",
                elements: [],
                id: "preview1"
            ),
            Letterspace_CanvasDocument(
                title: "Walking in Love",
                subtitle: "Christ's Example for Daily Living",
                elements: [],
                id: "preview2"
            )
        ],
        onSelectDocument: { _ in },
        onDismiss: {}
    )
}