import AppKit
import SwiftUI

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
            let attributedString = NSAttributedString(
                string: element.content,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 16),
                    .foregroundColor: NSColor.textColor
                ]
            )
            return AnyView(
                CustomTextEditor(
                    text: .constant(attributedString),
                    isFocused: false,
                    onSelectionChange: { _ in },
                    showToolbar: .constant(false), onAtCommand: nil
                )
            )
            
        case .image:
            return AnyView(
                ImageBlockView(element: element)
            )
            
        case .scripture:
            return AnyView(
                ScriptureBlock(
                    document: .constant(Letterspace_CanvasDocument()),
                    content: .constant(element.content),
                    element: .constant(element)
                )
            )
            
        case .dropdown:
            return AnyView(
                DropdownBlockView(element: element)
            )
            
        case .table:
            return AnyView(
                TableEditor(content: .constant(element.content))
            )
            
        case .chart:
            return AnyView(
                ChartView(content: .constant(element.content))
            )
            
        case .signature:
            return AnyView(
                SignaturePad(signature: .constant(element.content))
            )
            
        default:
            return AnyView(
                Text("Unsupported Block Type")
            )
        }
    }
    
    // MARK: - Height Management
    
    static func defaultHeight(for type: ElementType) -> CGFloat {
        switch type {
        case .textBlock:
            return 100
        case .image:
            return 200
        case .scripture:
            return 150
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
            return 100
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
}

// MARK: - Helper Views

struct ImageBlockView: View {
    let element: DocumentElement
    
    var body: some View {
        if let imageName = element.content.isEmpty ? nil : element.content,
           let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imagesPath = documentsPath.appendingPathComponent("Images")
            let imageUrl = imagesPath.appendingPathComponent(imageName)
            if let nsImage = NSImage(contentsOf: imageUrl) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
}

struct DropdownBlockView: View {
    let element: DocumentElement
    
    var body: some View {
        Menu {
            ForEach(element.options, id: \.self) { option in
                Button(option) { }
            }
        } label: {
            HStack {
                Text(element.content.isEmpty ? "Select an option" : element.content)
                Spacer()
                Image(systemName: "chevron.down")
            }
            .padding()
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
} 
