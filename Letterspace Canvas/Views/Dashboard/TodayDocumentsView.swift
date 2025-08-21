#if os(macOS) || os(iOS)
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Today's Documents View
struct TodayDocumentsView: View {
    // MARK: - Properties
    let documents: [Letterspace_CanvasDocument]
    let todayDocumentIds: Set<String>
    let todayStructure: [TodaySectionHeader]
    let todayStructureDocuments: [TodayStructureDocument]
    let onSelectDocument: (Letterspace_CanvasDocument) -> Void
    let onRemoveDocument: (String) -> Void
    let onAddHeader: () -> Void
    let onUpdateHeaderTitle: (String, String) -> Void
    let onRemoveHeader: (String) -> Void
    let onReorderStructure: (IndexSet, Int) -> Void
    
    @Environment(\.themeColors) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorTheme) private var colorTheme
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Description text
            Text("Documents you've selected for today")
                .font(.custom("InterTight-Regular", size: 16))
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 20)
            
            if todayDocumentIds.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundStyle(theme.primary.opacity(0.4))
                    
                    VStack(spacing: 8) {
                        Text("No documents added for today")
                            .font(.custom("InterTight-Medium", size: 18))
                            .foregroundStyle(theme.primary.opacity(0.7))
                        
                        Text("Tap the + button to add documents you want to work with today")
                            .font(.custom("InterTight-Regular", size: 14))
                            .foregroundStyle(theme.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Documents list with headers and reordering (SwiftUI List with onMove)
                List {
                    ForEach(renderTodayStructure(), id: \.id) { item in
                        switch item {
                        case .header(let header):
                            TodaySectionHeaderView(
                                header: header,
                                onUpdateTitle: { onUpdateHeaderTitle(header.id, $0) },
                                onRemove: { onRemoveHeader(header.id) }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        case .document(let doc, let index):
                            TodayDocumentCard(
                                document: doc,
                                index: index,
                                onTap: { onSelectDocument(doc) },
                                onRemove: { onRemoveDocument(doc.id) }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { onRemoveDocument(doc.id) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onMove(perform: onReorderStructure)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(renderTodayStructure().count * 80 + 100))
            }
        }
    }
    
    // MARK: - Helper Functions
    private func renderTodayStructure() -> [TodayStructureItem] {
        var items: [TodayStructureItem] = []
        
        // Add headers first
        for header in todayStructure.sorted(by: { $0.order < $1.order }) {
            items.append(.header(header))
            
            // Add documents under this header
            let documentsUnderHeader = todayStructureDocuments
                .filter { $0.headerId == header.id }
                .sorted(by: { $0.order < $1.order })
            
            for (index, docStruct) in documentsUnderHeader.enumerated() {
                if let document = documents.first(where: { $0.id == docStruct.id }) {
                    items.append(.document(document, index + 1))
                }
            }
        }
        
        // Add documents without headers (root level)
        let rootDocuments = todayStructureDocuments
            .filter { $0.headerId == nil }
            .sorted(by: { $0.order < $1.order })
        
        for (index, docStruct) in rootDocuments.enumerated() {
            if let document = documents.first(where: { $0.id == docStruct.id }) {
                items.append(.document(document, index + 1))
            }
        }
        
        // Fallback: if structure is empty but we have selected Today docs, show them in root order
        if items.isEmpty && !todayDocumentIds.isEmpty {
            let todayDocs = documents.filter { todayDocumentIds.contains($0.id) }
            for (idx, doc) in todayDocs.enumerated() {
                items.append(.document(doc, idx + 1))
            }
        }
        return items
    }
}

// MARK: - Today's Documents Data Models
struct TodaySectionHeader: Identifiable, Codable {
    let id: String
    var title: String
    var order: Int
}

struct TodayStructureDocument: Identifiable, Codable {
    let id: String
    var headerId: String?
    var order: Int
}

struct TodayStructureData: Codable {
    var headers: [TodaySectionHeader]
    var documents: [TodayStructureDocument]
}

enum TodayStructureItem: Identifiable {
    case header(TodaySectionHeader)
    case document(Letterspace_CanvasDocument, Int)
    
    var id: String {
        switch self {
        case .header(let header):
            return "header-\(header.id)"
        case .document(let document, _):
            return "document-\(document.id)"
        }
    }
}

// MARK: - Today Document Card
private struct TodayDocumentCard: View {
    let document: Letterspace_CanvasDocument
    let index: Int
    let onTap: () -> Void
    let onRemove: () -> Void
    @Environment(\.themeColors) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorTheme) private var colorTheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Document icon/image
            if let headerImage = loadHeaderImage(for: document) {
                let isIcon = document.elements.first(where: { $0.type == .headerImage })?.content.contains("header_icon_") ?? false
                #if os(macOS)
                Image(nsImage: headerImage)
                    .resizable()
                    .aspectRatio(contentMode: isIcon ? .fit : .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(isIcon ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
                #else
                Image(uiImage: headerImage)
                    .resizable()
                    .aspectRatio(contentMode: isIcon ? .fit : .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(isIcon ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
                #endif
            } else {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            
            // Document info
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title.isEmpty ? "Untitled" : document.title)
                    .font(.custom("InterTight-SemiBold", size: 16))
                    .foregroundStyle(theme.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if !document.subtitle.isEmpty {
                    Text(document.subtitle)
                        .font(.custom("InterTight-Regular", size: 14))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill({
                    if colorScheme == .dark {
                        #if os(iOS)
                        return Color(.systemGray6)
                        #else
                        return Color(.controlBackgroundColor)
                        #endif
                    } else {
                        #if os(iOS)
                        return Color(.systemBackground)
                        #else
                        return Color(.windowBackgroundColor)
                        #endif
                    }
                }())
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke({
                    #if os(iOS)
                    return Color(.separator)
                    #else
                    return Color(.separatorColor)
                    #endif
                }(), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    #if os(macOS)
    private func loadHeaderImage(for document: Letterspace_CanvasDocument) -> NSImage? {
        guard let headerElement = document.elements.first(where: { $0.type == .headerImage }), !headerElement.content.isEmpty, let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else { return nil }
        let documentPath = appDirectory.appendingPathComponent("\(document.id)")
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
        return NSImage(contentsOf: imageUrl)
    }
    #else
    private func loadHeaderImage(for document: Letterspace_CanvasDocument) -> UIImage? {
        guard let headerElement = document.elements.first(where: { $0.type == .headerImage }), !headerElement.content.isEmpty, let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else { return nil }
        let documentPath = appDirectory.appendingPathComponent("\(document.id)")
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
        return UIImage(contentsOfFile: imageUrl.path)
    }
    #endif
}

// MARK: - Today Section Header View
private struct TodaySectionHeaderView: View {
    let header: TodaySectionHeader
    let onUpdateTitle: (String) -> Void
    let onRemove: () -> Void
    @Environment(\.themeColors) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Header content
            HStack(spacing: 16) {
                if isEditing {
                    TextField("Section Title", text: $editedTitle)
                        .font(.custom("InterTight-Bold", size: 18))
                        .foregroundStyle(theme.primary)
                        .textFieldStyle(.plain)
                        .focused($isTitleFocused)
                        .onSubmit {
                            if !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onUpdateTitle(editedTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                            isEditing = false
                        }
                        .onAppear {
                            editedTitle = header.title
                            DispatchQueue.main.async { isTitleFocused = true }
                        }
                } else {
                    Text(header.title)
                        .font(.custom("InterTight-Bold", size: 18))
                        .foregroundStyle(theme.primary)
                }
                
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill({
                    if colorScheme == .dark {
                        #if os(iOS)
                        return Color(.systemGray5)
                        #else
                        return Color(.controlColor)
                        #endif
                    } else {
                        #if os(iOS)
                        return Color(.systemGray6)
                        #else
                        return Color(.controlBackgroundColor)
                        #endif
                    }
                }())
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke({
                    #if os(iOS)
                    return Color(.separator)
                    #else
                    return Color(.separatorColor)
                    #endif
                }(), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                editedTitle = header.title
                isEditing = true
                DispatchQueue.main.async { isTitleFocused = true }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { isEditing = true } label: {
                Label("Rename", systemImage: "pencil")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onRemove() } label: {
                Label("Delete Section", systemImage: "trash")
            }
        }
    }
}


#endif
