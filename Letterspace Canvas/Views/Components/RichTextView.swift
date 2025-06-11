#if os(macOS)
import AppKit
import SwiftUI

class RichTextView: NSTextView {
    var onSelectionChange: ((Bool) -> Void)?
    var textDidChangeNotification: ((String) -> Void)?
    private var keyboardMonitor: Any?
    
    var isFirstResponder: Bool {
        return window?.firstResponder === self
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        let container = NSTextContainer(size: frame.size)
        let layoutManager = NSLayoutManager()
        let storage = NSTextStorage()
        
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        
        super.init(frame: frame, textContainer: container)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isRichText = true
        allowsUndo = true
        isEditable = true
        isSelectable = true
        font = .systemFont(ofSize: 16)
        insertionPointColor = NSColor(Color(hex: "#3ee5a1"))
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: self
        )
        
        // Add keyboard shortcut monitoring
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "b":
                    self.toggleBold()
                    return nil
                case "i":
                    self.toggleItalic()
                    return nil
                case "k":
                    self.insertLink()
                    return nil
                case "l":
                    self.toggleBulletList()
                    return nil
                case "n":
                    self.toggleNumberedList()
                    return nil
                case "h":
                    self.toggleHeading()
                    return nil
                case "q":
                    self.toggleQuote()
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    @objc private func selectionDidChange(_ notification: Notification) {
        let hasSelection = selectedRange().length > 0
        onSelectionChange?(hasSelection)
    }
    
    override func didChangeText() {
        super.didChangeText()
        textDidChangeNotification?(string)
        
        // Reset cursor position when text is empty
        if string.isEmpty {
            selectedRange = NSRange(location: 0, length: 0)
            
            // Reset any paragraph styles
            let defaultStyle = NSMutableParagraphStyle()
            typingAttributes[.paragraphStyle] = defaultStyle
            
            // Reset any other formatting attributes
            typingAttributes[.font] = NSFont.systemFont(ofSize: 16)
            typingAttributes[.foregroundColor] = NSColor.textColor
        }
    }
    
    // MARK: - Formatting Methods
    func toggleBold() {
        let range = selectedRange()
        guard range.length > 0,
              let font = font,
              let textStorage = textStorage else { return }
        
        let traits = NSFontManager.shared.traits(of: font)
        let newFont = if traits.contains(.boldFontMask) {
            NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
        } else {
            NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        
        textStorage.addAttribute(.font, value: newFont, range: range)
    }
    
    func toggleItalic() {
        let range = selectedRange()
        guard range.length > 0,
              let font = font,
              let textStorage = textStorage else { return }
        
        let traits = NSFontManager.shared.traits(of: font)
        let newFont = if traits.contains(.italicFontMask) {
            NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
        } else {
            NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        
        textStorage.addAttribute(.font, value: newFont, range: range)
    }
    
    func toggleUnderline(color: NSColor = .textColor) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        if color == NSColor(Color.clear) {
            // Remove underline
            textStorage.removeAttribute(.underlineStyle, range: range)
            textStorage.removeAttribute(.underlineColor, range: range)
        } else {
            // Apply or update underline
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            textStorage.addAttribute(.underlineColor, value: color, range: range)
        }
    }
    
    func insertLink() {
        let range = selectedRange()
        guard range.length > 0 else { return }
        
        let alert = NSAlert()
        alert.messageText = "Add Link"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "Enter URL"
        alert.accessoryView = input
        
        if alert.runModal() == .alertFirstButtonReturn {
            var urlString = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Don't proceed if the URL is empty
            guard !urlString.isEmpty else { return }
            
            // Add "https://" if the URL doesn't already have a scheme
            if !urlString.contains("://") {
                // If it starts with "www." or has a domain suffix like ".com", ".org", etc.
                // we'll assume it's a web URL and add https://
                urlString = "https://" + urlString
            }
            
            if let url = URL(string: urlString) {
                textStorage?.addAttribute(.link, value: url, range: range)
                // Also add underline and color styling for links
                textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                textStorage?.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            }
        }
    }
    
    func toggleBulletList() {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        let text = string as NSString
        let paragraphRange = text.paragraphRange(for: range)
        
        // Get current paragraph style
        let currentStyle = textStorage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        
        // Check if we already have a bullet list by looking for specific indentation
        let hasList = currentStyle.headIndent == 25
        
        // Create mutable string for the modification
        let mutableString = NSMutableAttributedString()
        
        if !hasList {
            // Split text into lines
            let lines = text.substring(with: paragraphRange).components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Create bullet point
                    let bulletString = NSAttributedString(string: "• ", attributes: [
                        .font: NSFont.systemFont(ofSize: 16),
                        .foregroundColor: NSColor.textColor
                    ])
                    mutableString.append(bulletString)
                    mutableString.append(NSAttributedString(string: line))
                } else {
                    mutableString.append(NSAttributedString(string: line))
                }
                
                if index < lines.count - 1 {
                    mutableString.append(NSAttributedString(string: "\n"))
                }
            }
            
            // Set indentation
            currentStyle.headIndent = 25
            currentStyle.firstLineHeadIndent = 0
            
            // Copy original attributes
            let originalAttrs = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            mutableString.addAttributes(originalAttrs, range: NSRange(location: 0, length: mutableString.length))
            
            // Apply paragraph style
            mutableString.addAttribute(.paragraphStyle, value: currentStyle, range: NSRange(location: 0, length: mutableString.length))
        } else {
            // Remove bullets
            let lines = text.substring(with: paragraphRange).components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                var lineText = line
                if lineText.hasPrefix("• ") {
                    lineText = String(lineText.dropFirst(2))
                }
                mutableString.append(NSAttributedString(string: lineText))
                
                if index < lines.count - 1 {
                    mutableString.append(NSAttributedString(string: "\n"))
                }
            }
            
            // Reset paragraph style
            currentStyle.headIndent = 0
            currentStyle.firstLineHeadIndent = 0
            
            // Copy original attributes
            let originalAttrs = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            mutableString.addAttributes(originalAttrs, range: NSRange(location: 0, length: mutableString.length))
            
            // Apply paragraph style
            mutableString.addAttribute(.paragraphStyle, value: currentStyle, range: NSRange(location: 0, length: mutableString.length))
        }
        
        // Replace text
        textStorage.replaceCharacters(in: paragraphRange, with: mutableString)
        
        // Update selection to match numbered list behavior
        selectedRange = NSRange(location: paragraphRange.location, length: mutableString.length)
        
        needsDisplay = true
        didChangeText()
    }
    
    func toggleNumberedList() {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        let text = string as NSString
        let paragraphRange = text.paragraphRange(for: range)
        let currentText = text.substring(with: paragraphRange)
        
        // Split text into lines
        let lines = currentText.components(separatedBy: .newlines)
        
        // Check if ANY line starts with a number
        let numberPattern = #/^\d+\. /#
        let hasNumbers = lines.contains { line in
            line.matches(of: numberPattern).count > 0
        }
        
        // Create new attributed string
        let mutableString = NSMutableAttributedString()
        
        if hasNumbers {
            // Remove numbers from all lines
            for (index, line) in lines.enumerated() {
                var lineText = line
                if let match = line.matches(of: numberPattern).first {
                    lineText = String(line.dropFirst(match.0.count))
                }
                mutableString.append(NSAttributedString(string: lineText))
                
                if index < lines.count - 1 {
                    mutableString.append(NSAttributedString(string: "\n"))
                }
            }
            
            // Reset paragraph style
            let defaultStyle = NSMutableParagraphStyle()
            mutableString.addAttribute(.paragraphStyle, value: defaultStyle, range: NSRange(location: 0, length: mutableString.length))
        } else {
            // Add numbers to all lines
            for (index, line) in lines.enumerated() {
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    let numberString = "\(index + 1). "
                    mutableString.append(NSAttributedString(string: numberString + line))
                } else {
                    mutableString.append(NSAttributedString(string: line))
                }
                
                if index < lines.count - 1 {
                    mutableString.append(NSAttributedString(string: "\n"))
                }
            }
            
            // Add paragraph style with indent
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 20
            paragraphStyle.firstLineHeadIndent = 0
            mutableString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutableString.length))
        }
        
        // Copy original attributes except paragraph style
        let originalAttrs = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
        for (key, value) in originalAttrs {
            if key != .paragraphStyle {
                mutableString.addAttribute(key, value: value, range: NSRange(location: 0, length: mutableString.length))
            }
        }
        
        // Replace text
        textStorage.replaceCharacters(in: paragraphRange, with: mutableString)
        
        // Maintain selection
        selectedRange = NSRange(location: paragraphRange.location, length: mutableString.length)
        needsDisplay = true
        didChangeText()
    }
    
    func toggleHeading() {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        // Check if the selection is already a heading
        if let currentFont = textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont,
           currentFont.pointSize > 16 {
            // Remove heading
            let normalFont = NSFont.systemFont(ofSize: 16)
            textStorage.addAttribute(.font, value: normalFont, range: range)
        } else {
            // Add heading
            let headingFont = NSFont.systemFont(ofSize: 24, weight: .bold)
            textStorage.addAttribute(.font, value: headingFont, range: range)
        }
    }
    
    func toggleQuote() {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        // Check if the selection is already a quote
        if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle,
           paragraphStyle.headIndent == 20 && paragraphStyle.firstLineHeadIndent == 20 {
            // Remove quote
            let defaultStyle = NSMutableParagraphStyle()
            textStorage.addAttribute(.paragraphStyle, value: defaultStyle, range: range)
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
        } else {
            // Add quote
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 20
            paragraphStyle.firstLineHeadIndent = 20
            
            textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
        }
    }
    
    override func insertTab(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else {
            super.insertTab(sender)
            return
        }
        
        let text = string as NSString
        let paragraphRange = text.paragraphRange(for: range)
        
        // Get current paragraph style
        if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle {
            let newStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
            
            // Increase indentation
            newStyle.headIndent += 20
            newStyle.firstLineHeadIndent += 20
            
            // Apply new style
            textStorage.addAttribute(.paragraphStyle, value: newStyle, range: paragraphRange)
        }
        
        needsDisplay = true
    }
    
    override func insertBacktab(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else {
            super.insertBacktab(sender)
            return
        }
        
        let text = string as NSString
        let paragraphRange = text.paragraphRange(for: range)
        
        // Get current paragraph style
        if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle {
            let newStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
            
            // Decrease indentation, but don't go below 0
            newStyle.headIndent = max(0, newStyle.headIndent - 20)
            newStyle.firstLineHeadIndent = max(0, newStyle.firstLineHeadIndent - 20)
            
            // Apply new style
            textStorage.addAttribute(.paragraphStyle, value: newStyle, range: paragraphRange)
        }
        
        needsDisplay = true
    }
    
    override func insertNewline(_ sender: Any?) {
        // Always insert newline first
        super.insertNewline(sender)
        
        // Then check if we need to continue list formatting
        let range = selectedRange()
        guard let textStorage = textStorage else { return }
        
        // Get the current paragraph style
        if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: max(0, range.location - 1), effectiveRange: nil) as? NSParagraphStyle {
            let isList = paragraphStyle.headIndent == 25 || paragraphStyle.headIndent == 20
            
            if isList {
                let text = string as NSString
                let currentParagraphRange = text.paragraphRange(for: NSRange(location: range.location, length: 0))
                let previousParagraphRange = text.paragraphRange(for: NSRange(location: max(0, range.location - 1), length: 0))
                let previousLine = text.substring(with: previousParagraphRange)
                
                // Check if previous line was empty (just bullet/number)
                let trimmedLine = previousLine.trimmingCharacters(in: .whitespaces)
                if trimmedLine == "•" || trimmedLine.matches(of: #/^\d+\.$/#).count > 0 {
                    // Remove list formatting from current line
                    let defaultStyle = NSMutableParagraphStyle()
                    textStorage.addAttribute(.paragraphStyle, value: defaultStyle, range: currentParagraphRange)
                    return
                }
                
                // Continue list formatting
                if previousLine.contains("• ") {
                    let bulletString = NSAttributedString(string: "• ", attributes: [
                        .font: NSFont.systemFont(ofSize: 16),
                        .foregroundColor: NSColor.textColor
                    ])
                    textStorage.insert(bulletString, at: range.location)
                    
                    // Move cursor after bullet point
                    selectedRange = NSRange(location: range.location + 2, length: 0)
                } else {
                    // For numbered lists, find the last number and increment
                    var lastNumber = 0
                    let lines = text.substring(with: NSRange(location: 0, length: range.location)).components(separatedBy: .newlines)
                    for line in lines.reversed() {
                        if let match = line.matches(of: #/^(\d+)\. /#).first,
                           let number = Int(match.1.description) {
                            lastNumber = number
                            break
                        }
                    }
                    
                    let nextNumber = lastNumber + 1
                    let numberString = "\(nextNumber). "
                    textStorage.insert(NSAttributedString(string: numberString), at: range.location)
                    
                    // Move cursor after number
                    selectedRange = NSRange(location: range.location + numberString.count, length: 0)
                }
                
                // Apply list paragraph style
                if let listStyle = paragraphStyle.mutableCopy() as? NSMutableParagraphStyle {
                    textStorage.addAttribute(.paragraphStyle, value: listStyle, range: currentParagraphRange)
                }
            }
        }
    }
    
    override func deleteBackward(_ sender: Any?) {
        let range = selectedRange()
        
        // Handle normal delete first
        super.deleteBackward(sender)
        
        // Then check if we need to handle list formatting
        guard let textStorage = textStorage,
              range.location > 0 else { return }
        
        let text = string as NSString
        let currentLocation = selectedRange().location
        
        // Check if we're in a list
        if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: currentLocation, effectiveRange: nil) as? NSParagraphStyle,
           paragraphStyle.headIndent > 0 {
            
            let paragraphRange = text.paragraphRange(for: NSRange(location: currentLocation, length: 0))
            let currentLine = text.substring(with: paragraphRange)
            
            // If we're at the start of a line with just a bullet/number, remove the list formatting
            if currentLine.trimmingCharacters(in: .whitespaces).isEmpty ||
               currentLine == "•" ||
               currentLine.matches(of: #/^\d+\.$/#).count > 0 {
                let defaultStyle = NSMutableParagraphStyle()
                textStorage.addAttribute(.paragraphStyle, value: defaultStyle, range: paragraphRange)
            }
        }
    }
    
    func setTextColor(_ color: SwiftUI.Color) {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(color)
        ]
        
        textStorage?.addAttributes(attributes, range: selectedRange)
    }
    
    func setHighlightColor(_ color: NSColor) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        if color == NSColor(Color.clear) {
            // Remove highlight
            textStorage.removeAttribute(.backgroundColor, range: range)
        } else {
            // Apply highlight
            textStorage.addAttribute(.backgroundColor, value: color.withAlphaComponent(0.3), range: range)
        }
    }
    
    func setAlignment(_ alignment: SwiftUI.TextAlignment) {
        guard let selectedRange = selectedRanges.first?.rangeValue,
              let textStorage = textStorage else { return }
        
        // Get the paragraph ranges that contain the selection
        var effectiveRange = NSRange()
        let rangeStart = selectedRange.location
        let rangeEnd = rangeStart + selectedRange.length
        
        var location = rangeStart
        while location < rangeEnd {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment.toNSTextAlignment()
            
            // Get the paragraph range at this location
            textStorage.attribute(.paragraphStyle, at: location, effectiveRange: &effectiveRange)
            
            // Apply the alignment to the entire paragraph
            textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: effectiveRange)
            
            // Move to the next paragraph
            location = effectiveRange.location + effectiveRange.length
        }
    }
}

extension SwiftUI.TextAlignment {
    func toNSTextAlignment() -> NSTextAlignment {
        switch self {
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        }
    }
}

extension NSColor {
    convenience init(_ color: SwiftUI.Color) {
        let cgColor = color.cgColor ?? CGColor(gray: 0, alpha: 1)
        self.init(cgColor: cgColor)!
    }
}
#endif 