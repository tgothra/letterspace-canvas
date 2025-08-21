# Drag and Drop Setup for SwiftUI Lists

## Overview
This document outlines the proven drag and drop pattern implemented for Today's Documents that eliminates duplication issues and provides smooth reordering functionality.

## 🎯 Complete Implementation Pattern

### 1. SwiftUI List Configuration
```swift
List {
    ForEach(renderItems(), id: \.id) { item in
        // Row content with proper modifiers
        YourRowView(item: item)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { 
                    onRemoveItem(item.id) 
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
    .onMove(perform: onReorderItems)
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.frame(height: CGFloat(renderItems().count * estimatedRowHeight + paddingBuffer))
// Optional: show drag handles if you want visible grips
// .environment(\.editMode, .constant(.active))
```

### 2. Required Data Models

#### Base Requirements
- **Stable IDs**: Each item needs a unique, stable identifier
- **Order Properties**: Items must have `order: Int` for positioning
- **Codable**: For persistence to UserDefaults/Core Data

#### Example Models
```swift
struct SectionHeader: Identifiable, Codable {
    let id: String
    var title: String
    var order: Int
}

struct StructureDocument: Identifiable, Codable {
    let id: String
    var headerId: String?
    var order: Int
}

enum StructureItem: Identifiable {
    case header(SectionHeader)
    case document(Document, Int)
    
    var id: String {
        switch self {
        case .header(let header):
            return "header-\(header.id)"
        case .document(let document, _):
            return "document-\(document.id)"
        }
    }
}
```

### 3. Critical Reorder Function
```swift
private func reorderItems(from source: IndexSet, to destination: Int) {
    var items = renderItems()
    // ✅ CRITICAL: Use .move() - NOT manual removal/insertion
    items.move(fromOffsets: source, toOffset: destination)
    
    // Update the data structure based on new order
    updateStructureFromItems(items)
}

private func updateStructureFromItems(_ items: [StructureItem]) {
    var newHeaders: [SectionHeader] = []
    var newDocuments: [StructureDocument] = []
    
    for (index, item) in items.enumerated() {
        switch item {
        case .header(let header):
            var updatedHeader = header
            updatedHeader.order = index
            newHeaders.append(updatedHeader)
        case .document(let document, _):
            let headerId = findHeaderIdForDocument(at: index, in: items)
            let docStruct = StructureDocument(
                id: document.id,
                headerId: headerId,
                order: index
            )
            newDocuments.append(docStruct)
        }
    }
    
    // Update your data sources
    self.headers = newHeaders
    self.structureDocuments = newDocuments
    saveStructure()
}
```

### 4. Render Function Pattern
```swift
private func renderItems() -> [StructureItem] {
    var items: [StructureItem] = []
    
    // Add headers first
    for header in headers.sorted(by: { $0.order < $1.order }) {
        items.append(.header(header))
        
        // Add documents under this header
        let documentsUnderHeader = structureDocuments
            .filter { $0.headerId == header.id }
            .sorted(by: { $0.order < $1.order })
        
        for (index, docStruct) in documentsUnderHeader.enumerated() {
            if let document = allDocuments.first(where: { $0.id == docStruct.id }) {
                items.append(.document(document, index + 1))
            }
        }
    }
    
    // Add root-level documents (no header)
    let rootDocuments = structureDocuments
        .filter { $0.headerId == nil }
        .sorted(by: { $0.order < $1.order })
    
    for (index, docStruct) in rootDocuments.enumerated() {
        if let document = allDocuments.first(where: { $0.id == docStruct.id }) {
            items.append(.document(document, index + 1))
        }
    }
    
    return items
}
```

## 🚨 Critical Success Factors

### ✅ DO This
1. **Use `items.move(fromOffsets:toOffset:)`** in reorder function
2. **Set explicit List height** based on content count
3. **Visible handles are optional**: add `.environment(\.editMode, .constant(.active))` if desired
4. **Implement stable IDs** for all items
5. **Add proper list row modifiers** for clean appearance

### ❌ DON'T Do This
1. **Manual removal/insertion** - causes duplicates:
   ```swift
   // ❌ This creates duplicates:
   for index in source {
       reorderedItems.append(items[index])
   }
   items.insert(contentsOf: reorderedItems, at: destination)
   ```
2. **Rely on automatic List sizing** - items won't render properly
3. **Forget to persist changes** after reordering

## 🎪 Features This Pattern Provides

- **Smooth drag animations** with visual feedback
- **No duplicate items** during or after drag operations
- **Proper data persistence** to UserDefaults/Core Data
- **Swipe-to-delete functionality** on individual rows
- **Optional header swipe actions** (e.g., delete section)
- **Mixed content types** (headers + documents) in same list
- **Hierarchical organization** with items under headers

## 📱 Usage Examples

This pattern is successfully implemented in:
  - **Today's Documents** - Headers and documents with reordering
    - Handle-less drag and drop (long-press to move)
    - Swipe-to-delete on documents; delete section on headers
    - Tap anywhere on header row to rename inline
    - Leading swipe on headers for quick rename
- Ready for use in:
  - **Calendar events** reordering
  - **Sermon series** organization
  - **Tag management** with categories
  - **Any hierarchical list** with mixed content types

## 🔧 Customization Points

- **Row height estimation**: Adjust `estimatedRowHeight` value
- **Padding buffer**: Modify padding added to total height
- **Swipe actions**: Customize trailing/leading swipe buttons
- **Header interactions**: Configure tap areas and inline editing behavior
- **Visual styling**: Modify list row appearance
- **Persistence layer**: Adapt save/load functions to your data store

## 🏗️ Implementation Checklist

- [ ] Create data models with stable IDs and order properties
- [ ] Implement render function that converts data to display items
- [ ] Set up List with proper modifiers and editMode
- [ ] Implement reorder function using `items.move()`
- [ ] Add updateStructureFromItems function
- [ ] Set explicit List height based on content count
- [ ] Test drag and drop to ensure no duplicates
- [ ] Add swipe actions for additional functionality
- [ ] Implement persistence (save/load)

---

*Last updated: January 2025*
*Tested and verified on iOS 26*
