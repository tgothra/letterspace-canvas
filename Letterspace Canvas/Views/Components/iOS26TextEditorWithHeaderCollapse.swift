#if os(iOS)
import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct iOS26TextEditorWithHeaderCollapse: UIViewRepresentable {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var headerCollapseProgress: CGFloat
    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    
    let maxScrollForCollapse: CGFloat
    
    init(
        document: Binding<Letterspace_CanvasDocument>,
        headerCollapseProgress: Binding<CGFloat>,
        maxScrollForCollapse: CGFloat = 300
    ) {
        self._document = document
        self._headerCollapseProgress = headerCollapseProgress
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
        
        // Set up attributed text support
        textView.allowsEditingTextAttributes = true
        
        // Add custom pan gesture recognizer for header collapse
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        textView.addGestureRecognizer(panGesture)
        
        // Set delegate
        textView.delegate = context.coordinator
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Update text if needed
        let newText = getDocumentText()
        if uiView.text != newText {
            uiView.text = newText
        }
        
        // Update coordinator bindings
        context.coordinator.headerCollapseProgress = $headerCollapseProgress
        context.coordinator.maxScrollForCollapse = maxScrollForCollapse
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
    
    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: iOS26TextEditorWithHeaderCollapse
        var headerCollapseProgress: Binding<CGFloat>
        var maxScrollForCollapse: CGFloat
        private var initialPanLocation: CGPoint = .zero
        private var initialHeaderProgress: CGFloat = 0
        
        init(_ parent: iOS26TextEditorWithHeaderCollapse) {
            self.parent = parent
            self.headerCollapseProgress = parent.$headerCollapseProgress
            self.maxScrollForCollapse = parent.maxScrollForCollapse
            super.init()
        }
        
        // MARK: - Pan Gesture Handling
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            
            switch gesture.state {
            case .began:
                initialPanLocation = gesture.location(in: textView)
                initialHeaderProgress = headerCollapseProgress.wrappedValue
                
            case .changed:
                _ = gesture.location(in: textView)
                let translation = gesture.translation(in: textView)
                
                // Only handle vertical swipes when at top of document OR header is already collapsing
                let isAtTop = textView.contentOffset.y <= 0
                let isHeaderCollapsing = headerCollapseProgress.wrappedValue > 0
                
                if (isAtTop || isHeaderCollapsing) && abs(translation.x) < abs(translation.y) {
                    // Calculate header collapse based on upward swipe
                    let dragDistance = -translation.y // Negative for upward swipe
                    let progress = max(0, min(1, (initialHeaderProgress * maxScrollForCollapse + dragDistance) / maxScrollForCollapse))
                    
                    DispatchQueue.main.async {
                        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9)) {
                            self.headerCollapseProgress.wrappedValue = progress
                        }
                    }
                }
                
            case .ended, .cancelled:
                // Snap to nearest state
                let targetProgress: CGFloat = headerCollapseProgress.wrappedValue > 0.5 ? 1.0 : 0.0
                
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.headerCollapseProgress.wrappedValue = targetProgress
                    }
                }
                
            default:
                break
            }
        }
        
        // MARK: - Gesture Recognizer Delegate
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow simultaneous recognition with text view's built-in gestures
            return true
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
                  let textView = gestureRecognizer.view as? UITextView else {
                return true
            }
            
            let translation = panGesture.translation(in: textView)
            let isVerticalSwipe = abs(translation.y) > abs(translation.x)
            let isAtTop = textView.contentOffset.y <= 0
            let isHeaderCollapsing = headerCollapseProgress.wrappedValue > 0
            
            // Only begin gesture for vertical swipes when at top or header is collapsing
            return isVerticalSwipe && (isAtTop || isHeaderCollapsing)
        }
        
        // MARK: - Text View Delegate
        func textViewDidChange(_ textView: UITextView) {
            // Update document when text changes
            DispatchQueue.main.async {
                self.parent.saveToDocument(textView.text)
            }
        }
    }
    
    private func saveToDocument(_ newText: String) {
        if let index = document.elements.firstIndex(where: { $0.type == .textBlock }) {
            document.elements[index].content = newText
        } else {
            var newElement = DocumentElement(type: .textBlock)
            newElement.content = newText
            document.elements.append(newElement)
        }
    }
}
#endif 

