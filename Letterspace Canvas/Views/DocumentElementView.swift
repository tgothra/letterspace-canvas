import SwiftUI
import PhotosUI
import AppKit

struct HeaderImageView: View {
    @Binding var element: DocumentElement
    @State private var headerImageHeight: CGFloat = 300
    @State private var isHovering = false
    @State private var nsImage: NSImage?
    
    var body: some View {
        Group {
            if let image = nsImage {
                GeometryReader { geo in
                    ZStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width + 96, alignment: .center)
                            .position(x: (geo.size.width + 96) / 2, y: headerImageHeight / 2)
                            .padding(.horizontal, -48)
                            .background(Color.clear)
                            .onAppear {
                                headerImageHeight = calculateHeaderImageHeight(image: image, containerWidth: geo.size.width + 96)
                            }
                            .onChange(of: geo.size.width) { oldValue, newValue in
                                headerImageHeight = calculateHeaderImageHeight(image: image, containerWidth: newValue + 96)
                            }
                    }
                    .overlay(alignment: .topTrailing) {
                        optionsMenu
                            .offset(x: -48, y: 16)
                            .opacity(isHovering ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHovering = hovering
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: headerImageHeight)
            } else {
                ImagePickerButton(element: $element)
                    .padding(.horizontal, -DesignSystem.Spacing.xl)
            }
        }
        .onChange(of: element.content) { oldValue, newValue in
            loadImage()
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        if let imageName = element.content.isEmpty ? nil : element.content,
           let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imagesPath = documentsPath.appendingPathComponent("Images")
            let imageUrl = imagesPath.appendingPathComponent(imageName)
            nsImage = NSImage(contentsOf: imageUrl)
        } else {
            nsImage = nil
        }
    }
    
    private func calculateHeaderImageHeight(image: NSImage, containerWidth: CGFloat) -> CGFloat {
        let aspectRatio = image.size.width / image.size.height
        return containerWidth / aspectRatio
    }
    
    private var optionsMenu: some View {
        Menu {
            Button(role: .destructive, action: {
                withAnimation {
                    element.content = ""
                }
            }) {
                Label("Remove", systemImage: "trash")
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
    }
}

struct ImagePickerButton: View {
    @Binding var element: DocumentElement
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.image]
            
            if panel.runModal() == .OK {
                if let url = panel.url,
                   let originalImage = NSImage(contentsOf: url) {
                    if let savedPath = saveImage(originalImage) {
                        element.content = savedPath
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
        
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imagesPath = documentsPath.appendingPathComponent("Images")
            
            do {
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
}

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
    
    var body: some View {
        Group {
            if element.type == .headerImage {
                HeaderImageView(element: $element)
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
                    .foregroundStyle(element.content.isEmpty ? Color.gray.opacity(0.3) : Color(.textColor))
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
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if element.content.isEmpty && !isFocused {
                        Text("Start typing...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                            .zIndex(1)
                    }
                    
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
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isFocused = true
                }
                .background(Color.clear)
                .onAppear {
                    if element.content.isEmpty {
                        isFocused = false  // Start with placeholder visible
                    }
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
                        .foregroundStyle(element.content.isEmpty ? Color.gray.opacity(0.5) : Color(.textColor))
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
            ScriptureBlock(
                document: $document,
                content: $element.content,
                element: $element
            )
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .id(element.id)
            
        case .headerImage:
            HeaderImageView(element: $element)
            
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
                    let imagesPath = documentsPath.appendingPathComponent("Images")
                    let imageUrl = imagesPath.appendingPathComponent(imageName)
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
                } else {
                    ImagePickerButton(element: $element)
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
                    .foregroundStyle(element.date == nil ? Color.gray.opacity(0.5) : Color(.textColor))
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
        
        let font = NSFont.systemFont(ofSize: baseSize, weight: .bold)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        
        if size.width > width {
            let scale = width / size.width
            return max(baseSize * scale, minSize)
        }
        
        return baseSize
    }
} 