#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - Today's Documents Picker (matching folder picker style)
struct TodayDocumentsPicker: View {
    let allDocuments: [Letterspace_CanvasDocument]
    let initiallySelected: Set<String>
    let onDone: (Set<String>) -> Void
    let onCancel: () -> Void
    @Environment(\.themeColors) private var theme
    @State private var selection: Set<String> = []
    @State private var searchText: String = ""

    init(allDocuments: [Letterspace_CanvasDocument], initiallySelected: Set<String>, onDone: @escaping (Set<String>) -> Void, onCancel: @escaping () -> Void) {
        self.allDocuments = allDocuments
        self.initiallySelected = initiallySelected
        self.onDone = onDone
        self.onCancel = onCancel
        _selection = State(initialValue: initiallySelected)
    }

    var body: some View {
        #if os(macOS)
        // macOS: Optimized layout for popover/modal context
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Documents")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondary)
                TextField("Search documents...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Documents list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredDocuments) { doc in
                        DocumentSelectionRowForToday(
                            document: doc,
                            isSelected: selection.contains(doc.id),
                            theme: theme
                        ) {
                            toggleDocumentSelection(doc.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .frame(maxHeight: 300) // Constrain height for modal context
            
            Divider()
            
            // Bottom action bar
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .foregroundColor(theme.secondary)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .background(theme.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: { onDone(selection) }) {
                    Text("Add \(selection.count) Documents")
                        .foregroundColor(.white)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .background(selection.isEmpty ? theme.secondary : theme.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(selection.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 450, height: 500) // Fixed size for macOS modal
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        #else
        // iOS: Use NavigationView as before
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(theme.secondary)
                    TextField("Search documents...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.secondary.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Documents list
                List {
                    ForEach(filteredDocuments) { doc in
                        DocumentSelectionRowForToday(
                            document: doc,
                            isSelected: selection.contains(doc.id),
                            theme: theme
                        ) {
                            toggleDocumentSelection(doc.id)
                        }
                    }
                }
                .listStyle(.plain)
                
                // Bottom action bar
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(theme.secondary)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(theme.secondary.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button("Add \(selection.count) Documents") {
                        onDone(selection)
                    }
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(selection.isEmpty ? theme.secondary : theme.accent)
                    .cornerRadius(8)
                    .disabled(selection.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 8)
                .background(theme.surface)
            }
            .navigationTitle("Add Documents")
            .navigationBarTitleDisplayMode(.inline)
        }
        #endif
    }
    
    private var filteredDocuments: [Letterspace_CanvasDocument] {
        if searchText.isEmpty {
            return allDocuments
        } else {
            return allDocuments.filter { doc in
                doc.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func toggleDocumentSelection(_ documentId: String) {
        if selection.contains(documentId) {
            selection.remove(documentId)
        } else {
            selection.insert(documentId)
        }
    }
}

// Document selection row matching the folder picker style
private struct DocumentSelectionRowForToday: View {
    let document: Letterspace_CanvasDocument
    let isSelected: Bool
    let theme: ThemeColors
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(theme.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Document info with proper header icon/image
                HStack(spacing: 10) {
                    if let headerImage = loadHeaderImage(for: document) {
                        let isIcon = document.elements.first(where: { $0.type == .headerImage })?.content.contains("header_icon_") ?? false
                        #if os(macOS)
                        Image(nsImage: headerImage)
                            .resizable()
                            .aspectRatio(contentMode: isIcon ? .fit : .fill)
                            .frame(width: 20, height: 20)
                            .clipShape(isIcon ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 3)))
                        #else
                        Image(uiImage: headerImage)
                            .resizable()
                            .aspectRatio(contentMode: isIcon ? .fit : .fill)
                            .frame(width: 20, height: 20)
                            .clipShape(isIcon ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 3)))
                        #endif
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.secondary)
                            .frame(width: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.title.isEmpty ? "Untitled" : document.title)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.primary)
                            .lineLimit(1)
                        
                        if !document.subtitle.isEmpty {
                            Text(document.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#endif
