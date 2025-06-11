struct TextFormattingToolbar: View {
    var onBold: () -> Void
    var onItalic: () -> Void
    var onUnderline: (Color) -> Void
    var onLink: () -> Void
    var onHighlight: (Color) -> Void
    var onTextColor: (Color) -> Void
    var onBulletList: () -> Void
    var onNumberedList: () -> Void
    var onTextSize: (CGFloat) -> Void
    var onAlignment: (TextAlignment) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            FormatButton(icon: "textformat.size", action: onBold)
            FormatButton(icon: "italic", action: onItalic)
            FormatButton(icon: "underline", action: { onUnderline(.white) })
            FormatButton(icon: "link", action: onLink)
            FormatButton(icon: "list.bullet", action: onBulletList)
            FormatButton(icon: "list.number", action: onNumberedList)
            FormatButton(icon: "link.badge.plus", action: { onTextColor(.white) })
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(white: 0.2, opacity: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct FormatButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isHovered ? .white : .white.opacity(0.8))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.1)) {
                self.isHovered = isHovered
            }
        }
    }
} 