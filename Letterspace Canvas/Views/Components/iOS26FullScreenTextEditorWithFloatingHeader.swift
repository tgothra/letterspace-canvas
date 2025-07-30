#if os(iOS)
import SwiftUI
import UIKit

// MARK: - Full Screen Text Editor with Floating Header
@available(iOS 26.0, *)
struct iOS26FullScreenTextEditorWithFloatingHeader: View {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @Environment(\.colorScheme) private var colorScheme
    
    // Text editor state
    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    @FocusState private var isFocused: Bool
    
    // Floating header state
    @State private var showFloatingHeader: Bool = false
    @State private var headerImage: UIImage?
    @State private var isEditingTitle: Bool = false
    @State private var isEditingSubtitle: Bool = false
    @State private var titleText: String = ""
    @State private var subtitleText: String = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isSubtitleFocused: Bool
    
    // Toolbar state
    @State private var showToolbar: Bool = false
    @State private var toolbarOpacity: Double = 0.0
    
    // Color picker state
    enum InlinePicker {
        case none, textColor, highlightColor, underlineColor
    }
    @State private var activeInlinePicker: InlinePicker = .none
    
    // Current formatting states for visual feedback
    @State private var currentTextColor: Color = .primary
    @State private var currentHighlightColor: Color = .clear
    @State private var currentUnderlineColor: Color = .clear
    @State private var currentIsBold: Bool = false
    @State private var currentIsItalic: Bool = false
    
    // Color arrays for compact picker
    private var textColors: [Color] {
        [.clear, .gray, .blue, .green, .yellow, .red, .orange, .purple, .pink, .brown, .primary]
    }
    
    private var highlightColors: [Color] {
        [.clear, .yellow, .green, .blue, .pink, .purple, .orange]
    }
    
    private var underlineColors: [Color] {
        [.clear, .blue, .green, .yellow, .red, .orange, .purple, .pink, .brown, .primary, .black]
    }
    
    var body: some View {
        ZStack {
            // Full screen text editor
            VStack(spacing: 0) {
                TextEditor(text: $attributedText, selection: $selection)
                    .focused($isFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, showFloatingHeader ? 100 : 20) // Add top padding when header is visible
                    .padding(.bottom, 20)
                    .background(Color(UIColor.systemBackground))
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        loadDocumentContent()
                        isFocused = true
                    }
                    .onChange(of: attributedText) { _, newValue in
                        saveToDocument(newValue)
                    }
                    .onChange(of: selection) { _, newSelection in
                        updateToolbarVisibility(for: newSelection)
                        updateFormattingIndicators(for: newSelection)
                    }
                    .onTapGesture {
                        // Hide floating header when tapping in text area
                        if showFloatingHeader && !isEditingTitle && !isEditingSubtitle {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                showFloatingHeader = false
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            if activeInlinePicker != .none {
                                toolbarColorPicker
                            } else {
                                toolbarFormattingButtons
                            }
                        }
                    }
            }
            
            // Floating header overlay
            VStack {
                if showFloatingHeader {
                    floatingHeaderView
                        .padding(.horizontal, 16)
                        .padding(.top, 50)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
            .allowsHitTesting(showFloatingHeader)
            
            // Show/hide header button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showFloatingHeader.toggle()
                        }
                    }) {
                        Image(systemName: showFloatingHeader ? "chevron.up" : "doc.text.image")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 20)
                }
                .padding(.top, 20)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Floating Header View
    private var floatingHeaderView: some View {
        Group {
            if let headerImage = headerImage {
                // Header with image
                ZStack {
                    // Glass effect background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.clear)
                        .frame(height: 80)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    
                    // Content
                    HStack(spacing: 12) {
                        // Header image
                        Image(uiImage: headerImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        
                        // Title and subtitle
                        VStack(alignment: .leading, spacing: 2) {
                            titleView
                            subtitleView
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                // Header without image
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .frame(height: 60)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        titleView
                        subtitleView
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - Title and Subtitle Views
    private var titleView: some View {
        Group {
            if isEditingTitle {
                TextField("Enter title", text: $titleText)
                    .font(.system(size: 18, weight: .semibold))
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .onSubmit {
                        document.title = titleText
                        saveDocument()
                        isEditingTitle = false
                    }
                    .onAppear {
                        titleText = document.title
                        isTitleFocused = true
                    }
            } else {
                Button(action: {
                    titleText = document.title
                    isEditingTitle = true
                }) {
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var subtitleView: some View {
        Group {
            if isEditingSubtitle {
                TextField("Enter subtitle", text: $subtitleText)
                    .font(.system(size: 14, weight: .regular))
                    .textFieldStyle(.plain)
                    .focused($isSubtitleFocused)
                    .onSubmit {
                        document.subtitle = subtitleText
                        saveDocument()
                        isEditingSubtitle = false
                    }
                    .onAppear {
                        subtitleText = document.subtitle
                        isSubtitleFocused = true
                    }
            } else if !document.subtitle.isEmpty || isEditingTitle {
                Button(action: {
                    subtitleText = document.subtitle
                    isEditingSubtitle = true
                }) {
                    Text(document.subtitle.isEmpty ? "Add subtitle" : document.subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Toolbar Views
    @ViewBuilder
    private var toolbarColorPicker: some View {
        if activeInlinePicker == .textColor {
            colorPickerRow(colors: textColors) { color in
                applyTextColor(color)
                currentTextColor = color
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    activeInlinePicker = .none
                }
            }
        } else if activeInlinePicker == .highlightColor {
            colorPickerRow(colors: highlightColors) { color in
                applyHighlightColor(color)
                currentHighlightColor = color
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    activeInlinePicker = .none
                }
            }
        } else if activeInlinePicker == .underlineColor {
            colorPickerRow(colors: underlineColors) { color in
                applyUnderlineColor(color)
                currentUnderlineColor = color
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    activeInlinePicker = .none
                }
            }
        }
    }
    
    private var toolbarFormattingButtons: some View {
        HStack {
            // Bold button
            Button("Bold", systemImage: "bold") {
                attributedText.transformAttributes(in: &selection) { container in
                    let currentFont = container.font ?? .default
                    let resolved = currentFont.resolve(in: fontResolutionContext)
                    container.font = currentFont.bold(!resolved.isBold)
                }
            }
            .frame(width: 32, height: 32)
            
            // Italic button  
            Button("Italic", systemImage: "italic") {
                attributedText.transformAttributes(in: &selection) { container in
                    let currentFont = container.font ?? .default
                    let resolved = currentFont.resolve(in: fontResolutionContext)
                    container.font = currentFont.italic(!resolved.isItalic)
                }
            }
            .frame(width: 32, height: 32)
            
            // Text color button
            Button(action: {
                withAnimation {
                    activeInlinePicker = activeInlinePicker == .textColor ? .none : .textColor
                }
            }) {
                ZStack {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.primary)
                    
                    if currentTextColor != .primary && currentTextColor != .clear {
                        Circle()
                            .fill(currentTextColor)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(UIColor.systemBackground), lineWidth: 1)
                                    .frame(width: 8, height: 8)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .frame(width: 32, height: 32)
            
            // Highlight color button
            Button(action: {
                withAnimation {
                    activeInlinePicker = activeInlinePicker == .highlightColor ? .none : .highlightColor
                }
            }) {
                ZStack {
                    Image(systemName: "highlighter")
                        .foregroundColor(.primary)
                    
                    if currentHighlightColor != .clear {
                        Circle()
                            .fill(currentHighlightColor)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(UIColor.systemBackground), lineWidth: 1)
                                    .frame(width: 8, height: 8)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .frame(width: 32, height: 32)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    private func colorPickerRow(colors: [Color], action: @escaping (Color) -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    activeInlinePicker = .none
                }
            }) {
                Image(systemName: "arrow.left")
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(colors, id: \.self) { color in
                        Button(action: {
                            action(color)
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                                        .frame(width: 28, height: 28)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(height: 44)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: activeInlinePicker)
    }
    
    // MARK: - Document Management
    private func loadDocumentContent() {
        if let element = document.elements.first(where: { $0.type == .textBlock }) {
            if let data = element.rtfData {
                do {
                    attributedText = try JSONDecoder().decode(AttributedString.self, from: data)
                } catch {
                    // Fallback to RTF/RTFD loading
                    if let nsAttributedString = try? NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.rtfd],
                        documentAttributes: nil
                    ) {
                        attributedText = AttributedString(nsAttributedString)
                    } else if let nsAttributedString = try? NSAttributedString(
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
        
        // Load header image if available
        if let headerElement = document.elements.first(where: { $0.type == .headerImage && !$0.content.isEmpty }) {
            // Try to load from cache first
            if let cachedImage = ImageCache.shared.getImage(for: headerElement.content) {
                #if os(iOS)
                headerImage = cachedImage
                #endif
            } else {
                // Load from file path
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let imageUrl = documentsPath.appendingPathComponent(headerElement.content)
                
                if let imageData = try? Data(contentsOf: imageUrl),
                   let loadedImage = UIImage(data: imageData) {
                    headerImage = loadedImage
                    ImageCache.shared.setImage(loadedImage, for: headerElement.content)
                }
            }
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
        saveDocument()
    }
    
    private func saveDocument() {
        DispatchQueue.global(qos: .utility).async {
            document.save()
        }
    }
    
    // MARK: - Formatting Methods
    private func applyTextColor(_ color: Color) {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            return
        }
        
        attributedText.transform(updating: &selection) { text in
            if color == .clear {
                text[ranges].foregroundColor = nil
            } else {
                text[ranges].foregroundColor = color
            }
        }
        
        saveToDocument(attributedText)
    }
    
    private func applyHighlightColor(_ color: Color) {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            return
        }
        
        attributedText.transform(updating: &selection) { text in
            if color == .clear {
                text[ranges].backgroundColor = nil
            } else {
                text[ranges].backgroundColor = color.opacity(0.3)
            }
        }
        
        saveToDocument(attributedText)
    }
    
    private func applyUnderlineColor(_ color: Color) {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else { return }
        attributedText.transform(updating: &selection) { text in
            if color == .clear {
                text[ranges].underlineStyle = nil
            } else {
                text[ranges].underlineStyle = Text.LineStyle(pattern: .solid, color: color)
            }
        }
        saveToDocument(attributedText)
    }
    
    // MARK: - Toolbar Management
    private func updateToolbarVisibility(for newSelection: AttributedTextSelection) {
        let hasSelection = hasTextSelection(newSelection)
        
        withAnimation(.easeInOut(duration: 0.25)) {
            if hasSelection && !showToolbar {
                showToolbar = true
                toolbarOpacity = 1.0
            } else if !hasSelection && showToolbar {
                toolbarOpacity = 0.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if !hasTextSelection(selection) {
                        showToolbar = false
                    }
                }
            }
        }
    }
    
    private func updateFormattingIndicators(for newSelection: AttributedTextSelection) {
        guard case .ranges(let ranges) = newSelection.indices(in: attributedText), !ranges.isEmpty else {
            currentTextColor = .primary
            currentHighlightColor = .clear
            currentUnderlineColor = .clear
            currentIsBold = false
            currentIsItalic = false
            return
        }
        
        let selectedText = attributedText[ranges]
        if let firstRun = selectedText.runs.first {
            // Update color indicators
            if let foregroundColor = firstRun.foregroundColor {
                currentTextColor = Color(foregroundColor)
            } else {
                currentTextColor = .primary
            }
            
            if let backgroundColor = firstRun.backgroundColor {
                currentHighlightColor = Color(backgroundColor)
            } else {
                currentHighlightColor = .clear
            }
            
            if let underlineStyle = firstRun.underlineStyle {
                let styleDescription = String(describing: underlineStyle)
                currentUnderlineColor = parseColorFromLineStyle(styleDescription)
            } else {
                currentUnderlineColor = .clear
            }
            
            // Update formatting indicators
            if let font = firstRun.font {
                let resolved = font.resolve(in: fontResolutionContext)
                currentIsBold = resolved.isBold
                currentIsItalic = resolved.isItalic
            } else {
                currentIsBold = false
                currentIsItalic = false
            }
        }
    }
    
    private func parseColorFromLineStyle(_ styleDescription: String) -> Color {
        let lowercaseDescription = styleDescription.lowercased()
        
        if lowercaseDescription.contains("red") {
            return .red
        } else if lowercaseDescription.contains("blue") {
            return .blue
        } else if lowercaseDescription.contains("green") {
            return .green
        } else if lowercaseDescription.contains("yellow") {
            return .yellow
        } else if lowercaseDescription.contains("orange") {
            return .orange
        } else if lowercaseDescription.contains("purple") {
            return .purple
        } else if lowercaseDescription.contains("pink") {
            return .pink
        } else if lowercaseDescription.contains("brown") {
            return .brown
        } else if lowercaseDescription.contains("black") {
            return .black
        } else if lowercaseDescription.contains("primary") {
            return .primary
        } else {
            return .clear
        }
    }
    
    private func hasTextSelection(_ selection: AttributedTextSelection) -> Bool {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            return false
        }
        return true
    }
}

// MARK: - Preview
@available(iOS 26.0, *)
struct iOS26FullScreenTextEditorWithFloatingHeader_Previews: PreviewProvider {
    static var previews: some View {
        iOS26FullScreenTextEditorWithFloatingHeader(
            document: .constant(Letterspace_CanvasDocument())
        )
    }
}
#endif 