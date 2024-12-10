import SwiftUI
import AppKit

struct BodyTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isFocused: Bool
    var onSelectionChange: (Bool) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        // Create text container and text view properly
        let textContainer = NSTextContainer(size: NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        ))
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage()
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        let textView = RichTextView(frame: .zero, textContainer: textContainer)
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.textColor = NSColor.textColor
        textView.drawsBackground = false
        textView.isRichText = true
        
        textView.textDidChangeNotification = { newText in
            text = newText
        }
        textView.onSelectionChange = onSelectionChange
        
        // Configure for continuous text
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        
        // Set up text view sizing
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? RichTextView else { return }
        
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        
        if isFocused {
            DispatchQueue.main.async {
                scrollView.window?.makeFirstResponder(textView)
            }
        }
    }
} 