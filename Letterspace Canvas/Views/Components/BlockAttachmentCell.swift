#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

class BlockAttachmentCell: NSTextAttachmentCell {
    let element: DocumentElement
    private var hostingView: NSHostingView<AnyView>?
    private var height: CGFloat
    
    init(element: DocumentElement) {
        self.element = element
        self.height = Self.defaultHeight(for: element.type)
        super.init()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        guard hostingView == nil else { return }
        
        // Create the appropriate view based on block type
        let blockView = createBlockView()
        
        // Wrap in ResizableBlock if supported
        let wrappedView = AnyView(
            ResizableBlock(
                height: .init(
                    get: { self.height },
                    set: { newHeight in
                        self.height = newHeight
                        controlView?.needsLayout = true
                    }
                ),
                minHeight: Self.minHeight(for: element.type),
                maxHeight: Self.maxHeight(for: element.type)
            ) {
                blockView
                    .transition(.opacity.combined(with: .scale))
            }
        )
        
        hostingView = NSHostingView(rootView: wrappedView)
        hostingView?.frame = cellFrame
        
        if let hostingView = hostingView {
            controlView?.addSubview(hostingView)
            
            // Add animation
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                hostingView.animator().alphaValue = 1.0
            }
        }
    }
    
    override func cellSize() -> NSSize {
        return NSSize(width: 800, height: height)
    }
    
    private func createBlockView() -> AnyView {
        // Create view based on element type
        switch element.type {
        case .textBlock:
            return AnyView(
                Text(element.content)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            )
            
        case .image:
            // Get the document ID from the parent view or document context
            if let textView = hostingView?.superview as? NSTextView,
               let document = textView.window?.windowController?.document as? Letterspace_CanvasDocument {
                return AnyView(
                    ImageBlockView(
                        element: element,
                        documentId: document.id,
                        onImageChange: { newImagePath in
                            // Update the element's content
                            if let textView = self.hostingView?.superview as? NSTextView,
                               let textStorage = textView.textStorage {
                                // Find this attachment in the text storage
                                textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, range, stop in
                                    if let attachment = value as? NSTextAttachment,
                                       attachment.attachmentCell === self {
                                        // Create a new element with updated content
                                        var updatedElement = self.element
                                        updatedElement.content = newImagePath
                                        
                                        // Create a new attachment with the updated element
                                        let newAttachment = NSTextAttachment()
                                        let newCell = BlockAttachmentCell(element: updatedElement)
                                        newAttachment.attachmentCell = newCell
                                        
                                        // Replace the old attachment
                                        textStorage.beginEditing()
                                        textStorage.replaceCharacters(in: range, with: NSAttributedString(attachment: newAttachment))
                                        textStorage.endEditing()
                                        
                                        stop.pointee = true
                                    }
                                }
                            }
                        }
                    )
                )
            } else {
                print("Warning: Could not get document ID for image block")
                return AnyView(
                    ImageBlockView(element: element, documentId: "")
                )
            }
            
        case .scripture:
            return AnyView(
                Text("Scripture: \(element.content)")
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            )
            
        case .dropdown:
            return AnyView(
                Text("Dropdown Option: \(element.content)")
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            )
            
        case .table:
            return AnyView(
                Text("Table: \(element.content)")
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            )
            
        case .chart:
            return AnyView(
                Text("Chart: \(element.content)")
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            )
            
        case .signature:
            return AnyView(
                Text("Signature: \(element.content)")
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            )
            
        default:
            return AnyView(
                Text("Unsupported Block Type")
            )
        }
    }
    
    private func createScriptureCard(from content: String) -> some View {
        // Parse the content string (expected format: "reference|translation|text")
        let components = content.split(separator: "|", maxSplits: 2).map(String.init)
        let reference = components.count > 0 ? components[0] : ""
        let translation = components.count > 1 ? components[1] : ""
        let text = components.count > 2 ? components[2] : content
        
        return VStack(alignment: .leading, spacing: 8) {
            Text(reference)
                .font(.headline)
            
            if !translation.isEmpty {
                Text(translation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(text)
                .font(.body)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Height Management
    
    static func defaultHeight(for type: ElementType) -> CGFloat {
        switch type {
        case .textBlock:
            return 100
        case .image:
            return 200
        case .scripture:
            return 120
        case .dropdown:
            return 44
        case .table:
            return 200
        case .chart:
            return 200
        case .signature:
            return 100
        default:
            return 44
        }
    }
    
    static func minHeight(for type: ElementType) -> CGFloat {
        switch type {
        case .textBlock:
            return 60
        case .image:
            return 100
        case .scripture:
            return 80
        case .dropdown:
            return 44
        case .table:
            return 100
        case .chart:
            return 100
        case .signature:
            return 60
        default:
            return 44
        }
    }
    
    static func maxHeight(for type: ElementType) -> CGFloat {
        switch type {
        case .image:
            return 600
        case .table:
            return 800
        case .chart:
            return 600
        default:
            return 400
        }
    }
    
    // Add handlers for delete and select
    private func handleDelete() {
        // Find the attachment range and remove it from the text view
        if let textView = hostingView?.superview as? NSTextView,
           let textStorage = textView.textStorage {
            // Search for this attachment in the text storage
            var attachmentRange = NSRange(location: NSNotFound, length: 0)
            textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, range, stop in
                if let attachment = value as? NSTextAttachment,
                   attachment.attachmentCell === self {
                    attachmentRange = range
                    stop.pointee = true
                }
            }
            
            if attachmentRange.location != NSNotFound {
                textStorage.beginEditing()
                textStorage.deleteCharacters(in: attachmentRange)
                textStorage.endEditing()
            }
        }
    }
    
    private func handleSelect() {
        // Find the attachment range and select it in the text view
        if let textView = hostingView?.superview as? NSTextView {
            // Search for this attachment in the text storage
            if let textStorage = textView.textStorage {
                var attachmentRange = NSRange(location: NSNotFound, length: 0)
                textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, range, stop in
                    if let attachment = value as? NSTextAttachment,
                       attachment.attachmentCell === self {
                        attachmentRange = range
                        stop.pointee = true
                    }
                }
                
                if attachmentRange.location != NSNotFound {
                    textView.setSelectedRange(attachmentRange)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct ImageBlockView: View {
    let element: DocumentElement
    let documentId: String
    var onImageChange: ((String) -> Void)?
    @State private var isHovering = false
    
    private func saveImage(_ image: NSImage) -> String? {
        let fileName = UUID().uuidString + ".png"
        
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let documentPath = documentsPath.appendingPathComponent(documentId)
            let imagesPath = documentPath.appendingPathComponent("Images")
            
            do {
                try FileManager.default.createDirectory(at: documentPath, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
                let fileURL = imagesPath.appendingPathComponent(fileName)
                
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let imageRep = NSBitmapImageRep(cgImage: cgImage)
                    if let imageData = imageRep.representation(using: .png, properties: [:]) {
                        try imageData.write(to: fileURL)
                        return fileName
                    }
                }
            } catch {
                print("Error saving image: \(error)")
            }
        }
        return nil
    }
    
    private func handleImageSelection(url: URL) {
        if let image = NSImage(contentsOf: url) {
            if let savedPath = saveImage(image) {
                onImageChange?(savedPath)
            }
        }
    }
    
    private func debugImageInfo(imageName: String, imageUrl: URL) {
        print("Attempting to load image:")
        print("Image name: \(imageName)")
        print("Full URL: \(imageUrl)")
        print("Document ID: \(documentId)")
        if FileManager.default.fileExists(atPath: imageUrl.path) {
            print("Image file exists at path")
        } else {
            print("Image file does not exist at path")
        }
    }
    
    private var optionsMenu: some View {
        Menu {
            if element.content.isEmpty {
                Button {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [UTType.image]
                    
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            handleImageSelection(url: url)
                        }
                    }
                } label: {
                    Label("Add Image", systemImage: "plus")
                }
            } else {
                Button {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [UTType.image]
                    
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            // Delete old image first
                            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                let documentPath = documentsPath.appendingPathComponent(documentId)
                                let imagesPath = documentPath.appendingPathComponent("Images")
                                let oldImageUrl = imagesPath.appendingPathComponent(element.content)
                                try? FileManager.default.removeItem(at: oldImageUrl)
                            }
                            handleImageSelection(url: url)
                        }
                    }
                } label: {
                    Label("Replace Image", systemImage: "photo")
                }
                
                Button {
                    if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let documentPath = documentsPath.appendingPathComponent(documentId)
                        let imagesPath = documentPath.appendingPathComponent("Images")
                        let imageUrl = imagesPath.appendingPathComponent(element.content)
                        
                        let savePanel = NSSavePanel()
                        savePanel.allowedContentTypes = [UTType.image]
                        savePanel.nameFieldStringValue = element.content
                        
                        if savePanel.runModal() == .OK {
                            if let destinationURL = savePanel.url {
                                try? FileManager.default.copyItem(at: imageUrl, to: destinationURL)
                            }
                        }
                    }
                } label: {
                    Label("Download Image", systemImage: "square.and.arrow.down")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let documentPath = documentsPath.appendingPathComponent(documentId)
                        let imagesPath = documentPath.appendingPathComponent("Images")
                        let imageUrl = imagesPath.appendingPathComponent(element.content)
                        try? FileManager.default.removeItem(at: imageUrl)
                        onImageChange?("")
                    }
                } label: {
                    Label("Delete Image", systemImage: "trash")
                }
            }
        } label: {
            Circle()
                .fill(Color(.sRGB, white: 0.3, opacity: 0.4))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                )
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(.sRGB, white: 0.95, opacity: 1))
                }
        }
        .buttonStyle(.plain)
        .opacity(isHovering ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
    
    var body: some View {
        if element.content.isEmpty {
            ZStack(alignment: .bottomTrailing) {
                Button {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [UTType.image]
                    
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            handleImageSelection(url: url)
                        }
                    }
                } label: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .buttonStyle(.plain)
                
                optionsMenu
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
            .onHover { hovering in
                isHovering = hovering
            }
        } else {
            ZStack(alignment: .bottomTrailing) {
                Button {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [UTType.image]
                    
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            handleImageSelection(url: url)
                        }
                    }
                } label: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .buttonStyle(.plain)
                
                optionsMenu
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
            .onHover { hovering in
                isHovering = hovering
            }
        }
    }
}

struct DropdownBlockView: View {
    let element: DocumentElement
    
    var body: some View {
        Menu {
            ForEach(["Option 1", "Option 2", "Option 3"], id: \.self) { option in
                Button {
                    // Action would go here
                } label: {
                    Text(option)
                }
            }
        } label: {
            HStack {
                Text(element.content.isEmpty ? "Select an option" : element.content)
                Spacer()
                Image(systemName: "chevron.down")
            }
            .padding()
        }
    }
}
#endif 
