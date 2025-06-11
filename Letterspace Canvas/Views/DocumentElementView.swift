import SwiftUI
import PhotosUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

private struct DocumentSaveKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var documentSave: (() -> Void)? {
        get { self[DocumentSaveKey.self] }
        set { self[DocumentSaveKey.self] = newValue }
    }
}

#if os(macOS)
struct ImagePickerButton: View {
    @Binding var element: DocumentElement
    @Binding var document: Letterspace_CanvasDocument
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [UTType.image]
            
            if panel.runModal() == .OK {
                if let url = panel.url,
                   let originalImage = NSImage(contentsOf: url) {
                    print("Selected image from URL: \(url)")
                    if let savedPath = saveImage(originalImage) {
                        print("Saved image to path: \(savedPath)")
                        
                        // Update the element content
                        element.content = savedPath
                        
                        // Update the document's elements array
                        if let index = document.elements.firstIndex(where: { $0.id == element.id }) {
                            print("Updating existing header image element at index: \(index)")
                            document.elements[index] = element
                        } else {
                            print("Adding new header image element")
                            // Create a new header image element if one doesn't exist
                            var headerElement = DocumentElement(type: .headerImage)
                            headerElement.content = savedPath
                            document.elements.insert(headerElement, at: 0)
                        }
                        
                        // Save the document
                        print("Saving document with updated elements: \(document.elements)")
                        document.save()
                    }
                }
            }
        }) {
            ZStack {
                Color.black.opacity(0.1)
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Add Header Image")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .buttonStyle(.plain)
    }
    
    private func saveImage(_ image: NSImage) -> String? {
        let fileName = UUID().uuidString + ".png"
        print("Generating new image filename: \(fileName)")
        
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let documentPath = documentsPath.appendingPathComponent("\(document.id)")
            let imagesPath = documentPath.appendingPathComponent("Images")
            
            do {
                try FileManager.default.createDirectory(at: documentPath, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
                let fileURL = imagesPath.appendingPathComponent(fileName)
                print("Saving image to URL: \(fileURL)")
                
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let imageRep = NSBitmapImageRep(cgImage: cgImage)
                    if let imageData = imageRep.representation(using: .png, properties: [:]) {
                        try imageData.write(to: fileURL)
                        print("Successfully wrote image data to file")
                        return fileName
                    }
                }
            } catch {
                print("Error saving image: \(error)")
            }
        }
        return nil
    }
}
#elseif os(iOS)
struct ImagePickerButton: View {
    @Binding var element: DocumentElement
    @Binding var document: Letterspace_CanvasDocument
    
    var body: some View {
        Button(action: {
            // TODO: Implement iOS image picker using PHPickerViewController
            print("iOS image picker not yet implemented")
        }) {
            ZStack {
                Color.black.opacity(0.1)
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Add Header Image")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .buttonStyle(.plain)
    }
}
#endif

struct CustomTitleTextField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 40, weight: .bold))
            .textFieldStyle(.plain)
            .foregroundColor(.primary)
            .onSubmit(onSubmit)
    }
}

struct DocumentElementView: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var element: DocumentElement
    @Binding var selectedElement: UUID?
    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var showToolbar = false
    var initialFocus: Bool = false
    
    // Animation state for header image
    @State private var isHeaderImageAppeared = false
    @AppStorage("hasPerformedInitialTransition") private var hasPerformedInitialTransition = false
    
    var body: some View {
        Group {
            if element.type == .headerImage {
                HeaderImageView(element: $element, document: $document)
                    .environment(\.documentSave, {
                        document.save()
                    })
                    .opacity(isHeaderImageAppeared ? 1 : 0)
                    .onAppear {
                        // Only animate the first time a document is opened in a session
                        if !hasPerformedInitialTransition {
                            // A short delay to ensure the document view has rendered
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isHeaderImageAppeared = true
                                }
                                // Mark that we've done the transition
                                hasPerformedInitialTransition = true
                            }
                        } else {
                            // Immediately show if not first load
                            isHeaderImageAppeared = true
                        }
                    }
            } else {
                HStack(spacing: 0) {
                    ZStack(alignment: .trailing) {
                        contentView
                            .padding(.top, element.type == .title ? 96 : element.type == .scripture ? 0 : 8)
                            .padding(.bottom, element.type == .title ? 64 : element.type == .scripture ? 0 : 8)
                            .padding(.horizontal, element.type == .scripture ? 0 : 12)
                            .background(Color.clear)
                    }
                    
                    // Options button area
                    ZStack {
                        Color.clear
                            .frame(width: 40)  // Wide enough area for the button
                        
                        optionsMenu
                            .opacity(isHovering ? 1 : 0)
                    }
                }
                .contentShape(Rectangle())  // Make entire HStack hoverable
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // Only set focus for title block in new documents
            if element.type == .title && initialFocus {
                isFocused = true
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch element.type {
        case .header:
            GeometryReader { geo in
                TextField(element.placeholder, text: $element.content)
                    .font(.system(size: calculateFontSize(for: element.content, in: geo.size.width - 48), weight: .bold))
                    #if os(macOS)
                    .foregroundStyle(element.content.isEmpty ? Color.gray.opacity(0.3) : Color(.textColor))
                    #elseif os(iOS)
                    .foregroundStyle(element.content.isEmpty ? Color.gray.opacity(0.3) : Color(.label))
                    #endif
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .focused($isFocused)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                    .textFieldStyle(.plain)
                    .border(.clear)
                    .tint(theme.accent)
                    .onChange(of: element.content) { oldValue, newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            document.updateTitleFromHeader()
                        }
                    }
            }
            .frame(height: 70)
            
        case .subheader:
            GeometryReader { geo in
                TextField(element.placeholder, text: $element.content)
                    .font(.system(size: calculateFontSize(for: element.content, in: geo.size.width - 48), weight: .semibold))
                    #if os(macOS)
                    .foregroundStyle(element.content.isEmpty ? Color.gray.opacity(0.3) : Color(.textColor))
                    #elseif os(iOS)
                    .foregroundStyle(element.content.isEmpty ? Color.gray.opacity(0.3) : Color(.label))
                    #endif
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .focused($isFocused)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 24)
                    .textFieldStyle(.plain)
                    .border(.clear)
                    .tint(theme.accent)
            }
            .frame(height: 50)
            
        case .title:
            CustomTitleTextField(
                text: $element.content,
                placeholder: element.placeholder,
                onSubmit: {
                    if let firstTextBlock = document.elements.first(where: { $0.type == .textBlock }) {
                        selectedElement = firstTextBlock.id
                    } else {
                        let newBlock = DocumentElement(type: .textBlock)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            document.elements.append(newBlock)
                            selectedElement = newBlock.id
                        }
                    }
                }
            )
            .frame(height: 72)
            .padding(.top, 24)
            .padding(.bottom, 8)
            
        case .textBlock:
            VStack(alignment: .leading, spacing: 0) {
                if element.content.isEmpty && !isFocused {
                    // Placeholder state
                    Button(action: {
                        isFocused = true
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(element.placeholder)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.gray.opacity(0.3))
                                .padding(.horizontal, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                } else {
                    #if os(macOS)
                    CustomTextEditor(
                        text: Binding(
                            get: {
                                if let attributedContent = element.attributedContent {
                                    return attributedContent
                                } else {
                                    return NSAttributedString(
                                        string: element.content,
                                        attributes: [
                                            .font: NSFont.systemFont(ofSize: 16),
                                            .foregroundColor: NSColor.textColor
                                        ]
                                    )
                                }
                            },
                            set: { newValue in
                                element.attributedContent = newValue
                                element.content = newValue.string
                            }
                        ),
                        isFocused: isFocused,
                        onSelectionChange: { hasSelection in
                            print("Selection changed: \(hasSelection)")
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showToolbar = hasSelection
                            }
                        },
                        showToolbar: $showToolbar
                    )
                    .padding(.horizontal, 20)
                    #elseif os(iOS)
                    // iOS text editor - simpler implementation for now
                    TextEditor(text: $element.content)
                        .font(.system(size: 16))
                        .padding(.horizontal, 20)
                        .focused($isFocused)
                    #endif
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.clear)
            .layoutPriority(1)
            
        case .dropdown:
            Menu {
                ForEach(element.options, id: \.self) { option in
                    Button(option) {
                        element.content = option
                    }
                }
            } label: {
                HStack {
                    Text(element.content.isEmpty ? "Select an option" : element.content)
                        .font(.system(size: 16))
                        #if os(macOS)
                        .foregroundStyle(element.content.isEmpty ? Color.gray.opacity(0.5) : Color(.textColor))
                        #elseif os(iOS)
                        .foregroundStyle(element.content.isEmpty ? Color.gray.opacity(0.5) : Color(.label))
                        #endif
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(Color.gray)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            
        case .date:
            dateButton
            
        case .multiSelect:
            MultiSelectView(selectedOptions: $element.content, options: $element.options)
            
        case .chart:
            ChartView(content: $element.content)
            
        case .signature:
            SignaturePad(signature: $element.content)
            
        case .table:
            TableEditor(content: $element.content)
            
        case .scripture:
            #if os(macOS)
            Group {
                createScriptureCard(from: element.content)
                    .padding(.vertical, element.isInline ? 4 : 8)
                    .id(element.id)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, -20)
            }
            .environment(\.font, nil)  // Prevent font inheritance
            .fixedSize(horizontal: false, vertical: true)  // Allow vertical growth
            #elseif os(iOS)
            // Simple text display for iOS until ScriptureCard is made cross-platform
            VStack(alignment: .leading, spacing: 8) {
                Text("Scripture Reference")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(element.content)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            #endif
            
            // Options button area
            optionsMenu
                .opacity(isHovering ? 1 : 0)
                .offset(x: -20)
            
        case .headerImage:
            HeaderImageView(element: $element, document: $document)
            
        case .image:
            GeometryReader { geo in
                if element.content == "Separator Icon" {
                    Image("Separator Icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 1)
                        .padding(.vertical, 8)
                } else if let imageName = element.content.isEmpty ? nil : element.content,
                          let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let documentPath = documentsPath.appendingPathComponent("\(document.id)")
                    let imagesPath = documentPath.appendingPathComponent("Images")
                    let imageUrl = imagesPath.appendingPathComponent(imageName)
                    
                    #if os(macOS)
                    if let nsImage = NSImage(contentsOf: imageUrl) {
                        let aspectRatio = nsImage.size.width / nsImage.size.height
                        let height = geo.size.width / aspectRatio
                        
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .background(Color.black.opacity(0.1))
                    }
                    #elseif os(iOS)
                    if let uiImage = UIImage(contentsOfFile: imageUrl.path) {
                        let aspectRatio = uiImage.size.width / uiImage.size.height
                        let height = geo.size.width / aspectRatio
                        
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .background(Color.black.opacity(0.1))
                    }
                    #endif
                } else {
                    ImagePickerButton(element: $element, document: $document)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(0)
        }
    }
    
    private var dateButton: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.gray)
                Text(element.date?.formatted(date: .long, time: .shortened) ?? "Select date")
                    .font(.system(size: 16))
                    #if os(macOS)
                    .foregroundStyle(element.date == nil ? Color.gray.opacity(0.5) : Color(.textColor))
                    #elseif os(iOS)
                    .foregroundStyle(element.date == nil ? Color.gray.opacity(0.5) : Color(.label))
                    #endif
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
    }
    
    private var optionsMenu: some View {
        Menu {
            Button(role: .destructive, action: {
                withAnimation {
                    if let index = document.elements.firstIndex(where: { $0.id == element.id }) {
                        document.elements.remove(at: index)
                    }
                }
            }) {
                Label("Remove", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .frame(width: 32, height: 32)
    }
    
    private func calculateFontSize(for text: String, in width: CGFloat) -> CGFloat {
        let baseSize: CGFloat = 48
        let minSize: CGFloat = 24
        
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: baseSize, weight: .bold)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        
        if size.width > width {
            let scale = width / size.width
            return max(baseSize * scale, minSize)
        }
        
        return baseSize
        #elseif os(iOS)
        let font = UIFont.systemFont(ofSize: baseSize, weight: .bold)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        
        if size.width > width {
            let scale = width / size.width
            return max(baseSize * scale, minSize)
        }
        
        return baseSize
        #endif
    }
    
    #if os(macOS)
    private func createScriptureCard(from content: String) -> ScriptureCard {
        // Parse the content string (expected format: "reference|translation|text")
        let components = content.split(separator: "|", maxSplits: 2).map(String.init)
        let scriptureElement = ScriptureElement(
            reference: components.count > 0 ? components[0] : "",
            translation: components.count > 1 ? components[1] : "",
            text: components.count > 2 ? components[2] : content
        )
        
        // Always create fresh formatting, ignore any stored attributedContent
        return ScriptureCard(content: scriptureElement)
    }
    #endif
} 