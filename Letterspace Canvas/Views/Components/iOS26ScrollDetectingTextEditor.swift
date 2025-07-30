#if os(iOS)
import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct iOS26ScrollDetectingTextEditor: UIViewRepresentable {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var headerCollapseProgress: CGFloat
    @Binding var text: String
    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    
    let maxScrollForCollapse: CGFloat
    
    init(
        document: Binding<Letterspace_CanvasDocument>,
        headerCollapseProgress: Binding<CGFloat>,
        text: Binding<String>,
        maxScrollForCollapse: CGFloat = 300
    ) {
        self._document = document
        self._headerCollapseProgress = headerCollapseProgress
        self._text = text
        self.maxScrollForCollapse = maxScrollForCollapse
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        // Configure text view
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.showsVerticalScrollIndicator = true
        
        // Enable swipe-to-dismiss keyboard
        textView.keyboardDismissMode = .interactive
        
        // Set up attributed text support for iOS 26
        textView.allowsEditingTextAttributes = true
        
        // Set delegate to track scrolling
        textView.delegate = context.coordinator
        
        // Set up text view reference in coordinator
        context.coordinator.textView = textView
        
        // Set up the keyboard toolbar
        context.coordinator.setupKeyboardToolbar(for: textView)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Use the text binding instead of getDocumentText()
        if uiView.text != text {
            uiView.text = text
        }
        
        // Update coordinator bindings
        context.coordinator.headerCollapseProgress = $headerCollapseProgress
        context.coordinator.maxScrollForCollapse = maxScrollForCollapse
        context.coordinator.document = $document
        
        // Let coordinator handle content inset updates
        context.coordinator.updateContentInsets(for: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func getDocumentText() -> String {
        if let element = document.elements.first(where: { $0.type == .textBlock }) {
            return element.content
        }
        return ""
    }
    
    class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        var parent: iOS26ScrollDetectingTextEditor
        var headerCollapseProgress: Binding<CGFloat>
        var maxScrollForCollapse: CGFloat
        var document: Binding<Letterspace_CanvasDocument>
        private var toolbarHostingController: IOSFormattingToolbarHostingController?
        weak var textView: UITextView?
        
        init(_ parent: iOS26ScrollDetectingTextEditor) {
            self.parent = parent
            self.headerCollapseProgress = parent.$headerCollapseProgress
            self.maxScrollForCollapse = parent.maxScrollForCollapse
            self.document = parent.$document
            super.init()
            
            // Set up keyboard notifications for toolbar dismissal
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
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillChangeFrame),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )
            
            // Set up scroll-to-top notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScrollToTop),
                name: NSNotification.Name("ScrollToTop"),
                object: nil
            )
        }
        
        // MARK: - Content Inset Management
        func updateContentInsets(for textView: UITextView) {
            // Smoothly interpolate content insets based on header collapse progress
            let currentProgress = headerCollapseProgress.wrappedValue
            
            // Extend the transition period for more gradual content expansion
            let transitionStart: CGFloat = 0.70  // Start earlier for smoother transition
            let transitionEnd: CGFloat = 1.20    // End later to slow down the final movement
            
            let normalInset: CGFloat = 16
            let floatingInset: CGFloat = 160  // Increased from 120 to push text higher
            
            let interpolatedInset: CGFloat
            
            if currentProgress < transitionStart {
                // Before transition - use normal inset
                interpolatedInset = normalInset
            } else if currentProgress > transitionEnd {
                // After transition - use floating inset
                interpolatedInset = floatingInset
            } else {
                // During transition - interpolate smoothly with easing
                let transitionProgress = (currentProgress - transitionStart) / (transitionEnd - transitionStart)
                
                // Apply much gentler easing to slow down the final transition significantly
                let easedProgress = pow(transitionProgress, 0.7) // Very slow, very gradual curve
                
                interpolatedInset = normalInset + (floatingInset - normalInset) * easedProgress
            }
            
            // Apply the smoothly interpolated inset
            textView.contentInset.top = interpolatedInset
            textView.verticalScrollIndicatorInsets.top = interpolatedInset
        }
        
        // MARK: - Scroll Detection
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let scrollY = scrollView.contentOffset.y
            print("🔍 SCROLL DETECTED - Y offset: \(scrollY)")
            
            // Calculate header collapse progress
            // When scrollY is negative (overscroll at top), we want to expand header
            // When scrollY is positive, we want to collapse header
            // Allow progress to exceed 1.0 for extended content inset transition
            let progress = max(0, min(1.2, scrollY / maxScrollForCollapse))
            
            print("📊 Header Collapse Progress: \(progress) (from scrollY: \(scrollY))")
            
            // Update header collapse progress on main thread
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.1)) {
                    self.headerCollapseProgress.wrappedValue = progress
                }
                
                // Update content insets when header state changes (without animation)
                if let textView = scrollView as? UITextView {
                    // Disable implicit animations for smooth content inset updates
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.updateContentInsets(for: textView)
                    CATransaction.commit()
                }
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            print("🎯 User started dragging scroll view")
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            print("🏁 User ended dragging, will decelerate: \(decelerate)")
            
            if !decelerate {
                snapToNearestState()
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            print("🛑 Scroll deceleration ended")
            snapToNearestState()
        }
        
        private func snapToNearestState() {
            let currentProgress = headerCollapseProgress.wrappedValue
            
            // Adjust snap logic to preserve extended collapse state
            let targetProgress: CGFloat
            if currentProgress < 0.3 {
                targetProgress = 0.0  // Snap to fully expanded
            } else if currentProgress < 1.0 {
                targetProgress = 1.0  // Snap to normal collapsed
            } else {
                targetProgress = 1.2  // Snap to fully extended collapse (maintains text position)
            }
            
            print("📍 Snapping from \(currentProgress) to \(targetProgress)")
            
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.headerCollapseProgress.wrappedValue = targetProgress
                }
            }
        }
        
        // MARK: - Keyboard Toolbar Setup
        func setupKeyboardToolbar(for textView: UITextView) {
            let toolbar = IOSTextFormattingToolbar(
                onTextStyle: { [weak self] style in
                    self?.applyTextStyle(style)
                },
                onBold: { [weak self] in
                    self?.toggleBold()
                },
                onItalic: { [weak self] in
                    self?.toggleItalic()
                },
                onUnderline: { [weak self] in
                    self?.toggleUnderline()
                },
                onLink: { [weak self] in
                    self?.insertLink()
                },
                onLinkCreate: { [weak self] url, text in
                    self?.insertLink(linkText: text, linkURL: url)
                },
                onTextColor: { [weak self] color in
                    self?.applyTextColor(color)
                },
                onHighlight: { [weak self] color in
                    self?.applyHighlight(color)
                },
                onBulletList: { [weak self] in
                    self?.toggleBulletList()
                },
                onAlignment: { [weak self] alignment in
                    self?.applyAlignment(alignment)
                },
                onBookmark: { [weak self] in
                    self?.toggleBookmark()
                },
                currentTextStyle: getCurrentTextStyle(),
                isBold: getCurrentFormatting().isBold,
                isItalic: getCurrentFormatting().isItalic,
                isUnderlined: getCurrentFormatting().isUnderlined,
                hasLink: getCurrentFormatting().hasLink,
                hasBulletList: getCurrentFormatting().hasBulletList,
                hasTextColor: getCurrentFormatting().hasTextColor,
                hasHighlight: getCurrentFormatting().hasHighlight,
                hasBookmark: getCurrentFormatting().hasBookmark,
                currentTextColor: getCurrentFormatting().textColor,
                currentHighlightColor: getCurrentFormatting().highlightColor
            )
            
            toolbarHostingController = IOSFormattingToolbarHostingController(toolbar: toolbar)
            textView.inputAccessoryView = toolbarHostingController?.view
        }
        
        // MARK: - Formatting Methods
        private func toggleBold() {
            guard let textView = textView else { 
                print("❌ toggleBold: no textView")
                return 
            }
            
            print("🔥 toggleBold called - selectedRange: \(textView.selectedRange)")
            
            // Use UIKit formatting for all cases - it's more reliable
            print("🔥 Using UIKit bold formatting")
            applyUIKitBoldFormatting()
            updateFormattingToolbar()
        }
        
        @available(iOS 26.0, *)
        private func applyiOS26Formatting(_ formatAction: (inout AttributedString, inout AttributedTextSelection) -> Void) {
            guard let textView = textView else { 
                print("❌ applyiOS26Formatting: no textView")
                return 
            }
            
            print("🔥 applyiOS26Formatting: originalRange: \(textView.selectedRange)")
            
            // Save current state
            let originalRange = textView.selectedRange
            let originalContentOffset = textView.contentOffset
            
            // Convert NSAttributedString to AttributedString
            var attributedString = AttributedString(textView.attributedText)
            print("🔥 AttributedString length: \(attributedString.characters.count)")
            
            // Create AttributedTextSelection from NSRange
            var selection = createAttributedTextSelection(from: originalRange, in: attributedString)
            print("🔥 Created AttributedTextSelection")
            
            // Apply the formatting using iOS 26 native methods
            formatAction(&attributedString, &selection)
            print("🔥 Applied formatting action")
            
            // Convert back to NSAttributedString and update UITextView
            let nsAttributedString = NSAttributedString(attributedString)
            print("🔥 Converted back to NSAttributedString")
            
            // Disable animations to prevent scroll jumping
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            textView.attributedText = nsAttributedString
            textView.selectedRange = originalRange
            
            // Restore scroll position
            textView.contentOffset = originalContentOffset
            
            CATransaction.commit()
            
            // Update parent text binding
            parent.text = textView.text
            print("🔥 Updated parent text binding")
        }
        
        @available(iOS 26.0, *)
        private func createAttributedTextSelection(from nsRange: NSRange, in attributedString: AttributedString) -> AttributedTextSelection {
            print("🔥 createAttributedTextSelection: nsRange: \(nsRange), stringLength: \(attributedString.characters.count)")
            
            // Convert NSRange to AttributedString indices
            let location = max(0, min(nsRange.location, attributedString.characters.count))
            let length = nsRange.length
            
            // For zero-length selections (cursor position), create a minimal range for formatting
            let adjustedLength = length == 0 ? min(1, attributedString.characters.count - location) : length
            
            let startIndex = attributedString.characters.index(attributedString.startIndex, offsetBy: location)
            let endIndex = attributedString.characters.index(startIndex, offsetBy: adjustedLength)
            let range = startIndex..<endIndex
            
            print("🔥 Created range from \(startIndex) to \(endIndex) (adjusted length: \(adjustedLength))")
            
            var rangeSet = RangeSet<AttributedString.Index>()
            rangeSet.insert(contentsOf: range)
            
            print("🔥 RangeSet created with range")
            
            return AttributedTextSelection(ranges: rangeSet)
        }
        
        private func applyUIKitBoldFormatting() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            
            if selectedRange.length == 0 {
                // Handle cursor position - modify typing attributes
                print("🔥 UIKit: Setting typing attributes for cursor position")
                var typingAttributes = textView.typingAttributes
                
                if let currentFont = typingAttributes[.font] as? UIFont {
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
                    typingAttributes[.font] = newFont
                    textView.typingAttributes = typingAttributes
                    print("🔥 UIKit: Updated typing attributes with new font")
                }
            } else {
                // Handle text selection - modify selected text
                print("🔥 UIKit: Formatting selected text")
                let originalContentOffset = textView.contentOffset
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
                
                // Disable animations to prevent scroll jumping
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                
                textView.attributedText = attributedText
                textView.selectedRange = selectedRange
                
                // Restore scroll position
                textView.contentOffset = originalContentOffset
                
                CATransaction.commit()
                
                // Update parent text binding
                parent.text = textView.text
                print("🔥 UIKit: Updated attributed text and parent binding")
            }
        }
        
        private func toggleItalic() {
            print("🔥 Using UIKit italic formatting")
            applyUIKitItalicFormatting()
            updateFormattingToolbar()
        }
        
        private func toggleUnderline() {
            print("🔥 Using UIKit underline formatting")
            applyUIKitUnderlineFormatting()
            updateFormattingToolbar()
        }
        
        private func applyTextColor(_ color: Color) {
            print("🔥 Using UIKit text color formatting")
            applyUIKitTextColor(color)
            updateFormattingToolbar()
        }
        
        private func applyHighlight(_ color: Color) {
            print("🔥 Using UIKit highlight formatting")
            applyUIKitHighlight(color)
            updateFormattingToolbar()
        }
        
        // MARK: - UIKit Fallback Methods
        private func applyUIKitItalicFormatting() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            
            if selectedRange.length == 0 {
                // Handle cursor position - modify typing attributes
                print("🔥 UIKit: Setting italic typing attributes for cursor position")
                var typingAttributes = textView.typingAttributes
                
                if let currentFont = typingAttributes[.font] as? UIFont {
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
                    typingAttributes[.font] = newFont
                    textView.typingAttributes = typingAttributes
                    print("🔥 UIKit: Updated italic typing attributes")
                }
            } else {
                // Handle text selection - modify selected text
                print("🔥 UIKit: Formatting selected text with italic")
                let originalContentOffset = textView.contentOffset
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
                
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                textView.attributedText = attributedText
                textView.selectedRange = selectedRange
                textView.contentOffset = originalContentOffset
                CATransaction.commit()
                parent.text = textView.text
                print("🔥 UIKit: Updated italic attributed text")
            }
        }
        
        private func applyUIKitUnderlineFormatting() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let originalContentOffset = textView.contentOffset
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            attributedText.enumerateAttribute(.underlineStyle, in: selectedRange) { underlineAttribute, range, _ in
                let currentUnderline = underlineAttribute as? Int ?? 0
                let newUnderline = currentUnderline == 0 ? NSUnderlineStyle.single.rawValue : 0
                attributedText.addAttribute(.underlineStyle, value: newUnderline, range: range)
            }
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            textView.contentOffset = originalContentOffset
            CATransaction.commit()
            parent.text = textView.text
        }
        
        private func applyUIKitTextColor(_ color: Color) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let originalContentOffset = textView.contentOffset
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if color == .clear {
                attributedText.removeAttribute(.foregroundColor, range: selectedRange)
            } else {
                attributedText.addAttribute(.foregroundColor, value: UIColor(color), range: selectedRange)
            }
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            textView.contentOffset = originalContentOffset
            CATransaction.commit()
            parent.text = textView.text
        }
        
        private func applyUIKitHighlight(_ color: Color) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let originalContentOffset = textView.contentOffset
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if color == .clear {
                attributedText.removeAttribute(.backgroundColor, range: selectedRange)
            } else {
                attributedText.addAttribute(.backgroundColor, value: UIColor(color), range: selectedRange)
            }
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            textView.contentOffset = originalContentOffset
            CATransaction.commit()
            parent.text = textView.text
        }
        
        private func applyTextStyle(_ style: String) {
            // TODO: Implement text style application
            print("📝 Text style applied: \(style)")
            updateFormattingToolbar()
        }
        
        private func insertLink(linkText: String = "", linkURL: String = "") {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            let selectedText = selectedRange.length > 0 ? (textView.text as NSString).substring(with: selectedRange) : ""
            let finalLinkText = linkText.isEmpty ? (selectedText.isEmpty ? "Link" : selectedText) : linkText
            let finalLinkURL = linkURL.isEmpty ? "https://example.com" : linkURL
            
            let linkString = NSAttributedString(
                string: finalLinkText,
                attributes: [
                    .link: finalLinkURL,
                    .foregroundColor: UIColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
            
            attributedText.replaceCharacters(in: selectedRange, with: linkString)
            textView.attributedText = attributedText
            textView.selectedRange = NSRange(location: selectedRange.location, length: linkString.length)
            updateFormattingToolbar()
        }
        
        private func toggleBulletList() {
            // TODO: Implement bullet list
            print("📝 Bullet list toggled")
            updateFormattingToolbar()
        }
        
        private func applyAlignment(_ alignment: TextAlignment) {
            print("🔥 Using UIKit alignment formatting")
            applyUIKitAlignment(alignment)
            updateFormattingToolbar()
        }
        
        private func applyUIKitAlignment(_ alignment: TextAlignment) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let originalContentOffset = textView.contentOffset
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
            
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: selectedRange)
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            textView.attributedText = attributedText
            textView.selectedRange = selectedRange
            textView.contentOffset = originalContentOffset
            CATransaction.commit()
            parent.text = textView.text
        }
        
        private func toggleBookmark() {
            // TODO: Implement bookmark
            print("📝 Bookmark toggled")
            updateFormattingToolbar()
        }
        
        private func getCurrentTextStyle() -> String {
            // TODO: Implement text style detection
            return "body"
        }
        
        private func getCurrentFormatting() -> (isBold: Bool, isItalic: Bool, isUnderlined: Bool, hasLink: Bool, hasBulletList: Bool, hasTextColor: Bool, hasHighlight: Bool, hasBookmark: Bool, textColor: Color?, highlightColor: Color?) {
            guard let textView = textView else {
                return (false, false, false, false, false, false, false, false, nil, nil)
            }
            
            guard let attributedText = textView.attributedText, attributedText.length > 0 else {
                return (false, false, false, false, false, false, false, false, nil, nil)
            }
            
            let selectedRange = textView.selectedRange
            
            // If no selection, check formatting at cursor position
            let rangeToCheck: NSRange
            if selectedRange.length > 0 {
                rangeToCheck = selectedRange
            } else {
                // Check formatting at cursor position (or just before cursor if at end)
                let location = max(0, min(selectedRange.location, attributedText.length - 1))
                rangeToCheck = NSRange(location: location, length: 1)
            }
            
            var isBold = false
            var isItalic = false
            var isUnderlined = false
            var hasLink = false
            var hasTextColor = false
            var hasHighlight = false
            var textColor: Color? = nil
            var highlightColor: Color? = nil
            
            attributedText.enumerateAttributes(in: rangeToCheck) { attributes, range, _ in
                // Check font traits
                if let font = attributes[.font] as? UIFont {
                    let traits = font.fontDescriptor.symbolicTraits
                    isBold = traits.contains(.traitBold)
                    isItalic = traits.contains(.traitItalic)
                }
                
                // Check underline
                if let underlineStyle = attributes[.underlineStyle] as? Int {
                    isUnderlined = underlineStyle != 0
                }
                
                // Check link
                if attributes[.link] != nil {
                    hasLink = true
                }
                
                // Check text color
                if let foregroundColor = attributes[.foregroundColor] as? UIColor {
                    hasTextColor = true
                    textColor = Color(foregroundColor)
                }
                
                // Check highlight color
                if let backgroundColor = attributes[.backgroundColor] as? UIColor {
                    hasHighlight = true
                    highlightColor = Color(backgroundColor)
                }
            }
            
            return (isBold, isItalic, isUnderlined, hasLink, false, hasTextColor, hasHighlight, false, textColor, highlightColor)
        }
        
        private func updateFormattingToolbar() {
            guard let textView = textView else { return }
            
            let formatting = getCurrentFormatting()
            let toolbar = IOSTextFormattingToolbar(
                onTextStyle: { [weak self] style in
                    self?.applyTextStyle(style)
                },
                onBold: { [weak self] in
                    self?.toggleBold()
                },
                onItalic: { [weak self] in
                    self?.toggleItalic()
                },
                onUnderline: { [weak self] in
                    self?.toggleUnderline()
                },
                onLink: { [weak self] in
                    self?.insertLink()
                },
                onLinkCreate: { [weak self] url, text in
                    self?.insertLink(linkText: text, linkURL: url)
                },
                onTextColor: { [weak self] color in
                    self?.applyTextColor(color)
                },
                onHighlight: { [weak self] color in
                    self?.applyHighlight(color)
                },
                onBulletList: { [weak self] in
                    self?.toggleBulletList()
                },
                onAlignment: { [weak self] alignment in
                    self?.applyAlignment(alignment)
                },
                onBookmark: { [weak self] in
                    self?.toggleBookmark()
                },
                currentTextStyle: getCurrentTextStyle(),
                isBold: formatting.isBold,
                isItalic: formatting.isItalic,
                isUnderlined: formatting.isUnderlined,
                hasLink: formatting.hasLink,
                hasBulletList: formatting.hasBulletList,
                hasTextColor: formatting.hasTextColor,
                hasHighlight: formatting.hasHighlight,
                hasBookmark: formatting.hasBookmark,
                currentTextColor: formatting.textColor,
                currentHighlightColor: formatting.highlightColor
            )
            
            toolbarHostingController?.updateToolbar(toolbar)
        }
        
        // MARK: - Keyboard Notification Handlers
        @objc private func keyboardWillShow(_ notification: Notification) {
            guard let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                return
            }
            
            // Animate toolbar fade-in
            if let toolbar = toolbarHostingController?.view {
                toolbar.alpha = 0.0
                UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseInOut]) {
                    toolbar.alpha = 1.0
                }
            }
        }
        
        @objc private func keyboardWillHide(_ notification: Notification) {
            guard let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                return
            }
            
            // Check if this is a swipe-to-dismiss gesture (very fast animation)
            let isSwipeToDismiss = animationDuration < 0.3
            
            if let toolbar = toolbarHostingController?.view {
                if isSwipeToDismiss {
                    // For swipe-to-dismiss, immediately hide toolbar
                    toolbar.alpha = 0.0
                } else {
                    // For normal dismissal, animate with keyboard
                    UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseInOut]) {
                        toolbar.alpha = 0.0
                    }
                }
            }
        }
        
        @objc private func keyboardWillChangeFrame(_ notification: Notification) {
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let _ = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                return
            }
            
            let keyboardHeight = keyboardFrame.height
            
            // If keyboard is moving off screen (height is very small or zero)
            if keyboardHeight < 50 {
                // Make sure toolbar is hidden immediately
                if let toolbar = toolbarHostingController?.view {
                    toolbar.alpha = 0.0
                    
                    // Reset alpha for next appearance after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        toolbar.alpha = 1.0
                    }
                }
            }
        }
        
        @objc private func handleScrollToTop() {
            // Smoothly scroll to the top of the text view
            DispatchQueue.main.async {
                if let textView = self.textView {
                    textView.setContentOffset(.zero, animated: true)
                }
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - Text View Delegate
        func textViewDidChange(_ textView: UITextView) {
            // Update SwiftUI binding
            parent.text = textView.text
            
            // Save changes back to document
            if let index = document.wrappedValue.elements.firstIndex(where: { $0.type == .textBlock }) {
                document.wrappedValue.elements[index].content = textView.text
            } else {
                var newElement = DocumentElement(type: .textBlock)
                newElement.content = textView.text
                document.wrappedValue.elements.append(newElement)
            }
            
            // Update formatting toolbar after text changes
            updateFormattingToolbar()
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            // Update formatting toolbar when selection changes
            updateFormattingToolbar()
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            print("✏️ Text editing began")
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            print("✅ Text editing ended")
        }
    }
}
#endif 
