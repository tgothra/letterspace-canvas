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
            // iOS 26 Native Text Editor with Floating Header for titles
            if #available(iOS 26.0, *) {
                iOS26NativeTextEditorWithToolbar(document: Binding(
                    get: {
                        var tempDoc = Letterspace_CanvasDocument()
                        var element = DocumentElement(type: .textBlock)
                        element.content = title
                        tempDoc.elements = [element]
                        return tempDoc
                    },
                    set: { (newDoc: Letterspace_CanvasDocument) in
                        if let updatedElement = newDoc.elements.first {
                            onUpdate(updatedElement.content)
                        }
                    }
                ))
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Fallback for older iOS versions
                TextEditor(text: Binding(
                    get: { title },
                    set: { newValue in onUpdate(newValue) }
                ))
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            #endif
        }
    }
} 

