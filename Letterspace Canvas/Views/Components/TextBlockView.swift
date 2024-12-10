import SwiftUI
import AppKit

struct TextBlockView: View {
    @Binding var text: String
    var isFocused: Bool
    var onReturn: (String?) -> Void
    var onDelete: (() -> Void)?
    var isFirstBlock: Bool
    @FocusState private var focused: Bool
    @State private var isHovered = false
    @State private var showBlockMenu = false
    @State private var menuPosition: CGPoint = .zero
    @State private var hasSelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField(isFirstBlock && text.isEmpty ? "Type something..." : "", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .focused($focused)
                    .onAppear {
                        focused = isFocused
                    }
                    .onChange(of: isFocused) { oldValue, newValue in
                        if newValue {
                            DispatchQueue.main.async {
                                focused = true
                                if let fieldEditor = NSApp.keyWindow?.firstResponder as? NSTextView {
                                    fieldEditor.selectedRange = NSRange(location: text.count, length: 0)
                                }
                            }
                        }
                    }
                    .onChange(of: focused) { oldValue, newValue in
                        if !newValue {
                            hasSelection = false
                        }
                    }
                    .background {
                        GeometryReader { _ in
                            Color.clear.preference(key: TextSelectionKey.self, value: false)
                                .onAppear {
                                    // Monitor text selection
                                    NotificationCenter.default.addObserver(
                                        forName: NSTextView.didChangeSelectionNotification,
                                        object: nil,
                                        queue: .main
                                    ) { notification in
                                        if let textView = notification.object as? NSTextView,
                                           textView == NSApp.keyWindow?.firstResponder {
                                            hasSelection = textView.selectedRange().length > 0
                                        }
                                    }
                                }
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
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 80)
            }
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
            .overlay(alignment: .top) {
                if hasSelection && focused {
                    VStack {
                        HStack(spacing: 12) {
                            FormatButton(icon: "bold", action: {})
                            FormatButton(icon: "italic", action: {})
                            Divider().frame(height: 16)
                            FormatButton(icon: "list.bullet", action: {})
                            FormatButton(icon: "list.number", action: {})
                            Divider().frame(height: 16)
                            FormatButton(icon: "text.quote", action: {})
                            FormatButton(icon: "link", action: {})
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.windowBackgroundColor))
                        .cornerRadius(6)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .offset(y: -45)
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

struct TextSelectionKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

struct FormatButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
 