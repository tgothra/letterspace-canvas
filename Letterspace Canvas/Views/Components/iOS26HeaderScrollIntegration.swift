#if os(iOS)
import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct iOS26HeaderScrollIntegration<Content: View>: View {
    let content: Content
    @Binding var headerCollapseProgress: CGFloat
    @State private var scrollOffset: CGFloat = 0
    
    let maxScrollForCollapse: CGFloat
    
    init(
        headerCollapseProgress: Binding<CGFloat>,
        maxScrollForCollapse: CGFloat = 300,
        @ViewBuilder content: () -> Content
    ) {
        self._headerCollapseProgress = headerCollapseProgress
        self.maxScrollForCollapse = maxScrollForCollapse
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
                .onScrollGeometryChange(for: CGPoint.self) { geometry in
                    geometry.contentOffset
                } action: { oldValue, newValue in
                    updateHeaderCollapse(for: newValue.y)
                }
        }
        .scrollIndicators(.hidden)
    }
    
    private func updateHeaderCollapse(for scrollY: CGFloat) {
        // Calculate collapse progress (0.0 = fully expanded, 1.0 = fully collapsed)
        let rawProgress = max(0, min(1, scrollY / maxScrollForCollapse))
        
        // Apply gentle easing for smooth transition
        let easedProgress = 1.0 - pow(1.0 - rawProgress, 1.2)
        
        // Update with animation for smooth transitions
        withAnimation(.linear(duration: 0.1)) {
            headerCollapseProgress = easedProgress
        }
    }
}

@available(iOS 26.0, *)
struct iOS26HeaderScrollTextEditor: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var headerCollapseProgress: CGFloat
    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
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
    
    var body: some View {
        TextEditor(text: $attributedText, selection: $selection)
            .font(.system(size: 16))
            .padding()
            .background(Color(UIColor.systemBackground))
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let currentDragOffset = -value.translation.height // Negative because we want upward swipe to collapse header
                        
                        // Only handle upward swipes when at the top (or downward to expand when collapsed)
                        if currentDragOffset > 0 || headerCollapseProgress > 0 {
                            isDragging = true
                            updateHeaderCollapse(dragOffset: currentDragOffset)
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        // Apply gentle snap only if very close to natural positions
                        gentleSnapIfNeeded()
                    }
            )
            .onAppear {
                loadDocumentContent()
            }
            .onChange(of: attributedText) { _, newValue in
                saveToDocument(newValue)
            }
    }
    
    private func updateHeaderCollapse(dragOffset: CGFloat) {
        // Calculate progress based on drag distance
        let rawProgress = max(0, min(1, dragOffset / maxScrollForCollapse))
        
        // Apply smooth easing
        let easedProgress = 1.0 - pow(1.0 - rawProgress, 1.2)
        
        // Update header collapse progress
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
            headerCollapseProgress = easedProgress
        }
    }
    
    private func snapToNearestState() {
        // Snap to expanded (0) or collapsed (1) based on current progress
        let targetProgress: CGFloat = headerCollapseProgress > 0.5 ? 1.0 : 0.0
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            headerCollapseProgress = targetProgress
        }
    }
    
    private func gentleSnapIfNeeded() {
        let currentProgress = headerCollapseProgress
        
        // Only snap if we're very close to natural positions (within 5%)
        // This preserves the natural feel while providing subtle magnetic behavior
        let snapThreshold: CGFloat = 0.05
        let targetProgress: CGFloat?
        
        if abs(currentProgress - 0.0) < snapThreshold {
            targetProgress = 0.0  // Snap to fully expanded only if very close
        } else if abs(currentProgress - 1.0) < snapThreshold {
            targetProgress = 1.0  // Snap to collapsed only if very close
        } else {
            targetProgress = nil  // No snapping - let it rest naturally
        }
        
        if let target = targetProgress {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                headerCollapseProgress = target
            }
        }
    }
    
    private func loadDocumentContent() {
        // Load from document - simplified for focus
        if let element = document.elements.first(where: { $0.type == .textBlock }) {
            attributedText = AttributedString(element.content)
        }
    }
    
    private func saveToDocument(_ newText: AttributedString) {
        // Save to document - simplified for focus
        if let index = document.elements.firstIndex(where: { $0.type == .textBlock }) {
            document.elements[index].content = String(newText.characters)
        } else {
            var newElement = DocumentElement(type: .textBlock)
            newElement.content = String(newText.characters)
            document.elements.append(newElement)
        }
    }
}
#endif 