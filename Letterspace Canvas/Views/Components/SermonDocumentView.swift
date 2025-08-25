import SwiftUI

struct SermonDocumentView: View {
    let document: Letterspace_CanvasDocument
    let onDismiss: () -> Void
    
    @Environment(\.themeColors) var theme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(document.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(theme.primary)
                        
                        if !document.subtitle.isEmpty {
                            Text(document.subtitle)
                                .font(.title2)
                                .foregroundStyle(theme.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Document content
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(document.elements) { element in
                            SermonElementView(element: element, document: document)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Sermon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done", action: onDismiss)
                }
                #endif
            }
        }
    }
}

struct SermonElementView: View {
    let element: DocumentElement
    let document: Letterspace_CanvasDocument
    @Environment(\.themeColors) var theme
    
    var body: some View {
        switch element.type {
        case .header:
            Text(element.content)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(theme.primary)
        case .subheader:
            Text(element.content)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(theme.primary)
        case .title:
            Text(element.content)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(theme.primary)
        case .textBlock:
            if let attributedContent = element.attributedContent {
                // Display rich text content
                #if os(iOS)
                Text(AttributedString(attributedContent))
                    .font(.body)
                #else
                Text(AttributedString(attributedContent))
                    .font(.body)
                #endif
            } else {
                Text(element.content)
                    .font(.body)
                    .foregroundStyle(theme.primary)
            }
        case .scripture:
            VStack(alignment: .leading, spacing: 4) {
                Text(element.content)
                    .font(.body)
                    .foregroundStyle(theme.primary)
                    .italic()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.accent.opacity(0.1))
            )
        case .headerImage:
            if !element.content.isEmpty,
               let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                let imagesPath = appDirectory.appendingPathComponent("Images")
                let imageUrl = imagesPath.appendingPathComponent(element.content)
                
                #if os(iOS)
                if let uiImage = UIImage(contentsOfFile: imageUrl.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                #else
                if let nsImage = NSImage(contentsOf: imageUrl) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                #endif
            }
        case .image:
            if !element.content.isEmpty,
               let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                let documentPath = appDirectory.appendingPathComponent(document.id)
                let imagesPath = documentPath.appendingPathComponent("Images")
                let imageUrl = imagesPath.appendingPathComponent(element.content)
                
                #if os(iOS)
                if let uiImage = UIImage(contentsOfFile: imageUrl.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                #else
                if let nsImage = NSImage(contentsOf: imageUrl) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                #endif
            }
        case .dropdown:
            Text("• \(element.content)")
                .font(.body)
                .foregroundStyle(theme.primary)
        case .date:
            if let date = element.date {
                Text(date.formatted(date: .long, time: .shortened))
                    .font(.body)
                    .foregroundStyle(theme.secondary)
            }
        case .multiSelect:
            Text(element.content)
                .font(.body)
                .foregroundStyle(theme.primary)
        case .chart, .signature, .table:
            Text(element.content)
                .font(.body)
                .foregroundStyle(theme.primary)
        }
    }
}