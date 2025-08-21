//
//  CardView.swift
//  FlashCards
//
//  Created by Balaji Venkatesh on 27/01/25.
//

import SwiftUI

struct FlashCardView: View {
    var card: FlashCard
    var category: Category
    @EnvironmentObject private var properties: DragProperties
    @Environment(\.managedObjectContext) private var context
    /// View Properties
    @GestureState private var isActive: Bool = false
    /// Let's give some little haptics feedback when the gesture becomes active
    @State private var haptics: Bool = false
    var body: some View {
        GeometryReader {
            let rect = $0.frame(in: .global)
            let isSwappingInSameGroup = rect.contains(properties.location) && properties.sourceCard != card && properties.destinationCategory == nil
            
            Text(card.title ?? "")
                .padding(.horizontal, 15)
                .frame(width: rect.width, height: rect.height, alignment: .leading)
                .background(Color("Background"), in: .rect(cornerRadius: 10))
                .gesture(customGesture(rect: rect))
                .onChange(of: isSwappingInSameGroup) { oldValue, newValue in
                    if newValue {
                        properties.swapCardsInSameGroup(card)
                    }
                }
        }
        .frame(height: 60)
        /// Hiding the active dragging view
        .opacity(properties.sourceCard == card ? 0 : 1)
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                haptics.toggle()
            } else {
                handleGestureEnd()
            }
        }
        .sensoryFeedback(.impact, trigger: haptics)
    }
    
    private func customGesture(rect: CGRect) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(coordinateSpace: .global))
            .updating($isActive, body: { _, out, _ in
                out = true
            })
            .onChanged { value in
                /// This means that the long-press gesture has been finished successfully and drag gesture has been initiated!
                if case .second(_, let gesture) = value {
                    handleGestureChange(gesture, rect: rect)
                }
            }
    }
    
    private func handleGestureChange(_ gesture: DragGesture.Value?, rect: CGRect) {
        /// Step 1: Let's create a preview image of the dragging view
        if properties.previewImage == nil {
            properties.show = true
            properties.previewImage = createPreviewImage(rect)
            /// Storing source properties
            properties.sourceCard = card
            properties.sourceCategory = category
            properties.initialViewLocation = rect.origin
        }
        
        /// Updating Gesture Values
        guard let gesture else { return }
        
        properties.offset = gesture.translation
        properties.location = gesture.location
        properties.updatedViewLocation = rect.origin
    }
    
    private func handleGestureEnd() {
        withAnimation(.easeInOut(duration: 0.25), completionCriteria: .logicallyComplete) {
            if properties.destinationCategory != nil {
                properties.changeGroup(context)
            } else {
                /// Updating view location if there is any change
                if properties.updatedViewLocation != .zero {
                    properties.initialViewLocation = properties.updatedViewLocation
                }
                
                properties.offset = .zero
            }
        } completion: {
            /// Saving changes, if so
            if properties.isCardsSwapped {
                try? context.save()
            }
            
            properties.resetAllProperties()
        }
    }
    
    private func createPreviewImage(_ rect: CGRect) -> UIImage? {
        let view = HStack {
            Text(card.title ?? "")
                .padding(.horizontal, 15)
                .foregroundStyle(.white)
                .frame(width: rect.width, height: rect.height, alignment: .leading)
                .background(Color("Background"), in: .rect(cornerRadius: 10))
        }
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        
        return renderer.uiImage
    }
}

#Preview {
    ContentView()
        /// Preview Core Data for testing
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
