#if os(macOS)
import SwiftUI
import AppKit

struct TextBlockView: View {
    @Binding var text: String
    var isFocused: Bool
    var onReturn: (String?) -> Void
    var onDelete: (() -> Void)?
    var isFirstBlock: Bool
    @State private var isHovered = false
    @State private var showBlockMenu = false
    @State private var menuPosition: CGPoint = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(isFirstBlock && text.isEmpty ? "Type something..." : "", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .frame(maxWidth: .infinity)
                .padding(.trailing, 80)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .overlay(alignment: .trailing) {
                    if isHovered {
                        HStack(spacing: 8) {
                            Button(action: {
                                if let window = NSApp.keyWindow {
                                    let point = window.mouseLocationOutsideOfEventStream
                                    menuPosition = point
                                    showBlockMenu = true
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .frame(width: 20, height: 20)
                        }
                        .padding(.trailing, 8)
                    }
                }
                .onKeyPress(.return) {
                    // Get cursor position and split text
                    if let fieldEditor = NSApp.keyWindow?.firstResponder as? NSTextView {
                        let selectedRange = fieldEditor.selectedRange()
                        let beforeCursor = text.prefix(selectedRange.location)
                        let afterCursor = text.dropFirst(selectedRange.location)
                        
                        // Update current block with text before cursor
                        text = String(beforeCursor)
                        
                        // Create new block with text after cursor
                        onReturn(String(afterCursor))
                    } else {
                        onReturn(nil)
                    }
                    return .handled
                }
                .onKeyPress(.delete) {
                    if text.isEmpty && !isFirstBlock {
                        // Only delete if we're at the start of the block
                        if let fieldEditor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            let selectedRange = fieldEditor.selectedRange()
                            if selectedRange.location == 0 {
                                onDelete?()
                                return .handled
                            }
                        }
                    }
                    return .ignored
                }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

extension String {
    var nonEmpty: String? {
        return self.isEmpty ? nil : self
    }
}

struct TextSelectionKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}
#endif 