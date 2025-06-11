import SwiftUI

#if os(macOS)
struct BlockResizeHandle: View {
    let position: ResizePosition
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    enum ResizePosition {
        case top
        case bottom
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .overlay(
                Rectangle()
                    .fill(Color.accentColor.opacity(isDragging ? 0.3 : 0.0))
                    .frame(height: 2)
            )
            .contentShape(Rectangle())
            .onHover { _ in
                NSCursor.resizeUpDown.push()
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        let delta = value.translation.height - dragOffset
                        dragOffset = value.translation.height
                        
                        switch position {
                        case .top:
                            let newHeight = height - delta
                            if newHeight >= minHeight && newHeight <= maxHeight {
                                height = newHeight
                            }
                        case .bottom:
                            let newHeight = height + delta
                            if newHeight >= minHeight && newHeight <= maxHeight {
                                height = newHeight
                            }
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragOffset = 0
                        NSCursor.pop()
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
}

struct ResizableBlock<Content: View>: View {
    let content: Content
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    @State private var isHovering = false
    
    init(
        height: Binding<CGFloat>,
        minHeight: CGFloat = 44,
        maxHeight: CGFloat = 600,
        @ViewBuilder content: () -> Content
    ) {
        self._height = height
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            BlockResizeHandle(
                position: .top,
                height: $height,
                minHeight: minHeight,
                maxHeight: maxHeight
            )
            .opacity(isHovering ? 1 : 0)
            
            content
                .frame(height: height)
            
            BlockResizeHandle(
                position: .bottom,
                height: $height,
                minHeight: minHeight,
                maxHeight: maxHeight
            )
            .opacity(isHovering ? 1 : 0)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}
#endif 