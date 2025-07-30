#if os(iOS)
import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct iOS26SimpleHeaderCollapseTextEditor: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var headerCollapseProgress: CGFloat
    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var startLocation: CGPoint = .zero
    
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
            .simultaneousGesture(
                // Use simultaneousGesture so it doesn't interfere with text editing
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .onAppear {
                loadDocumentContent()
            }
            .onChange(of: attributedText) { _, newValue in
                saveToDocument(newValue)
            }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if !isDragging {
            // Start of drag - record initial position
            startLocation = value.startLocation
            isDragging = true
            print("🎯 Started drag at: \(startLocation)")
        }
        
        // Calculate vertical drag distance (negative for upward swipe)
        let verticalDistance = -(value.location.y - startLocation.y)
        
        // Only handle if this is primarily a vertical swipe
        let horizontalDistance = abs(value.location.x - startLocation.x)
        let isVerticalSwipe = abs(verticalDistance) > horizontalDistance
        
        print("📏 Drag - Vertical: \(verticalDistance), Horizontal: \(horizontalDistance), IsVertical: \(isVerticalSwipe)")
        
        // Only respond to upward swipes or when header is already collapsing
        if isVerticalSwipe && (verticalDistance > 0 || headerCollapseProgress > 0) {
            print("✅ Updating header collapse with distance: \(verticalDistance)")
            updateHeaderCollapse(dragDistance: verticalDistance)
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false
        snapToNearestState()
    }
    
    private func updateHeaderCollapse(dragDistance: CGFloat) {
        // Calculate progress based on drag distance
        let rawProgress = max(0, min(1, dragDistance / maxScrollForCollapse))
        
        // Apply smooth easing
        let easedProgress = 1.0 - pow(1.0 - rawProgress, 1.2)
        
        print("🔄 Header Collapse - Distance: \(dragDistance), Raw: \(rawProgress), Eased: \(easedProgress)")
        
        // Update header collapse progress with smooth animation
        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9)) {
            headerCollapseProgress = easedProgress
        }
    }
    
    private func snapToNearestState() {
        // Snap to expanded (0) or collapsed (1) based on current progress
        let targetProgress: CGFloat = headerCollapseProgress > 0.3 ? 1.0 : 0.0
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            headerCollapseProgress = targetProgress
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