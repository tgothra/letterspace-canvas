import SwiftUI

struct TitleBlockView: View {
    let title: String
    let isSelected: Bool
    let onUpdate: (String) -> Void
    
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    
    var body: some View {
        CustomTextEditor(
            text: Binding(
                get: { NSAttributedString(string: title) },
                set: { newValue in onUpdate(newValue.string) }
            ),
            isFocused: isSelected,
            onSelectionChange: { _ in },
            showToolbar: .constant(false)
        )
        .font(.system(size: 32, weight: .bold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .placeholder(when: title.isEmpty) {
            Text("Untitled")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.vertical, 24)
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
} 