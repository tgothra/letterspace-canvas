#if os(iOS)
import SwiftUI
import Foundation
import UIKit

// MARK: - iOS 26 Native Text Editor With Custom Toolbar
@available(iOS 26.0, *)
struct iOS26NativeTextEditorWithToolbar: View {
    @Binding var document: Letterspace_CanvasDocument
    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    @State private var isEditing: Bool = false
    
    // Toolbar visibility
    @State private var showToolbar: Bool = false
    @State private var toolbarOpacity: Double = 0.0
    @State private var lastBoldState: Bool = false  // Track bold state manually
    @State private var lastItalicState: Bool = false  // Track italic state manually
    
    // Exclusive picker state management
    enum InlinePicker {
        case none, textColor, highlightColor, underlineColor
    }
    @State private var activeInlinePicker: InlinePicker = .none
    @State private var isBookmarked: Bool = false
    
    // Current color states for visual feedback
    @State private var currentTextColor: Color = .primary
    @State private var currentHighlightColor: Color = .clear
    @State private var currentUnderlineColor: Color = .clear
    
    // Current formatting states for visual feedback
    @State private var currentIsBold: Bool = false
    @State private var currentIsItalic: Bool = false
    
    // Floating header state
    @State private var showFloatingHeader: Bool = true // Show expanded by default
    @State private var isHeaderCollapsed: Bool = false // Track if header is collapsed
    @State private var headerImage: UIImage?
    @State private var isEditingTitle: Bool = false
    @State private var isEditingSubtitle: Bool = false
    @State private var titleText: String = ""
    @State private var subtitleText: String = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isSubtitleFocused: Bool
    
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
                // Main Text Editor - now full screen like RichTextEditor example
                textEditorView
            }
            .onAppear {
                loadDocumentContent()
            }
            .onChange(of: attributedText) { _, newValue in
                print("🔄 AttributedText changed, triggering save...")
                saveToDocument(newValue)
            }
            .onChange(of: selection) { _, newValue in
                print("🔄 Selection changed, checking bookmark state...")
                checkBookmarkState()
            }
            .onChange(of: selection) { _, newSelection in
                updateToolbarVisibility(for: newSelection)
                updateColorIndicators(for: newSelection)
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
            
            // Header collapse/expand button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            if headerImage != nil {
                                isHeaderCollapsed.toggle()
                            } else {
                                showFloatingHeader.toggle()
                            }
                        }
                    }) {
                        Image(systemName: headerImage != nil 
                              ? (isHeaderCollapsed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                              : (showFloatingHeader ? "chevron.up" : "doc.text.image"))
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
    
    // MARK: - Text Editor View
    private var textEditorView: some View {
        TextEditor(text: $attributedText, selection: $selection)
            .font(.system(size: 16))
            .padding(.horizontal, 16)
            .padding(.top, showFloatingHeader && !isHeaderCollapsed ? 200 : (isHeaderCollapsed ? 80 : 20)) // Adjust padding based on header state
            .padding(.bottom, 20)
            .background(Color(UIColor.systemBackground))
            .scrollContentBackground(.hidden)
            .onTapGesture {
                isEditing = true
            }
                .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                        if activeInlinePicker != .none {
                                                         if activeInlinePicker == .textColor {
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
                                            ForEach(textColors, id: \.self) { color in
                                                Button(action: {
                                                    applyTextColor(color)
                                                    currentTextColor = color
                                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                                        activeInlinePicker = .none
                                                    }
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
                            } else if activeInlinePicker == .highlightColor {
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
                                            ForEach(highlightColors, id: \.self) { color in
                                                Button(action: {
                                                    applyHighlightColor(color)
                                                    currentHighlightColor = color
                                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                                        activeInlinePicker = .none
                                                    }
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
                            } else if activeInlinePicker == .underlineColor {
                                // Underline color picker replaces underline toggle.
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
                                            ForEach(underlineColors, id: \.self) { color in
                                                Button(action: {
                                                    applyUnderlineColor(color)
                                                    currentUnderlineColor = color
                                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                                        activeInlinePicker = .none
                                                    }
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
                        } else {
                            Button(action: { applyBold() }) {
                                ZStack {
                                    Image(systemName: "bold")
                                        .foregroundColor(.primary)
                                    
                                    // Blue indicator for active bold
                                    if currentIsBold {
                                        Circle()
                                            .fill(Color.blue)
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
                            Button(action: { applyItalic() }) {
                                ZStack {
                                    Image(systemName: "italic")
                                        .foregroundColor(.primary)
                                    
                                    // Blue indicator for active italic
                                    if currentIsItalic {
                                        Circle()
                                            .fill(Color.blue)
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
                            Button(action: {
                                // Toggle underline color picker
                                withAnimation {
                                    activeInlinePicker = activeInlinePicker == .underlineColor ? .none : .underlineColor
                                }
                            }) {
                                ZStack {
                                    Image(systemName: "underline")
                                        .foregroundColor(.primary)
                                    
                                    // Color indicator circle
                                    if currentUnderlineColor != .clear {
                                        Circle()
                                            .fill(currentUnderlineColor)
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
                            
                            Button(action: {
                                // Toggle text color picker
                                withAnimation {
                                    activeInlinePicker = activeInlinePicker == .textColor ? .none : .textColor
                                }
                            }) {
                                ZStack {
                                    Image(systemName: "paintbrush")
                                        .foregroundColor(.primary)
                                    
                                    // Color indicator circle
                                    if currentTextColor != .primary {
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
                            
                            Button(action: {
                                // Toggle highlight color picker
                                withAnimation {
                                    activeInlinePicker = activeInlinePicker == .highlightColor ? .none : .highlightColor
                                }
                            }) {
                                ZStack {
                                    Image(systemName: "highlighter")
                                        .foregroundColor(.primary)
                                    
                                    // Color indicator circle
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
                            
                            Button(action: { toggleBookmark() }) {
                                Image(systemName: "bookmark")
                                    .foregroundColor(isBookmarked ? .yellow : .primary)
                            }
                        }
                    }
                }
    }
    
    // MARK: - Floating Header View
    private var floatingHeaderView: some View {
        Group {
            if let headerImage = headerImage {
                if isHeaderCollapsed {
                    // Collapsed header bar
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .frame(height: 60)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        HStack(spacing: 12) {
                            // Small header image
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
                    // Expanded header with large image
                    VStack(spacing: 0) {
                        // Large header image
                        Image(uiImage: headerImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        
                        // Title and subtitle overlay on image
                        VStack(alignment: .leading, spacing: 4) {
                            titleView
                            subtitleView
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .offset(y: -20) // Overlay on bottom of image
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
            } else {
                // Header without image - always collapsed style
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
    
    // Palette helper for inline picker row (no background or capsule)
    private func colorsRow(colors: [Color], action: @escaping (Color) -> Void) -> some View {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(minHeight: 44)
        // No background or clipShape here
    }
    
    // MARK: - Bookmark Functionality
    private func toggleBookmark() {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            print("🔖 No text selected for bookmark")
            return
        }
        
        // Get selected text snippet
        let selectedText = String(attributedText[ranges].characters).trimmingCharacters(in: .whitespacesAndNewlines)
        let title = selectedText.isEmpty ? "Bookmark" : String(selectedText.prefix(30))
        
        // Calculate line number
        let firstRange = ranges.ranges.first!
        let textUpToSelection = String(attributedText.characters.prefix(upTo: firstRange.lowerBound))
        let lineNumber = textUpToSelection.components(separatedBy: CharacterSet.newlines).count
        
        // Check if bookmark already exists at this position
        let existingBookmark = document.markers.first { marker in
            marker.type == "bookmark" && marker.position == lineNumber
        }
        
        if let existingBookmark = existingBookmark {
            // Remove existing bookmark
            print("🔖 Removing bookmark with ID: \(existingBookmark.id)")
            document.removeMarker(id: existingBookmark.id)
            isBookmarked = false
            print("🔖 Removed bookmark from document")
            
            // Remove bookmark star and highlight from text
            attributedText.transform(updating: &selection) { text in
                // Find and remove the circle star icon
                let starText = "⍟ "
                // Convert to String to use range(of:)
                let textString = String(text.characters)
                if let iconRange = textString.range(of: starText) {
                    let startOffset = textString.distance(from: textString.startIndex, to: iconRange.lowerBound)
                    let endOffset = textString.distance(from: textString.startIndex, to: iconRange.upperBound)
                    let startIndex = text.characters.index(text.characters.startIndex, offsetBy: startOffset)
                    let endIndex = text.characters.index(text.characters.startIndex, offsetBy: endOffset)
                    text.removeSubrange(startIndex..<endIndex)
                }
                
                // Remove highlight from the bookmarked text
                text[ranges].backgroundColor = nil
            }
        } else {
            // Add new bookmark
            let uuid = UUID()
            print("🔖 Adding bookmark with ID: \(uuid)")
            
            // Add to document markers
            document.addMarker(
                id: uuid,
                title: title,
                type: "bookmark",
                position: lineNumber,
                metadata: [
                    "charPosition": String(attributedText.characters.distance(from: attributedText.startIndex, to: firstRange.lowerBound)),
                    "charLength": String(attributedText.characters.distance(from: firstRange.lowerBound, to: firstRange.upperBound)),
                    "snippet": selectedText
                ]
            )
            isBookmarked = true
            print("🔖 Added bookmark with title: '\(title)' at line \(lineNumber)")
            
            // Add bookmark icon and highlight
            attributedText.transform(updating: &selection) { text in
                // First, add highlight to the selected text
                text[ranges].backgroundColor = Color.orange.opacity(0.15)
                
                // Then, insert bookmark icon at the start of the range
                var bookmarkStar = AttributedString("⍟ ")
                bookmarkStar.backgroundColor = Color.orange.opacity(0.2)
                text.insert(bookmarkStar, at: ranges.ranges.first!.lowerBound)
            }
        }
        
        // Save changes
        saveToDocument(attributedText)
        
        // Save document to persist markers
        DispatchQueue.main.async {
            self.document.save()
            print("🔖 Document saved with markers count: \(self.document.markers.count)")
        }
    }
    
    // MARK: - Bookmark State Detection
    private func checkBookmarkState() {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            isBookmarked = false
            return
        }
        
        // Calculate line number for current selection
        let firstRange = ranges.ranges.first!
        let textUpToSelection = String(attributedText.characters.prefix(upTo: firstRange.lowerBound))
        let lineNumber = textUpToSelection.components(separatedBy: CharacterSet.newlines).count
        
        // Check if selected text has bookmark circle star
        let selectedText = attributedText[ranges]
        let hasBookmarkVisual = selectedText.characters.contains("⍟")
        
        // Also check document markers for consistency
        let hasBookmarkInMarkers = document.markers.contains { marker in
            marker.type == "bookmark" && marker.position == lineNumber
        }
        
        // Use visual indicator as primary, markers as backup
        isBookmarked = hasBookmarkVisual || hasBookmarkInMarkers
        print("🔖 Bookmark state: \(isBookmarked ? "marked" : "not marked") at line \(lineNumber)")
    }
    
    // MARK: - Color Application
    private func applyTextColor(_ color: Color) {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            return
        }
        
        attributedText.transform(updating: &selection) { text in
            if color == .clear {
                // Remove text color (use default)
                text[ranges].foregroundColor = nil
            } else {
                // Apply text color
                text[ranges].foregroundColor = color
            }
        }
        
        // Save changes
        saveToDocument(attributedText)
    }
    
    private func applyHighlightColor(_ color: Color) {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            return
        }
        
        attributedText.transform(updating: &selection) { text in
            if color == .clear {
                // Remove highlight
                text[ranges].backgroundColor = nil
            } else {
                // Apply highlight with opacity
                text[ranges].backgroundColor = color.opacity(0.3)
            }
        }
        
        // Save changes
        saveToDocument(attributedText)
    }
    
    private func applyUnderlineColor(_ color: Color) {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else { return }
        attributedText.transform(updating: &selection) { text in
            if color == .clear {
                // Remove underline completely
                text[ranges].underlineStyle = nil
            } else {
                // Apply colored underline using Text.LineStyle
                text[ranges].underlineStyle = Text.LineStyle(pattern: .solid, color: color)
                print("🎨 Applied \(color) underline to text")
            }
        }
        saveToDocument(attributedText)
    }
    
    // MARK: - Document Management
    private func loadDocumentContent() {
        print("📄 Loading document content...")
        
        // Load header image if available
        if let headerElement = document.elements.first(where: { $0.type == .headerImage && !$0.content.isEmpty }) {
            // Try to load from cache first
            if let cachedImage = ImageCache.shared.image(for: headerElement.content) {
                headerImage = cachedImage
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
        
        // Load from the first text element in the document
        if let element = document.elements.first(where: { $0.type == .textBlock }) {
            print("📝 Found text element with content: '\(element.content)'")
            if let data = element.rtfData {
                print("📊 Data size: \(data.count) bytes")
                
                // Try iOS 26 native JSON decoding first
                do {
                    attributedText = try JSONDecoder().decode(AttributedString.self, from: data)
                    print("✅ Successfully loaded native AttributedString JSON with \(attributedText.characters.count) characters")
                    
                    // Debug: Check if the loaded AttributedString has formatting
                    if attributedText.characters.count > 0 {
                        let firstRun = attributedText.runs.first
                        print("🧪 Native JSON - First run attributes: font=\(firstRun?.font.map {"\($0)" } ?? "nil"), foregroundColor=\(firstRun?.foregroundColor.map {"\($0)" } ?? "nil"), backgroundColor=\(firstRun?.backgroundColor.map {"\($0)" } ?? "nil")")
                    }
                    
                    // Check for bookmark state
                    checkBookmarkState()
                } catch {
                    print("🔄 JSON decode failed, trying RTF fallback...")
                    
                    // Fallback to RTF/RTFD loading for legacy data
                    var nsAttributedString: NSAttributedString?
                    
                    // Try RTFD first
                    nsAttributedString = try? NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.rtfd],
                        documentAttributes: nil
                    )
                    
                    // Fallback to RTF if RTFD fails
                    if nsAttributedString == nil {
                        nsAttributedString = try? NSAttributedString(
                            data: data,
                            options: [.documentType: NSAttributedString.DocumentType.rtf],
                            documentAttributes: nil
                        )
                    }
                    
                    if let nsAttributedString = nsAttributedString {
                        attributedText = AttributedString(nsAttributedString)
                        print("✅ Successfully loaded RTF/RTFD fallback with \(attributedText.characters.count) characters")
                        
                        // Debug: Check if the loaded AttributedString has formatting
                        if attributedText.characters.count > 0 {
                            let firstRun = attributedText.runs.first
                            print("🧪 RTF fallback - First run attributes: font=\(firstRun?.font.map {"\($0)" } ?? "nil"), foregroundColor=\(firstRun?.foregroundColor.map {"\($0)" } ?? "nil"), backgroundColor=\(firstRun?.backgroundColor.map {"\($0)" } ?? "nil")")
                        }
                        
                        // Check for bookmark state
                        checkBookmarkState()
                    } else {
                        print("❌ Failed to parse both JSON and RTF data, falling back to plain text")
                        attributedText = AttributedString(element.content)
                    }
                }
            } else {
                print("⚠️ No RTF data found, using plain text content")
                // No RTF data, use plain text content
                attributedText = AttributedString(element.content)
            }
        } else {
            print("📄 No text element found, creating empty AttributedString")
            // Create initial empty attributed string with default formatting
            attributedText = AttributedString()
        }
    }
    
    private func saveToDocument(_ newAttributedText: AttributedString) {
        print("💾 Saving document content...")
        print("📝 AttributedString has \(newAttributedText.characters.count) characters")
        
        // Use iOS 26 native AttributedString persistence (no RTF conversion needed!)
        var attributedStringData: Data?
        
        do {
            // AttributedString is natively Codable in iOS 26
            attributedStringData = try JSONEncoder().encode(newAttributedText)
            print("✅ Created native AttributedString JSON data: \(attributedStringData?.count ?? 0) bytes")
            
            // Verify by decoding back
            if let data = attributedStringData {
                let decodedString = try JSONDecoder().decode(AttributedString.self, from: data)
                print("🧪 Verification: Successfully decoded back, length: \(decodedString.characters.count)")
                if decodedString.characters.count > 0 {
                    let firstRun = decodedString.runs.first
                    print("🧪 First run: font=\(firstRun?.font.map {"\($0)" } ?? "nil"), foregroundColor=\(firstRun?.foregroundColor.map {"\($0)" } ?? "nil"), backgroundColor=\(firstRun?.backgroundColor.map {"\($0)" } ?? "nil")")
                }
            }
        } catch {
            print("❌ Failed to encode AttributedString as JSON: \(error)")
            
            // Fallback to RTF if JSON encoding fails
            print("🔄 Falling back to RTF...")
            let nsAttributedString = NSAttributedString(newAttributedText)
            attributedStringData = try? nsAttributedString.data(
                from: NSRange(location: 0, length: nsAttributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
        }
        
        // Update document
        var updatedDocument = document
        if let index = updatedDocument.elements.firstIndex(where: { $0.type == .textBlock }) {
            var element = updatedDocument.elements[index]
            
            // Store the native AttributedString data directly
            element.content = String(newAttributedText.characters)
            element.rtfData = attributedStringData  // This now contains JSON or RTF
            
            updatedDocument.elements[index] = element
            print("📄 Updated existing text element")
        } else {
            // Create new text element
            var element = DocumentElement(type: .textBlock)
            element.content = String(newAttributedText.characters)
            element.rtfData = attributedStringData
            updatedDocument.elements.append(element)
            print("📄 Created new text element")
        }
        
        // Update document binding before saving
        document = updatedDocument
        
        // Save asynchronously to avoid blocking UI
        DispatchQueue.global(qos: .utility).async {
            print("🚀 Starting document save...")
            document.save()
            print("💾 Document save completed")
        }
    }
    
    private func saveDocument() {
        DispatchQueue.global(qos: .utility).async {
            document.save()
        }
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
                // Delay hiding to allow animation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if !hasTextSelection(selection) {
                        showToolbar = false
                    }
                }
            }
        }
    }
    
    // MARK: - Color Indicator Management
    private func updateColorIndicators(for newSelection: AttributedTextSelection) {
        print("🔄 updateColorIndicators called")
        guard case .ranges(let ranges) = newSelection.indices(in: attributedText), !ranges.isEmpty else {
            // No text selected - reset to default colors and formatting
            print("🔄 No selection - resetting all indicators")
            currentTextColor = .primary
            currentHighlightColor = .clear
            currentUnderlineColor = .clear
            currentIsBold = false
            currentIsItalic = false
            return
        }
        
        // Get the first character's formatting to show in buttons
        let selectedText = attributedText[ranges]
        if let firstRun = selectedText.runs.first {
            // Update text color indicator
            if let foregroundColor = firstRun.foregroundColor {
                currentTextColor = Color(foregroundColor)
            } else {
                currentTextColor = .primary
            }
            
            // Update highlight color indicator
            if let backgroundColor = firstRun.backgroundColor {
                currentHighlightColor = Color(backgroundColor)
            } else {
                currentHighlightColor = .clear
            }
            
            // Update underline color indicator
            if let underlineStyle = firstRun.underlineStyle {
                // Extract color from Text.LineStyle description
                let styleDescription = String(describing: underlineStyle)
                print("🎨 Underline style description: \(styleDescription)")
                
                // Parse color from LineStyle description
                let detectedColor = parseColorFromLineStyle(styleDescription)
                if detectedColor != .clear {
                    currentUnderlineColor = detectedColor
                    print("🎨 Detected underline color: \(detectedColor)")
                } else {
                    // Preserve last known color if parsing fails
                    if currentUnderlineColor == .clear {
                        currentUnderlineColor = .primary
                    }
                    print("🎨 Using fallback underline color: \(currentUnderlineColor)")
                }
            } else {
                currentUnderlineColor = .clear
                print("🎨 No underline detected, clearing color")
            }
            
                        // Update bold/italic indicators
            if let font = firstRun.font {
                let fontDescription = String(describing: font)
                print("🎨 Font description: \(fontDescription)")
                
                // For BOLD: Reset the manual tracking when analyzing different text
                // Check if this selection was just formatted (use manual tracking)
                // Otherwise, reset based on actual analysis
                let selectedText = attributedText[ranges]
                
                // Simple approach: Use the manual tracking but reset when selecting unformatted text
                // Check if font has any formatting applied
                let hasAnyFormatting = selectedText.runs.contains { run in
                    if let font = run.font {
                        let fontDesc = String(describing: font).lowercased()
                        return fontDesc.contains("staticmodifierprovider") // Any custom formatting
                    }
                    return false
                }
                
                // If no formatting detected, clear bold state
                if !hasAnyFormatting {
                    currentIsBold = false
                    lastBoldState = false // Reset manual tracking too
                } else {
                    // Use manual tracking for formatted text
                    currentIsBold = lastBoldState
                }
                print("🎨 Has any formatting: \(hasAnyFormatting), Bold state: \(currentIsBold)")
                
                // For ITALIC: Use font description detection (works reliably)
                let lowercaseDesc = fontDescription.lowercased()
                let italicPatterns = ["italic", ".italic", "design(.italic)", "design: italic"]
                currentIsItalic = italicPatterns.contains { pattern in
                    let contains = lowercaseDesc.contains(pattern)
                    if contains {
                        print("✅ Found italic pattern: '\(pattern)'")
                    }
                    return contains
                }
                
                print("🎨 Final detection - Bold: \(currentIsBold), Italic: \(currentIsItalic)")
            } else {
                currentIsBold = false
                currentIsItalic = false
                print("🎨 No font detected, clearing bold/italic indicators")
            }
        }
    }
    
    // MARK: - Color Parsing Helper
    private func parseColorFromLineStyle(_ styleDescription: String) -> Color {
        let lowercaseDescription = styleDescription.lowercased()
        
        // Parse common colors from LineStyle description
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
            // Check for RGB values or hex patterns
            if lowercaseDescription.contains("colorspace") || lowercaseDescription.contains("rgb") {
                // Could add more sophisticated RGB parsing here if needed
                return .primary // Default for unrecognized RGB
            }
            return .clear // No recognizable color found
        }
    }
    
    private func hasTextSelection(_ selection: AttributedTextSelection) -> Bool {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Formatting Actions (for .toolbar buttons)
    private func applyBold() {
        print("🔥 Bold button pressed")
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            print("❌ No selection found")
            return
        }
        
        print("📝 Selected text: '\(String(attributedText[ranges].characters))'")
        
        // Check if any part of selection is bold (using same simple approach as italic)
        let hasBold = attributedText[ranges].runs.contains { run in
            if let font = run.font {
                let fontDesc = String(describing: font).lowercased()
                print("🔍 Font description: '\(fontDesc)'")
                let isBold = fontDesc.contains("bold")
                if isBold {
                    print("✅ Found bold font: \(fontDesc)")
                }
                return isBold
            }
            return false
        }
        
        print("📊 Has bold: \(hasBold)")
        
        // Update manual tracking to reflect actual selected text state
        let actuallyHasItalic = attributedText[ranges].runs.contains { run in
            if let font = run.font {
                return String(describing: font).lowercased().contains("italic")
            }
            return false
        }
        
        // Update states to match actual text
        lastBoldState = hasBold
        lastItalicState = actuallyHasItalic
        
        // Toggle bold state
        let shouldBeBold = !lastBoldState
        lastBoldState = shouldBeBold
        
        print("📊 Actual italic state: \(actuallyHasItalic)")
        print("📊 Should be bold: \(shouldBeBold)")
        
        attributedText.transform(updating: &selection) { text in
            if shouldBeBold {
                // Add bold - preserve existing italic
                if lastItalicState {
                    text[ranges].font = .system(size: 16, weight: .bold).italic()
                    print("➕ Adding bold + italic (manual tracking)")
                } else {
                    text[ranges].font = .system(size: 16, weight: .bold)
                    print("➕ Adding bold (manual tracking)")
                }
            } else {
                // Remove bold - preserve existing italic
                if lastItalicState {
                    text[ranges].font = .system(size: 16, weight: .regular).italic()
                    print("➖ Removing bold, keeping italic (manual tracking)")
                } else {
                    text[ranges].font = .system(size: 16, weight: .regular)
                    print("➖ Removing bold (manual tracking)")
                }
            }
        }
        
        // Save changes to document
        saveToDocument(attributedText)
        
        // Update badges to reflect new formatting (with small delay to ensure font change is processed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔄 Updating badges after bold formatting...")
            self.updateColorIndicators(for: self.selection)
        }
        
        // Force UI update
        DispatchQueue.main.async {
            // This ensures the TextEditor updates
        }
    }
    
    private func applyItalic() {
        print("🔥 Italic button pressed")
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            print("❌ No selection found")
            return
        }
        
        print("📝 Selected text: '\(String(attributedText[ranges].characters))'")
        
        // Check if any part of selection is italic
        let hasItalic = attributedText[ranges].runs.contains { run in
            if let font = run.font {
                return String(describing: font).lowercased().contains("italic")
            }
            return false
        }
        
        print("📊 Has italic: \(hasItalic)")
        
        // Update manual tracking to reflect actual selected text state
        let actuallyHasBold = attributedText[ranges].runs.contains { run in
            if let font = run.font {
                return String(describing: font).lowercased().contains("bold")
            }
            return false
        }
        
        // Update states to match actual text
        lastItalicState = hasItalic
        lastBoldState = actuallyHasBold
        
        // Toggle italic state
        let shouldBeItalic = !lastItalicState
        lastItalicState = shouldBeItalic
        
        print("📊 Actual bold state: \(actuallyHasBold)")
        print("📊 Should be italic: \(shouldBeItalic)")
        
        attributedText.transform(updating: &selection) { text in
            if shouldBeItalic {
                // Add italic - preserve existing bold
                if lastBoldState {
                    text[ranges].font = .system(size: 16, weight: .bold).italic()
                    print("➕ Adding italic + bold (manual tracking)")
                } else {
                    text[ranges].font = .system(size: 16, weight: .regular).italic()
                    print("➕ Adding italic (manual tracking)")
                }
            } else {
                // Remove italic - preserve existing bold
                if lastBoldState {
                    text[ranges].font = .system(size: 16, weight: .bold)
                    print("➖ Removing italic, keeping bold (manual tracking)")
                } else {
                    text[ranges].font = .system(size: 16, weight: .regular)
                    print("➖ Removing italic (manual tracking)")
                }
            }
        }
        
        // Save changes to document
        saveToDocument(attributedText)
        
        // Update badges to reflect new formatting (with small delay to ensure font change is processed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateColorIndicators(for: self.selection)
        }
    }
    
    private func applyUnderline() {
        print("🔥 Underline button pressed")
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            print("❌ No selection found")
            return
        }
        
        print("📝 Selected text: '\(String(attributedText[ranges].characters))'")
        
        // Use transform method for proper AttributedString manipulation
        attributedText.transform(updating: &selection) { text in
            // Check if any part of selection is underlined
            let hasUnderline = text[ranges].runs.contains { run in
                return run.underlineStyle == Text.LineStyle.single
            }
            
            print("📊 Has underline: \(hasUnderline)")
            
            if hasUnderline {
                // Remove underline
                text[ranges].underlineStyle = nil
                print("➖ Removing underline")
            } else {
                // Add underline
                text[ranges].underlineStyle = Text.LineStyle.single
                print("➕ Adding underline")
            }
        }
        
        // Save changes to document
        saveToDocument(attributedText)
    }
    

}

// MARK: - Compact Color Picker
struct CompactColorPicker: View {
    let title: String
    let colors: [Color]
    let onColorSelect: (Color) -> Void
    let onDismiss: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Color grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    CompactColorButton(
                        color: color,
                        onTap: {
                            onColorSelect(color)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 280, height: 140)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 8, x: 0, y: 4)
        .offset(y: -120) // Position above keyboard
    }
}

struct CompactColorButton: View {
    let color: Color
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            Group {
                if color == .clear {
                    // Clear/default color button
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                        
                        // Diagonal line through circle
                        Path { path in
                            path.move(to: CGPoint(x: 8, y: 8))
                            path.addLine(to: CGPoint(x: 24, y: 24))
                        }
                        .stroke(Color.red, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                    }
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Add this String extension for underline symbol rendering:
extension String {
    func applyingUnderline() -> AttributedString {
        var attributed = AttributedString(self)
        attributed.underlineStyle = Text.LineStyle.single
        return attributed
    }
}

// MARK: - iOS 26 Native Element Editor
@available(iOS 26.0, *)
struct iOS26NativeElementEditor: View {
    @Binding var element: DocumentElement
    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    @State private var showToolbar: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $attributedText, selection: $selection)
                .font(.system(size: 16))
                .onChange(of: attributedText) { _, newValue in
                    updateElement(with: newValue)
                }
                .onChange(of: selection) { _, newSelection in
                    updateToolbarVisibility(for: newSelection)
                }
                .onAppear {
                    loadElementContent()
                }
            
            if showToolbar {
                iOS26NativeToolbarWrapper(
                    text: $attributedText,
                    selection: $selection
                )
                .transition(.move(edge: .bottom))
            }
        }
    }
    
    private func loadElementContent() {
        if let rtfData = element.rtfData {
            if let nsAttributedString = try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                attributedText = AttributedString(nsAttributedString)
            } else {
                attributedText = AttributedString(element.content)
            }
        } else {
            attributedText = AttributedString(element.content)
        }
    }
    
    private func updateElement(with newAttributedText: AttributedString) {
        // Convert AttributedString back to element format
        let nsAttributedString = NSAttributedString(newAttributedText)
        
        // Create RTF data for persistence
        let rtfData = try? nsAttributedString.data(
            from: NSRange(location: 0, length: nsAttributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        
        // Update element
        var updatedElement = element
        
        // Always update both content and rtfData
        updatedElement.content = String(newAttributedText.characters)
        updatedElement.rtfData = rtfData
        
        element = updatedElement
    }
    
    private func updateToolbarVisibility(for newSelection: AttributedTextSelection) {
        let hasSelection = hasTextSelection(newSelection)
        
        withAnimation(.easeInOut(duration: 0.25)) {
            showToolbar = hasSelection
        }
    }
    
    private func hasTextSelection(_ selection: AttributedTextSelection) -> Bool {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Formatting Actions (same as main editor)
    #if canImport(UIKit)
    // Only available on UIKit platforms
    private func applyBold() {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            return // No selection
        }
        var newText = attributedText
        
        for range in ranges.ranges {
            for runRange in newText[range].runs {
                let currentFont = runRange.font ?? .system(size: 16)
                let uiFont = createUIFont(from: currentFont)
                var traits = uiFont.fontDescriptor.symbolicTraits
                
                if traits.contains(.traitBold) {
                    traits.remove(.traitBold)
                } else {
                    traits.insert(.traitBold)
                }
                
                guard let newDescriptor = uiFont.fontDescriptor.withSymbolicTraits(traits) else {
                    continue
                }
                
                let newUIFont = UIFont(descriptor: newDescriptor, size: uiFont.pointSize)
                let newFont = Font(newUIFont)
                newText[runRange.range].font = newFont
            }
        }
        
        attributedText = newText
    }
    
    private func applyItalic() {
        guard case .ranges(let ranges) = selection.indices(in: attributedText), !ranges.isEmpty else {
            return // No selection
        }
        var newText = attributedText
        
        for range in ranges.ranges {
            for runRange in newText[range].runs {
                let currentFont = runRange.font ?? .system(size: 16)
                let uiFont = createUIFont(from: currentFont)
                var traits = uiFont.fontDescriptor.symbolicTraits
                
                if traits.contains(.traitItalic) {
                    traits.remove(.traitItalic)
                } else {
                    traits.insert(.traitItalic)
                }
                
                guard let newDescriptor = uiFont.fontDescriptor.withSymbolicTraits(traits) else {
                    continue
                }
                
                let newUIFont = UIFont(descriptor: newDescriptor, size: uiFont.pointSize)
                let newFont = Font(newUIFont)
                newText[runRange.range].font = newFont
            }
        }
        
        attributedText = newText
    }
    
    private func createUIFont(from font: Font) -> UIFont {
        let uiFont: UIFont
        
        let mirror = Mirror(reflecting: font)
        if let provider = mirror.descendant("provider") {
            let providerMirror = Mirror(reflecting: provider)
            if let base = providerMirror.descendant("base") as? UIFont {
                uiFont = base
            } else {
                uiFont = UIFont.systemFont(ofSize: 16)
            }
        } else {
            uiFont = UIFont.systemFont(ofSize: 16)
        }
        return uiFont
    }
    #endif
}

// MARK: - Preview
@available(iOS 26.0, *)
struct iOS26NativeTextEditorWithToolbar_Previews: PreviewProvider {
    static var previews: some View {
        iOS26NativeTextEditorWithToolbar(
            document: .constant(Letterspace_CanvasDocument())
        )
    }
}
#endif

