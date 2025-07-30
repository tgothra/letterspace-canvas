#if os(macOS)
import SwiftUI
import AppKit
// Import BibleAPI service
import Foundation

// Define custom TextField that can be focused
struct ScriptureCardTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.font = .systemFont(ofSize: 14)
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.isBezeled = false
        textField.drawsBackground = false
        
        // Make it become first responder immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = textField.window {
                window.makeFirstResponder(textField)
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.placeholderString = placeholder
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ScriptureCardTextField
        
        init(_ parent: ScriptureCardTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

extension NSAttributedString.Key {
    static let nonHighlightable = NSAttributedString.Key("nonHighlightable")
}

// Helper extension for regex capture groups
extension String {
    func captureGroups(with pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        guard let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)) else { return [] }
        
        return (1..<match.numberOfRanges).compactMap { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound,
                  let substringRange = Range(range, in: self) else { return nil }
            return String(self[substringRange])
        }
    }
}

// Custom NSTextView subclass to handle highlighting behavior
class ScriptureTextView: NSTextView {
    override init(frame: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        self.delegate = self
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.delegate = self
        commonInit()
    }
    
    private func commonInit() {
        isEditable = false
        isSelectable = true
        drawsBackground = false
        textContainer?.lineFragmentPadding = 0
        textContainer?.widthTracksTextView = true
        
        // Configure text container for proper layout
        textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        minSize = NSSize(width: 0, height: 0)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        
        // Enable proper text layout
        layoutManager?.allowsNonContiguousLayout = false
        layoutManager?.usesFontLeading = true
        
        // Set selection granularity to character
        selectionGranularity = .selectByCharacter
    }
    
    // Override to prevent default selection highlighting
    override func drawBackground(in rect: NSRect) {
        // Only draw the custom background, skip super to prevent default selection highlight
        backgroundColor.setFill()
        rect.fill()
        
        guard let layoutManager = self.layoutManager,
              let textContainer = self.textContainer,
              let textStorage = self.textStorage,
              !selectedRanges.isEmpty else { return }
        
        // Draw permanent highlights first
        textStorage.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: textStorage.length)) { color, range, _ in
            if let highlightColor = color as? NSColor {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var rectCount: Int = 0
                let rectArray = layoutManager.rectArray(forGlyphRange: glyphRange, withinSelectedGlyphRange: glyphRange, in: textContainer, rectCount: &rectCount)
                
                if let rects = rectArray {
                    highlightColor.setFill()
                    for i in 0..<rectCount {
                        rects[i].fill()
                    }
                }
            }
        }
        
        // Then draw selection highlights
        let selectionColor = NSColor.selectedTextBackgroundColor.withAlphaComponent(0.3)
        
        for rangeValue in selectedRanges {
            var range = rangeValue.rangeValue
            guard range.length > 0 else { continue }
            
            // Get the selected text
            let selectedText = textStorage.attributedSubstring(from: range).string
            
            // Find first non-whitespace character
            var startOffset = 0
            for (index, char) in selectedText.enumerated() {
                if !String(char).trimmingCharacters(in: .whitespaces).isEmpty {
                    startOffset = index
                    break
                }
            }
            
            // Find last non-whitespace character
            var endOffset = selectedText.count
            for (index, char) in selectedText.reversed().enumerated() {
                if !String(char).trimmingCharacters(in: .whitespaces).isEmpty {
                    endOffset = selectedText.count - index
                    break
                }
            }
            
            // Only adjust the range if we found valid content
            if startOffset < endOffset {
                range.location += startOffset
                range.length = endOffset - startOffset
            }
            
            // Only highlight text that isn't marked as non-highlightable
            textStorage.enumerateAttributes(in: range, options: []) { attributes, charRange, _ in
                if attributes[.nonHighlightable] as? Bool != true {
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
                    var rectCount: Int = 0
                    let rectArray = layoutManager.rectArray(forGlyphRange: glyphRange, withinSelectedGlyphRange: glyphRange, in: textContainer, rectCount: &rectCount)
                    
                    if let rects = rectArray {
                        selectionColor.setFill()
                        for i in 0..<rectCount {
                            rects[i].fill()
                        }
                    }
                }
            }
        }
    }
    
    // Override to handle highlighting
    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        needsDisplay = true
    }
}

extension ScriptureTextView: NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        needsDisplay = true
    }
}

struct AttributedTextView: NSViewRepresentable {
    let attributedString: NSAttributedString
    @Environment(\.colorScheme) var colorScheme
    
    func makeNSView(context: Context) -> NSBox {
        let box = NSBox()
        
        let textView = ScriptureTextView(frame: .zero, textContainer: nil)
        
        // Set the attributed string
        textView.textStorage?.setAttributedString(attributedString)
        
        // Configure box
        box.contentView = textView
        box.boxType = .custom
     
        box.isTransparent = true
        box.cornerRadius = 12
        box.fillColor = colorScheme == .dark ? NSColor.black.withAlphaComponent(0.1) : NSColor.white
        box.contentViewMargins = NSSize(width: 16, height: 16)
        
        return box
    }
    
    func updateNSView(_ nsView: NSBox, context: Context) {
        // Update the text if it changed
        if let textView = nsView.contentView as? NSTextView,
           textView.textStorage?.isEqual(attributedString) == false {
            textView.textStorage?.setAttributedString(attributedString)
        }
        
        // Update colors for dark/light mode
        nsView.borderColor = colorScheme == .dark ? NSColor.white.withAlphaComponent(0.2) : NSColor.black.withAlphaComponent(0.2)
        nsView.fillColor = colorScheme == .dark ? NSColor.black.withAlphaComponent(0.1) : NSColor.white
    }
}

struct ScriptureCard: View {
    let content: ScriptureElement
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reference header
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(content.cleanedReference)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text("•")
                    .font(.system(size: 14))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
                
                Text(content.translation)
                    .font(.system(size: 13))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            .padding(.bottom, 8)
            
            // Scripture text
            Text(content.cleanedText)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding()
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.95))
        .cornerRadius(8)
    }
}

// MARK: - Scripture Search View

// Add step enum for the Scripture workflow
enum ScriptureInsertionStep {
    case search
    case layout
}

// MARK: - Button Styles (Add definitions here to fix scope errors)

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(colorScheme == .dark ? Color.blue : Color.accentColor) // Example colors
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15)) // Example colors
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Create a content view for the search step
struct ScriptureSearchContent: View {
    @Binding var searchText: String
    @Binding var selectedTranslation: String
    @Binding var isSearching: Bool
    @Binding var searchResults: [ScriptureElement]
    @Binding var fullPassageReference: String
    @Binding var selectedScripture: ScriptureElement?
    @Binding var currentStep: ScriptureInsertionStep
    let onSelect: (ScriptureElement) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and search
            VStack(spacing: 0) {
                // Title and close button
                HStack {
                    Text("Scripture")
                        .font(.system(size: 32, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Add close button
                    CloseButton(action: onCancel)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 6)
                
                // Search bar
                HStack(spacing: 5) {
                    // Book icon
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 15))
                        .frame(width: 30)
                    
                    // Search icon
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                    
                    // Using ScriptureCardTextField
                    ScriptureCardTextField(
                        text: $searchText,
                        placeholder: "acts 2:38-40",
                        onSubmit: performSearch
                    )
                    .frame(height: 24)
                    
                    // Search button
                    Button(action: performSearch) {
                        Text("Search")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Translation picker
                    Picker("", selection: $selectedTranslation) {
                        Text("KJV").tag("KJV")
                        Text("ESV").tag("ESV")
                        Text("NIV").tag("NIV")
                        Text("NASB").tag("NASB")
                        Text("NKJV").tag("NKJV")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 60)
                    .labelsHidden()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            }
            .padding(0)
            
            Divider()
            
            // Show the search results or empty state
            if isSearching {
                // Search in progress indicator
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Searching...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !searchResults.isEmpty {
                // Search results list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Passage action button if multiple verses found
                        if searchResults.count > 1 {
                            HStack {
                                Text("Passage: \(fullPassageReference)")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Spacer()
                                
                                Button(action: {
                                    // Create a combined scripture from all verses
                                    let combinedScripture = combineScriptures(searchResults)
                                    selectedScripture = combinedScripture
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentStep = .layout
                                    }
                                }) {
                                    Text("Add Passage")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.96))
                            
                            Divider()
                        }
                        
                        // Individual verses
                        ForEach(searchResults, id: \.reference) { result in
                            // Create a ZStack to allow overlapping views for centered button
                            ZStack(alignment: .trailing) {
                                // Main verse content
                                VStack(alignment: .leading, spacing: 10) {
                                    // Verse reference
                                    HStack {
                                        Text(result.reference)
                                            .font(.system(size: 14, weight: .medium))
                                        
                                        Text("·")
                                            .foregroundColor(.gray)
                                        
                                        Text(result.translation)
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                        
                                        Spacer()
                                    }
                                    
                                    // Verse text
                                    Text(result.cleanedText)
                                        .font(.system(size: 13))
                                        .lineSpacing(4)
                                        .padding(.trailing, 40) // Keep padding for button space
                                }
                                
                                // Add button - centered vertically and positioned at trailing edge
                                Button(action: {
                                    selectedScripture = result
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentStep = .layout
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Circle().fill(Color.blue))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.trailing, 20) // Align with the parent container padding
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            
                            // Add divider between results
                            if result.reference != searchResults.last?.reference {
                                Divider()
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            } else {
                // Empty state or initial state
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "book")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.7))
                    
                    Text("Search for a scripture reference")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text("For example: John 3:16, Romans 8:28-39, Psalm 23")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Call the parent view's search function
        Task {
            await MainActor.run {
                isSearching = true
                
                // Use the Bible API to perform the search
                Task {
                    do {
                        let result = try await BibleAPI.searchVerses(
                            query: searchText,
                            translation: selectedTranslation,
                            mode: .reference
                        )
                        
                        // Process the search results
                        let scriptureElements = result.verses.map { verse -> ScriptureElement in
                            return ScriptureElement(
                                reference: verse.reference,
                                translation: verse.translation,
                                text: verse.text
                            )
                        }
                        
                        // Update the UI on the main thread
                        await MainActor.run {
                            searchResults = scriptureElements
                            isSearching = false
                            
                            // Set the full passage reference
                            if !scriptureElements.isEmpty {
                                fullPassageReference = scriptureElements.first?.reference ?? ""
                                
                                // If there are multiple verses, adjust the full passage reference
                                if scriptureElements.count > 1 {
                                    if let firstRef = scriptureElements.first?.reference, let lastRef = scriptureElements.last?.reference {
                                        // Extract verse numbers from references
                                        let firstVerse = firstRef.components(separatedBy: ":").last ?? ""
                                        let lastVerse = lastRef.components(separatedBy: ":").last ?? ""
                                        
                                        // Combine into a range if possible
                                        if !firstVerse.isEmpty && !lastVerse.isEmpty {
                                            let baseRef = firstRef.components(separatedBy: ":").first ?? ""
                                            fullPassageReference = "\(baseRef):\(firstVerse)-\(lastVerse)"
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        print("Search error: \(error)")
                        
                        // Update UI on the main thread
                        await MainActor.run {
                            isSearching = false
                        }
                    }
                }
            }
        }
    }
    
    private func combineScriptures(_ scriptures: [ScriptureElement]) -> ScriptureElement {
        guard !scriptures.isEmpty else {
            return ScriptureElement(reference: "", translation: "KJV", text: "")
        }
        
        let firstRef = scriptures.first?.reference ?? ""
        let lastRef = scriptures.last?.reference ?? ""
        
        // Create a passage reference (e.g., "John 3:16-18")
        let baseRef = firstRef.components(separatedBy: ":").first ?? ""
        let firstVerse = firstRef.components(separatedBy: ":").last ?? ""
        let lastVerse = lastRef.components(separatedBy: ":").last ?? ""
        
        let passageRef: String
        if firstRef == lastRef {
            passageRef = firstRef
        } else if !firstVerse.isEmpty && !lastVerse.isEmpty {
            passageRef = "\(baseRef):\(firstVerse)-\(lastVerse)"
        } else {
            passageRef = "\(firstRef) - \(lastRef)"
        }
        
        // Process and combine the verses, detecting and merging fragments
        var formattedVerses: [String] = []
        var pendingFragment: String? = nil
        
        for (index, scripture) in scriptures.enumerated() {
            // Check if this is a verse reference without content (fragment)
            let referenceComponents = scripture.reference.components(separatedBy: ":")
            let isPartialReference = referenceComponents.count > 1 && 
                                   (referenceComponents[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            if isPartialReference {
                // This is a verse reference without a number (e.g., "Acts 2:")
                // Store it as a pending fragment to be combined with the next verse
                pendingFragment = scripture.reference
                continue
            }
            
            // Get verse number and text
            let verseNumber: String
            
            if let lastPart = scripture.reference.components(separatedBy: ":").last {
                verseNumber = lastPart.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                verseNumber = "\(index + 1)"
            }
            
            let cleanedText = scripture.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle pending fragments
            if pendingFragment != nil {
                // This verse follows a fragment, format with the correct verse number
                formattedVerses.append("[\(verseNumber)] \(cleanedText)")
                pendingFragment = nil
            } else {
                // Normal verse, use the verse number from reference
                formattedVerses.append("[\(verseNumber)] \(cleanedText)")
            }
        }
        
        // Join all verses with newlines to ensure proper separation
        let combinedText = formattedVerses.joined(separator: "\n")
        
        return ScriptureElement(
            reference: passageRef,
            translation: scriptures.first?.translation ?? "KJV",
            text: combinedText
        )
    }
}

// Create a content view for the layout selection step
struct ScriptureLayoutSelectionContent: View {
    let scripture: ScriptureElement
    let onSelect: (ScriptureElement, ScriptureLayoutStyle) -> Void
    let onBack: () -> Void
    let onCancel: () -> Void
    @State private var selectedLayout: ScriptureLayoutStyle
    @Environment(\.colorScheme) var colorScheme
    
    // Use the shared AppSettings instance with @State for @Observable classes
    @State private var appSettings = AppSettings.shared
    
    // Add State variable for the popover
    @State private var showColorPopover = false
    
    init(scripture: ScriptureElement, onSelect: @escaping (ScriptureElement, ScriptureLayoutStyle) -> Void, onBack: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.scripture = scripture
        self.onSelect = onSelect
        self.onBack = onBack
        self.onCancel = onCancel
        // Initialize selectedLayout with the current default
        _selectedLayout = State(initialValue: AppSettings.shared.defaultScriptureLayout)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.12) : Color.white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Choose Layout
            HStack {
                Text("Choose Layout")
                    .font(.title2)
                    .fontWeight(.medium)
                Spacer()
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                }
                .buttonStyle(PlainButtonStyle())
                CloseButton(action: onCancel)
            }
            .padding(20)
            
            Divider()
            
            // New Row for Default Layout and Color Picker
            HStack(spacing: 20) {
                Picker("Default Layout", selection: $appSettings.defaultScriptureLayout) {
                    ForEach(ScriptureLayoutStyle.allCases) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
                
                Spacer() // Pushes layout picker to the left

                // Scripture Line Color Selector
                Text("Scripture Line Color")
                    .font(.system(size: 14))

                Button(action: { showColorPopover.toggle() }) {
                    Circle()
                        .fill(appSettings.scriptureLineColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showColorPopover, arrowEdge: .bottom) {
                    ScriptureColorPopover(selectedColor: $appSettings.scriptureLineColor)
                }
                
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            
            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Individual Verses Layout
                    layoutOption(
                        title: "Individual Verses",
                        description: "Each verse on its own line with reference",
                        isSelected: selectedLayout == .individualVerses,
                        action: { selectedLayout = .individualVerses }
                    ) {
                        previewIndividualVerses
                    }
                    
                    Divider()
                    
                    // Paragraph Layout
                    layoutOption(
                        title: "Paragraph",
                        description: "Continuous text with verse numbers in brackets",
                        isSelected: selectedLayout == .paragraph,
                        action: { selectedLayout = .paragraph }
                    ) {
                        previewParagraph
                    }
                    
                    Divider()
                    
                    // Reference Layout
                    layoutOption(
                        title: "Reference Layout",
                        description: "Two-column layout with references on left",
                        isSelected: selectedLayout == .reference,
                        action: { selectedLayout = .reference }
                    ) {
                        previewReference
                    }
                    
                    // Removed Color Picker from here
                    
                    Divider()
                }
                .padding(.vertical, 15)
            }
            
            Divider()
            
            // Footer with Insert button
            HStack {
                Button(action: onBack) {
                    Text("Back")
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Spacer()
                
                Button(action: {
                    onSelect(scripture, selectedLayout)
                }) {
                    Text("Insert")
                        .frame(minWidth: 80)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
        .background(backgroundColor)
    }
    
    // Layout option builder
    private func layoutOption<Content: View>(
        title: String,
        description: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 22))
                    } else {
                        Circle()
                            .strokeBorder(Color.gray.opacity(0.5), lineWidth: 1)
                            .frame(width: 22, height: 22)
                    }
                }
                
                // Preview of the layout
                content()
                    .padding(10)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.18) : Color(.sRGB, white: 0.95))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Preview for Individual Verses layout
    private var previewIndividualVerses: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Acts 2:38")
                .font(.system(size: 13, weight: .medium))
            Text("Then Peter said unto them, Repent...")
                .font(.system(size: 12))
                .lineLimit(1)
            
            Text("Acts 2:39")
                .font(.system(size: 13, weight: .medium))
                .padding(.top, 4)
            Text("For the promise is unto you...")
                .font(.system(size: 12))
                .lineLimit(1)
        }
    }
    
    // Preview for Paragraph layout
    private var previewParagraph: some View {
        Text("[38] Then Peter said unto them, Repent... [39] For the promise is unto you...")
            .font(.system(size: 12))
            .lineLimit(2)
    }
    
    // Preview for Reference layout - Updated to work with single verses
    private var previewReference: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(getPreviewReference())
                    .font(.system(size: 12, weight: .medium))
                
                // Only show second reference for preview if this is a multi-verse example
                if scripture.text.contains("\n") {
                    Text("Acts 2:39")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            
            Rectangle()
                .frame(width: 1)
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(getPreviewVerseText())
                    .font(.system(size: 12))
                    .lineLimit(1)
                
                // Only show second verse for preview if this is a multi-verse example
                if scripture.text.contains("\n") {
                    Text("For the promise is unto you...")
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
            }
        }
    }
    
    // Helper methods to customize preview based on actual scripture
    private func getPreviewReference() -> String {
        // Use actual scripture reference if available, otherwise fallback to example
        return scripture.reference.isEmpty ? "Acts 2:38" : scripture.reference
    }
    
    private func getPreviewVerseText() -> String {
        // Use first line of actual scripture text if available, otherwise fallback to example
        if let firstLine = scripture.cleanedText.components(separatedBy: "\n").first, !firstLine.isEmpty {
            // Truncate if too long
            let maxLength = 40
            if firstLine.count > maxLength {
                return String(firstLine.prefix(maxLength)) + "..."
            }
            return firstLine
        }
        return "Then Peter said unto them, Repent..."
    }
}

// Helper function to get color names
private func colorName(for color: Color) -> String {
    if color == Color(hex: "#22C55E") { return "Green" }
    if color == Color(hex: "#3B82F6") { return "Blue" }
    if color == Color(hex: "#EC4899") { return "Pink" }
    if color == Color(hex: "#A855F7") { return "Purple" }
    if color == Color(hex: "#F97316") { return "Orange" }
    if color == Color(hex: "#EF4444") { return "Red" }
    if color == Color(hex: "#EAB308") { return "Yellow" }
    if color == Color(hex: "#10B981") { return "Teal" }
    if color == Color(hex: "#9CA3AF") { return "Light Gray" }
    return "Custom"
}

// New View for the Color Popover Content
struct ScriptureColorPopover: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) var dismiss

    let modernColors: [Color] = [
        Color(hex: "#22C55E"), // Vivid Green
        Color(hex: "#3B82F6"), // Vivid Blue
        Color(hex: "#EC4899"), // Vivid Pink
        Color(hex: "#A855F7"), // Vivid Purple
        Color(hex: "#F97316"), // Vivid Orange
        Color(hex: "#EF4444"), // Vivid Red
        Color(hex: "#EAB308"), // Vivid Yellow
        Color(hex: "#10B981"), // Vivid Teal
        Color(hex: "#9CA3AF")  // Light Gray
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(modernColors, id: \.self) { color in
                Button(action: {
                    selectedColor = color
                    dismiss()
                }) {
                    Circle()
                        .fill(color)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.3), lineWidth: selectedColor == color ? 2 : 1)
                        )
                        .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }
}

// MARK: - Close Button
struct CloseButton: View {
    @State private var isHoveringClose = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(isHoveringClose ? Color.red : Color.gray.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHoveringClose = hovering
        }
    }
}

// ScriptureSearchView wrapper to coordinate the search process
struct ScriptureSearchView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var searchResults: [ScriptureElement] = []
    @State private var fullPassageReference: String = ""
    @State private var isSearching = false
    @State private var selectedTranslation = "KJV"
    @State private var selectedScripture: ScriptureElement?
    @State private var currentStep: ScriptureInsertionStep = .search
    @Environment(\.colorScheme) var colorScheme
    
    let onSelect: (ScriptureElement) -> Void
    let onCancel: () -> Void
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.12) : Color.white
    }
    
    var body: some View {
        ZStack {
            // Search view
            Group {
                if currentStep == .search {
                    ScriptureSearchContent(
                        searchText: $searchText,
                        selectedTranslation: $selectedTranslation,
                        isSearching: $isSearching,
                        searchResults: $searchResults,
                        fullPassageReference: $fullPassageReference,
                        selectedScripture: $selectedScripture,
                        currentStep: $currentStep,
                        onSelect: onSelect,
                        onCancel: onCancel
                    )
                    .transition(AnyTransition.asymmetric(
                        insertion: .opacity,
                        removal: .opacity
                    ))
                } else {
                    EmptyView()
                }
            }
            
            // Layout selection view
            Group {
                if currentStep == .layout, let scripture = selectedScripture {
                    ScriptureLayoutSelectionContent(
                        scripture: scripture,
                        onSelect: { scripture, layout in
                            // First send explicit layout value via callback
                            let layoutValue = layoutToInt(layout)
                            
                            // Then post notification with explicit value
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ScriptureLayoutSelected"),
                                object: nil,
                                userInfo: ["layout": layoutValue]
                            )
                            
                            // Finally call scripture selection callback
                            onSelect(scripture)
                        },
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentStep = .search
                            }
                        },
                        onCancel: onCancel
                    )
                    .transition(AnyTransition.asymmetric(
                        insertion: .opacity,
                        removal: .opacity
                    ))
                } else {
                    EmptyView()
                }
            }
        }
        .frame(width: 700, height: 500)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !searchText.isEmpty {
                    performSearch()
                }
            }
        }
    }
    
    private func performSearch() {
        Task {
            await MainActor.run {
                isSearching = true
                
                // Use the Bible API to perform the search
                Task {
                    do {
                        let result = try await BibleAPI.searchVerses(
                            query: searchText,
                            translation: selectedTranslation, 
                            mode: .reference
                        )
                        
                        // Process the search results
                        let scriptureElements = result.verses.map { verse -> ScriptureElement in
                            return ScriptureElement(
                                reference: verse.reference,
                                translation: verse.translation,
                                text: verse.text
                            )
                        }
                        
                        // Update the UI on the main thread
                        await MainActor.run {
                            searchResults = scriptureElements
                            isSearching = false
                            
                            // Set the full passage reference
                            if !scriptureElements.isEmpty {
                                fullPassageReference = scriptureElements.first?.reference ?? ""
                                
                                // If there are multiple verses, adjust the full passage reference
                                if scriptureElements.count > 1 {
                                    if let firstRef = scriptureElements.first?.reference, let lastRef = scriptureElements.last?.reference {
                                        // Extract verse numbers from references
                                        let firstVerse = firstRef.components(separatedBy: ":").last ?? ""
                                        let lastVerse = lastRef.components(separatedBy: ":").last ?? ""
                                        
                                        // Combine into a range if possible
                                        if !firstVerse.isEmpty && !lastVerse.isEmpty {
                                            let baseRef = firstRef.components(separatedBy: ":").first ?? ""
                                            fullPassageReference = "\(baseRef):\(firstVerse)-\(lastVerse)"
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        print("Error searching verses: \(error)")
                        
                        // Update UI on the main thread
                        await MainActor.run {
                            isSearching = false
                        }
                    }
                }
            }
        }
    }
}
#endif 
