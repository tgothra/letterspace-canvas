import SwiftUI
import AppKit
import Letterspace_Canvas

struct CustomTextEditor: View {
    @Binding var text: NSAttributedString
    @Environment(\.colorScheme) var colorScheme
    var isFocused: Bool
    var onSelectionChange: (Bool) -> Void
    var showToolbar: Binding<Bool>
    var onAtCommand: ((NSPoint) -> Void)?
    var onScroll: ((CGFloat, CGFloat, CGFloat) -> Void)?
    var onShiftTab: (() -> Void)?
    
    var body: some View {
        CustomTextView(
            text: $text,
            colorScheme: colorScheme,
            isFocused: isFocused,
            onSelectionChange: onSelectionChange,
            showToolbar: showToolbar,
            onAtCommand: onAtCommand,
            onScroll: onScroll,
            onShiftTab: onShiftTab
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
    
    func makeNSView(context: Context) -> NSScrollView {
        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        // Create text container
        let container = NSTextContainer()
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        container.size = NSSize(width: scrollView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        
        let layoutManager = NSLayoutManager()
        let storage = NSTextStorage()
        
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        
        // Create text view
        let textView = EditorTextView(frame: .zero, textContainer: container)
        textView.backgroundColor = NSColor(white: 0, alpha: 0)
        textView.drawsBackground = false
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 16)
        textView.textContainerInset = NSSize(width: 24, height: 48)
        textView.delegate = context.coordinator
        textView.onAtCommand = onAtCommand
        
        // Configure text view for scrolling
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.textContainer?.containerSize = NSSize(width: scrollView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // Set up scroll view
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        
        // Add scroll observer
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }
        
        // Only update text if content actually changed and view is not focused
        if !isFocused && textView.attributedString() != text {
            let selectedRange = textView.selectedRange()
            let visibleRect = textView.visibleRect
            
            textView.textStorage?.setAttributedString(text)
            
            // Restore cursor position and scroll position
            textView.setSelectedRange(selectedRange)
            textView.scrollToVisible(visibleRect)
        }
        
        // Update the background color based on color scheme
        textView.backgroundColor = colorScheme == .dark ? NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) : NSColor.white
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
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextView
        
        init(_ parent: CustomTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let currentRange = textView.selectedRange()
            parent.text = textView.attributedString()
            textView.setSelectedRange(currentRange)
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let hasSelection = textView.selectedRange().length > 0
            parent.onSelectionChange(hasSelection)
        }
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            if let scrollView = (notification.object as? NSClipView)?.superview as? NSScrollView {
                updateScrollPosition(scrollView)
            }
        }
        
        func updateScrollPosition(_ scrollView: NSScrollView) {
            guard let onScroll = parent.onScroll else { return }
            
            let visibleRect = scrollView.contentView.bounds
            let documentRect = scrollView.documentView?.frame ?? .zero
            
            onScroll(
                visibleRect.origin.y,
                documentRect.height,
                visibleRect.height
            )
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
            titleLabel.textColor = .black
            shortcutLabel.textColor = NSColor.black.withAlphaComponent(0.3)
        } else {
            layer?.backgroundColor = nil
            iconView.contentTintColor = NSColor.black.withAlphaComponent(0.6)
            titleLabel.textColor = NSColor.black.withAlphaComponent(0.8)
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

class EditorTextView: NSTextView {
    var onAtCommand: ((NSPoint) -> Void)?
    var onSpaceKey: (() -> Void)?
    var onTextChange: (() -> Void)?
    var onShiftTab: (() -> Void)?
    private var commandPaletteHostingView: NSHostingView<CommandPalette>?
    @objc private var searchText: String = ""
    private var popoverPositioner: PopoverPositioner?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        // Dismiss menu when focus is lost
        if let popover = popoverPositioner, popover.isShown {
            popover.close()
        }
        return super.resignFirstResponder()
    }
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        textContainer?.widthTracksTextView = true
        
        // Create popover positioner
        popoverPositioner = PopoverPositioner()
        popoverPositioner?.customView?.onSelect = { [weak self] type in
            self?.insertBlock(type)
            self?.popoverPositioner?.close()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        let char = event.charactersIgnoringModifiers
        
        // Handle Shift+Tab to move focus back to title
        if event.keyCode == 48 && event.modifierFlags.contains(.shift) { // 48 is the key code for Tab
            // Only allow Shift+Tab if we're at the start of the text
            if selectedRange().location == 0 {
                onShiftTab?()
                return
            }
        }
        
        if char == "@" {
            super.keyDown(with: event)
            
            if let popover = popoverPositioner {
                let range = selectedRange()
                let glyphRange = layoutManager!.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                let rect = layoutManager!.boundingRect(forGlyphRange: glyphRange, in: textContainer!)
                
                // Position the menu below the @ symbol
                let point = NSPoint(
                    x: rect.minX + textContainerOrigin.x,
                    y: rect.minY + textContainerOrigin.y + 24  // Add offset to move down
                )
                
                // Show popover at cursor position
                let positioningRect = NSRect(x: point.x, y: point.y, width: 1, height: 1)
                popover.show(relativeTo: positioningRect, of: self, preferredEdge: .maxY)
                
                // Make this view the first responder to handle keyboard events
                window?.makeFirstResponder(self)
            }
        } else {
            // Dismiss menu on any other key press
            if let popover = popoverPositioner, popover.isShown {
                popover.close()
            }
            super.keyDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        // Dismiss menu on mouse click outside
        if let popover = popoverPositioner, popover.isShown {
            popover.close()
        }
        super.mouseDown(with: event)
    }
    
    private func insertBlock(_ type: ElementType) {
        print("Insert block of type: \(type)")
        commandPaletteHostingView?.removeFromSuperview()
        commandPaletteHostingView = nil
    }
}

class PopoverViewController: NSViewController {
    private var customView: CustomMenuView
    
    init(customView: CustomMenuView) {
        self.customView = customView
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = customView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Ensure the view is properly sized
        self.view.frame = customView.frame
    }
}

class PopoverPositioner: NSPopover {
    var customView: CustomMenuView?
    
    override init() {
        super.init()
        
        // Create and configure custom view
        let menuView = CustomMenuView(frame: .zero)  // Initialize with zero frame
        customView = menuView
        
        // Configure popover
        self.behavior = .transient
        self.animates = false
        self.contentViewController = PopoverViewController(customView: menuView)
        self.appearance = NSAppearance(named: .aqua)
        self.contentSize = menuView.frame.size
    }
    
    required override init?(coder: NSCoder) {
        super.init(coder: coder)
    }
} 
