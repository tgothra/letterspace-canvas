//
//  CustomDisclosureGroup.swift
//  FlashCards
//
//  Created by Balaji Venkatesh on 27/01/25.
//

import SwiftUI

struct CustomDisclosureGroup: View {
    var category: Category
    init (category: Category) {
        self.category = category
        
        let descriptors = [NSSortDescriptor(keyPath: \FlashCard.order, ascending: true)]
        let predicate = NSPredicate(format: "category == %@", category)
        
        _cards = .init(entity: FlashCard.entity(), sortDescriptors: descriptors, predicate: predicate, animation: .easeInOut(duration: 0.15))
    }
    
    @FetchRequest private var cards: FetchedResults<FlashCard>
    /// View Properties
    /// I always wanted all the categories to be expanded (But you can change this behaviour)
    @State private var isExpanded: Bool = true
    @State private var gestureRect: CGRect = .zero
    @EnvironmentObject private var properties: DragProperties
    @Environment(\.managedObjectContext) private var context
    
    var body: some View {
        let isDropping = gestureRect.contains(properties.location) && properties.sourceCategory != category
        
        VStack(alignment: .leading, spacing: 15) {
            DisclosureHeader()
            
            if isExpanded {
                CardsView()
                    .transition(.blurReplace)
            }
        }
        .padding(15)
        .padding(.vertical, isExpanded ? 0 : 5)
        /// Let's add some little animation
        .animation(.easeInOut(duration: 0.2)) {
            $0
                .background(isDropping ? .blue.opacity(0.2) : .gray.opacity(0.1))
        }
        .clipShape(.rect(cornerRadius: 10))
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: { newValue in
            gestureRect = newValue
        }
        .onChange(of: isDropping) { oldValue, newValue in
            properties.destinationCategory = newValue ? category : nil
        }
    }
    
    @ViewBuilder
    private func DisclosureHeader() -> some View {
        HStack {
            Text(category.title ?? "New Folder")
            
            Spacer(minLength: 0)
            
            Menu {
                Button("Delete Group", role: .destructive) {
                    context.delete(category)
                    try? context.save()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .padding(5)
                    .contentShape(.rect)
            }
            .padding(.trailing, 5)
            
            Image(systemName: "chevron.down")
                .rotationEffect(.init(degrees: isExpanded ? 0 : 180))
        }
        .font(.callout)
        .fontWeight(.semibold)
        .foregroundStyle(.blue)
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                isExpanded.toggle()
            }
        }
    }
    
    /// Cards View
    @ViewBuilder
    private func CardsView() -> some View {
        if cards.isEmpty {
            Text("No Flash cards have been\nadded to this folder yet.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        } else {
            ForEach(cards) { card in
                FlashCardView(card: card, category: category)
            }
        }
    }
}

#Preview {
    ContentView()
        /// Preview Core Data for testing
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
