#if os(macOS)
import AppKit 
class TrackingTableView: NSTableView {
    var hoveredRow: Int = -1
    var onHover: ((Int) -> Void)?
    var isDarkMode: Bool = false
    var lastClickTime: Date = Date()
    var lastClickedRow: Int = -1
    var onSingleClick: ((Int) -> Void)?
    var onDoubleClick: ((Int) -> Void)?
    var onLongPress: ((Int) -> Void)?
    var longPressTimer: Timer?
    var coordinator: DocumentTable.Coordinator?
    var parent: DocumentTable?
    private var popoverMonitorTimer: Timer?
    private var lastPopoverCloseTime: Date = Date.distantPast
    
    // Track the row with the active popover
    private var activePopoverRow: Int = -1
    
    var isCalendarPopupOpen: Bool = false {
        didSet {
            if isCalendarPopupOpen {
                // When a calendar popover opens, store the currently hovered row
                // but don't clear it, so the row stays visible
                if hoveredRow != -1 {
                    activePopoverRow = hoveredRow
                }
                
                // Update the window's tracking methods to prevent interference
                if let containingWindow = self.window {
                    // Force the window to update its event tracking
                    containingWindow.makeFirstResponder(nil)
                    updateTrackingAreas()
                }
                
                // Stop monitoring when popover is showing
                stopPopoverMonitoring()
            } else {
                // When the popover closes, clear the active popover row
                activePopoverRow = -1
                
                // Start monitoring for mouse position near the popover area
                // This helps detect when cursor moved to popover and it was dismissed
                lastPopoverCloseTime = Date()
                startPopoverMonitoring()
            }
        }
    }
    var isDetailsPopupOpen: Bool = false
    
    // Scroll optimization properties
    private var isAnimatingScroll: Bool = false
    private var needsOptimizedRedraw: Bool = false
    private var lastScrollTime: Date = Date()
    private var scrollThrottleTimer: Timer?
    
    // Add missing properties for context menu actions
    var onPin: ((String) -> Void)?
    var onWIP: ((String) -> Void)?
    var onCalendar: ((String) -> Void)?
    var onCalendarAction: ((String) -> Void)?
    var onDelete: (([String]) -> Void)?
    var onDuplicate: ((String) -> Void)?
    var onDetails: ((String) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupScrollOptimizations()
        setupNotifications()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollOptimizations()
        setupNotifications()
    }
    
    private func setupScrollOptimizations() {
        // Set layer properties for smoother rendering
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        // Set row drawing optimization
        usesAutomaticRowHeights = false
    }
    
    private func setupNotifications() {
        // Register for frame change notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBoundsChange),
            name: NSView.frameDidChangeNotification,
            object: self.enclosingScrollView?.contentView
        )
        
        // Register for document scheduling updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(documentScheduleDidUpdate),
            name: NSNotification.Name("DocumentScheduledUpdate"),
            object: nil
        )
        
        // Register for document list updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(documentListDidUpdate),
            name: NSNotification.Name("DocumentListDidUpdate"),
            object: nil
        )
        
        // Register for calendar popover state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarPopoverOpened),
            name: NSNotification.Name("CalendarPopoverOpened"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarPopoverClosed),
            name: NSNotification.Name("CalendarPopoverClosed"),
            object: nil
        )
        
        // Register for details popover state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(detailsPopoverOpened),
            name: NSNotification.Name("DetailsPopoverOpened"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(detailsPopoverClosed),
            name: NSNotification.Name("DetailsPopoverClosed"),
            object: nil
        )
    }
    
    @objc private func documentScheduleDidUpdate(_ notification: Notification) {
        // Refresh the table view to show updated calendar status
        DispatchQueue.main.async {
            self.reloadData()
        }
    }
    
    @objc private func documentListDidUpdate(_ notification: Notification) {
        // Refresh the table view for any document updates
        DispatchQueue.main.async {
            self.reloadData()
        }
    }
    
    @objc private func handleBoundsChange(_ notification: Notification) {
        // Don't process events too frequently
        if Date().timeIntervalSince(lastScrollTime) < 0.016 { // ~60fps
            invalidateScrollThrottleTimer()
            scrollThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: false) { [weak self] _ in
                self?.lastScrollTime = Date()
                self?.optimizeScrollRedraw()
            }
            return
        }
        
        lastScrollTime = Date()
        optimizeScrollRedraw()
    }
    
    private func optimizeScrollRedraw() {
        // Only redraw visible rows
        needsDisplay = true
    }
    
    private func invalidateScrollThrottleTimer() {
        scrollThrottleTimer?.invalidate()
        scrollThrottleTimer = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        invalidateScrollThrottleTimer()
        stopPopoverMonitoring()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
            owner: self
        ))
    }
    
    override func mouseEntered(with event: NSEvent) {
        // Always process mouse entered events normally
        updateHoveredRow(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        // Always process mouse moved events normally
        updateHoveredRow(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        // Don't clear hover state if we have an active popover on the currently hovered row
        if (isCalendarPopupOpen || isDetailsPopupOpen) && hoveredRow == activePopoverRow {
            return
        }
        
        // Otherwise, always clear hover state when mouse exits
        clearHoverState()
    }
    
    private func clearHoverState() {
        if hoveredRow != -1 {
            let oldRow = hoveredRow
            hoveredRow = -1
            onHover?(-1)
            reloadData(forRowIndexes: IndexSet(integer: oldRow), columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
        }
    }
    
    private func updateHoveredRow(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newRow = row(at: point)
        
        // Ignore rows that are out of bounds
        if newRow < 0 || newRow >= numberOfRows {
            // Clear hover state if we're not over a valid row
            if hoveredRow != -1 && (hoveredRow != activePopoverRow || (!isCalendarPopupOpen && !isDetailsPopupOpen)) {
                clearHoverState()
            }
            return
        }
        
        // Special case: if there's an active popover (calendar or details)
        if isCalendarPopupOpen || isDetailsPopupOpen {
            // A popover is open
            
            // If there's an active popover on a specific row
            if activePopoverRow != -1 {
                // If hovering over a different row than the active popover row
                if newRow != activePopoverRow {
                    // 1. Mouse is over a regular row, not the popover row
                    if newRow != hoveredRow {
                        // Update hover state for the new row
                        let oldRow = hoveredRow
                        hoveredRow = newRow
                        onHover?(newRow)
                        
                        // Only reload the old row if it wasn't the active popover row
                        if oldRow >= 0 && oldRow != activePopoverRow {
                            reloadData(forRowIndexes: IndexSet(integer: oldRow), 
                                     columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
                        }
                        
                        // Always reload the new row
                        reloadData(forRowIndexes: IndexSet(integer: newRow), 
                                  columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
                    }
                } else if newRow == activePopoverRow && newRow != hoveredRow {
                    // 2. Mouse is over the popover row but hover state needs updating
                    let oldRow = hoveredRow
                    hoveredRow = newRow
                    onHover?(newRow)
                    
                    if oldRow >= 0 && oldRow != activePopoverRow {
                        reloadData(forRowIndexes: IndexSet(integer: oldRow), 
                                  columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
                    }
                    
                    reloadData(forRowIndexes: IndexSet(integer: newRow), 
                              columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
                }
            } else {
                // No active popover row but popover is open (unusual case)
                // Use normal hover behavior
                updateNormalHoverState(newRow)
            }
        } else {
            // Normal case - no popovers are open
            updateNormalHoverState(newRow)
        }
    }
    
    private func updateNormalHoverState(_ newRow: Int) {
        if newRow != hoveredRow && newRow < numberOfRows {
            let oldRow = hoveredRow
            hoveredRow = newRow
            onHover?(newRow)
            
            if oldRow >= 0 {
                reloadData(forRowIndexes: IndexSet(integer: oldRow), 
                          columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
            }
            
            reloadData(forRowIndexes: IndexSet(integer: newRow), 
                      columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        
        // Handle Control + Click (same as right-click)
        if event.modifierFlags.contains(.control),
           clickedRow >= 0,
           let coordinator = delegate as? DocumentTable.Coordinator,
           clickedRow < coordinator.documents.count {
            let document = coordinator.documents[clickedRow]
            
            // Create context menu
            let menu = NSMenu()
            menu.items = [
                NSMenuItem(title: "Pin", action: #selector(handlePin(_:)), keyEquivalent: ""),
                NSMenuItem(title: "Mark as WIP", action: #selector(handleWIP(_:)), keyEquivalent: ""),
                NSMenuItem(title: "Schedule Presentation", action: #selector(handleCalendar(_:)), keyEquivalent: ""),
                NSMenuItem.separator(),
                NSMenuItem(title: "Create Variation", action: #selector(handleCreateVariation(_:)), keyEquivalent: ""),
                NSMenuItem(title: "Duplicate", action: #selector(handleDuplicate(_:)), keyEquivalent: ""),
                NSMenuItem.separator(),
                NSMenuItem(title: "Delete", action: #selector(handleDelete(_:)), keyEquivalent: "")
            ]
            
            // Set represented objects for menu items
            menu.items[0].representedObject = [document.id]
            menu.items[1].representedObject = [document.id]
            menu.items[2].representedObject = document.id
            menu.items[4].representedObject = document
            menu.items[5].representedObject = document
            menu.items[7].representedObject = [document.id]
            
            // Update menu item states based on current status
            menu.items[0].state = coordinator.pinnedDocuments.contains(document.id) ? .on : .off
            menu.items[1].state = coordinator.wipDocuments.contains(document.id) ? .on : .off
            menu.items[2].state = coordinator.calendarDocuments.contains(document.id) ? .on : .off
            
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
        
        // Handle double-click
        if event.clickCount == 2 {
            if clickedRow >= 0,
               let coordinator = delegate as? DocumentTable.Coordinator,
               clickedRow < coordinator.documents.count {
                let document = coordinator.documents[clickedRow]
                coordinator.handleDoubleClick(document)
                return
            }
        }
        
        // Handle single click with modifiers
        if clickedRow >= 0,
           let coordinator = delegate as? DocumentTable.Coordinator,
           clickedRow < coordinator.documents.count {
            let document = coordinator.documents[clickedRow]
            
            if event.modifierFlags.contains(.command) {
                // Command+Click: Toggle selection
                coordinator.handleCommandClick(document)
            } else if event.modifierFlags.contains(.shift) {
                // Shift+Click: Range selection
                coordinator.handleShiftClick(document)
            } else {
                // Normal click: Single selection
                coordinator.handleSingleClick(document)
            }
        }
        
        super.mouseDown(with: event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        
        if clickedRow >= 0,
           let coordinator = delegate as? DocumentTable.Coordinator,
           clickedRow < coordinator.documents.count {
            let document = coordinator.documents[clickedRow]
            
            // Create context menu
            let menu = NSMenu()
            menu.items = [
                NSMenuItem(title: "Pin", action: #selector(handlePin(_:)), keyEquivalent: ""),
                NSMenuItem(title: "Mark as WIP", action: #selector(handleWIP(_:)), keyEquivalent: ""),
                NSMenuItem(title: "Schedule Presentation", action: #selector(handleCalendar(_:)), keyEquivalent: ""),
                NSMenuItem.separator(),
                NSMenuItem(title: "Create Variation", action: #selector(handleCreateVariation(_:)), keyEquivalent: ""),
                NSMenuItem(title: "Duplicate", action: #selector(handleDuplicate(_:)), keyEquivalent: ""),
                NSMenuItem.separator(),
                NSMenuItem(title: "Delete", action: #selector(handleDelete(_:)), keyEquivalent: "")
            ]
            
            // Set represented objects for menu items
            menu.items[0].representedObject = [document.id]
            menu.items[1].representedObject = [document.id]
            menu.items[2].representedObject = document.id
            menu.items[4].representedObject = document
            menu.items[5].representedObject = document
            menu.items[7].representedObject = [document.id]
            
            // Update menu item states based on current status
            menu.items[0].state = coordinator.pinnedDocuments.contains(document.id) ? .on : .off
            menu.items[1].state = coordinator.wipDocuments.contains(document.id) ? .on : .off
            menu.items[2].state = coordinator.calendarDocuments.contains(document.id) ? .on : .off
            
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
        
        super.rightMouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        longPressTimer?.invalidate()
        super.mouseUp(with: event)
    }
    
    // Add the handler methods for context menu actions
    @objc private func handlePin(_ sender: NSMenuItem) {
        if let documentIds = sender.representedObject as? [String] {
            for docId in documentIds {
                onPin?(docId)
            }
        }
    }
    
    @objc private func handleWIP(_ sender: NSMenuItem) {
        if let documentIds = sender.representedObject as? [String] {
            for docId in documentIds {
                onWIP?(docId)
            }
        }
    }
    
    @objc private func handleCalendar(_ sender: NSMenuItem) {
        if let documentId = sender.representedObject as? String {
            onCalendarAction?(documentId)
        }
    }
    
    @objc private func handleDetails(_ sender: NSMenuItem) {
        if let document = sender.representedObject as? Letterspace_CanvasDocument {
            onDetails?(document.id)
        }
    }
    
    @objc private func handleDuplicate(_ sender: NSMenuItem) {
        if let document = sender.representedObject as? Letterspace_CanvasDocument {
            onDuplicate?(document.id)
        }
    }
    
    @objc private func handleDelete(_ sender: NSMenuItem) {
        print("handleDelete called")
        if let documentIds = sender.representedObject as? [String] {
            print("Document IDs to delete: \(documentIds)")
            onDelete?(documentIds)
        } else {
            print("No document IDs found in representedObject")
            if let obj = sender.representedObject {
                print("representedObject is of type: \(type(of: obj))")
            }
        }
    }
    
    // Add handler for Create Variation
    @objc private func handleCreateVariation(_ sender: NSMenuItem) {
        if let document = sender.representedObject as? Letterspace_CanvasDocument {
            // Check if the document has a valid header image
            let hasValidHeaderImage = document.elements.contains(where: {
                $0.type == .headerImage && !$0.content.isEmpty
            })
            
            // Create a new document as a variation
            var newDoc = Letterspace_CanvasDocument(
                title: document.title + " (Variation)",
                subtitle: document.subtitle,
                elements: document.elements,
                id: UUID().uuidString,
                markers: document.markers,
                series: document.series,
                variations: [
                    DocumentVariation(
                        id: UUID(),
                        name: "Original",
                        documentId: document.id,
                        parentDocumentId: document.id,
                        createdAt: Date(),
                        datePresented: document.variations.first?.datePresented,
                        location: document.variations.first?.location
                    )
                ],
                isVariation: true,
                parentVariationId: document.id,
                tags: document.tags,
                isHeaderExpanded: hasValidHeaderImage && document.isHeaderExpanded, // Only expand if original had valid header image
                isSubtitleVisible: document.isSubtitleVisible,
                links: document.links
            )
            
            // Save directly
            newDoc.save()
            
            // Post notifications to update the UI
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenDocument"),
                object: nil,
                userInfo: ["document": newDoc]
            )
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // If mouse is completely outside our bounds, don't bother with special handling
        if !bounds.contains(point) {
            return super.hitTest(point)
        }
        
        // If a calendar popover is open, handle special cases
        if isCalendarPopupOpen {
            // Get the row at the hit point
            let hitRow = row(at: point)
            
            // Special handling only needed in the popover area (right side)
            if let window = self.window {
                let mouseLocation = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                
                // Define the area where the popover appears
                let popoverWidth: CGFloat = 350
                let popoverRegion = NSRect(
                    x: self.bounds.width - popoverWidth,
                    y: 0,
                    width: popoverWidth,
                    height: self.bounds.height
                )
                
                // If mouse is in the popover region
                if popoverRegion.contains(mouseLocation) {
                    // Only allow interaction with the active popover row in the left portion
                    // (i.e., the button area, not the popover itself)
                    if hitRow == activePopoverRow && point.x < popoverRegion.minX {
                        return super.hitTest(point)
                    }
                    
                    // For all other points in the popover region, don't allow interaction
                    return nil
                }
            }
        }
        
        // For details popover, use a similar approach
        if isDetailsPopupOpen {
            if let window = self.window {
                let mouseLocation = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                let popoverWidth: CGFloat = 300
                
                // Define the details popover region
                let popoverRegion = NSRect(
                    x: self.bounds.width - popoverWidth,
                    y: 0,
                    width: popoverWidth,
                    height: self.bounds.height
                )
                
                // If mouse is in the popover region, don't allow interaction
                if popoverRegion.contains(mouseLocation) {
                    return nil
                }
            }
        }
        
        // Default behavior for all other cases
        return super.hitTest(point)
    }
    
    @objc private func calendarPopoverOpened(_ notification: Notification) {
        if let documentId = notification.userInfo?["documentId"] as? String,
           let coordinator = delegate as? DocumentTable.Coordinator {
            // Find the row containing this document ID
            for (index, document) in coordinator.documents.enumerated() {
                if document.id == documentId && index < numberOfRows {
                    // Set the active popover row
                    activePopoverRow = index
                    
                    // Make sure this row has the hover state
                    if hoveredRow != index {
                        let oldRow = hoveredRow
                        hoveredRow = index
                        onHover?(index)
                        
                        if oldRow >= 0 {
                            reloadData(forRowIndexes: IndexSet(integer: oldRow), 
                                      columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
                        }
                        reloadData(forRowIndexes: IndexSet(integer: index), 
                                  columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
                    }
                    break
                }
            }
        }
        
        // Keep this at the end
        isCalendarPopupOpen = true
    }
    
    @objc private func calendarPopoverClosed(_ notification: Notification) {
        // Capture the active popover row before resetting
        let previousActiveRow = activePopoverRow
        
        // Reset the popover state first
        isCalendarPopupOpen = false
        
        // Check if we need to reset the hover state
        DispatchQueue.main.async {
            // After closing the popover, check if the mouse is still over a valid row
            if let window = self.window {
                let mouseLocation = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                let rowAtMouse = self.row(at: mouseLocation)
                
                // Clear any lingering hover state from the popover row
                if previousActiveRow >= 0 && previousActiveRow < self.numberOfRows && previousActiveRow != rowAtMouse {
                    self.reloadData(forRowIndexes: IndexSet(integer: previousActiveRow), 
                                  columnIndexes: IndexSet(integersIn: 0..<self.numberOfColumns))
                }
                
                // Update the hover state to the row under the mouse (if any)
                if rowAtMouse >= 0 && rowAtMouse < self.numberOfRows {
                    // Update the hover state to the row under the mouse
                    self.hoveredRow = rowAtMouse
                    self.onHover?(rowAtMouse)
                    self.reloadData(forRowIndexes: IndexSet(integer: rowAtMouse), 
                                  columnIndexes: IndexSet(integersIn: 0..<self.numberOfColumns))
                } else {
                    // No row under the mouse, clear hover state completely
                    if self.hoveredRow != -1 {
                        let oldRow = self.hoveredRow
                        self.hoveredRow = -1
                        self.onHover?(-1)
                        self.reloadData(forRowIndexes: IndexSet(integer: oldRow), 
                                      columnIndexes: IndexSet(integersIn: 0..<self.numberOfColumns))
                    }
                }
            }
        }
    }
    
    @objc private func detailsPopoverOpened(_ notification: Notification) {
        if let documentId = notification.userInfo?["documentId"] as? String,
           let coordinator = delegate as? DocumentTable.Coordinator {
            // Find the row containing this document ID
            for (index, document) in coordinator.documents.enumerated() {
                if document.id == documentId && index < numberOfRows {
                    // Set the active popover row
                    activePopoverRow = index
                    
                    // Make sure this row has the hover state
                    if hoveredRow != index {
                        let oldRow = hoveredRow
                        hoveredRow = index
                        onHover?(index)
                        
                        if oldRow >= 0 {
                            reloadData(forRowIndexes: IndexSet(integer: oldRow), 
                                      columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
                        }
                        reloadData(forRowIndexes: IndexSet(integer: index), 
                                  columnIndexes: IndexSet(integersIn: 0..<numberOfColumns))
                    }
                    break
                }
            }
        }
        
        // Keep this at the end
        isDetailsPopupOpen = true
    }
    
    @objc private func detailsPopoverClosed(_ notification: Notification) {
        // Capture the active popover row before resetting
        let previousActiveRow = activePopoverRow
        
        // Reset the popover state first
        isDetailsPopupOpen = false
        
        // Check if we need to reset the hover state
        DispatchQueue.main.async {
            // After closing the popover, check if the mouse is still over a valid row
            if let window = self.window {
                let mouseLocation = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                let rowAtMouse = self.row(at: mouseLocation)
                
                // Clear any lingering hover state from the popover row
                if previousActiveRow >= 0 && previousActiveRow < self.numberOfRows && previousActiveRow != rowAtMouse {
                    self.reloadData(forRowIndexes: IndexSet(integer: previousActiveRow), 
                                  columnIndexes: IndexSet(integersIn: 0..<self.numberOfColumns))
                }
                
                // Update the hover state to the row under the mouse (if any)
                if rowAtMouse >= 0 && rowAtMouse < self.numberOfRows {
                    // Update the hover state to the row under the mouse
                    self.hoveredRow = rowAtMouse
                    self.onHover?(rowAtMouse)
                    self.reloadData(forRowIndexes: IndexSet(integer: rowAtMouse), 
                                  columnIndexes: IndexSet(integersIn: 0..<self.numberOfColumns))
                } else {
                    // No row under the mouse, clear hover state completely
                    if self.hoveredRow != -1 {
                        let oldRow = self.hoveredRow
                        self.hoveredRow = -1
                        self.onHover?(-1)
                        self.reloadData(forRowIndexes: IndexSet(integer: oldRow), 
                                      columnIndexes: IndexSet(integersIn: 0..<self.numberOfColumns))
                    }
                }
            }
        }
    }
    
    // Start monitoring for mouse position near the popover area
    private func startPopoverMonitoring() {
        stopPopoverMonitoring() // Clean up any existing timer
        
        // Only start monitoring if we recently closed a popover (within last 2 seconds)
        if Date().timeIntervalSince(lastPopoverCloseTime) < 2.0 {
            popoverMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.checkMousePositionNearPopover()
            }
        }
    }
    
    private func stopPopoverMonitoring() {
        popoverMonitorTimer?.invalidate()
        popoverMonitorTimer = nil
    }
    
    private func checkMousePositionNearPopover() {
        // Don't check if popover is already open
        if isCalendarPopupOpen { return }
        
        // Check if mouse is near the right edge of the view (where popovers typically appear)
        if let window = self.window {
            // Convert to view coordinates
            let mouseLocation = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            
            // If we're near the right edge of the view and the row is still in the view
            let edgeTolerance: CGFloat = 70 // Larger tolerance for triggering reopening
            if mouseLocation.x > (self.bounds.width - edgeTolerance) && 
               bounds.contains(mouseLocation) {
                // If we're within the time window for reopening and near the popover area,
                // post a notification to reopen the popover
                if Date().timeIntervalSince(lastPopoverCloseTime) < 1.0 {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ReopenCalendarPopover"),
                        object: nil
                    )
                    stopPopoverMonitoring() // Stop monitoring once we've reopened
                }
            }
        }
    }
}
#endif
