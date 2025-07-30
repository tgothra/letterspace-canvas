import SwiftUI

// MARK: - Block Options Menu
private struct BlockOptionsMenu: View {
    let block: CanvasBlock
    @ObservedObject var canvas: DocumentCanvas
    @State private var isHovered = false
    
    var body: some View {
        Menu {
            Menu("Add block") {
                Button(action: {
                    canvas.insertNewBlock(.textBlock, at: block.position + 1)
                }) {
                    Label("Text", systemImage: "text.alignleft")
                }
                
                Button(action: {
                    canvas.insertNewBlock(.image, at: block.position + 1)
                }) {
                    Label("Image", systemImage: "photo")
                }
                
                Button(action: {
                    canvas.insertNewBlock(.scripture, at: block.position + 1)
                }) {
                    Label("Bible", systemImage: "book")
                }
                
                Button(action: {
                    canvas.insertNewBlock(.table, at: block.position + 1)
                }) {
                    Label("Table", systemImage: "tablecells")
                }
                
                Button(action: {
                    canvas.insertNewBlock(.chart, at: block.position + 1)
                }) {
                    Label("Chart", systemImage: "chart.bar")
                }
                
                Button(action: {
                    canvas.insertNewBlock(.date, at: block.position + 1)
                }) {
                    Label("Date", systemImage: "calendar")
                }
                
                Button(action: {
                    canvas.insertNewBlock(.dropdown, at: block.position + 1)
                }) {
                    Label("Dropdown", systemImage: "chevron.down.circle")
                }
                
                Button(action: {
                    canvas.insertNewBlock(.multiSelect, at: block.position + 1)
                }) {
                    Label("Multi-select", systemImage: "checkmark.circle")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                // Delete block functionality will be added later
            }) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            ZStack {
                // Background circle with white fill and gray border
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                // Three dots
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 3, height: 3)
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 3, height: 3)
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 3, height: 3)
                }
            }
            .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .opacity(isHovered ? 1 : 0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Canvas Block View
private struct CanvasBlockView: View {
    let block: CanvasBlock
    let canvas: DocumentCanvas
    @Binding var document: Letterspace_CanvasDocument
    @Binding var selectedElement: UUID?
    @Binding var draggedBlock: CanvasBlock?
    @Binding var dropLocation: CGPoint?
    @State private var showCommandPalette = false
    @State private var commandSearchText = ""
    @State private var commandPosition: CGPoint = .zero
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            switch block.type {
            case .text(let attributedString):
                #if os(macOS)
                CustomTextEditor(
                    text: Binding(
                        get: { attributedString },
                        set: { newValue in
                            canvas.updateText(newValue, at: block.position)
                        }
                    ),
                    isFocused: selectedElement == block.id,
                    onSelectionChange: { isSelected in
                        if isSelected {
                            selectedElement = block.id
                        }
                    },
                    showToolbar: .constant(true),
                    onAtCommand: { point in
                        showCommandPalette = true
                        commandPosition = point
                    }
                )
                #elseif os(iOS)
                // iOS 26 Native Text Editor with Floating Header
                if #available(iOS 26.0, *) {
                    iOS26NativeTextEditorWithToolbar(document: Binding(
                        get: {
                            // Create a temporary document with this text block
                            var tempDoc = Letterspace_CanvasDocument()
                            var element = DocumentElement(type: .textBlock)
                            element.content = attributedString.string
                            tempDoc.elements = [element]
                            return tempDoc
                        },
                        set: { (newDoc: Letterspace_CanvasDocument) in
                            if let updatedElement = newDoc.elements.first {
                                let newAttributedString = updatedElement.attributedContent ?? NSAttributedString(string: updatedElement.content)
                                canvas.updateText(newAttributedString, at: block.position)
                            }
                        }
                    ))
                    .onTapGesture {
                        selectedElement = block.id
                    }
                } else {
                    // Fallback for older iOS versions
                    TextEditor(text: Binding(
                        get: { attributedString.string },
                        set: { newValue in
                            let newAttributedString = NSAttributedString(string: newValue)
                            canvas.updateText(newAttributedString, at: block.position)
                        }
                    ))
                    .font(.body)
                    .onTapGesture {
                        selectedElement = block.id
                    }
                }
                #endif
            case .element(let element):
                DocumentElementView(
                    document: $document,
                    element: Binding(
                        get: { element },
                        set: { _ in }
                    ),
                    selectedElement: $selectedElement
                )
                .padding(.vertical, 8)
            }
            
            BlockOptionsMenu(block: block, canvas: canvas)
                .opacity(isHovered ? 1 : 0)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .overlay(DragHandle(block: block, draggedBlock: $draggedBlock, canvas: canvas))
        .overlay {
            // Command Palette
            CommandPalette(
                isPresented: $showCommandPalette,
                searchText: $commandSearchText,
                position: commandPosition,
                onSelect: { elementType in
                    // Insert new block after current block
                    canvas.insertNewBlock(elementType, at: block.position + 1)
                    
                    // Update text to remove @ command
                    if case .text(let attributedString) = block.type {
                        if let atIndex = attributedString.string.lastIndex(of: "@") {
                            let newText = String(attributedString.string[..<atIndex])
                            canvas.updateText(NSAttributedString(string: newText), at: block.position)
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Drag Handle
private struct DragHandle: View {
    let block: CanvasBlock
    @Binding var draggedBlock: CanvasBlock?
    let canvas: DocumentCanvas
    
    var body: some View {
        HStack {
            Spacer()
            Menu {
                Button(action: {
                    // Add block after
                }) {
                    Label("Add block after", systemImage: "plus")
                }
                
                Button(action: {
                    // Move block
                }) {
                    Label("Move", systemImage: "arrow.up.arrow.down")
                }
                
                Button(action: {
                    // Delete block
                }) {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
                .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Canvas Section View
private struct CanvasSectionView: View {
    let section: DocumentSection
    let canvas: DocumentCanvas
    @Binding var document: Letterspace_CanvasDocument
    @Binding var selectedElement: UUID?
    @Binding var draggedBlock: CanvasBlock?
    @Binding var dropLocation: CGPoint?
    
    var body: some View {
        switch section {
        case .fixed(let element):
            DocumentElementView(
                document: $document,
                element: Binding(
                    get: { element },
                    set: { _ in }
                ),
                selectedElement: $selectedElement
            )
            .padding(.vertical, 8)
        case .canvas(let blocks):
            ForEach(blocks) { block in
                CanvasBlockView(
                    block: block,
                    canvas: canvas,
                    document: $document,
                    selectedElement: $selectedElement,
                    draggedBlock: $draggedBlock,
                    dropLocation: $dropLocation
                )
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: dropLocation) { _, location in
                                if let location = location,
                                   let draggedBlock = draggedBlock,
                                   draggedBlock.id != block.id {
                                    let blockFrame = geo.frame(in: .global)
                                    let blockCenter = blockFrame.midY
                                    
                                    if location.y < blockCenter && location.y > blockFrame.minY {
                                        canvas.moveBlock(from: draggedBlock.position, to: block.position)
                                    } else if location.y > blockCenter && location.y < blockFrame.maxY {
                                        canvas.moveBlock(from: draggedBlock.position, to: block.position + 1)
                                    }
                                }
                            }
                    }
                )
            }
        }
    }
}

// MARK: - Custom Layout
struct VerticalStackLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.reduce(0) { result, subview in
            let size = subview.sizeThatFits(.unspecified)
            return result + size.height
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let frame = CGRect(x: bounds.minX, y: y, width: bounds.width, height: size.height)
            subview.place(at: frame.origin, proposal: ProposedViewSize(frame.size))
            y += size.height
        }
    }
}

// MARK: - Main View
struct DocumentCanvasView: View {
    @ObservedObject var canvas: DocumentCanvas
    @Binding var document: Letterspace_CanvasDocument
    @Binding var selectedElement: UUID?
    @State private var isDragging = false
    @State private var draggedBlockIndex: Int?
    @State private var dragPosition: CGPoint = .zero
    @Environment(\.themeColors) var theme
    
    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            ZStack {
                // Background
                theme.background
                    .ignoresSafeArea()
                
                // Canvas Content
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(canvas.sections) { section in
                        CanvasSectionView(
                            section: section,
                            canvas: canvas,
                            document: $document,
                            selectedElement: $selectedElement,
                            draggedBlock: .constant(nil),
                            dropLocation: .constant(nil)
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentCanvasDidUpdate"))) { _ in
            // Update the document when canvas changes
            document = canvas.toDocument()
        }
    }
} 