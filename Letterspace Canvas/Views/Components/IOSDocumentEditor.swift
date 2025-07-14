#if os(iOS)
import SwiftUI
import Combine

// MARK: - Main iOS Document Editor
struct IOSDocumentEditor: View {
    @Binding var document: Letterspace_CanvasDocument
    let onScrollChange: ((CGFloat) -> Void)?
    
    @State private var textContent: String = ""
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                SimpleIOSTextView(
                    text: $textContent,
                    colorScheme: colorScheme,
                    document: $document,
                    onTextChange: { newText in
                        updateDocumentContent(newText)
                    },
                    onAttributedTextChange: { plainText, attributedText in
                        updateDocumentWithFormatting(plainText, attributedText: attributedText)
                    },
                    onScrollChange: onScrollChange
                )
            }
        }
        .onAppear {
            loadDocumentContent()
        }
    }
    
    private func loadDocumentContent() {
        if let textElement = document.elements.first(where: { $0.type == .textBlock }) {
            textContent = textElement.content
            
            // Apply attributed content if available
            if let attributedContent = textElement.attributedContent {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ApplyAttributedContent"),
                        object: nil,
                        userInfo: ["attributedContent": attributedContent]
                    )
                }
            }
        }
    }
    
    private func updateDocumentContent(_ newContent: String) {
        if let index = document.elements.firstIndex(where: { $0.type == .textBlock }) {
            document.elements[index].content = newContent
        } else {
            let element = DocumentElement(type: .textBlock, content: newContent)
            document.elements.append(element)
        }
        
        document.modifiedAt = Date()
        document.updateCanvasDocument()
        
        DispatchQueue.global(qos: .userInitiated).async {
        document.save()
        }
    }
    
    private func updateDocumentWithFormatting(_ newContent: String, attributedText: NSAttributedString) {
        if let index = document.elements.firstIndex(where: { $0.type == .textBlock }) {
            var newElement = DocumentElement(type: .textBlock, content: newContent)
            newElement.attributedContent = attributedText
            document.elements[index] = newElement
        } else {
            var element = DocumentElement(type: .textBlock, content: newContent)
            element.attributedContent = attributedText
            document.elements.append(element)
        }
        
        document.modifiedAt = Date()
        document.updateCanvasDocument()
        
        DispatchQueue.global(qos: .userInitiated).async {
            document.save()
        }
    }
}

// MARK: - Simple iOS Text View
struct SimpleIOSTextView: UIViewRepresentable {
    @Binding var text: String
    let colorScheme: ColorScheme
    @Binding var document: Letterspace_CanvasDocument
    let onTextChange: (String) -> Void
    let onAttributedTextChange: ((String, NSAttributedString) -> Void)?
    let onScrollChange: ((CGFloat) -> Void)?
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let textView = UITextView()
        
        // Configure scroll view
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = context.coordinator
        scrollView.keyboardDismissMode = .interactive // Enable swipe-to-dismiss keyboard
        
        // Configure text view
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textView.backgroundColor = UIColor.clear
        textView.textColor = colorScheme == .dark ? UIColor.white : UIColor.black
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 24, bottom: 300, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        textView.text = text
        
        // Enable link detection and interaction
        textView.isEditable = true
        textView.isSelectable = true
        textView.dataDetectorTypes = [.link] // Auto-detect links
        // Don't set linkTextAttributes - let our custom attributes take precedence
        textView.linkTextAttributes = [:]
        
        // Add text view to scroll view
        scrollView.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            textView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Store references
        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView
        context.coordinator.onTextChange = onTextChange
        context.coordinator.onAttributedTextChange = onAttributedTextChange
        context.coordinator.onScrollChange = onScrollChange
        
        // Setup formatting toolbar
        context.coordinator.setupFormattingToolbar(colorScheme: colorScheme)
        
        // Setup attributed content notification
        context.coordinator.setupAttributedContentNotification()
        
        // Setup search highlighting notification
        context.coordinator.setupSearchHighlightNotification()
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        
        // Update text if changed
        if textView.text != text {
            textView.text = text
        }
        
        // Update colors
        let expectedColor = colorScheme == .dark ? UIColor.white : UIColor.black
        if textView.textColor != expectedColor {
            textView.textColor = expectedColor
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, document: $document)
    }
    
    class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        @Binding var text: String
        var onTextChange: ((String) -> Void)?
        var onAttributedTextChange: ((String, NSAttributedString) -> Void)?
        var onScrollChange: ((CGFloat) -> Void)?
        var scrollView: UIScrollView?
        var textView: UITextView?
        @Binding var document: Letterspace_CanvasDocument

        private var applyAttributedContentObserver: NSObjectProtocol?
        private var searchHighlightObserver: NSObjectProtocol?
        private var attributedTextSaveTimer: Timer?
        
        init(text: Binding<String>, document: Binding<Letterspace_CanvasDocument>) {
            self._text = text
            self._document = document
            super.init()
            
            // Set up keyboard notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }
        
        deinit {
            if let observer = applyAttributedContentObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = searchHighlightObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            attributedTextSaveTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - Keyboard Handling
        @objc private func keyboardWillShow(_ notification: Notification) {
            guard let scrollView = scrollView,
                  let textView = textView,
                  let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                return
            }
            
            // Animate the toolbar fade-in along with keyboard appearance
            if let toolbar = textView.inputAccessoryView {
                toolbar.alpha = 0.0
                UIView.animate(withDuration: animationDuration,
                             delay: 0,
                             options: [.curveEaseInOut],
                             animations: {
                    toolbar.alpha = 1.0
                })
            }
            
            // Check if the document text view is NOT the first responder (likely a header TextField is focused)
            if !textView.isFirstResponder {
                print("🎹 Document text view is not first responder (likely header TextField), skipping auto-scroll to cursor")
                
                // Still adjust content insets for keyboard but don't scroll to cursor
                let keyboardFrameInScrollView = scrollView.convert(keyboardFrame, from: nil)
                let scrollViewBounds = scrollView.bounds
                let intersection = keyboardFrameInScrollView.intersection(scrollViewBounds)
                let keyboardHeight = intersection.height
                let toolbarHeight = textView.inputAccessoryView?.frame.height ?? 50
                let additionalPadding: CGFloat = UIDevice.current.orientation.isLandscape ? 100 : 80
                let totalHeight = keyboardHeight + toolbarHeight + additionalPadding
                
                let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: totalHeight, right: 0)
                scrollView.contentInset = contentInsets
                scrollView.scrollIndicatorInsets = contentInsets
                return
            }
            
            // Get the keyboard frame in the scroll view's coordinate space
            let keyboardFrameInScrollView = scrollView.convert(keyboardFrame, from: nil)
            
            // Calculate how much of the keyboard overlaps with the scroll view
            let scrollViewBounds = scrollView.bounds
            let intersection = keyboardFrameInScrollView.intersection(scrollViewBounds)
            let keyboardHeight = intersection.height
            
            // Add extra height for the toolbar (input accessory view) plus additional padding
            let toolbarHeight = textView.inputAccessoryView?.frame.height ?? 50
            // More padding in landscape since keyboard takes up more screen space
            let additionalPadding: CGFloat = UIDevice.current.orientation.isLandscape ? 100 : 80
            let totalHeight = keyboardHeight + toolbarHeight + additionalPadding
            
            print("🎹 Keyboard intersection height: \(keyboardHeight), Adding toolbar: \(toolbarHeight), Total: \(totalHeight)")
            
            // Adjust content insets to account for keyboard + toolbar
            let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: totalHeight, right: 0)
                scrollView.contentInset = contentInsets
                scrollView.scrollIndicatorInsets = contentInsets
                
            // Scroll to show the cursor/selection only if the document text view is the first responder
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Double-check that our document text view is still the first responder
                if textView.isFirstResponder {
                    let selectedRange = textView.selectedRange
                    if selectedRange.location != NSNotFound {
                    let cursorRect = textView.caretRect(for: textView.selectedTextRange?.start ?? textView.beginningOfDocument)
                        let convertedRect = textView.convert(cursorRect, to: scrollView)
                    
                    // Add some padding above the cursor
                    let targetRect = CGRect(
                            x: convertedRect.origin.x,
                            y: convertedRect.origin.y - 50,
                            width: convertedRect.width,
                            height: convertedRect.height + 100
                        )
                        
                        scrollView.scrollRectToVisible(targetRect, animated: true)
                        print("🎹 Scrolled to cursor position in document text view")
                    }
                } else {
                    print("🎹 Document text view is not first responder, skipping scroll to cursor")
                }
            }
        }
        
        @objc private func keyboardWillHide(_ notification: Notification) {
            guard let scrollView = scrollView,
                  let textView = textView,
                  let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                return
            }
            
            // Coordinate toolbar dismissal with keyboard animation
            if let toolbar = textView.inputAccessoryView {
                // For slow swipes, use the full animation duration to stay coordinated
                // For fast swipes, this will still be quick enough
                let toolbarDuration = max(animationDuration * 0.8, 0.2) // At least 0.2 seconds, but scale with keyboard
                
                UIView.animate(withDuration: toolbarDuration, 
                             delay: 0,
                             options: [.curveEaseOut, .allowUserInteraction],
                             animations: {
                    toolbar.alpha = 0.0
                }, completion: { _ in
                    // Only resign first responder after toolbar animation completes
                    if textView.isFirstResponder {
                        textView.resignFirstResponder()
                    }
                    // Reset alpha for next appearance
                    DispatchQueue.main.async {
                        toolbar.alpha = 1.0
                    }
                })
            }
            
            // Reset content insets with animation
            UIView.animate(withDuration: animationDuration) {
                scrollView.contentInset = .zero
                scrollView.scrollIndicatorInsets = .zero
            }
        }
        
        func setupAttributedContentNotification() {
            applyAttributedContentObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ApplyAttributedContent"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.applyAttributedContent(notification)
            }
        }
        
        func setupSearchHighlightNotification() {
            searchHighlightObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SearchHighlight"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.processSearchHighlight(notification)
            }
        }
        
        private func applyAttributedContent(_ notification: Notification) {
            guard let textView = textView,
                  let attributedContent = notification.userInfo?["attributedContent"] as? NSAttributedString else {
                return
            }
            
            let currentSelection = textView.selectedRange
            textView.attributedText = NSAttributedString(attributedString: attributedContent)
            text = attributedContent.string
            textView.selectedRange = currentSelection
        }
        
        private func processSearchHighlight(_ notification: Notification) {
            print("🔍 iOS processSearchHighlight called")
            
            guard let textView = textView,
                  let scrollView = scrollView,
                  let userInfo = notification.userInfo,
                  let charPosition = userInfo["charPosition"] as? Int,
                  let charLength = userInfo["charLength"] as? Int else {
                print("🔍 iOS: Missing textView, scrollView, or notification data")
                return
            }
            
            print("🔍 iOS: Search highlight at position \(charPosition), length \(charLength)")
            
            // Safety check
            let textLength = textView.text.count
            guard charPosition >= 0 && charPosition < textLength else {
                print("⚠️ iOS: Invalid character position: \(charPosition), text has \(textLength) characters")
                return
            }
            
            // Create range for the search result
            let searchRange = NSRange(location: charPosition, length: min(charLength, textLength - charPosition))
            
            // Scroll to the search result position
            DispatchQueue.main.async {
                // Calculate the rect for the character range
                let startPosition = textView.position(from: textView.beginningOfDocument, offset: charPosition) ?? textView.beginningOfDocument
                let endPosition = textView.position(from: startPosition, offset: charLength) ?? startPosition
                let textRange = textView.textRange(from: startPosition, to: endPosition)
                
                if let range = textRange {
                    let rect = textView.firstRect(for: range)
                    print("🔍 iOS: Calculated rect for search text: \(rect)")
                    
                    // Convert to scroll view coordinates
                    let convertedRect = textView.convert(rect, to: scrollView)
                    
                    // Position the search result about 20% from the top of the visible area
                    let visibleHeight = scrollView.bounds.height
                    let targetY = max(0, convertedRect.origin.y - (visibleHeight * 0.2))
                    
                    let scrollPoint = CGPoint(x: 0, y: targetY)
                    print("🔍 iOS: Scrolling to point: \(scrollPoint)")
                    
                    scrollView.setContentOffset(scrollPoint, animated: true)
                }
                
                // Apply yellow highlighting
                self.applySearchHighlight(to: textView, range: searchRange)
            }
        }
        
        private func applySearchHighlight(to textView: UITextView, range: NSRange) {
            print("🔍 iOS: Applying yellow highlight to range \(range)")
            
            // Create mutable attributed string from current text
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // Store original attributes for later restoration
            let originalAttributes = mutableAttributedString.attributes(at: range.location, effectiveRange: nil)
            
            // Apply yellow highlight
            let highlightColor = UIColor.systemYellow.withAlphaComponent(0.4)
            mutableAttributedString.addAttribute(.backgroundColor, value: highlightColor, range: range)
            
            // Update the text view
            textView.attributedText = mutableAttributedString
            
            // Set cursor position at the start of the search result
            textView.selectedRange = NSRange(location: range.location, length: 0)
            
            // Schedule removal of highlight after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.removeSearchHighlight(from: textView, range: range, originalAttributes: originalAttributes)
            }
        }
        
        private func removeSearchHighlight(from textView: UITextView, range: NSRange, originalAttributes: [NSAttributedString.Key: Any]) {
            print("🔍 iOS: Removing search highlight")
            
            // Create mutable attributed string
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // Animate the highlight removal with multiple steps
            self.animateSearchHighlightRemoval(textView: textView, range: range, originalAttributes: originalAttributes, step: 0)
        }
        
        private func animateSearchHighlightRemoval(textView: UITextView, range: NSRange, originalAttributes: [NSAttributedString.Key: Any], step: Int) {
            let totalSteps = 6
            let stepDuration = 0.1
            
            if step >= totalSteps {
                // Final step: restore original attributes
                let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                // Remove highlight and restore original attributes
                mutableAttributedString.removeAttribute(.backgroundColor, range: range)
                for (key, value) in originalAttributes {
                    if key != .backgroundColor { // Don't restore background if it was clear originally
                        mutableAttributedString.addAttribute(key, value: value, range: range)
                    }
                }
                
                textView.attributedText = mutableAttributedString
                self.text = textView.text // Update binding
                return
            }
            
            // Calculate fading alpha
            let alpha = 0.4 * (1.0 - (Double(step) / Double(totalSteps)))
            let fadeColor = UIColor.systemYellow.withAlphaComponent(CGFloat(alpha))
            
            // Apply fading highlight
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttributedString.addAttribute(.backgroundColor, value: fadeColor, range: range)
            textView.attributedText = mutableAttributedString
            
            // Schedule next step
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
                self.animateSearchHighlightRemoval(textView: textView, range: range, originalAttributes: originalAttributes, step: step + 1)
            }
        }
        
        // MARK: - UITextViewDelegate
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            onTextChange?(textView.text)
            
            // Update toolbar to reflect current formatting
            updateFormattingToolbar()
            
            // Save attributed text with debounce
            attributedTextSaveTimer?.invalidate()
            attributedTextSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                let attributedText = NSAttributedString(attributedString: textView.attributedText)
                self.onAttributedTextChange?(textView.text, attributedText)
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            // Update toolbar when selection changes to reflect current formatting
            updateFormattingToolbar()
        }
        
        // MARK: - UIScrollViewDelegate
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            onScrollChange?(scrollView.contentOffset.y)
        }
        
        // MARK: - Link Handling
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            // Only allow link interaction when not editing (when keyboard is not visible)
            if !textView.isFirstResponder {
                // Open the link
                UIApplication.shared.open(URL)
                return false // Prevent default behavior since we're handling it
            }
            // In edit mode, don't open links - let user select text instead
            return false
        }
        
        // MARK: - Formatting Toolbar
        private var toolbarHostingController: IOSFormattingToolbarHostingController?
        
        func setupFormattingToolbar(colorScheme: ColorScheme) {
            guard let textView = textView else { return }
            
            let formatting = getCurrentFormatting()
            let toolbar = IOSTextFormattingToolbar(
                onTextStyle: { [weak self] style in
                    self?.applyTextStyle(style, colorScheme: colorScheme)
                    self?.updateFormattingToolbar()
                },
                onBold: { [weak self] in
                    self?.toggleBold()
                    self?.updateFormattingToolbar()
                },
                onItalic: { [weak self] in
                    self?.toggleItalic()
                    self?.updateFormattingToolbar()
                },
                onUnderline: { [weak self] in
                    self?.toggleUnderline()
                    self?.updateFormattingToolbar()
                },
                onLink: { [weak self] in
                    self?.toggleLink()
                    self?.updateFormattingToolbar()
                },
                onLinkCreate: { [weak self] linkText, linkURL in
                    self?.insertLink(linkText: linkText, linkURL: linkURL)
                    self?.updateFormattingToolbar()
                },
                onLinkCreateWithStyle: { [weak self] linkText, linkURL, linkColor, shouldUnderline in
                    self?.insertLink(linkText: linkText, linkURL: linkURL, linkColor: linkColor, shouldUnderline: shouldUnderline)
                    self?.updateFormattingToolbar()
                },
                onTextColor: { [weak self] color in
                    self?.applyTextColor(color)
                    self?.updateFormattingToolbar()
                },
                onHighlight: { [weak self] color in
                    self?.applyHighlight(color)
                    self?.updateFormattingToolbar()
                },
                onBulletList: { [weak self] in
                    self?.toggleBulletList()
                    self?.updateFormattingToolbar()
                },
                onAlignment: { [weak self] alignment in
                    self?.applyAlignment(alignment)
                    self?.updateFormattingToolbar()
                },
                onBookmark: { [weak self] in
                    self?.toggleBookmark()
                    self?.updateFormattingToolbar()
                },
                currentTextStyle: formatting.textStyle,
                isBold: formatting.isBold,
                isItalic: formatting.isItalic,
                isUnderlined: formatting.isUnderlined,
                hasLink: formatting.hasLink,
                hasBulletList: formatting.hasBulletList,
                hasTextColor: formatting.hasTextColor,
                hasHighlight: formatting.hasHighlight,
                hasBookmark: formatting.hasBookmark,
                currentTextColor: formatting.currentTextColor,
                currentHighlightColor: formatting.currentHighlightColor
            )
            
                toolbarHostingController = IOSFormattingToolbarHostingController(toolbar: toolbar)
                textView.inputAccessoryView = toolbarHostingController?.view
        }
        
        func updateFormattingToolbar() {
            guard let textView = textView else { return }
            
            let formatting = getCurrentFormatting()
            let toolbar = IOSTextFormattingToolbar(
                onTextStyle: { [weak self] style in
                    self?.applyTextStyle(style, colorScheme: .light)
                    self?.updateFormattingToolbar()
                },
                onBold: { [weak self] in
                    self?.toggleBold()
                    self?.updateFormattingToolbar()
                },
                onItalic: { [weak self] in
                    self?.toggleItalic()
                    self?.updateFormattingToolbar()
                },
                onUnderline: { [weak self] in
                    self?.toggleUnderline()
                    self?.updateFormattingToolbar()
                },
                onLink: { [weak self] in
                    self?.toggleLink()
                    self?.updateFormattingToolbar()
                },
                onLinkCreate: { [weak self] linkText, linkURL in
                    self?.insertLink(linkText: linkText, linkURL: linkURL)
                    self?.updateFormattingToolbar()
                },
                onLinkCreateWithStyle: { [weak self] linkText, linkURL, linkColor, shouldUnderline in
                    self?.insertLink(linkText: linkText, linkURL: linkURL, linkColor: linkColor, shouldUnderline: shouldUnderline)
                    self?.updateFormattingToolbar()
                },
                onTextColor: { [weak self] color in
                    self?.applyTextColor(color)
                    self?.updateFormattingToolbar()
                },
                onHighlight: { [weak self] color in
                    self?.applyHighlight(color)
                    self?.updateFormattingToolbar()
                },
                onBulletList: { [weak self] in
                    self?.toggleBulletList()
                    self?.updateFormattingToolbar()
                },
                onAlignment: { [weak self] alignment in
                    self?.applyAlignment(alignment)
                    self?.updateFormattingToolbar()
                },
                onBookmark: { [weak self] in
                    self?.toggleBookmark()
                    self?.updateFormattingToolbar()
                },
                currentTextStyle: formatting.textStyle,
                isBold: formatting.isBold,
                isItalic: formatting.isItalic,
                isUnderlined: formatting.isUnderlined,
                hasLink: formatting.hasLink,
                hasBulletList: formatting.hasBulletList,
                hasTextColor: formatting.hasTextColor,
                hasHighlight: formatting.hasHighlight,
                hasBookmark: formatting.hasBookmark,
                currentTextColor: formatting.currentTextColor,
                currentHighlightColor: formatting.currentHighlightColor
            )
            
                toolbarHostingController?.rootView = toolbar
        }
        
        private func getCurrentFormatting() -> TextFormatting {
            guard let textView = textView else { return TextFormatting() }
            
            let selectedRange = textView.selectedRange
            guard selectedRange.location != NSNotFound else { return TextFormatting() }
            
            var formatting = TextFormatting()
            
            if selectedRange.length > 0 {
                // Check formatting of selected text
                let attributes = textView.attributedText.attributes(at: selectedRange.location, effectiveRange: nil)
                
                if let font = attributes[.font] as? UIFont {
                    let symbolicTraits = font.fontDescriptor.symbolicTraits
                    formatting.isBold = symbolicTraits.contains(.traitBold)
                    formatting.isItalic = symbolicTraits.contains(.traitItalic)
                    
                    // Detect text style based on font size
                    let fontSize = font.pointSize
                    if fontSize >= 32 {
                        formatting.textStyle = "Title"
                    } else if fontSize >= 25 {
                        formatting.textStyle = "Heading"
                    } else if fontSize >= 17 {
                        formatting.textStyle = "Strong"
                    } else if fontSize <= 13 {
                        formatting.textStyle = "Caption"
                    } else {
                        formatting.textStyle = "Body"
                    }
                }
                
                formatting.hasLink = attributes[.link] != nil
                
                // For links, don't show underline or text color as active since they're part of link styling
                if !formatting.hasLink {
                    formatting.isUnderlined = (attributes[.underlineStyle] as? Int ?? 0) != 0
                    
                    if let textColor = attributes[.foregroundColor] as? UIColor {
                        // Only set if different from default
                        let defaultColor = UIColor.label
                        if !textColor.isEqual(defaultColor) {
                            formatting.hasTextColor = true
                            formatting.currentTextColor = Color(textColor)
                        }
                    }
                }
                
                if let backgroundColor = attributes[.backgroundColor] as? UIColor {
                    formatting.hasHighlight = true
                    formatting.currentHighlightColor = Color(backgroundColor)
                }
                
                // Check for bookmark
                formatting.hasBookmark = attributes[.isBookmark] != nil
                
                // Check for bullet list (simple check for bullet character)
                let text = textView.attributedText.string
                let paragraphRange = (text as NSString).paragraphRange(for: selectedRange)
                let paragraphText = (text as NSString).substring(with: paragraphRange)
                formatting.hasBulletList = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("• ")
            }
            
            return formatting
        }
        
        private struct TextFormatting {
            var textStyle: String = "Body"
            var isBold: Bool = false
            var isItalic: Bool = false
            var isUnderlined: Bool = false
            var hasLink: Bool = false
            var hasBulletList: Bool = false
            var hasTextColor: Bool = false
            var hasHighlight: Bool = false
            var hasBookmark: Bool = false
            var currentTextColor: Color? = nil
            var currentHighlightColor: Color? = nil
        }
        
        // MARK: - Formatting Methods
        private func toggleBold() {
            print("🔥 toggleBold called")
            guard let textView = textView else { 
                print("❌ toggleBold: no textView")
                return 
            }
            
            let selectedRange = textView.selectedRange
            print("🔥 toggleBold selectedRange: \(selectedRange)")
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            attributedText.enumerateAttribute(.font, in: selectedRange) { fontAttribute, range, _ in
                if let currentFont = fontAttribute as? UIFont {
                    let traits = currentFont.fontDescriptor.symbolicTraits
                    let isBold = traits.contains(.traitBold)
                    
                    let newFont: UIFont
                    if isBold {
                        if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.subtracting(.traitBold)) {
                            newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        } else {
                            newFont = currentFont
                        }
                    } else {
                        if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.union(.traitBold)) {
                            newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        } else {
                            newFont = currentFont
                        }
                    }
                    attributedText.addAttribute(.font, value: newFont, range: range)
                }
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            self.text = textView.text
        }
        
        private func toggleItalic() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            attributedText.enumerateAttribute(.font, in: selectedRange) { fontAttribute, range, _ in
                if let currentFont = fontAttribute as? UIFont {
                    let traits = currentFont.fontDescriptor.symbolicTraits
                    let isItalic = traits.contains(.traitItalic)
                    
                    let newFont: UIFont
                    if isItalic {
                        if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.subtracting(.traitItalic)) {
                            newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        } else {
                            newFont = currentFont
                        }
                    } else {
                        if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits.union(.traitItalic)) {
                            newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        } else {
                            newFont = currentFont
                        }
                    }
                    attributedText.addAttribute(.font, value: newFont, range: range)
                }
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            self.text = textView.text
        }
        
        private func toggleUnderline() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            attributedText.enumerateAttribute(.underlineStyle, in: selectedRange) { underlineAttribute, range, _ in
                let currentUnderline = underlineAttribute as? Int ?? 0
                let newUnderline = currentUnderline == 0 ? NSUnderlineStyle.single.rawValue : 0
                attributedText.addAttribute(.underlineStyle, value: newUnderline, range: range)
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            self.text = textView.text
        }
        
        private func applyTextColor(_ color: Color) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if color == .clear {
                attributedText.removeAttribute(.foregroundColor, range: selectedRange)
            } else {
                let uiColor = UIColor(color)
                attributedText.addAttribute(.foregroundColor, value: uiColor, range: selectedRange)
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            self.text = textView.text
        }
        
        private func applyHighlight(_ color: Color) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if color == .clear {
                attributedText.removeAttribute(.backgroundColor, range: selectedRange)
            } else {
                let uiColor = UIColor(color).withAlphaComponent(0.3)
                attributedText.addAttribute(.backgroundColor, value: uiColor, range: selectedRange)
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            self.text = textView.text
        }
        
        private func applyAlignment(_ alignment: TextAlignment) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            let paragraphStyle = NSMutableParagraphStyle()
            switch alignment {
            case .leading:
                paragraphStyle.alignment = .left
            case .center:
                paragraphStyle.alignment = .center
            case .trailing:
                paragraphStyle.alignment = .right
            }
            
            let text = attributedText.string
            let paragraphRange = (text as NSString).paragraphRange(for: selectedRange)
            
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            self.text = textView.text
        }
        
        private func applyTextStyle(_ styleName: String, colorScheme: ColorScheme) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            let baseFontSize: CGFloat = 16
            var font: UIFont
            var paragraphStyle = NSMutableParagraphStyle()
            
            switch styleName {
            case "Title":
                font = UIFont.systemFont(ofSize: baseFontSize * 2.0, weight: .regular)
                paragraphStyle.paragraphSpacingBefore = baseFontSize * 0.8
                paragraphStyle.paragraphSpacing = baseFontSize * 0.6
                paragraphStyle.lineHeightMultiple = 1.2
                
            case "Heading":
                font = UIFont.systemFont(ofSize: baseFontSize * 1.6, weight: .semibold)
                paragraphStyle.paragraphSpacingBefore = baseFontSize * 0.6
                paragraphStyle.paragraphSpacing = baseFontSize * 0.4
                paragraphStyle.lineHeightMultiple = 1.1
                
            case "Strong":
                font = UIFont.systemFont(ofSize: baseFontSize * 1.1, weight: .medium)
                paragraphStyle.lineHeightMultiple = 1.3
                
            case "Caption":
                font = UIFont.systemFont(ofSize: baseFontSize * 0.8, weight: .regular)
                paragraphStyle.paragraphSpacingBefore = baseFontSize * 0.3
                paragraphStyle.paragraphSpacing = baseFontSize * 0.2
                paragraphStyle.lineHeightMultiple = 1.15
                
            default: // "Body"
                font = UIFont.systemFont(ofSize: baseFontSize, weight: .regular)
                paragraphStyle.lineHeightMultiple = 1.3
            }
            
            if selectedRange.length > 0 {
                attributedText.addAttribute(.font, value: font, range: selectedRange)
                attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: selectedRange)
            } else {
                textView.typingAttributes = [
                    .font: font,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: colorScheme == .dark ? UIColor.white : UIColor.black
                ]
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            self.text = textView.text
        }
        
        private func toggleLink() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            guard selectedRange.length > 0 else {
                // No text selected, insert new link
                insertLink()
                return
            }
            
            // Check if selected text has link
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            let attributes = attributedText.attributes(at: selectedRange.location, effectiveRange: nil)
            
            if attributes[.link] != nil {
                // Remove link from selected text
                print("🔗 Removing link from selected text")
                attributedText.removeAttribute(.link, range: selectedRange)
                
                // Also remove link-specific formatting (color and underline) and restore default text color
                attributedText.removeAttribute(.underlineStyle, range: selectedRange)
                attributedText.addAttribute(.foregroundColor, value: UIColor.label, range: selectedRange)
                
                textView.attributedText = attributedText
                textView.selectedRange = selectedRange
                self.text = textView.text
            } else {
                // Add link to selected text
                insertLink()
            }
        }
        
        private func insertLink(linkText: String? = nil, linkURL: String? = nil, linkColor: UIColor? = nil, shouldUnderline: Bool = true) {
            print("🔗 insertLink called with: linkText=\(linkText ?? "nil"), linkURL=\(linkURL ?? "nil"), linkColor=\(linkColor?.description ?? "nil"), shouldUnderline=\(shouldUnderline)")
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if selectedRange.length > 0 {
                // Apply link to selected text (preserve the selected text)
                let urlString = linkURL ?? "https://example.com"
                if let url = URL(string: urlString) {
                    attributedText.addAttribute(.link, value: url, range: selectedRange)
                }
                
                // Apply custom color or default to blue
                let color = linkColor ?? UIColor.systemBlue
                print("🔗 Applying color \(color) to range \(selectedRange)")
                attributedText.addAttribute(.foregroundColor, value: color, range: selectedRange)
                
                // Apply underline if requested
                if shouldUnderline {
                    attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
                }
                
                textView.attributedText = attributedText
                textView.selectedRange = selectedRange
                
                self.text = textView.text
                print("📎 Link applied to selected text: \(urlString)")
            } else if let linkText = linkText, !linkText.isEmpty {
                // Insert link text at cursor position (when no text is selected)
                attributedText.replaceCharacters(in: selectedRange, with: linkText)
                
                // Update the range to cover the inserted text
                let newRange = NSRange(location: selectedRange.location, length: linkText.count)
                
                // Add link attributes
                if let urlString = linkURL, let url = URL(string: urlString) {
                    attributedText.addAttribute(.link, value: url, range: newRange)
                }
                
                // Apply custom color or default to blue
                let color = linkColor ?? UIColor.systemBlue
                print("🔗 Applying color \(color) to new range \(newRange)")
                attributedText.addAttribute(.foregroundColor, value: color, range: newRange)
                
                // Apply underline if requested
                if shouldUnderline {
                    attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: newRange)
                }
                
                textView.attributedText = attributedText
                textView.selectedRange = NSRange(location: newRange.location + newRange.length, length: 0)
                
                self.text = textView.text
                print("📎 Link text inserted: \(linkText) -> \(linkURL ?? "https://example.com")")
            } else {
                print("📎 No text selected and no link text provided")
                return
            }
        }
        
        private func toggleBulletList() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // Find the paragraph range
            let text = attributedText.string
            let paragraphRange = (text as NSString).paragraphRange(for: selectedRange)
            
            let paragraphText = (text as NSString).substring(with: paragraphRange)
            let trimmedText = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedText.hasPrefix("• ") {
                // Remove bullet
                let newText = String(trimmedText.dropFirst(2))
                attributedText.replaceCharacters(in: paragraphRange, with: newText)
            } else {
                // Add bullet
                let bulletText = "• \(trimmedText)"
                attributedText.replaceCharacters(in: paragraphRange, with: bulletText)
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = NSRange(location: selectedRange.location, length: 0)
            self.text = textView.text
            
            print("📝 Bullet list toggled")
        }
        
        private func toggleBookmark() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            guard selectedRange.length > 0 else {
                print("🔖 No text selected for bookmark")
            return
        }
        
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            let currentAttributes = attributedText.attributes(at: selectedRange.location, effectiveRange: nil)
            let existingBookmarkID = currentAttributes[.isBookmark] as? String
            
            print("🔖 Current document markers count before toggle: \(document.markers.count)")
            
            if let bookmarkID = existingBookmarkID, let uuid = UUID(uuidString: bookmarkID) {
                // Remove bookmark
                print("🔖 Removing bookmark with ID: \(bookmarkID)")
                attributedText.removeAttribute(.isBookmark, range: selectedRange)
                
                // Remove from document markers
                document.removeMarker(id: uuid)
                print("🔖 Document markers count after removal: \(document.markers.count)")
                
                // Save document
                DispatchQueue.main.async {
                    self.document.save()
                }
            } else {
                // Add bookmark
                let uuid = UUID()
                let bookmarkID = uuid.uuidString
                print("🔖 Adding bookmark with ID: \(bookmarkID)")
                attributedText.addAttribute(.isBookmark, value: bookmarkID, range: selectedRange)
                
                let snippet = (attributedText.string as NSString).substring(with: selectedRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let title = snippet.isEmpty ? "Bookmark" : String(snippet.prefix(30))
                let fullText = attributedText.string
                let textUpToCursor = (fullText as NSString).substring(to: selectedRange.location)
                let lineNumber = textUpToCursor.components(separatedBy: .newlines).count
                
                // Add to document markers
                document.addMarker(
                    id: uuid,
                    title: title,
                    type: "bookmark",
                    position: lineNumber,
                    metadata: [
                        "charPosition": selectedRange.location,
                        "charLength": selectedRange.length,
                        "snippet": snippet
                    ]
                )
                print("🔖 Document markers count after adding: \(document.markers.count)")
                print("🔖 Added bookmark with title: '\(title)' at line \(lineNumber)")
                
                // Save document
                DispatchQueue.main.async {
                    self.document.save()
                    print("🔖 Document saved on main thread")
                }
            }
            
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            self.text = textView.text
            
            print("🔖 Bookmark toggled - final markers count: \(document.markers.count)")
        }
    }
}

// Preview for development
#Preview {
    IOSDocumentEditor(document: .constant(Letterspace_CanvasDocument()), onScrollChange: nil)
        .padding()
}
#endif 