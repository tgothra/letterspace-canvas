import SwiftUI

struct CommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var searchText: String
    let position: CGPoint
    let onSelect: (ElementType) -> Void
    
    private let blockTypes: [(ElementType, String, String)] = [
        (.textBlock, "Text", "text.alignleft"),
        (.image, "Image", "photo"),
        (.scripture, "Bible", "book"),
        (.table, "Table", "tablecells"),
        (.chart, "Chart", "chart.bar"),
        (.date, "Date", "calendar"),
        (.dropdown, "Dropdown", "chevron.down.circle"),
        (.multiSelect, "Multi-select", "checkmark.circle")
    ]
    
    var body: some View {
        if isPresented {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 0) {
                    // Search field
                    TextField("Search for a block type...", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.clear)
                    
                    Divider()
                    
                    // Block type list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredBlockTypes, id: \.0) { blockType, name, icon in
                                Button(action: {
                                    onSelect(blockType)
                                    isPresented = false
                                    searchText = ""
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: icon)
                                            .frame(width: 20)
                                        Text(name)
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .frame(width: 200)
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .offset(x: position.x, y: position.y - 100) // Position relative to cursor with offset
            }
            .ignoresSafeArea()
        }
    }
    
    private var filteredBlockTypes: [(ElementType, String, String)] {
        if searchText.isEmpty {
            return blockTypes
        }
        return blockTypes.filter { $0.1.localizedCaseInsensitiveContains(searchText) }
    }
} 