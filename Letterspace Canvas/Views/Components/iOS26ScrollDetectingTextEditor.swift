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
        // Load attributed content if available, otherwise use plain text
        loadDocumentContentWithFormatting(into: uiView)
        
        // Update coordinator bindings
        context.coordinator.headerCollapseProgress = $headerCollapseProgress
        context.coordinator.maxScrollForCollapse = maxScrollForCollapse
        context.coordinator.document = $document
        
        // Let coordinator handle content inset updates
        context.coordinator.updateContentInsets(for: uiView)
    }
    
    private func loadDocumentContentWithFormatting(into textView: UITextView) {
        guard let textElement = document.elements.first(where: { $0.type == .textBlock }) else {
            // No text element exists, set empty text
            if textView.text != "" {
                textView.text = ""
            }
            return
        }
        
        // Check if we have attributed content (formatting)
        if let attributedContent = textElement.attributedContent {
            // Use attributed content with formatting
            if !textView.attributedText.isEqual(to: attributedContent) {
                textView.attributedText = attributedContent
                print("📄 Loaded document with formatting - attributed text length: \(attributedContent.length)")
            }
        } else {
            // Fall back to plain text
            let plainText = textElement.content
            if textView.text != plainText {
                textView.text = plainText
                print("📄 Loaded document with plain text - length: \(plainText.count)")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, document: $document)
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
        private var isApplyingFormatting = false  // Flag to prevent recursive updates
        private var userIntendedScrollPosition: CGPoint?  // Store user's intended position
        
        init(_ parent: iOS26ScrollDetectingTextEditor, document: Binding<Letterspace_CanvasDocument>) {
            self.parent = parent
            self.headerCollapseProgress = parent.$headerCollapseProgress
            self.maxScrollForCollapse = parent.maxScrollForCollapse
            self.document = document
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
            
            // If we're applying formatting and have a stored user position, force back to it
            if isApplyingFormatting, let intendedPosition = userIntendedScrollPosition {
                print("🔒 FORCING scroll back to user intended position: \(intendedPosition)")
                scrollView.contentOffset = intendedPosition
                return
            }
            
            // Prevent normal scroll detection during formatting operations
            if isApplyingFormatting {
                print("🚫 Ignoring scroll event during formatting to prevent jump")
                return
            }
            
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
            
            // Only snap if not decelerating, and only for very gentle adjustments
            if !decelerate {
                gentleSnapIfNeeded()
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            print("🛑 Scroll deceleration ended")
            // Apply gentle snap only if we're very close to a natural position
            gentleSnapIfNeeded()
        }
        
        private func gentleSnapIfNeeded() {
            let currentProgress = headerCollapseProgress.wrappedValue
            
            // Only snap if we're very close to natural positions (within 5%)
            // This preserves the natural feel while providing subtle magnetic behavior
            let snapThreshold: CGFloat = 0.05
            let targetProgress: CGFloat?
            
            if abs(currentProgress - 0.0) < snapThreshold {
                targetProgress = 0.0  // Snap to fully expanded only if very close
            } else if abs(currentProgress - 1.0) < snapThreshold {
                targetProgress = 1.0  // Snap to collapsed only if very close
            } else if currentProgress > 1.0 && abs(currentProgress - 1.2) < snapThreshold {
                targetProgress = 1.2  // Snap to extended collapse only if very close
            } else {
                targetProgress = nil  // No snapping - let it rest naturally
            }
            
            if let target = targetProgress {
                print("📍 Gentle snap from \(currentProgress) to \(target)")
                
                DispatchQueue.main.async {
                    // Use a very gentle spring animation for subtle correction
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        self.headerCollapseProgress.wrappedValue = target
                    }
                }
            } else {
                print("🌊 Natural rest at \(currentProgress) - no snapping needed")
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
        
        // MARK: - Document Update Methods
        private func updateDocumentWithFormatting() {
            guard let textView = textView else { return }
            
            let plainText = textView.text ?? ""
            let attributedText = textView.attributedText ?? NSAttributedString()
            
            print("💾 Updating document with formatting - text length: \(plainText.count), attributed text length: \(attributedText.length)")
            
            // Create a mutable copy of the document
            var updatedDocument = parent.document
            
            // Update the document element with both plain text and formatting
            if let index = updatedDocument.elements.firstIndex(where: { $0.type == .textBlock }) {
                var newElement = DocumentElement(type: .textBlock, content: plainText)
                newElement.attributedContent = attributedText
                updatedDocument.elements[index] = newElement
                print("💾 Updated existing text block element at index \(index)")
            } else {
                var element = DocumentElement(type: .textBlock, content: plainText)
                element.attributedContent = attributedText
                updatedDocument.elements.append(element)
                print("💾 Created new text block element")
            }
            
            // Update modification date
            updatedDocument.modifiedAt = Date()
            updatedDocument.updateCanvasDocument()
            
            // Update the binding and text binding
            parent.document = updatedDocument
            parent.text = plainText
            
            // Save the document asynchronously
            DispatchQueue.global(qos: .userInitiated).async {
                var documentToSave = updatedDocument
                documentToSave.save()
                print("💾 Document saved with formatting")
            }
        }
        
        // MARK: - Formatting Methods
        private func toggleBold() {
            guard let textView = textView else { 
                print("❌ toggleBold: no textView")
                return 
            }
            
            print("🔥 toggleBold called - selectedRange: \(textView.selectedRange)")
            
            // Store the user's current scroll position as their intended position
            userIntendedScrollPosition = textView.contentOffset
            let originalSelectedRange = textView.selectedRange
            
            print("💾 Stored user intended position: \(userIntendedScrollPosition!)")
            
            // Set flag to activate aggressive scroll position enforcement
            isApplyingFormatting = true
            
            // Apply bold formatting
            applyBoldFormattingDirect(textView: textView, selectedRange: originalSelectedRange)
            
            // Force scroll position back immediately and aggressively
            textView.contentOffset = userIntendedScrollPosition!
            textView.selectedRange = originalSelectedRange
            
            // Update parent binding
            updateDocumentWithFormatting()
            
            // Update toolbar IMMEDIATELY for instant visual feedback
            updateFormattingToolbar()
            
            // Continue aggressive scroll position enforcement
            var checkCount = 0
            let maxChecks = 20
            
            func enforceScrollPosition() {
                checkCount += 1
                if checkCount > maxChecks {
                    self.isApplyingFormatting = false
                    self.userIntendedScrollPosition = nil
                    print("🔓 Released scroll position enforcement for bold")
                    return
                }
                
                if let intended = self.userIntendedScrollPosition, textView.contentOffset != intended {
                    print("🔧 Correcting bold scroll drift: \(textView.contentOffset) -> \(intended)")
                    textView.contentOffset = intended
                    textView.selectedRange = originalSelectedRange
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    enforceScrollPosition()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                enforceScrollPosition()
            }
            
            print("✅ Bold formatting complete, aggressive scroll enforcement active")
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
                
                // Update parent text binding with scroll position protection
                updateParentTextSafely(textView)
                print("🔥 UIKit: Updated attributed text and parent binding")
            }
        }
        
        private func toggleItalic() {
            guard let textView = textView else { 
                print("❌ toggleItalic: no textView")
                return 
            }
            
            print("🔥 toggleItalic called")
            
            // Store the user's current scroll position as their intended position
            userIntendedScrollPosition = textView.contentOffset
            let originalSelectedRange = textView.selectedRange
            
            print("💾 Stored user intended position: \(userIntendedScrollPosition!)")
            
            // Set flag to activate aggressive scroll position enforcement
            isApplyingFormatting = true
            
            // Apply italic formatting
            applyItalicFormattingDirect(textView: textView, selectedRange: originalSelectedRange)
            
            // Force scroll position back immediately and aggressively
            textView.contentOffset = userIntendedScrollPosition!
            textView.selectedRange = originalSelectedRange
            
            // Update parent binding
            updateDocumentWithFormatting()
            
            // Update toolbar IMMEDIATELY for instant visual feedback
            updateFormattingToolbar()
            
            // Continue aggressive scroll position enforcement
            var checkCount = 0
            let maxChecks = 20
            
            func enforceScrollPosition() {
                checkCount += 1
                if checkCount > maxChecks {
                    self.isApplyingFormatting = false
                    self.userIntendedScrollPosition = nil
                    print("🔓 Released scroll position enforcement for italic")
                    return
                }
                
                if let intended = self.userIntendedScrollPosition, textView.contentOffset != intended {
                    print("🔧 Correcting italic scroll drift: \(textView.contentOffset) -> \(intended)")
                    textView.contentOffset = intended
                    textView.selectedRange = originalSelectedRange
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    enforceScrollPosition()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                enforceScrollPosition()
            }
            
            print("✅ Italic formatting complete, aggressive scroll enforcement active")
        }
        
        private func toggleUnderline() {
            guard let textView = textView else { 
                print("❌ toggleUnderline: no textView")
                return 
            }
            
            print("🔥 toggleUnderline called")
            
            // Store the user's current scroll position as their intended position
            userIntendedScrollPosition = textView.contentOffset
            let originalSelectedRange = textView.selectedRange
            
            print("💾 Stored user intended position: \(userIntendedScrollPosition!)")
            
            // Set flag to activate aggressive scroll position enforcement
            isApplyingFormatting = true
            
            // Apply underline formatting
            applyUnderlineFormattingDirect(textView: textView, selectedRange: originalSelectedRange)
            
            // Force scroll position back immediately and aggressively
            textView.contentOffset = userIntendedScrollPosition!
            textView.selectedRange = originalSelectedRange
            
            // Update parent binding
            updateDocumentWithFormatting()
            
            // Update toolbar IMMEDIATELY for instant visual feedback
            updateFormattingToolbar()
            
            // Continue aggressive scroll position enforcement
            var checkCount = 0
            let maxChecks = 20
            
            func enforceScrollPosition() {
                checkCount += 1
                if checkCount > maxChecks {
                    self.isApplyingFormatting = false
                    self.userIntendedScrollPosition = nil
                    print("🔓 Released scroll position enforcement for underline")
                    return
                }
                
                if let intended = self.userIntendedScrollPosition, textView.contentOffset != intended {
                    print("🔧 Correcting underline scroll drift: \(textView.contentOffset) -> \(intended)")
                    textView.contentOffset = intended
                    textView.selectedRange = originalSelectedRange
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    enforceScrollPosition()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                enforceScrollPosition()
            }
            
            print("✅ Underline formatting complete, aggressive scroll enforcement active")
        }
        
        private func applyTextColor(_ color: Color) {
            guard let textView = textView else { 
                print("❌ applyTextColor: no textView")
                return 
            }
            
            print("🔥 applyTextColor called with color: \(color)")
            
            // Store the user's current scroll position as their intended position
            userIntendedScrollPosition = textView.contentOffset
            let originalSelectedRange = textView.selectedRange
            
            print("💾 Stored user intended position: \(userIntendedScrollPosition!)")
            
            // Set flag to activate aggressive scroll position enforcement
            isApplyingFormatting = true
            
            // Apply text color formatting
            print("🔥 Using UIKit text color formatting")
            applyUIKitTextColor(color)
            
            // Force scroll position back immediately and aggressively
            textView.contentOffset = userIntendedScrollPosition!
            textView.selectedRange = originalSelectedRange
            
            // Update parent binding
            updateDocumentWithFormatting()
            
            // Update toolbar IMMEDIATELY for instant visual feedback
            updateFormattingToolbar()
            
            // Continue aggressive scroll position enforcement
            var checkCount = 0
            let maxChecks = 20
            
            func enforceScrollPosition() {
                checkCount += 1
                if checkCount > maxChecks {
                    self.isApplyingFormatting = false
                    self.userIntendedScrollPosition = nil
                    print("🔓 Released scroll position enforcement for text color")
                    return
                }
                
                if let intended = self.userIntendedScrollPosition, textView.contentOffset != intended {
                    print("🔧 Correcting text color scroll drift: \(textView.contentOffset) -> \(intended)")
                    textView.contentOffset = intended
                    textView.selectedRange = originalSelectedRange
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    enforceScrollPosition()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                enforceScrollPosition()
            }
            
            print("✅ Text color formatting complete, aggressive scroll enforcement active")
        }
        
        private func applyHighlight(_ color: Color) {
            guard let textView = textView else { 
                print("❌ applyHighlight: no textView")
                return 
            }
            
            print("🔥 applyHighlight called with color: \(color)")
            
            // Store the user's current scroll position as their intended position
            userIntendedScrollPosition = textView.contentOffset
            let originalSelectedRange = textView.selectedRange
            
            print("💾 Stored user intended position: \(userIntendedScrollPosition!)")
            
            // Set flag to activate aggressive scroll position enforcement
            isApplyingFormatting = true
            
            // Apply highlight formatting
            print("🔥 Using UIKit highlight formatting")
            applyUIKitHighlight(color)
            
            // Force scroll position back immediately and aggressively
            textView.contentOffset = userIntendedScrollPosition!
            textView.selectedRange = originalSelectedRange
            
            // Update parent binding
            updateDocumentWithFormatting()
            
            // Update toolbar IMMEDIATELY for instant visual feedback
            updateFormattingToolbar()
            
            // Continue aggressive scroll position enforcement
            var checkCount = 0
            let maxChecks = 20
            
            func enforceScrollPosition() {
                checkCount += 1
                if checkCount > maxChecks {
                    self.isApplyingFormatting = false
                    self.userIntendedScrollPosition = nil
                    print("🔓 Released scroll position enforcement for highlight")
                    return
                }
                
                if let intended = self.userIntendedScrollPosition, textView.contentOffset != intended {
                    print("🔧 Correcting highlight scroll drift: \(textView.contentOffset) -> \(intended)")
                    textView.contentOffset = intended
                    textView.selectedRange = originalSelectedRange
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    enforceScrollPosition()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                enforceScrollPosition()
            }
            
            print("✅ Highlight formatting complete, aggressive scroll enforcement active")
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
                updateParentTextSafely(textView)
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
            updateParentTextSafely(textView)
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
            updateParentTextSafely(textView)
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
            updateParentTextSafely(textView)
        }
        
        private func applyTextStyle(_ style: String) {
            guard let textView = textView else { 
                print("❌ applyTextStyle: no textView")
                return 
            }
            
            print("🔥 applyTextStyle called with style: \(style)")
            
            // Store the user's current scroll position as their intended position
            userIntendedScrollPosition = textView.contentOffset
            let originalSelectedRange = textView.selectedRange
            
            print("💾 Stored user intended position: \(userIntendedScrollPosition!)")
            
            // Set flag to activate aggressive scroll position enforcement
            isApplyingFormatting = true
            
            // Apply text style formatting
            applyUIKitTextStyle(style)
            
            // Force scroll position back immediately and aggressively
            textView.contentOffset = userIntendedScrollPosition!
            textView.selectedRange = originalSelectedRange
            
            // Update parent binding
            updateDocumentWithFormatting()
            
            // Update toolbar IMMEDIATELY for instant visual feedback
            updateFormattingToolbar()
            
            // Continue aggressive scroll position enforcement
            var checkCount = 0
            let maxChecks = 20
            
            func enforceScrollPosition() {
                checkCount += 1
                if checkCount > maxChecks {
                    self.isApplyingFormatting = false
                    self.userIntendedScrollPosition = nil
                    print("🔓 Released scroll position enforcement for text style")
                    return
                }
                
                if let intended = self.userIntendedScrollPosition, textView.contentOffset != intended {
                    print("🔧 Correcting text style scroll drift: \(textView.contentOffset) -> \(intended)")
                    textView.contentOffset = intended
                    textView.selectedRange = originalSelectedRange
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    enforceScrollPosition()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                enforceScrollPosition()
            }
            
            print("✅ Text style formatting complete, aggressive scroll enforcement active")
        }
        
        private func applyUIKitTextStyle(_ style: String) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let originalContentOffset = textView.contentOffset
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // Define font styles
            let font: UIFont
            switch style.lowercased() {
            case "title":
                font = UIFont.systemFont(ofSize: 28, weight: .bold)
            case "heading":
                font = UIFont.systemFont(ofSize: 22, weight: .semibold)
            case "strong":
                font = UIFont.systemFont(ofSize: 16, weight: .bold)
            case "caption":
                font = UIFont.systemFont(ofSize: 12, weight: .regular)
            case "body":
                font = UIFont.systemFont(ofSize: 16, weight: .regular)
            default:
                font = UIFont.systemFont(ofSize: 16, weight: .regular)
            }
            
            if selectedRange.length == 0 {
                // No selection - update typing attributes for new text
                var typingAttributes = textView.typingAttributes
                typingAttributes[.font] = font
                textView.typingAttributes = typingAttributes
                print("🔤 Updated typing attributes for style: \(style)")
            } else {
                // Selection exists - apply style to selected text
                attributedText.addAttribute(.font, value: font, range: selectedRange)
                
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                textView.attributedText = attributedText
                textView.selectedRange = selectedRange
                textView.contentOffset = originalContentOffset
                CATransaction.commit()
                print("🔤 Applied \(style) style to selected text range: \(selectedRange)")
            }
            
            updateParentTextSafely(textView)
        }
        
        private func insertLink(linkText: String = "", linkURL: String = "") {
            guard let textView = textView else { 
                print("❌ insertLink: no textView")
                return 
            }
            
            print("🔥 insertLink called with text: \(linkText), URL: \(linkURL)")
            
            // Store the user's current scroll position as their intended position
            userIntendedScrollPosition = textView.contentOffset
            let originalSelectedRange = textView.selectedRange
            
            print("💾 Stored user intended position: \(userIntendedScrollPosition!)")
            
            // Set flag to activate aggressive scroll position enforcement
            isApplyingFormatting = true
            
            // Apply link insertion
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            let selectedText = originalSelectedRange.length > 0 ? (textView.text as NSString).substring(with: originalSelectedRange) : ""
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
            
            attributedText.replaceCharacters(in: originalSelectedRange, with: linkString)
            textView.attributedText = attributedText
            let newSelectedRange = NSRange(location: originalSelectedRange.location, length: linkString.length)
            
            // Force scroll position back immediately and aggressively
            textView.contentOffset = userIntendedScrollPosition!
            textView.selectedRange = newSelectedRange
            
            // Update parent binding
            updateDocumentWithFormatting()
            
            // Update toolbar IMMEDIATELY for instant visual feedback
            updateFormattingToolbar()
            
            // Continue aggressive scroll position enforcement
            var checkCount = 0
            let maxChecks = 20
            
            func enforceScrollPosition() {
                checkCount += 1
                if checkCount > maxChecks {
                    self.isApplyingFormatting = false
                    self.userIntendedScrollPosition = nil
                    print("🔓 Released scroll position enforcement for link insertion")
                    return
                }
                
                if let intended = self.userIntendedScrollPosition, textView.contentOffset != intended {
                    print("🔧 Correcting link insertion scroll drift: \(textView.contentOffset) -> \(intended)")
                    textView.contentOffset = intended
                    textView.selectedRange = newSelectedRange
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    enforceScrollPosition()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                enforceScrollPosition()
            }
            
            print("✅ Link insertion complete, aggressive scroll enforcement active")
        }
        
        private func toggleBulletList() {
            // TODO: Implement bullet list
            print("📝 Bullet list toggled")
            updateFormattingToolbar()
        }
        
        private func applyAlignment(_ alignment: TextAlignment) {
            guard let textView = textView else { 
                print("❌ applyAlignment: no textView")
                return 
            }
            
            print("🔥 applyAlignment called with alignment: \(alignment)")
            
            // Store the user's current scroll position as their intended position
            userIntendedScrollPosition = textView.contentOffset
            let originalSelectedRange = textView.selectedRange
            
            print("💾 Stored user intended position: \(userIntendedScrollPosition!)")
            
            // Set flag to activate aggressive scroll position enforcement
            isApplyingFormatting = true
            
            // Apply alignment formatting
            print("🔥 Using UIKit alignment formatting")
            applyUIKitAlignment(alignment)
            
            // Force scroll position back immediately and aggressively
            textView.contentOffset = userIntendedScrollPosition!
            textView.selectedRange = originalSelectedRange
            
            // Update parent binding
            updateDocumentWithFormatting()
            
            // Update toolbar IMMEDIATELY for instant visual feedback
            updateFormattingToolbar()
            
            // Continue aggressive scroll position enforcement
            var checkCount = 0
            let maxChecks = 20
            
            func enforceScrollPosition() {
                checkCount += 1
                if checkCount > maxChecks {
                    self.isApplyingFormatting = false
                    self.userIntendedScrollPosition = nil
                    print("🔓 Released scroll position enforcement for alignment")
                    return
                }
                
                if let intended = self.userIntendedScrollPosition, textView.contentOffset != intended {
                    print("🔧 Correcting alignment scroll drift: \(textView.contentOffset) -> \(intended)")
                    textView.contentOffset = intended
                    textView.selectedRange = originalSelectedRange
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    enforceScrollPosition()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                enforceScrollPosition()
            }
            
            print("✅ Alignment formatting complete, aggressive scroll enforcement active")
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
            guard let textView = textView else { return "Body" }
            
            let selectedRange = textView.selectedRange
            let currentFont: UIFont
            
            if selectedRange.length > 0 {
                // Check font of selected text
                if let attributedText = textView.attributedText, attributedText.length > 0 {
                    let attributes = attributedText.attributes(at: selectedRange.location, effectiveRange: nil)
                    currentFont = attributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
                } else {
                    currentFont = UIFont.systemFont(ofSize: 16)
                }
            } else {
                // Check typing attributes at cursor
                currentFont = textView.typingAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
            }
            
            // Determine style based on font size and weight
            let fontSize = currentFont.pointSize
            let fontWeight = currentFont.fontDescriptor.symbolicTraits
            
            if fontSize >= 26 {
                return "Title"
            } else if fontSize >= 20 {
                return "Heading"
            } else if fontSize <= 13 {
                return "Caption"
            } else if fontWeight.contains(.traitBold) && fontSize == 16 {
                return "Strong"
            } else {
                return "Body"
            }
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
        
        private func updateFormattingToolbarSafely() {
            updateFormattingToolbar()
        }
        
        private func updateParentTextSafely(_ textView: UITextView) {
            // Store current scroll position before updating parent binding
            let currentContentOffset = textView.contentOffset
            let currentSelectedRange = textView.selectedRange
            
            // Update parent text binding
            parent.text = textView.text
            
            // Immediately restore scroll position after SwiftUI update
            DispatchQueue.main.async {
                textView.contentOffset = currentContentOffset
                textView.selectedRange = currentSelectedRange
            }
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
            // If we're currently applying formatting, skip the update to prevent scroll jumps
            if isApplyingFormatting {
                print("🚫 Skipping textViewDidChange during formatting to prevent scroll jump")
                return
            }
            
            // Update SwiftUI binding
            parent.text = textView.text
            
            // Save changes back to document with formatting
            updateDocumentWithFormatting()
            
            // Update formatting toolbar after text changes
            updateFormattingToolbar()
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            // If we're currently applying formatting, skip toolbar update to prevent interference
            if isApplyingFormatting {
                print("🚫 Skipping selection change update during formatting")
                return
            }
            
            // Update formatting toolbar when selection changes
            updateFormattingToolbar()
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            print("✏️ Text editing began")
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            print("✅ Text editing ended")
        }
        
        private enum FormattingType {
            case bold, italic, underline
        }
        
        private func applyFormattingWithoutScrollJump(textView: UITextView, formattingType: FormattingType) {
            // Capture current state
            let originalContentOffset = textView.contentOffset
            let originalSelectedRange = textView.selectedRange
            let originalText = textView.text
            
            print("🛡️ Applying \(formattingType) with scroll protection")
            print("🛡️ Original offset: \(originalContentOffset), range: \(originalSelectedRange)")
            
            // Temporarily disable delegate to prevent textViewDidChange from firing
            let originalDelegate = textView.delegate
            textView.delegate = nil
            
            // Apply formatting based on type
            switch formattingType {
            case .bold:
                applyBoldFormattingDirect(textView: textView, selectedRange: originalSelectedRange)
            case .italic:
                applyItalicFormattingDirect(textView: textView, selectedRange: originalSelectedRange)
            case .underline:
                applyUnderlineFormattingDirect(textView: textView, selectedRange: originalSelectedRange)
            }
            
            // Force restore scroll position and selection immediately
            textView.selectedRange = originalSelectedRange
            textView.contentOffset = originalContentOffset
            
            // Re-enable delegate
            textView.delegate = originalDelegate
            
            // Update parent text binding manually without triggering delegates
            DispatchQueue.main.async {
                // Ensure scroll position is still correct after any SwiftUI updates
                textView.contentOffset = originalContentOffset
                textView.selectedRange = originalSelectedRange
                
                // Update parent binding
                self.parent.text = textView.text
                
                // Update document manually
                if let index = self.document.wrappedValue.elements.firstIndex(where: { $0.type == .textBlock }) {
                    self.document.wrappedValue.elements[index].content = textView.text
                }
                
                // Update toolbar
                self.updateFormattingToolbar()
                
                print("🛡️ Final offset: \(textView.contentOffset), range: \(textView.selectedRange)")
            }
        }
        
        private func applyBoldFormattingDirect(textView: UITextView, selectedRange: NSRange) {
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if selectedRange.length == 0 {
                // Handle cursor position - modify typing attributes
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
                }
            } else {
                // Handle text selection
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
            }
        }
        
        private func applyItalicFormattingDirect(textView: UITextView, selectedRange: NSRange) {
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if selectedRange.length == 0 {
                // Handle cursor position
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
                }
            } else {
                // Handle text selection
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
            }
        }
        
        private func applyUnderlineFormattingDirect(textView: UITextView, selectedRange: NSRange) {
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            attributedText.enumerateAttribute(.underlineStyle, in: selectedRange) { underlineAttribute, range, _ in
                let currentUnderline = underlineAttribute as? Int ?? 0
                let newUnderline = currentUnderline == 0 ? NSUnderlineStyle.single.rawValue : 0
                attributedText.addAttribute(.underlineStyle, value: newUnderline, range: range)
            }
            
            textView.attributedText = attributedText
        }
        
        private func debugScrollJumpIssue(textView: UITextView, operation: String) {
            print("🐛 === DEBUG SCROLL JUMP for \(operation) ===")
            print("🐛 BEFORE: contentOffset = \(textView.contentOffset)")
            print("🐛 BEFORE: selectedRange = \(textView.selectedRange)")
            print("🐛 BEFORE: contentSize = \(textView.contentSize)")
            print("🐛 BEFORE: bounds = \(textView.bounds)")
            
            // Store original state
            let originalOffset = textView.contentOffset
            let originalRange = textView.selectedRange
            
            // Create observer to track all scroll changes
            var scrollChanges: [CGPoint] = []
            
            // Method to track scroll changes
            func trackScrollChange(reason: String) {
                let currentOffset = textView.contentOffset
                scrollChanges.append(currentOffset)
                print("🐛 SCROLL CHANGE (\(reason)): \(currentOffset)")
                
                if currentOffset != originalOffset {
                    print("⚠️ SCROLL POSITION CHANGED! Original: \(originalOffset), New: \(currentOffset)")
                }
            }
            
            // Track initial state
            trackScrollChange(reason: "initial")
            
            // Apply simple bold formatting without any scroll protection
            print("🐛 Applying simple bold formatting...")
            
            if originalRange.length == 0 {
                // Cursor position - just update typing attributes
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
                    
                    print("🐛 Updating typing attributes...")
                    trackScrollChange(reason: "before typing attributes")
                    typingAttributes[.font] = newFont
                    textView.typingAttributes = typingAttributes
                    trackScrollChange(reason: "after typing attributes")
                }
            } else {
                // Text selection - update attributed text
                print("🐛 Updating attributed text for selection...")
                let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
                
                trackScrollChange(reason: "before attributedText creation")
                
                attributedText.enumerateAttribute(.font, in: originalRange) { fontAttribute, range, _ in
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
                
                trackScrollChange(reason: "before setting attributedText")
                textView.attributedText = attributedText
                trackScrollChange(reason: "after setting attributedText")
                
                print("🐛 Restoring selection...")
                textView.selectedRange = originalRange
                trackScrollChange(reason: "after restoring selection")
            }
            
            // Check if parent.text update causes issues
            print("🐛 Updating parent.text...")
            trackScrollChange(reason: "before parent.text update")
            parent.text = textView.text
            trackScrollChange(reason: "after parent.text update")
            
            // Final state
            print("🐛 FINAL: contentOffset = \(textView.contentOffset)")
            print("🐛 FINAL: selectedRange = \(textView.selectedRange)")
            print("🐛 === END DEBUG ===")
            
            // If scroll position changed, try to identify the culprit
            if textView.contentOffset != originalOffset {
                print("🚨 SCROLL JUMP DETECTED!")
                print("🚨 All scroll changes: \(scrollChanges)")
                print("🚨 Original: \(originalOffset), Final: \(textView.contentOffset)")
                
                // Try to force it back
                print("🚨 Attempting to force scroll position back...")
                textView.contentOffset = originalOffset
                print("🚨 After force restore: \(textView.contentOffset)")
            }
        }
    }
}
#endif 

