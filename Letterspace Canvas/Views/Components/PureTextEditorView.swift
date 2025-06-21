import SwiftUI

// MARK: - Pure Text Editor View (No Headers, No Document Structure)
struct PureTextEditorView: View {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    #if os(macOS)
                    // Ultra-minimal static editor with NO dynamic height calculations
                    StaticTextEditor(document: $document)
                        .frame(width: min(714, geometry.size.width - 40))
                        .frame(minHeight: max(400, geometry.size.height - 40))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
                                .shadow(
                                    color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.04),
                                    radius: 8,
                                    x: 0,
                                    y: 2
                                )
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    #else
                    // iOS fallback
                    TextEditor(text: Binding(
                        get: {
                            document.elements
                                .filter { $0.type == .textBlock }
                                .compactMap { $0.content }
                                .joined(separator: "\n\n")
                        },
                        set: { newValue in
                            document.elements.removeAll { $0.type == .textBlock }
                            if !newValue.isEmpty {
                                let textElement = DocumentElement(
                                    type: .textBlock,
                                    content: newValue
                                )
                                document.elements.append(textElement)
                            }
                        }
                    ))
                    .font(.system(size: 15))
                    .frame(minHeight: 400)
                    .padding()
                    #endif
                }
            }
        }
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.08) : Color(.sRGB, white: 0.96))
        .navigationTitle("Pure Text Editor")
        .onAppear {
            print("🎯 PURE EDITOR: Showing completely header-free text editor")
        }
    }
} 