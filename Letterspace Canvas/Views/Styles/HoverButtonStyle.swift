import SwiftUI 
struct HoverButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#22c27d").opacity(isHovering ? 0.15 : 0))
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
