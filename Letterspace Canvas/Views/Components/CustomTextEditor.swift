#if os(macOS)
import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

struct CustomTextEditor: View {
    @Binding var text: NSAttributedString
    @Environment(\.colorScheme) var colorScheme
    var isFocused: Bool
    var onSelectionChange: (Bool) -> Void
    var showToolbar: Binding<Bool>
    var onAtCommand: ((NSPoint) -> Void)?
    var onScroll: ((CGFloat, CGFloat, CGFloat) -> Void)?
    var onShiftTab: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var placeholder: String?
    var placeholderAttributedString: NSAttributedString?
    
    var body: some View {
        CustomTextView(
            text: $text,
            colorScheme: colorScheme,
            isFocused: isFocused,
            onSelectionChange: onSelectionChange,
            showToolbar: showToolbar,
            onAtCommand: onAtCommand,
            onScroll: onScroll,
            onShiftTab: onShiftTab,
            onFocusChange: onFocusChange,
            placeholder: placeholder,
            placeholderAttributedString: placeholderAttributedString
        )
    }
}

struct CustomTextView: NSViewRepresentable {
    @Binding var text: NSAttributedString
    var colorScheme: ColorScheme
    var isFocused: Bool
    var onSelectionChange: (Bool) -> Void
    var showToolbar: Binding<Bool>
    var onAtCommand: ((NSPoint) -> Void)?
    var onScroll: ((CGFloat, CGFloat, CGFloat) -> Void)?
    var onShiftTab: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var placeholder: String?
    var placeholderAttributedString: NSAttributedString?
    
    func makeNSView(context: Context) -> NSScrollView {
        // Create scroll view with optimized settings
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true  // Enable vertical scroller
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollsDynamically = true  // Enable dynamic scrolling
        
        // Create text container with default settings
        let container = NSTextContainer()
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        container.size = NSSize(width: scrollView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        
        // Set line fragment padding to exactly 0
        container.lineFragmentPadding = 0
        
        // Create layout manager with simplified settings
        let layoutManager = NSLayoutManager()
        
        // Create text storage with proper configuration
        let textStorage = NSTextStorage()
        textStorage.delegate = context.coordinator
        
        // Configure layout manager and text storage
        layoutManager.addTextContainer(container)
        textStorage.addLayoutManager(layoutManager)
        
        // Create text view with the text storage
        let textView = EditorTextView(frame: .zero, textContainer: container)
        textView.colorScheme = colorScheme  // Set the colorScheme
        
        // Set initial text if any
        if text.length > 0 {
            textStorage.beginEditing()
            textStorage.setAttributedString(text)
            textStorage.endEditing()
        }
        
        // Configure text view
        textView.allowsUndo = true
        textView.isRichText = true
        textView.importsGraphics = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
        textView.delegate = context.coordinator
        textView.onAtCommand = onAtCommand
        textView.onSelectionChange = onSelectionChange
        textView.onScroll = onScroll  // Keep the onScroll callback
        textView.placeholder = placeholder
        
        // Set the exact text container inset to 19px
        textView.textContainerInset = NSSize(width: 19, height: textView.textContainerInset.height)
        
        // Configure text view for proper layout
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.textContainer?.containerSize = NSSize(width: scrollView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // Set initial typing attributes using getBodyStyleAttributes()
        textView.typingAttributes = textView.getBodyStyleAttributes()
        
        // If the text is empty, ensure cursor is at the beginning
        if text.length == 0 {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            
            // Reset paragraph style
            let defaultStyle = NSMutableParagraphStyle()
            defaultStyle.defaultTabInterval = NSParagraphStyle.default.defaultTabInterval
            defaultStyle.lineSpacing = NSParagraphStyle.default.lineSpacing
            defaultStyle.paragraphSpacing = NSParagraphStyle.default.paragraphSpacing
            
            // Set indentation explicitly to 0
            defaultStyle.headIndent = 0
            defaultStyle.tailIndent = 0
            defaultStyle.firstLineHeadIndent = 0
            defaultStyle.alignment = .natural
            
            // Apply default style to typing attributes
            textView.typingAttributes = [
                .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15),
                .paragraphStyle: defaultStyle,
                .foregroundColor: NSColor.textColor
            ]
        }
        
        // Set up scroll view with text view
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        
        // Use default background color
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        
        // Remove debug visualization
        // ALWAYS add debug visualization regardless of UserDefaults settings
        // This ensures we can see the text view boundaries and insets
        // textView.addDebugBorder()
        // textView.showInsetDebugInfo()
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }
        textView.colorScheme = colorScheme  // Update colorScheme when it changes
        
        // Only update text if content actually changed and view is not focused
        if !isFocused && textView.attributedString() != text {
            let selectedRange = textView.selectedRange()
            let visibleRect = textView.visibleRect
            
            // Begin editing session
            textView.textStorage?.beginEditing()
            
            // Store existing attributes for each character range
            var attributeRanges: [(NSRange, [NSAttributedString.Key: Any])] = []
            let fullRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
            textView.textStorage?.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
                attributeRanges.append((range, attributes))
            }
            
            // Update the text while preserving attributes
            let mutableText = NSMutableAttributedString(attributedString: text)
            for (range, attributes) in attributeRanges {
                if range.location + range.length <= mutableText.length {
                    // Preserve existing attributes
                    mutableText.addAttributes(attributes, range: range)
                }
            }
            
            textView.textStorage?.setAttributedString(mutableText)
            textView.textStorage?.endEditing()
            
            // Restore cursor position and scroll position
            textView.setSelectedRange(selectedRange)
            textView.scrollToVisible(visibleRect)
        }
        
        // Use default background color
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        
        // Update container width to match view width
        if let container = textView.textContainer {
            container.size = NSSize(
                width: scrollView.contentView.bounds.width - (textView.textContainerInset.width * 2),
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: CustomTextView
        private var isProcessingChange = false
        private var lastScrollPosition: CGFloat = 0
        private var isInOverscrollTransition = false
        private var lastTransitionTime: TimeInterval = 0
        private let transitionCooldown: TimeInterval = 0.5
        
        init(_ parent: CustomTextView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !isProcessingChange else { return }
            
            isProcessingChange = true
            
            // Get the current text with its attributes
            let attributedString = textView.attributedString()
            
            // Update the parent's text binding
            parent.text = attributedString
            
            isProcessingChange = false
        }
        
        // MARK: - NSTextStorageDelegate
        
        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            if editedMask.contains(.editedCharacters) {
                // Calculate the actual range of new text
                let newTextRange = NSRange(location: editedRange.location, length: max(0, delta))
                
                // Only apply attributes if there's text before the insertion point
                if editedRange.location > 0 {
                    // Get attributes from the character before the edit
                    let previousCharRange = NSRange(location: editedRange.location - 1, length: 1)
                    let attributes = textStorage.attributes(at: previousCharRange.location, effectiveRange: nil)
                    
                    // Apply attributes only to the new text
                    if delta > 0 {
                        textStorage.addAttributes(attributes, range: newTextRange)
                    }
                }
            }
        }
        
        // MARK: - NSTextViewDelegate
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let hasSelection = textView.selectedRange().length > 0
            parent.onSelectionChange(hasSelection)
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            // Trigger expansion synchronously
            self.parent.onFocusChange?(true)
            
            // Reset paragraph indentation when focus begins
            if let textView = notification.object as? EditorTextView {
                textView.resetParagraphIndentation()
            }
        }
        
        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange?(false)
            
            // Reset paragraph indentation when focus ends
            if let textView = notification.object as? EditorTextView {
                textView.resetParagraphIndentation()
            }
        }
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let scrollView = (notification.object as? NSClipView)?.superview as? NSScrollView,
                  let _ = scrollView.documentView else { return }
            
            let currentPosition = scrollView.contentView.bounds.origin.y
            
            // Start animation transaction for smooth transitions
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                
                // Update scroll info first to ensure proper animation timing
                lastScrollPosition = currentPosition
                
                // Call onScroll directly
                if let onScroll = parent.onScroll {
                    let visibleRect = scrollView.contentView.bounds
                    let documentRect = scrollView.documentView?.frame ?? .zero
                    onScroll(
                        visibleRect.origin.y,
                        documentRect.height,
                        visibleRect.height
                    )
                }
                
                // Then trigger header state change
                if currentPosition <= 0 && isInOverscrollTransition {
                    isInOverscrollTransition = false
                    self.parent.onFocusChange?(false)
                } else if currentPosition > 0 && !isInOverscrollTransition {
                    isInOverscrollTransition = true
                    self.parent.onFocusChange?(true)
                }
            })
        }
    }
}

class CustomMenuItem: NSMenuItem {
    var customView: CustomMenuItemView? {
        get { return view as? CustomMenuItemView }
    }
}

class CustomMenuItemView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")
    
    var isHighlighted = false {
        didSet {
            updateColors()
        }
    }
    
    init(title: String, icon: String?, shortcut: String?) {
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 32))
        setup(title: title, icon: icon, shortcut: shortcut)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setup(title: String, icon: String?, shortcut: String?) {
        wantsLayer = true
        
        // Icon
        if let iconName = icon, let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            image.isTemplate = true
            iconView.image = image
            iconView.frame = NSRect(x: 16, y: 6, width: 20, height: 20)
            addSubview(iconView)
        }
        
        // Title
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.frame = NSRect(x: 44, y: 8, width: 120, height: 16)
        addSubview(titleLabel)
        
        // Shortcut
        if let shortcut = shortcut {
            shortcutLabel.stringValue = shortcut
            shortcutLabel.font = .systemFont(ofSize: 12)
            shortcutLabel.alignment = .right
            shortcutLabel.frame = NSRect(x: 164, y: 8, width: 20, height: 16)
            addSubview(shortcutLabel)
        }
        
        updateColors()
    }
    
    private func updateColors() {
        if isHighlighted {
            layer?.backgroundColor = NSColor(white: 0.95, alpha: 1.0).cgColor
            iconView.contentTintColor = .black
            titleLabel.textColor = .labelColor
            shortcutLabel.textColor = NSColor.black.withAlphaComponent(0.3)
        } else {
            layer?.backgroundColor = nil
            iconView.contentTintColor = NSColor.black.withAlphaComponent(0.6)
            titleLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
            shortcutLabel.textColor = NSColor.black.withAlphaComponent(0.3)
        }
    }
}

class CustomMenu: NSMenu, NSMenuDelegate {
    override init(title: String) {
        super.init(title: title)
        self.delegate = self
        appearance = NSAppearance(named: .aqua)
        autoenablesItems = false
        minimumWidth = 200
        
        // Add header
        let headerItem = CustomMenuItem()
        let headerView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor(red: 0.98, green: 0.95, blue: 0.90, alpha: 1.0).cgColor
        
        let headerLabel = NSTextField(labelWithString: "Insert")
        headerLabel.frame = NSRect(x: 16, y: 12, width: 150, height: 16)
        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = NSColor.black.withAlphaComponent(0.8)
        headerView.addSubview(headerLabel)
        
        headerItem.view = headerView
        headerItem.isEnabled = false
        addItem(headerItem)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func addCustomItem(title: String, icon: String?, shortcut: String?, action: Selector?, target: AnyObject?, representedObject: Any?) {
        let item = CustomMenuItem()
        item.view = CustomMenuItemView(title: title, icon: icon, shortcut: shortcut)
        item.target = target
        item.action = action
        item.representedObject = representedObject
        addItem(item)
    }
    
    // MARK: - NSMenuDelegate
    
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // Reset all items
        items.forEach { menuItem in
            (menuItem as? CustomMenuItem)?.customView?.isHighlighted = false
        }
        
        // Highlight selected item
        if let item = item as? CustomMenuItem {
            item.customView?.isHighlighted = true
        }
    }
}

class CustomMenuView: NSView {
    internal var items: [(title: String, icon: String, type: ElementType, shortcut: String?)] = [
        ("Text", "text.alignleft", .textBlock, "T"),
        ("Image", "photo", .image, "I"),
        ("Scripture", "book", .scripture, "B"),
        ("Table", "tablecells", .table, "⌘T")
    ]
    
    var onSelect: ((ElementType) -> Void)?
    private var myTrackingAreas: [NSTrackingArea] = []
    private var hoveredIndex: Int? = nil
    private let verticalPadding: CGFloat = 8
    private let itemHeight: CGFloat = 32
    private let headerHeight: CGFloat = 32
    private let menuWidth: CGFloat = 180
    
    override init(frame: NSRect) {
        let totalHeight = CGFloat(items.count * Int(itemHeight)) + (verticalPadding * 2) + headerHeight
        super.init(frame: NSRect(x: 0, y: 0, width: menuWidth, height: totalHeight))
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = .clear
        layer?.cornerRadius = 12
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowOffset = NSSize(width: 0, height: 2)
        layer?.shadowRadius = 10
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let isDarkMode = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        // Draw main background
        let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        let backgroundColor = isDarkMode ? NSColor(calibratedWhite: 0.12, alpha: 1.0) : NSColor.white
        backgroundColor.setFill()
        backgroundPath.fill()
        
        // Draw "Insert" header
        let headerTitle = NSAttributedString(
            string: "Insert",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: (isDarkMode ? NSColor.white : NSColor.black).withAlphaComponent(0.4)
            ]
        )
        headerTitle.draw(at: NSPoint(x: 16, y: bounds.height - headerHeight + 8))
        
        // Draw items
        for (index, item) in items.enumerated() {
            let itemY = bounds.height - headerHeight - verticalPadding - CGFloat(index + 1) * itemHeight
            let itemRect = NSRect(x: 0, y: itemY, width: bounds.width, height: itemHeight)
            
            // Draw hover background with mint color
            if hoveredIndex == index {
                NSColor(red: 0.443, green: 0.953, blue: 0.671, alpha: 0.2).setFill()
                NSBezierPath(rect: itemRect).fill()
            }
            
            // Draw icon
            if let image = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) {
                image.isTemplate = true
                let tint = isDarkMode ? 
                    (hoveredIndex == index ? NSColor.white : NSColor.white.withAlphaComponent(0.6)) :
                    (hoveredIndex == index ? NSColor.black : NSColor.black.withAlphaComponent(0.6))
                let iconSize: CGFloat = 18
                let iconY = itemY + (itemHeight - iconSize) / 2
                let iconRect = NSRect(x: 16, y: iconY, width: iconSize, height: iconSize)
                
                image.size = NSSize(width: iconSize, height: iconSize)
                image.draw(in: iconRect)
                
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let tintedImage = NSImage(size: NSSize(width: iconSize, height: iconSize))
                    tintedImage.lockFocus()
                    tint.set()
                    NSRect(origin: .zero, size: tintedImage.size).fill(using: .sourceAtop)
                    NSGraphicsContext.current?.cgContext.draw(cgImage, in: NSRect(origin: .zero, size: tintedImage.size))
                    tintedImage.unlockFocus()
                    tintedImage.draw(in: iconRect)
                }
            }
            
            // Draw title
            let titleColor = isDarkMode ?
                (hoveredIndex == index ? NSColor.white : NSColor.white.withAlphaComponent(0.8)) :
                (hoveredIndex == index ? NSColor.black : NSColor.black.withAlphaComponent(0.8))
            let title = NSAttributedString(
                string: item.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: titleColor
                ]
            )
            title.draw(at: NSPoint(x: 44, y: itemY + 8))
            
            // Draw shortcut
            if let shortcut = item.shortcut {
                let shortcutColor = (isDarkMode ? NSColor.white : NSColor.black).withAlphaComponent(0.3)
                let shortcutText = NSAttributedString(
                    string: shortcut,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 12),
                        .foregroundColor: shortcutColor
                    ]
                )
                let shortcutWidth = shortcutText.size().width
                shortcutText.draw(at: NSPoint(x: bounds.width - shortcutWidth - 16, y: itemY + 8))
            }
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove existing tracking areas
        myTrackingAreas.forEach { removeTrackingArea($0) }
        myTrackingAreas.removeAll()
        
        // Add tracking area for each item
        for (index, _) in items.enumerated() {
            let itemY = bounds.height - headerHeight - verticalPadding - CGFloat(index + 1) * itemHeight
            let itemRect = NSRect(x: 0, y: itemY, width: bounds.width, height: itemHeight)
            let trackingArea = NSTrackingArea(
                rect: itemRect,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: self,
                userInfo: ["index": index]
            )
            addTrackingArea(trackingArea)
            myTrackingAreas.append(trackingArea)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo as? [String: Any],
           let index = userInfo["index"] as? Int {
            hoveredIndex = index
            needsDisplay = true
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        hoveredIndex = nil
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (index, item) in items.enumerated() {
            let itemY = bounds.height - headerHeight - verticalPadding - CGFloat(index + 1) * itemHeight
            let itemRect = NSRect(x: 0, y: itemY, width: bounds.width, height: itemHeight)
            if itemRect.contains(point) {
                onSelect?(item.type)
                break
            }
        }
    }
}

class MenuPanel: NSPanel {
    var customView: CustomMenuView?
    private var positioningMenu: NSMenu?
    
    init() {
        // Create with zero frame initially
        super.init(contentRect: .zero,
                  styleMask: [.nonactivatingPanel, .borderless],
                  backing: .buffered,
                  defer: false)
        
        // Configure panel
        self.isFloatingPanel = true
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        
        // Create and configure custom view
        customView = CustomMenuView()
        self.contentView = customView
        
        // Set the panel size to match the custom view
        self.setContentSize(NSSize(width: 160, height: CGFloat(4 * 32 + 32 + 4)))
        
        // Create positioning menu
        positioningMenu = NSMenu()
        positioningMenu?.addItem(NSMenuItem())
    }
    
    func show(at point: NSPoint, in view: NSView) {
        if let window = view.window {
            // Use NSMenu for positioning
            positioningMenu?.popUp(positioning: positioningMenu?.item(at: 0),
                                 at: point,
                                 in: view)
            
            // Get the menu's position and use it for our panel
            if let menuWindow = NSApp.windows.first(where: { $0.className.contains("MenuWindow") }) {
                let menuFrame = menuWindow.frame
                self.setFrame(menuFrame, display: true)
                
                if !self.isVisible {
                    window.addChildWindow(self, ordered: .above)
                }
                
                // Hide the actual menu window
                menuWindow.orderOut(nil)
            }
        }
    }
    
    func hide() {
        if let parent = self.parent {
            parent.removeChildWindow(self)
        }
        self.orderOut(nil)
    }
}

class SwiftUIAttachmentCell: NSTextAttachmentCell {
    private var hostingView: NSHostingView<AnyView>?
    private weak var parentView: NSView?
    private var lastBounds: NSRect = .zero
    private let isInline: Bool
    private var contentHeight: CGFloat = 0
    
    init(view: some View, isInline: Bool = false) {
        self.isInline = isInline
        super.init(textCell: "")
        
        // Create a temporary hosting view to calculate the content height
        let tempHostingView = NSHostingView(rootView: AnyView(view))
        // Use a reasonable initial width that will be updated when drawn
        let initialWidth = NSScreen.main?.frame.width ?? 1000
        tempHostingView.frame = NSRect(x: 0, y: 0, width: initialWidth * 0.8, height: 1000)
        tempHostingView.layoutSubtreeIfNeeded()
        self.contentHeight = tempHostingView.fittingSize.height
        
        self.hostingView = NSHostingView(rootView: AnyView(
            view
                .frame(maxWidth: .infinity)
        ))
    }
    
    required init(coder: NSCoder) {
        self.isInline = false
        super.init(coder: coder)
    }
    
    override func cellSize() -> NSSize {
        // Get the container width if available
        var containerWidth: CGFloat = 0
        if let textContainer = (parentView as? NSTextView)?.textContainer {
            containerWidth = textContainer.size.width
        } else {
            containerWidth = NSScreen.main?.frame.width ?? 1000
            containerWidth *= 0.8 // Use 80% of screen width as fallback
        }
        
        // Add padding proportional to the content height
        let verticalPadding = min(max(contentHeight * 0.2, 16), 32)
        return NSSize(width: containerWidth, height: contentHeight + verticalPadding * 2)
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        guard let hostingView = hostingView else { return }
        
        // Store the parent view for size updates
        self.parentView = controlView
        
        if hostingView.superview == nil {
            controlView?.addSubview(hostingView)
            
            // Set initial frame with proper positioning
            let verticalPadding = (cellFrame.height - contentHeight) / 2
            let horizontalInset = cellFrame.width * 0.03 // 3% inset on each side
            let adjustedFrame = NSRect(
                x: cellFrame.origin.x + horizontalInset,
                y: cellFrame.origin.y + verticalPadding,
                width: cellFrame.width * 0.94, // 94% of container width
                height: contentHeight
            )
            
            // Use frame-based positioning only
            hostingView.translatesAutoresizingMaskIntoConstraints = true
            hostingView.frame = adjustedFrame
            
        } else {
            // Update frame if needed
            let verticalPadding = (cellFrame.height - contentHeight) / 2
            let horizontalInset = cellFrame.width * 0.03 // 3% inset on each side
            let adjustedFrame = NSRect(
                x: cellFrame.origin.x + horizontalInset,
                y: cellFrame.origin.y + verticalPadding,
                width: cellFrame.width * 0.94, // 94% of container width
                height: contentHeight
            )
            
            if adjustedFrame != hostingView.frame {
                hostingView.frame = adjustedFrame
            }
        }
    }
    
    override func wantsToTrackMouse() -> Bool {
        return true
    }
    
    override func highlight(_ flag: Bool, withFrame cellFrame: NSRect, in controlView: NSView?) {
        // Prevent selection highlighting
    }
    
    override func trackMouse(with event: NSEvent, in cellFrame: NSRect, of controlView: NSView?, untilMouseUp flag: Bool) -> Bool {
        // Prevent text selection from affecting the attachment
        return true
    }
    
    deinit {
        // Clean up the hosting view when the cell is deallocated
        hostingView?.removeFromSuperview()
        hostingView = nil
    }
}

class EditorTextView: NSTextView {
    var colorScheme: ColorScheme = .light
    var onAtCommand: ((NSPoint) -> Void)?
    var onSelectionChange: ((Bool) -> Void)?
    var onScroll: ((CGFloat, CGFloat, CGFloat) -> Void)?
    var onShiftTab: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var onTextChange: (() -> Void)?
    var placeholder: String?
    var placeholderAttributedString: NSAttributedString?
    private var keyboardMonitor: Any?
    private var formattingToolbarPanel: NSPanel?
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw placeholder if text is empty
        if string.isEmpty {
            if let placeholderAttributedString = placeholderAttributedString {
                // Use attributed placeholder if available
                var placeholderRect = dirtyRect
                placeholderRect.origin.x = 19  // Reduced by 1 character from 20
                placeholderRect.origin.y = textContainerInset.height
                placeholderAttributedString.draw(in: placeholderRect)
            } else if let placeholder = placeholder {
                // Fall back to standard placeholder
                let placeholderAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.placeholderTextColor,
                    .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
                ]
                var placeholderRect = dirtyRect
                placeholderRect.origin.x = 19  // Reduced by 1 character from 20
                placeholderRect.origin.y = textContainerInset.height
                NSAttributedString(string: placeholder, attributes: placeholderAttributes).draw(in: placeholderRect)
            }
        }
    }
    
    private func setup() {
        print("🔧 Starting DocumentTextView setup")
        
        // Basic configuration
        isRichText = true
        isEditable = true
        isSelectable = true
        allowsUndo = true
        
        // Set text container inset to exactly 19 as specified
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        
        // Set line fragment padding to 0 as specified
        if let textContainer = textContainer {
            textContainer.lineFragmentPadding = 0
        }
        
        // Set up simplified paragraph style with default values
        let style = NSMutableParagraphStyle()
        style.defaultTabInterval = NSParagraphStyle.default.defaultTabInterval
        style.lineSpacing = NSParagraphStyle.default.lineSpacing
        style.paragraphSpacing = NSParagraphStyle.default.paragraphSpacing
        style.headIndent = NSParagraphStyle.default.headIndent
        style.tailIndent = NSParagraphStyle.default.tailIndent
        style.firstLineHeadIndent = NSParagraphStyle.default.firstLineHeadIndent
        defaultParagraphStyle = style
        
        // Set up typing attributes with Inter-Regular font
        typingAttributes = [
            .font: NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15),
            .paragraphStyle: style,
            .foregroundColor: NSColor.textColor
        ]
        
        // Set up formatting toolbar
        setupFormattingToolbar()
        
        // Set up keyboard shortcuts
        setupKeyboardShortcuts()
        
        // Add selection change observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: self
        )
        
        // Add text change observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: self
        )
        
        print("✅ DocumentTextView setup complete")
    }
    
    private func setupFormattingToolbar() {
        let toolbar = NSHostingView(rootView: TextFormattingToolbar(
            onBold: { [weak self] in
                self?.toggleBold()
            },
            onItalic: { [weak self] in
                self?.toggleItalic()
            },
            onUnderline: { [weak self] in
                self?.toggleUnderline()
            },
            onLink: { [weak self] in
                self?.insertLink()
            },
            onTextColor: { [weak self] color in
                self?.applyTextColor(color)
            },
            onHighlight: { [weak self] color in
                self?.applyHighlight(color)
            },
            onBulletList: { [weak self] in
                self?.toggleBulletList()
            },
            onTextStyleSelect: { [weak self] styleName in
                // TODO: Implement style application logic
                print("Style selected in CustomTextEditor: \(styleName)")
                self?.applyTextStyle(styleName) // Call the new placeholder method
            },
            onAlignment: { [weak self] alignment in
                self?.applyAlignment(alignment)
            },
            onBookmark: {},
            isBookmarked: false
        ).environment(\.colorScheme, .dark))
        
        toolbar.wantsLayer = true
        toolbar.layer?.masksToBounds = true
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 40),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel for proper visibility
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.fullScreenAuxiliary]
        
        // Set the content view
        panel.contentView = toolbar
        formattingToolbarPanel = panel
        
        print("📝 Formatting toolbar setup complete")
    }
    
    private func showFormattingToolbar() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let layoutManager = layoutManager,
              let window = self.window,
              let panel = formattingToolbarPanel else {
            print("❌ Could not show formatting toolbar - missing components")
            return
        }
        
        // Calculate position above selection
        let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer!)
        
        // Convert the bounding rect to window coordinates
        let localPoint = NSPoint(
            x: boundingRect.midX + textContainerOrigin.x,
            y: boundingRect.minY + textContainerOrigin.y
        )
        let windowPoint = convert(localPoint, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        
        // Position panel above the selection with proper spacing
        let spacing: CGFloat = 8
        let panelX = screenPoint.x - (panel.frame.width / 2)
        let panelY = screenPoint.y + spacing + 30 // Add extra offset to ensure visibility
        
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        
        if !panel.isVisible {
            window.addChildWindow(panel, ordered: .above)
            print("✅ Showing formatting toolbar")
        }
    }
    
    private func hideFormattingToolbar() {
        if let panel = formattingToolbarPanel {
            if let parent = panel.parent {
                parent.removeChildWindow(panel)
            }
            panel.orderOut(nil)
            print("🔽 Hiding formatting toolbar")
        }
    }
    
    @objc private func selectionDidChange(_ notification: Notification) {
        let hasSelection = selectedRange().length > 0
        if hasSelection {
            showFormattingToolbar()
        } else {
            hideFormattingToolbar()
        }
        onSelectionChange?(hasSelection)
    }
    
    // MARK: - Text Formatting Methods
    
    func toggleBold() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selectedRange) { fontAttribute, subrange, _ in
            if let currentFont = fontAttribute as? NSFont {
                let traits = NSFontManager.shared.traits(of: currentFont)
                let isBold = traits.contains(.boldFontMask)
                
                let newFont = if isBold {
                    NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
                } else {
                    NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                }
                textStorage.addAttribute(.font, value: newFont, range: subrange)
            }
        }
        textStorage.endEditing()
        needsDisplay = true
    }
    
    func toggleItalic() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selectedRange) { fontAttribute, subrange, _ in
            if let currentFont = fontAttribute as? NSFont {
                let traits = NSFontManager.shared.traits(of: currentFont)
                let isItalic = traits.contains(.italicFontMask)
                
                let newFont = if isItalic {
                    NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask)
                } else {
                    NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                }
                textStorage.addAttribute(.font, value: newFont, range: subrange)
            }
        }
        textStorage.endEditing()
        needsDisplay = true
    }
    
    func toggleUnderline() {
        guard let selectedRange = selectedRanges.first as? NSRange,
              let textStorage = textStorage else { return }
        
        let currentAttributes = textStorage.attributes(at: selectedRange.location, effectiveRange: nil)
        let isUnderlined = currentAttributes[.underlineStyle] as? Int == NSUnderlineStyle.single.rawValue
        
        textStorage.beginEditing()
        if isUnderlined {
            textStorage.removeAttribute(.underlineStyle, range: selectedRange)
        } else {
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
        }
        textStorage.endEditing()
        needsDisplay = true
    }
    
    func toggleBulletList() {
        // TODO: Implement bullet list
        print("Bullet list toggled")
    }
    
    func insertLink() {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        let panel = NSAlert()
        panel.messageText = "Insert Link"
        panel.informativeText = "Enter the URL:"
        panel.addButton(withTitle: "OK")
        panel.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        panel.accessoryView = textField
        
        if panel.runModal() == .alertFirstButtonReturn {
            var urlString = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Don't proceed if the URL is empty
            guard !urlString.isEmpty else { return }
            
            // Add "https://" if the URL doesn't already have a scheme
            if !urlString.contains("://") {
                // If it starts with "www." or has a domain suffix like ".com", ".org", etc.
                // we'll assume it's a web URL and add https://
                urlString = "https://" + urlString
            }
            
            if let url = URL(string: urlString) {
                textStorage.beginEditing()
                textStorage.addAttribute(.link, value: url, range: range)
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                textStorage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
                textStorage.endEditing()
                needsDisplay = true
            }
        }
    }
    
    @objc private func scrollViewDidScroll(_ notification: Notification) {
        if let scrollView = enclosingScrollView {
            updateScrollPosition(scrollView)
        }
    }
    
    private func updateScrollPosition(_ scrollView: NSScrollView) {
        guard let onScroll = self.onScroll else { return }
        
        let visibleRect = scrollView.contentView.bounds
        let documentRect = scrollView.documentView?.frame ?? .zero
        
        onScroll(
            visibleRect.origin.y,
            documentRect.height,
            visibleRect.height
        )
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if window?.firstResponder != self {
            window?.makeFirstResponder(self)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove existing tracking areas
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        
        // Add new tracking area for the entire text view
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, 
                                        options: options,
                                        owner: self, 
                                        userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    private func setupKeyboardShortcuts() {
        // Remove any existing monitor
        if let existingMonitor = keyboardMonitor {
            NSEvent.removeMonitor(existingMonitor)
        }
        
        // Add new keyboard monitor
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
                case "u":
                    self.toggleUnderline()
                    return nil
                case "k":
                    self.insertLink()
                    return nil
                case "l":
                    self.toggleBulletList()
                    return nil
                default:
                    break
                }
            }
            return event
        }
        
        // Add scroll observation
        if let scrollView = enclosingScrollView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }
    }
    
    func applyTextColor(_ color: Color) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        textStorage.beginEditing()
        let nsColor = NSColor(color)
        textStorage.addAttribute(.foregroundColor, value: nsColor, range: range)
        textStorage.endEditing()
        needsDisplay = true
    }
    
    func applyHighlight(_ color: Color) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        textStorage.beginEditing()
        if color == .clear {
            // Remove highlight
            textStorage.removeAttribute(.backgroundColor, range: range)
        } else {
            // Apply highlight with 30% opacity
            let nsColor = NSColor(color).withAlphaComponent(0.3)
            textStorage.addAttribute(.backgroundColor, value: nsColor, range: range)
        }
        textStorage.endEditing()
        needsDisplay = true
    }
    
    func applyTextStyle(_ styleName: String) {
        guard let textStorage = self.textStorage else { return }
        let selectedRange = self.selectedRange()
        
        // Store current scroll position
        let savedVisibleRect = visibleRect
        
        var attributes: [NSAttributedString.Key: Any] = [:]
        let baseFontSize: CGFloat = 15 // Define base font size
        let defaultFont = NSFont(name: "Inter-Regular", size: baseFontSize) ?? NSFont.systemFont(ofSize: baseFontSize)
        
        // Special style behaviors
        var applyToParagraph = false
        var needsNewLine = false 
        var isBlockStyle = false
        
        // Determine attributes based on style name
        switch styleName {
        case "Title":
            attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: baseFontSize * 2.2, weight: .regular) // Non-bold, 2.2x size
            let paragraphStyle = NSMutableParagraphStyle()
            // Add more spacing before and after titles
            paragraphStyle.paragraphSpacingBefore = baseFontSize * 1.2
            paragraphStyle.paragraphSpacing = baseFontSize * 1.0
            // Adjust line height to create appropriate visual spacing
            paragraphStyle.lineHeightMultiple = 1.2
            paragraphStyle.minimumLineHeight = baseFontSize * 2.5
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            needsNewLine = true
            isBlockStyle = true
            
        case "Heading":
            attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: baseFontSize * 1.7, weight: .semibold) // 1.7x size
            let paragraphStyle = NSMutableParagraphStyle()
            // Add proper spacing around headings
            paragraphStyle.paragraphSpacingBefore = baseFontSize * 1.0
            paragraphStyle.paragraphSpacing = baseFontSize * 0.8
            paragraphStyle.lineHeightMultiple = 1.1
            paragraphStyle.minimumLineHeight = baseFontSize * 2.0
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            needsNewLine = true
            isBlockStyle = true
            
        case "Strong":
            // Now using medium weight at 1.13x size instead of bold trait
            attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: baseFontSize * 1.13, weight: .medium)
            // Strong remains inline - does not apply to paragraph
            
        case "Body":
            attributes[NSAttributedString.Key.font] = defaultFont
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacingBefore = baseFontSize * 0.2
            paragraphStyle.paragraphSpacing = baseFontSize * 0.2
            paragraphStyle.lineHeightMultiple = 1.0
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            applyToParagraph = true // Body *should* apply to the entire paragraph
            
        case "Caption":
            attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: baseFontSize * 0.87, weight: .regular)
            // No color changes to respect user's color choices
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacingBefore = baseFontSize * 0.8
            paragraphStyle.paragraphSpacing = baseFontSize * 0.6
            paragraphStyle.lineHeightMultiple = 1.15
            paragraphStyle.minimumLineHeight = baseFontSize * 1.2
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            applyToParagraph = true // Apply to the entire paragraph
            needsNewLine = false // Keep the paragraph intact
            isBlockStyle = false // Don't treat as a block style
            
        default:
            attributes[NSAttributedString.Key.font] = defaultFont
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 1.0
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
            applyToParagraph = true // Ensure default also applies paragraph-wide
        }
        
        // Begin editing
            textStorage.beginEditing()
        
        var finalRange = selectedRange
        var finalSelectionRange = selectedRange
        
        // Get text before and after selection
        let nsString = string as NSString
        _ = nsString.substring(with: selectedRange)
        
        // Check if we should create a new line
        if needsNewLine && selectedRange.length > 0 {
            // Get the paragraph range containing the selection
            let currentParagraphRange = nsString.paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
            
            // Check if selection is already its own paragraph
            let selectedTextIsFullParagraph = (currentParagraphRange.location == selectedRange.location && 
                                             currentParagraphRange.length == selectedRange.length)
            
            // If the selected text is not already its own paragraph, or if it already has a style we're changing
            let needsToAddLines = !selectedTextIsFullParagraph
            
            // Check if this text already has a block style that we're changing (to avoid duplicate linebreaks)
            if !needsToAddLines && isBlockStyle {
                // We'll reuse the existing paragraph structure but apply new style
                // No need to add additional lines
                finalRange = currentParagraphRange
            } else if needsToAddLines {
                // Create a mutable attributed string with the current text
                let mutableString = NSMutableAttributedString(attributedString: textStorage)
                var insertedChars = 0
                
                // ALWAYS insert a newline before the selection for Title/Heading
                // unless it's already at the very beginning of the document
                if selectedRange.location > 0 {
                    // Check if there's already a newline before
                    let hasNewlineBefore = selectedRange.location > 0 && 
                        nsString.substring(with: NSRange(location: selectedRange.location - 1, length: 1)) == "\n"
                    
                    // Only add if needed
                    if !hasNewlineBefore {
                        let newline = NSAttributedString(string: "\n", attributes: getBodyStyleAttributes())
                        mutableString.insert(newline, at: selectedRange.location)
                        insertedChars += 1
                    }
                }
                
                // Update the affected range after inserting the first newline
                finalRange = NSRange(location: selectedRange.location + insertedChars, 
                                   length: selectedRange.length)
                
                // ALWAYS insert a newline after the selection for Title/Heading
                // unless it's already at the very end of the document
                if finalRange.location + finalRange.length < nsString.length {
                    // Check if there's already a newline after
                    let checkLocation = finalRange.location + finalRange.length
                    let hasNewlineAfter = checkLocation < nsString.length && 
                        nsString.substring(with: NSRange(location: checkLocation, length: 1)) == "\n"
                    
                    // Only add if needed
                    if !hasNewlineAfter {
                        let newline = NSAttributedString(string: "\n", attributes: getBodyStyleAttributes())
                        mutableString.insert(newline, at: finalRange.location + finalRange.length)
                    }
                }
                
                // Apply all changes to the text storage
                textStorage.setAttributedString(mutableString)
                
                // Position cursor at the end of the styled text
                finalSelectionRange = NSRange(location: finalRange.location + finalRange.length, length: 0)
            }
        } else if applyToParagraph {
            // For paragraph styles, get the paragraph range
            finalRange = getParagraphRange(for: selectedRange.location)
        }
        
        // Apply the style attributes
        if !attributes.isEmpty {
            // Preserve existing colors within the range
            textStorage.enumerateAttribute(NSAttributedString.Key.foregroundColor, in: finalRange, options: []) { (value, range, stop) in
                if let color = value as? NSColor {
                    // Preserve the existing color for this subrange
                    var subAttributes = attributes
                    subAttributes[NSAttributedString.Key.foregroundColor] = color
                    
                    // Apply attributes with preserved color
                    for (key, value) in subAttributes {
                        textStorage.addAttribute(key, value: value, range: range)
                    }
                } else {
                    // No color set, just apply the attributes without modifying color
                    for (key, value) in attributes {
                        if key != NSAttributedString.Key.foregroundColor {
                            textStorage.addAttribute(key, value: value, range: range)
                        }
                    }
                }
            }
        }
        
            textStorage.endEditing()
        
        // Set final selection
        setSelectedRange(finalSelectionRange)
        
        // Restore scroll position and ensure cursor is visible
        scrollToVisible(savedVisibleRect)
        scrollRangeToVisible(selectedRange)
        
        // Ensure layout and display update
        layoutManager?.ensureLayout(for: textContainer!)
            needsDisplay = true
        
        // Trigger text change notification to update binding and save
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: self)
    }
    
    // Helper method to get the range of the entire paragraph containing a location
    private func getParagraphRange(for location: Int) -> NSRange {
        let nsString = self.string as NSString
        
        // Find the paragraph range
        return nsString.paragraphRange(for: NSRange(location: location, length: 0))
    }
    
    // Helper method to check if a location is at the start of a paragraph
    private func isAtStartOfParagraph(_ location: Int) -> Bool {
        if location == 0 {
            return true // Beginning of document is always start of paragraph
        }
        
        // Check if previous character is a newline
        let previousLocation = location - 1
        let nsString = self.string as NSString
        if previousLocation >= 0 && previousLocation < nsString.length {
            let previousChar = nsString.substring(with: NSRange(location: previousLocation, length: 1))
            return previousChar == "\n"
        }
        
        return false
    }
    
    func applyAlignment(_ alignment: TextAlignment) {
        let range = selectedRange()
        guard range.length > 0,
              let textStorage = textStorage else { return }
        
        let nsString = string as NSString
        
        // Create the paragraph style with the desired alignment
        let paragraphStyle = NSMutableParagraphStyle()
        switch alignment {
        case .leading:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .trailing:
            paragraphStyle.alignment = .right
        }
        
        // Apply alignment to all paragraphs in the selection range
        textStorage.beginEditing()
        
        var location = range.location
        while location < range.location + range.length {
            // Get the paragraph range containing this location
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            
            // Apply the style to this paragraph
            textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
            
            // Move to the next paragraph
            location = paragraphRange.location + paragraphRange.length
            
            // Safety check to avoid infinite loops if something goes wrong
            if paragraphRange.length == 0 {
                break
            }
        }
        
        textStorage.endEditing()
        needsDisplay = true
    }
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity = .downstream, stillSelecting: Bool = false) {
        // For empty text, always make sure cursor is at position 0
        if string.isEmpty {
            // When empty, always force cursor to position 0
            super.setSelectedRange(NSRange(location: 0, length: 0), affinity: affinity, stillSelecting: stillSelecting)
            needsDisplay = true
        } else {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        }
        
        let hasSelection = charRange.length > 0
        if hasSelection {
            showFormattingToolbar()
            } else {
            hideFormattingToolbar()
        }
        onSelectionChange?(hasSelection)
    }
    
    // Add new method to handle text changes
    @objc private func textDidChange(_ notification: Notification) {
        // Clear text attributes and reset cursor when content is empty
        if string.isEmpty {
            resetTextAttributesWhenEmpty()
        }
        
        // Call custom text change handler if provided
        onTextChange?()
    }
    
    // New method to reset text attributes when content is empty
    private func resetTextAttributesWhenEmpty() {
        guard string.isEmpty, let textStorage = textStorage else { return }
        
        // Begin editing session
        textStorage.beginEditing()
        
        // Clear any existing attributes
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.foregroundColor, range: fullRange)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        textStorage.removeAttribute(.underlineStyle, range: fullRange)
        textStorage.removeAttribute(.strikethroughStyle, range: fullRange)
        textStorage.removeAttribute(.link, range: fullRange)
        
        // Reset paragraph style to default
        let defaultStyle = NSMutableParagraphStyle()
        defaultStyle.defaultTabInterval = NSParagraphStyle.default.defaultTabInterval
        defaultStyle.lineSpacing = NSParagraphStyle.default.lineSpacing
        defaultStyle.paragraphSpacing = NSParagraphStyle.default.paragraphSpacing
        defaultStyle.headIndent = NSParagraphStyle.default.headIndent
        defaultStyle.tailIndent = NSParagraphStyle.default.tailIndent
        defaultStyle.firstLineHeadIndent = NSParagraphStyle.default.firstLineHeadIndent
        defaultStyle.alignment = .natural
        textStorage.addAttribute(.paragraphStyle, value: defaultStyle, range: fullRange)
        
        // Reset font to default
        let defaultFont = NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
        textStorage.addAttribute(.font, value: defaultFont, range: fullRange)
        
        // End editing session
        textStorage.endEditing()
        
        // Force cursor to beginning of text with explicit positioning
        setSelectedRange(NSRange(location: 0, length: 0))
        
        // Force redraw
        needsDisplay = true
        
        // Mark the layout for display - safely unwrapping each optional
        if let layoutManager = self.layoutManager, let textStorage = layoutManager.textStorage {
            textStorage.edited([.editedAttributes, .editedCharacters], range: NSRange(location: 0, length: 1), changeInLength: 0)
        }
    }
    
    // Override insertion point drawing to adjust position when text is empty
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        if string.isEmpty {
            // Create a completely new rect to draw the insertion point at the exact position we want
            let defaultFont = NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
            let cursorHeight = defaultFont.boundingRectForFont.height
            
            // Define exact position with no room for interpretation by the layout system
            let exactRect = NSRect(
                x: 19, // Hard-coded exact position - independent of textContainerInset
                y: textContainerInset.height,
                width: 1.0, // Standard cursor width
                height: cursorHeight
            )
            
            // For debug purposes, draw a visual indicator of the cursor position
            if UserDefaults.standard.bool(forKey: "com.letterspace.enableDebugBorders") {
                // Draw a small red dot at cursor position
                let dotSize: CGFloat = 4.0
                let dotRect = NSRect(
                    x: exactRect.minX - dotSize/2,
                    y: exactRect.minY - dotSize - 2,
                    width: dotSize,
                    height: dotSize
                )
                NSColor.red.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
                
                // Draw position label
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: NSColor.white,
                    .backgroundColor: NSColor.black.withAlphaComponent(0.7)
                ]
                let posLabel = NSAttributedString(string: "x:19", attributes: attrs)
                posLabel.draw(at: NSPoint(x: exactRect.minX - 12, y: exactRect.minY - 16))
            }
            
            // Draw the cursor ourselves
            super.drawInsertionPoint(in: exactRect, color: color, turnedOn: flag)
        } else {
            // Add debug indicator for non-empty text cursors too
            if UserDefaults.standard.bool(forKey: "com.letterspace.enableDebugBorders") {
                let dotSize: CGFloat = 4.0
                let dotRect = NSRect(
                    x: rect.minX - dotSize/2,
                    y: rect.minY - dotSize - 2,
                    width: dotSize,
                    height: dotSize
                )
                NSColor.orange.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
                
                // Draw position label
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: NSColor.white,
                    .backgroundColor: NSColor.black.withAlphaComponent(0.7)
                ]
                let posLabel = NSAttributedString(string: "x:\(Int(rect.minX))", attributes: attrs)
                posLabel.draw(at: NSPoint(x: rect.minX - 12, y: rect.minY - 16))
            }
            
            super.drawInsertionPoint(in: rect, color: color, turnedOn: flag)
        }
    }
    
    // Override selection drawing to ensure cursor position is correct when text is empty
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        
        // Force cursor positioning when text is empty
        if string.isEmpty {
            setSelectedRange(NSRange(location: 0, length: 0))
        }
    }
    
    // Completely override the text container setup
    private func ensureProperTextContainer() {
        // Ensure text container inset is exactly 19
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        
        // Set line fragment padding to exactly 0
        textContainer?.lineFragmentPadding = 0
        
        // Reset paragraph style explicitly
        resetParagraphIndentation()
        
        // Update layout
        layoutManager?.ensureLayout(for: textContainer!)
    }
    
    // Add a custom method to completely reset the text container and layout
    private func completeTextReset() {
        guard string.isEmpty else { return }
        
        // Reset text attributes
        resetTextAttributesWhenEmpty()
        
        // Ensure proper text container settings
        ensureProperTextContainer()
        
        // Reset paragraph indentation explicitly
        resetParagraphIndentation()
        
        // Force cursor to beginning with explicit positioning
        setSelectedRange(NSRange(location: 0, length: 0))
        
        // Force complete redisplay
        needsDisplay = true
    }
    
    // Override text did change notification handling
    override func didChangeText() {
        super.didChangeText()
        
        // Notify delegate of text changes
        if let coordinator = self.delegate as? CustomTextView.Coordinator {
            coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
        }

        // Force redraw for highlights
        needsDisplay = true
        displayIfNeeded()
    }
    
    // Override key handling to fix indentation on line breaks
    override func keyDown(with event: NSEvent) {
        let isBackspace = event.keyCode == 51 || event.keyCode == 117 // Backspace or Delete
        _ = event.keyCode == 36 // Return key
        let wasEmpty = string.isEmpty
        
        // --> Remove Return key handling from here <--
        /*
        if isReturn {
            // ... existing logic removed ...
            return
        }
        */
        
        super.keyDown(with: event)
        
        // Check if text became empty after backspace/delete
        if isBackspace && !wasEmpty && string.isEmpty {
            // Force immediate reset when emptied by deletion
            completeTextReset()
            
            // Specifically force the cursor position with a slight delay to ensure it takes effect
            DispatchQueue.main.async {
                self.setSelectedRange(NSRange(location: 0, length: 0))
                self.resetParagraphIndentation()
                self.needsDisplay = true
            }
        }
    }
    
    override func insertNewline(_ sender: Any?) {
        // Store current selection range before newline
        let originalRange = selectedRange()
        
        // Let the superclass handle the actual newline insertion
        super.insertNewline(sender)
        
        // Get the range of the newly inserted paragraph
        let newRange = selectedRange()
        
        // Ensure we actually inserted a newline (cursor moved)
        if newRange.location > originalRange.location, let textStorage = self.textStorage {
            // Get the range of the paragraph containing the new cursor position
            let paragraphRange = (textStorage.string as NSString).paragraphRange(for: NSRange(location: newRange.location, length: 0))
            
            // Get the default Body style attributes
            let bodyAttributes = getBodyStyleAttributes()
            
            // Apply the Body style attributes synchronously to the new paragraph range
            textStorage.beginEditing()
            textStorage.setAttributes(bodyAttributes, range: paragraphRange)
            textStorage.endEditing()
            
            // Ensure the typing attributes are also reset to Body style
            self.typingAttributes = bodyAttributes
        }

        // ---> MODIFY THIS <--- Delay the scroll to ensure layout is complete
        DispatchQueue.main.async {
            self.scrollRangeToVisible(self.selectedRange())
        }
    }
    
    // Helper to get Body style attributes
    func getBodyStyleAttributes() -> [NSAttributedString.Key: Any] {
        let baseFontSize: CGFloat = 15
        let defaultFont = NSFont(name: "Inter-Regular", size: baseFontSize) ?? NSFont.systemFont(ofSize: baseFontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = baseFontSize * 0.2
        paragraphStyle.paragraphSpacing = baseFontSize * 0.2
        paragraphStyle.lineHeightMultiple = 1.0
        // Ensure default alignment and indentation
        paragraphStyle.alignment = .natural
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.headIndent = 0
        
        // Preserve current text color if possible, otherwise use default
        var attributes: [NSAttributedString.Key: Any] = [
            .font: defaultFont,
            .paragraphStyle: paragraphStyle,
            .kern: -0.1 // Add kerning for letter spacing
        ]
        if let currentColor = self.typingAttributes[.foregroundColor] as? NSColor {
            attributes[.foregroundColor] = currentColor
        } else {
            attributes[.foregroundColor] = NSColor.labelColor // Default text color
        }
        
        return attributes
    }
    
    // Add a direct override of NSResponder's mouseDown to ensure proper cursor position on click
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        // If text is empty, ensure cursor position is correct
        if string.isEmpty {
            setSelectedRange(NSRange(location: 0, length: 0))
            needsDisplay = true
        }
    }
    
    // Add a method to reset paragraph indentation consistently
    func resetParagraphIndentation() {
        // Create a clean paragraph style with zero indentation
        let cleanStyle = NSMutableParagraphStyle()
        cleanStyle.firstLineHeadIndent = 0
        cleanStyle.headIndent = 0
        cleanStyle.tailIndent = 0
        
        // Preserve other paragraph style attributes from default style
        cleanStyle.lineSpacing = NSParagraphStyle.default.lineSpacing
        cleanStyle.paragraphSpacing = NSParagraphStyle.default.paragraphSpacing
        cleanStyle.defaultTabInterval = NSParagraphStyle.default.defaultTabInterval
        cleanStyle.alignment = .natural
        
        // Apply to entire text or to typing attributes if empty
        if string.isEmpty {
            typingAttributes[.paragraphStyle] = cleanStyle
        } else {
            // Only reset if we have text storage
            if let textStorage = self.textStorage {
                textStorage.beginEditing()
                textStorage.addAttribute(.paragraphStyle, value: cleanStyle, 
                                range: NSRange(location: 0, length: string.count))
                textStorage.endEditing()
            }
        }
        
        // Force text container inset to exact value
        textContainerInset = NSSize(width: 19, height: textContainerInset.height)
        if let container = textContainer {
            container.lineFragmentPadding = 0
        }
        
        // Force layout refresh
        layoutManager?.ensureLayout(for: textContainer!)
        needsDisplay = true
    }
    
    // MARK: - Paste Handling
    
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        
        // Check if the pasteboard has RTF or attributed string content
        if let attributedString = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)?.first as? NSAttributedString {
            // Get the document's base attributes for text styling
            let baseAttributes = self.typingAttributes
            
            // Create a mutable copy to modify
            let mutableString = NSMutableAttributedString(attributedString: attributedString)
            let range = NSRange(location: 0, length: mutableString.length)
            
            // Apply base paragraph style to ensure consistent layout
            if let baseStyle = baseAttributes[.paragraphStyle] as? NSParagraphStyle {
                mutableString.addAttribute(.paragraphStyle, value: baseStyle, range: range)
            }
            
            // Apply document's font family and size while preserving weight variations
            if let baseFont = baseAttributes[.font] as? NSFont {
                // Go through each character to preserve bold/italic while using document's font
                mutableString.enumerateAttribute(.font, in: range, options: []) { (font, subrange, stop) in
                    if let originalFont = font as? NSFont {
                        // Get traits from original font (bold, italic)
                        let fontManager = NSFontManager.shared
                        let traits = fontManager.traits(of: originalFont)
                        
                        // Create a new font with document's font family but preserve weight
                        var newFont = baseFont
                        
                        // Apply bold if original had it
                        if traits.contains(.boldFontMask) {
                            newFont = fontManager.convert(newFont, toHaveTrait: .boldFontMask)
                        }
                        
                        // Apply italic if original had it
                        if traits.contains(.italicFontMask) {
                            newFont = fontManager.convert(newFont, toHaveTrait: .italicFontMask)
                        }
                        
                        mutableString.addAttribute(.font, value: newFont, range: subrange)
                    } else {
                        // If no font specified, use document's default font
                        mutableString.addAttribute(.font, value: baseFont, range: subrange)
                    }
                }
            }
            
            // Ensure text color matches the editor's theme
            if let baseColor = baseAttributes[.foregroundColor] as? NSColor {
                mutableString.addAttribute(.foregroundColor, value: baseColor, range: range)
            }
            
            // Insert the modified attributed string
            if shouldChangeText(in: selectedRange(), replacementString: mutableString.string) {
                insertText(mutableString, replacementRange: selectedRange())
                didChangeText()
            }
        } else if let plainText = pasteboard.string(forType: .string) {
            // For plain text, apply the document's default styling
            if shouldChangeText(in: selectedRange(), replacementString: plainText) {
                // Create an attributed string with the document's default attributes
                let styledText = NSAttributedString(string: plainText, attributes: typingAttributes)
                insertText(styledText, replacementRange: selectedRange())
                didChangeText()
            }
        } else {
            // Use default paste as last resort
            super.paste(sender)
        }
    }
}
#endif


