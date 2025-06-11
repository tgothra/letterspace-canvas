#if os(macOS)
import SwiftUI
import AppKit

struct InsertElementMenu: View {
    @Binding var isPresented: Bool
    let position: NSPoint
    let onSelect: (ElementType) -> Void
    
    private let elements: [(String, String, ElementType)] = [
        ("Scripture", "book.closed", .scripture),
        ("Header", "textformat.size", .header),
        ("Image", "photo", .image),
        ("Table", "tablecells", .table)
    ]
    
    var body: some View {
        if isPresented {
            ZStack {
                // Invisible background to handle click-outside
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPresented = false
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(elements, id: \.0) { element in
                        Button(action: {
                            onSelect(element.2)
                            isPresented = false
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: element.1)
                                    .frame(width: 20)
                                Text(element.0)
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Color.clear)
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.windowBackgroundColor))
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .position(x: position.x, y: position.y)
            }
            .ignoresSafeArea()
        }
    }
}
#endif 