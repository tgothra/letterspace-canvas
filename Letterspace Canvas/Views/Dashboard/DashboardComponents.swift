import SwiftUI

// MARK: - Dashboard Components

struct AddHeaderButtonBackground: View {
    let theme: ThemeColors
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}

struct ScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // No updates needed
    }
}

struct ScrollViewConfigurator_iOS: UIViewRepresentable {
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // No updates needed
    }
}

struct CustomScrollModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
    }
}

struct DocumentNameView: View {
    let document: Letterspace_CanvasDocument
    let theme: ThemeColors
    
    var body: some View {
        Text(document.title.isEmpty ? "Untitled" : document.title)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(theme.primary)
            .lineLimit(1)
    }
}

struct CarouselHeaderStyling: ViewModifier {
    let theme: ThemeColors
    let colorScheme: ColorScheme
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(theme.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
            )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        return _path(rect)
    }
} 