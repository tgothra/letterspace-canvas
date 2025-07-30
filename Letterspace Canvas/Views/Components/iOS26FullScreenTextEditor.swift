#if os(iOS)
import SwiftUI
import UIKit

// MARK: - iOS 26 Full Screen Text Editor with Floating Header
@available(iOS 26.0, *)
struct iOS26FullScreenTextEditor: View {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    @FocusState private var isTextEditorFocused: Bool
    
    // Floating header states
    @State private var isEditingFloatingTitle: Bool = false
    @State private var isEditingFloatingSubtitle: Bool = false
    @State private var floatingTitleText: String = ""
    @State private var floatingSubtitleText: String = ""
    @FocusState private var isFloatingTitleFocused: Bool
    @FocusState private var isFloatingSubtitleFocused: Bool
    
    // Header image state
    @State private var headerImage: UIImage?
    @State private var showImageActionSheet: Bool = false
    
    // Paper dimensions
    private let paperWidth: CGFloat = 752
    
    var body: some View {
        ZStack {
            // Full screen text editor
            VStack(spacing: 0) {
                // Floating header
                floatingHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                // Full screen text editor
                fullScreenTextEditor
            }
        }
        .onAppear {
            loadDocumentContent()
            setupFloatingHeader()
        }
    }
    
    // MARK: - Floating Header
    private var floatingHeader: some View {
        ZStack {
            // Glass effect background
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .frame(width: paperWidth - 32, height: 80)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 0.25) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 0.25))
                    .frame(width: paperWidth - 32, height: 80)
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
            }
            
            // Header content
            HStack(spacing: 12) {
                // Image thumbnail
                Button(action: {
                    showImageActionSheet = true
                }) {
                    if let headerImage = headerImage {
                        Image(uiImage: headerImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .buttonStyle(.plain)
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    if isEditingFloatingTitle {
                        TextField("Enter title", text: $floatingTitleText)
                            .font(.system(size: 18, weight: .semibold))
                            .textFieldStyle(.plain)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .focused($isFloatingTitleFocused)
                            .onSubmit {
                                document.title = floatingTitleText
                                document.save()
                                isEditingFloatingTitle = false
                            }
                            .onAppear {
                                floatingTitleText = document.title
                                isFloatingTitleFocused = true
                            }
                    } else {
                        Button(action: {
                            floatingTitleText = document.title
                            isEditingFloatingTitle = true
                        }) {
                            Text(document.title.isEmpty ? "Untitled" : document.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Subtitle
                    if isEditingFloatingSubtitle {
                        TextField("Enter subtitle", text: $floatingSubtitleText)
                            .font(.system(size: 14, weight: .regular))
                            .textFieldStyle(.plain)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                            .focused($isFloatingSubtitleFocused)
                            .onSubmit {
                                document.subtitle = floatingSubtitleText
                                document.save()
                                isEditingFloatingSubtitle = false
                            }
                            .onAppear {
                                floatingSubtitleText = document.subtitle
                                isFloatingSubtitleFocused = true
                            }
                    } else {
                        Button(action: {
                            floatingSubtitleText = document.subtitle
                            isEditingFloatingSubtitle = true
                        }) {
                            Text(document.subtitle.isEmpty ? "Add subtitle" : document.subtitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 80)
        .frame(maxWidth: paperWidth)
    }
    
    // MARK: - Full Screen Text Editor
    private var fullScreenTextEditor: some View {
        TextEditor(text: $attributedText, selection: $selection)
            .focused($isTextEditorFocused)
            .font(.system(size: 16))
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .onAppear {
                isTextEditorFocused = true
            }
            .onChange(of: attributedText) { _, newValue in
                saveToDocument(newValue)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    HStack(spacing: 16) {
                        // Bold button
                        Button("Bold", systemImage: "bold") {
                            applyBold()
                        }
                        .frame(width: 32, height: 32)
                        
                        // Italic button
                        Button("Italic", systemImage: "italic") {
                            applyItalic()
                        }
                        .frame(width: 32, height: 32)
                        
                        // Underline button
                        Button("Underline", systemImage: "underline") {
                            applyUnderline()
                        }
                        .frame(width: 32, height: 32)
                        
                        Spacer()
                        
                        // Done button
                        Button("Done") {
                            isTextEditorFocused = false
                        }
                    }
                }
            }
    }
    
    // MARK: - Document Management
    private func loadDocumentContent() {
        if let element = document.elements.first(where: { $0.type == .textBlock }) {
            if let data = element.rtfData {
                do {
                    attributedText = try JSONDecoder().decode(AttributedString.self, from: data)
                } catch {
                    if let nsAttributedString = try? NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                    ) {
                        attributedText = AttributedString(nsAttributedString)
                    } else {
                        attributedText = AttributedString(element.content)
                    }
                }
            } else {
                attributedText = AttributedString(element.content)
            }
        } else {
            attributedText = AttributedString()
        }
    }
    
    private func saveToDocument(_ newAttributedText: AttributedString) {
        var attributedStringData: Data?
        
        do {
            attributedStringData = try JSONEncoder().encode(newAttributedText)
        } catch {
            let nsAttributedString = NSAttributedString(newAttributedText)
            attributedStringData = try? nsAttributedString.data(
                from: NSRange(location: 0, length: nsAttributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
        }
        
        var updatedDocument = document
        if let index = updatedDocument.elements.firstIndex(where: { $0.type == .textBlock }) {
            var element = updatedDocument.elements[index]
            element.content = String(newAttributedText.characters)
            element.rtfData = attributedStringData
            updatedDocument.elements[index] = element
        } else {
            var element = DocumentElement(type: .textBlock)
            element.content = String(newAttributedText.characters)
            element.rtfData = attributedStringData
            updatedDocument.elements.append(element)
        }
        
        document = updatedDocument
        
        DispatchQueue.global(qos: .utility).async {
            document.save()
        }
    }
    
    private func setupFloatingHeader() {
        floatingTitleText = document.title
        floatingSubtitleText = document.subtitle
        
        // Load header image if available
        if let imageData = document.headerImageData {
            headerImage = UIImage(data: imageData)
        }
    }
    
    // MARK: - Formatting Actions
    private func applyBold() {
        attributedText.transformAttributes(in: &selection) { container in
            let currentFont = container.font ?? .default
            let resolved = currentFont.resolve(in: fontResolutionContext)
            container.font = currentFont.bold(!resolved.isBold)
        }
    }
    
    private func applyItalic() {
        attributedText.transformAttributes(in: &selection) { container in
            let currentFont = container.font ?? .default
            let resolved = currentFont.resolve(in: fontResolutionContext)
            container.font = currentFont.italic(!resolved.isItalic)
        }
    }
    
    private func applyUnderline() {
        attributedText.transformAttributes(in: &selection) { container in
            if container.underlineStyle == nil {
                container.underlineStyle = Text.LineStyle.single
            } else {
                container.underlineStyle = nil
            }
        }
    }
}

// MARK: - Preview
@available(iOS 26.0, *)
struct iOS26FullScreenTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        iOS26FullScreenTextEditor(
            document: .constant(Letterspace_CanvasDocument())
        )
    }
}
#endif 