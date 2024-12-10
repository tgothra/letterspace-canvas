import SwiftUI

struct FloatingToolbar: View {
    @Environment(\.themeColors) var theme
    @State private var isExpanded = false
    @Binding var document: Letterspace_CanvasDocument
    
    let blocks = [
        ("text.alignleft", ElementType.textBlock),
        ("photo", ElementType.image),
        ("tablecells", ElementType.table),
        ("list.bullet", ElementType.dropdown),
        ("book.fill", ElementType.scripture)
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Block menu
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(blocks, id: \.0) { icon, type in
                        FloatingToolbarButton(icon: icon, action: {
                            document.elements.append(DocumentElement(type: type))
                            isExpanded = false
                        })
                    }
                }
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 20)),
                    removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 20))
                ))
                .offset(y: -44) // Just enough space for the menu to appear above the button
            }
            
            // Main plus button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .rotationEffect(Angle(degrees: isExpanded ? 45 : 0))
        }
    }
}

struct FloatingToolbarButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isHovering ? theme.accent : .white)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    FloatingToolbar(document: .constant(Letterspace_CanvasDocument()))
        .padding()
        .background(Color.gray)
} 