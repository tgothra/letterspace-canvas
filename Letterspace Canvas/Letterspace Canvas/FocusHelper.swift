#if os(macOS)
import SwiftUI

// Helper to dismiss keyboard and clear first responder in macOS
extension NSApplication {
    func endEditing() {
        sendAction(#selector(NSResponder.resignFirstResponder), to: nil, from: nil)
    }
}

// Extension to add a view modifier for clicking outside
extension View {
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            NSApplication.shared.endEditing()
        }
    }
}

// Struct for hiding a specific dropdown on tap
struct HideDropdownOnTapModifier: ViewModifier {
    @Binding var isVisible: Bool

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                NSApplication.shared.endEditing()
                isVisible = false
            }
    }
}

extension View {
    func hideDropdownOnTap(_ isVisible: Binding<Bool>) -> some View {
        self.modifier(HideDropdownOnTapModifier(isVisible: isVisible))
    }
}
#endif
