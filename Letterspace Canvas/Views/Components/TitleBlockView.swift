import SwiftUI

struct TitleBlockView: View {
    let title: String
    let isSelected: Bool
    let onUpdate: (String) -> Void
    
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    
    var body: some View {
        ZStack(alignment: .leading) {
            if title.isEmpty {
                Text("Untitled")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.gray.opacity(0.5))
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            #if os(macOS)
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
            #elseif os(iOS)
            TextEditor(text: Binding(
                get: { title },
                set: { newValue in onUpdate(newValue) }
            ))
            .font(.system(size: 32, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            #endif
        }
    }
} 