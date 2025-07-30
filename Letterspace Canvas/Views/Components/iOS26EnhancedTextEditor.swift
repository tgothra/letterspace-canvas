#if os(iOS)
import SwiftUI
import UIKit
import NaturalLanguage

// MARK: - iOS 26 Enhanced Text Editor
@available(iOS 26.0, *)
struct iOS26EnhancedTextEditor: UIViewRepresentable {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var isEditing: Bool
    
    @StateObject private var textEditingService = iOS26TextEditingService.shared
    @StateObject private var rtfService = iOS26RTFService.shared
    
    // iOS 26 Enhancement: Advanced text editing settings
    @State private var smartSelectionEnabled = true
    @State private var markdownPreviewEnabled = true
    @State private var aiSuggestionsEnabled = true
    
    // Callbacks
    let onTextChange: ((String, NSAttributedString) -> Void)?
    let onSelectionChange: ((Bool) -> Void)?
    let onFocusChange: ((Bool) -> Void)?
    
    init(
        document: Binding<Letterspace_CanvasDocument>,
        isEditing: Binding<Bool>,
        onTextChange: ((String, NSAttributedString) -> Void)? = nil,
        onSelectionChange: ((Bool) -> Void)? = nil,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._document = document
        self._isEditing = isEditing
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
        self.onFocusChange = onFocusChange
    }
    
    func makeUIView(context: Context) -> iOS26TextEditorView {
        let textView = iOS26TextEditorView()
        textView.delegate = context.coordinator
        textView.textEditingService = textEditingService
        textView.rtfService = rtfService
        
        // iOS 26 Enhancement: Configure advanced features
        textView.setupiOS26Features()
        
        return textView
    }
    
    func updateUIView(_ uiView: iOS26TextEditorView, context: Context) {
        // iOS 26 Enhancement: Update with enhanced RTF content
        if let element = document.elements.first(where: { $0.type == .textBlock }),
           let enhancedContent = element.enhancedAttributedContent {
            
            if uiView.attributedText != enhancedContent {
                uiView.attributedText = enhancedContent
            }
        }
        
        // Update iOS 26 settings
        uiView.updateiOS26Settings(
            smartSelection: smartSelectionEnabled,
            markdownPreview: markdownPreviewEnabled,
            aiSuggestions: aiSuggestionsEnabled
        )
        
        // Update editing state
        if isEditing && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isEditing && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UITextViewDelegate, iOS26TextEditorDelegate {
        var parent: iOS26EnhancedTextEditor
        
        init(_ parent: iOS26EnhancedTextEditor) {
            self.parent = parent
        }
        
        // MARK: - UITextViewDelegate
        func textViewDidChange(_ textView: UITextView) {
            guard textView is iOS26TextEditorView else { return }
            
            // Performance: Update content immediately but defer expensive operations
            var updatedDocument = parent.document
            
            if let index = updatedDocument.elements.firstIndex(where: { $0.type == .textBlock }) {
                var element = updatedDocument.elements[index]
                element.content = textView.text
                updatedDocument.elements[index] = element
            } else {
                var element = DocumentElement(type: .textBlock)
                element.content = textView.text
                updatedDocument.elements.append(element)
            }
            
            // Update document immediately
            parent.document = updatedDocument
            
            // Defer expensive RTF processing and saving to background
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                // Create RTF data on background thread
                if let enhancedRTFData = self.parent.rtfService.createEnhancedRTF(from: textView.attributedText) {
                    var updatedDoc = self.parent.document
                    if let index = updatedDoc.elements.firstIndex(where: { $0.type == .textBlock }) {
                        var element = updatedDoc.elements[index]
                        element.rtfData = enhancedRTFData
                        updatedDoc.elements[index] = element
                    }
                    
                    DispatchQueue.main.async {
                        self.parent.document = updatedDoc
                        
                        // Save on background thread
                        DispatchQueue.global(qos: .utility).async {
                            self.parent.document.save()
                        }
                        
                        // Trigger callback
                        self.parent.onTextChange?(textView.text, textView.attributedText)
                    }
                }
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            let hasSelection = textView.selectedRange.length > 0
            parent.onSelectionChange?(hasSelection)
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange?(true)
            parent.isEditing = true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange?(false)
            parent.isEditing = false
        }
        
        // MARK: - iOS 26 Text Editor Delegate
        func textEditor(_ textEditor: iOS26TextEditorView, didReceiveSmartSelection range: NSRange) {
            // Handle smart selection
            textEditor.selectedRange = range
            HapticFeedback.impact(.light, intensity: 0.7)
        }
        
        func textEditor(_ textEditor: iOS26TextEditorView, didReceiveTextSuggestions suggestions: [TextSuggestion]) {
            // Handle AI suggestions
            print("📝 iOS 26: Received \(suggestions.count) text suggestions")
        }
        
        func textEditor(_ textEditor: iOS26TextEditorView, shouldApplyMarkdownStyling text: String) -> Bool {
            return parent.markdownPreviewEnabled
        }
    }
}

// MARK: - iOS 26 Text Editor View
@available(iOS 26.0, *)
class iOS26TextEditorView: UITextView {
    
    // iOS 26 Services
    weak var textEditingService: iOS26TextEditingService?
    weak var rtfService: iOS26RTFService?
    weak var ios26Delegate: iOS26TextEditorDelegate?
    
    // iOS 26 Enhancement: Advanced text features
    private var smartSelectionEnabled = true
    private var markdownPreviewEnabled = true
    private var aiSuggestionsEnabled = true
    
    // iOS 26 Enhancement: Gesture recognizers
    private var doubleTapGestureRecognizer: UITapGestureRecognizer!
    private var tripleTapGestureRecognizer: UITapGestureRecognizer!
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Basic configuration
        isScrollEnabled = true
        isEditable = true
        isUserInteractionEnabled = true
        allowsEditingTextAttributes = true
        
        // iOS 26 Enhancement: Enhanced text input traits
        autocorrectionType = .default
        spellCheckingType = .default
        smartQuotesType = .default
        smartDashesType = .default
        smartInsertDeleteType = .default
        
        // iOS 26 Enhancement: Font and styling
        font = UIFont.systemFont(ofSize: 16)
        textColor = .label
        backgroundColor = .systemBackground
        
        // iOS 26 Enhancement: Content insets for better readability
        textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        print("🎯 iOS 26 Enhanced Text Editor View initialized")
    }
    
    func setupiOS26Features() {
        setupGestureRecognizers()
        setupKeyboardObservers()
    }
    
    private func setupGestureRecognizers() {
        // iOS 26 Enhancement: Smart selection gestures
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.delegate = self
        addGestureRecognizer(doubleTapGestureRecognizer)
        
        tripleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTripleTap(_:)))
        tripleTapGestureRecognizer.numberOfTapsRequired = 3
        tripleTapGestureRecognizer.delegate = self
        addGestureRecognizer(tripleTapGestureRecognizer)
        
        // iOS 26 Enhancement: Gesture precedence
        doubleTapGestureRecognizer.require(toFail: tripleTapGestureRecognizer)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidShow(_:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidHide(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }
    
    func updateiOS26Settings(smartSelection: Bool, markdownPreview: Bool, aiSuggestions: Bool) {
        smartSelectionEnabled = smartSelection
        markdownPreviewEnabled = markdownPreview
        aiSuggestionsEnabled = aiSuggestions
        
        // iOS 26 Enhancement: Apply markdown styling if enabled
        if markdownPreviewEnabled {
            applyMarkdownStyling()
        }
    }
    
    // MARK: - iOS 26 Smart Selection
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard smartSelectionEnabled, let textEditingService = textEditingService else { return }
        
        let location = gesture.location(in: self)
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        let smartRange = textEditingService.performSmartSelection(in: self, at: characterIndex)
        ios26Delegate?.textEditor(self, didReceiveSmartSelection: smartRange)
        
        print("🎯 iOS 26: Smart double-tap selection at \(characterIndex)")
    }
    
    @objc private func handleTripleTap(_ gesture: UITapGestureRecognizer) {
        guard smartSelectionEnabled else { return }
        
        let location = gesture.location(in: self)
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        // iOS 26 Enhancement: Triple tap selects paragraph
        let text = attributedText.string as NSString
        let paragraphRange = text.paragraphRange(for: NSRange(location: characterIndex, length: 0))
        
        ios26Delegate?.textEditor(self, didReceiveSmartSelection: paragraphRange)
        
        print("🎯 iOS 26: Smart triple-tap paragraph selection")
    }
    
    // MARK: - iOS 26 Markdown Enhancement
    private func applyMarkdownStyling() {
        guard markdownPreviewEnabled, let textEditingService = textEditingService else { return }
        
        let enhancedText = textEditingService.enhanceMarkdown(text: text)
        
        // iOS 26 Enhancement: Apply without losing selection
        let currentSelection = selectedRange
        attributedText = enhancedText
        selectedRange = currentSelection
        
        print("📝 iOS 26: Applied markdown styling")
    }
    
    // MARK: - iOS 26 AI Suggestions
    override func insertText(_ text: String) {
        super.insertText(text)
        
        // iOS 26 Enhancement: Trigger AI analysis after text insertion
        if aiSuggestionsEnabled, let textEditingService = textEditingService {
            textEditingService.analyzeText(self.text) { [weak self] suggestions in
                guard let self = self else { return }
                self.ios26Delegate?.textEditor(self, didReceiveTextSuggestions: suggestions)
            }
        }
        
        // iOS 26 Enhancement: Apply markdown styling on the fly
        if markdownPreviewEnabled && (text == "*" || text == "`" || text == "#" || text == "[") {
            applyMarkdownStyling()
        }
    }
    
    // Suppress the iOS system selection/copy/paste/formatting menu so only the custom toolbar displays
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Only allow paste to maintain basic usability, or return false for everything to suppress all
        return false
    }
    
    // MARK: - iOS 26 Keyboard Handling
    @objc private func keyboardDidShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        // iOS 26 Enhancement: Adjust content insets for keyboard
        let keyboardHeight = keyboardFrame.height
        contentInset.bottom = keyboardHeight
        verticalScrollIndicatorInsets.bottom = keyboardHeight
        
        // iOS 26 Enhancement: Scroll to cursor if needed
        if selectedRange.location != NSNotFound {
            scrollRangeToVisible(selectedRange)
        }
    }
    
    @objc private func keyboardDidHide(_ notification: Notification) {
        // iOS 26 Enhancement: Reset content insets
        contentInset.bottom = 0
        verticalScrollIndicatorInsets.bottom = 0
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - iOS 26 Text Editor Delegate Protocol
@available(iOS 26.0, *)
protocol iOS26TextEditorDelegate: AnyObject {
    func textEditor(_ textEditor: iOS26TextEditorView, didReceiveSmartSelection range: NSRange)
    func textEditor(_ textEditor: iOS26TextEditorView, didReceiveTextSuggestions suggestions: [TextSuggestion])
    func textEditor(_ textEditor: iOS26TextEditorView, shouldApplyMarkdownStyling text: String) -> Bool
}

// MARK: - UIGestureRecognizerDelegate
@available(iOS 26.0, *)
extension iOS26TextEditorView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // iOS 26 Enhancement: Allow simultaneous gesture recognition
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // iOS 26 Enhancement: Only handle touches on text
        let location = touch.location(in: self)
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        return characterIndex < textStorage.length
    }
}

// MARK: - iOS 26 Text Editor Wrapper View
@available(iOS 26.0, *)
struct iOS26TextEditorWrapper: View {
    @Binding var document: Letterspace_CanvasDocument
    @State private var isEditing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // iOS 26 Enhancement: Status bar
            if #available(iOS 26.0, *) {
                iOS26TextEditorStatusBar(
                    isEditing: $isEditing,
                    rtfService: iOS26RTFService.shared,
                    textEditingService: iOS26TextEditingService.shared
                )
            }
            
            // iOS 26 Native AttributedString TextEditor
            if #available(iOS 26.0, *) {
                iOS26NativeAttributedTextEditor(document: $document)
            } else {
                // Fallback for pre-iOS 26
                iOS26EnhancedTextEditor(
                    document: $document,
                    isEditing: $isEditing,
                    onTextChange: { text, attributedText in
                        print("📝 iOS 26: Text changed - \(text.count) characters")
                    },
                    onSelectionChange: { hasSelection in
                        print("🎯 iOS 26: Selection changed - \(hasSelection ? "has selection" : "no selection")")
                    },
                    onFocusChange: { isFocused in
                        print("🔍 iOS 26: Focus changed - \(isFocused ? "focused" : "unfocused")")
                    }
                )
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - iOS 26 Status Bar
@available(iOS 26.0, *)
struct iOS26TextEditorStatusBar: View {
    @Binding var isEditing: Bool
    @ObservedObject var rtfService: iOS26RTFService
    @ObservedObject var textEditingService: iOS26TextEditingService
    
    var body: some View {
        HStack {
            // Status indicators
            HStack(spacing: 8) {
                if rtfService.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Processing RTF...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if textEditingService.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Analyzing text...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !rtfService.isProcessing && !textEditingService.isAnalyzing {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("iOS 26 Enhanced")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Performance metrics
            if rtfService.lastProcessingTime > 0 {
                Text("\(String(format: "%.3f", rtfService.lastProcessingTime))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - iOS 26 Native AttributedString Text Editor
@available(iOS 26.0, *)
struct iOS26NativeAttributedTextEditor: View {
    @Binding var document: Letterspace_CanvasDocument
    @State private var attributedText: AttributedString = AttributedString()
    
    var body: some View {
        VStack {
            // iOS 26 Native: TextEditor with AttributedString binding
            TextEditor(text: $attributedText)
                .font(.system(size: 16))
                .padding()
                .background(Color(.systemBackground))
                .onChange(of: attributedText) { _, newValue in
                    updateDocument(with: newValue)
                }
                .onAppear {
                    loadAttributedText()
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
    }
    
    private func loadAttributedText() {
        // Load from document
        if let element = document.elements.first(where: { $0.type == .textBlock }) {
            if let rtfData = element.rtfData {
                // Try to convert RTF to AttributedString
                if let nsAttributedString = try? NSAttributedString(
                    data: rtfData,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                ) {
                    // Convert NSAttributedString to AttributedString
                    attributedText = AttributedString(nsAttributedString)
                } else {
                    // Fallback to plain text
                    attributedText = AttributedString(element.content)
                }
            } else {
                attributedText = AttributedString(element.content)
            }
        }
    }
    
    private func updateDocument(with newAttributedText: AttributedString) {
        // Convert AttributedString back to document format
        let nsAttributedString = NSAttributedString(newAttributedText)
        
        // Create RTF data
        let rtfData = try? nsAttributedString.data(
            from: NSRange(location: 0, length: nsAttributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        
        // Update document
        var updatedDocument = document
        if let index = updatedDocument.elements.firstIndex(where: { $0.type == .textBlock }) {
            var element = updatedDocument.elements[index]
            element.content = String(newAttributedText.characters)
            element.rtfData = rtfData
            updatedDocument.elements[index] = element
        } else {
            var element = DocumentElement(type: .textBlock)
            element.content = String(newAttributedText.characters)
            element.rtfData = rtfData
            updatedDocument.elements.append(element)
        }
        
        document = updatedDocument
        
        // Save asynchronously
        DispatchQueue.global(qos: .utility).async {
            document.save()
        }
    }
}

#endif 
