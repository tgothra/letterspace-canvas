import SwiftUI

/// A view modifier that prepares content for glass sheet presentation
struct GlassSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // Glass effect background
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .ignoresSafeArea()
            
            // Content with glass-compatible styling
            content
                .background(.clear)
                .environment(\.colorScheme, .light) // Force light mode for better glass visibility
        }
        .presentationBackground(.clear)
    }
}

extension View {
    /// Apply glass sheet styling to a view
    func glassSheet() -> some View {
        modifier(GlassSheetModifier())
    }
}
