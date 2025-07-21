#if os(macOS)
import SwiftUI
import AppKit 

// Custom header view that doesn't draw background but shows column titles
class ClearBackgroundHeaderView: NSTableHeaderView {
    override func draw(_ dirtyRect: NSRect) {
        // Clear the background but draw the column headers
        NSColor.clear.setFill()
        dirtyRect.fill()
        
        // Draw each column header manually
        guard let tableView = tableView else { return }
        
        for column in tableView.tableColumns {
            let headerCell = column.headerCell
            let columnIndex = tableView.tableColumns.firstIndex(of: column) ?? 0
            let headerRect = headerRect(ofColumn: columnIndex)
            
            if headerRect.intersects(dirtyRect) {
                headerCell.draw(withFrame: headerRect, in: self)
            }
        }
    }
    
    override var isOpaque: Bool {
        return false
    }
}

struct DocumentTable: NSViewRepresentable {
    // Add defaultColumnOrder at the top of DocumentTable
    private let defaultColumnOrder = ["status", "name", "series", "location", "date", "createdDate", "presentedDate"]
    
    // Add sorting state
    private var currentSortColumn: String = "name"
    private var isAscending: Bool = true
    
    @Binding var documents: [Letterspace_CanvasDocument]
    @Binding var selectedDocuments: Set<String>
    let isSelectionMode: Bool
    let pinnedDocuments: Set<String>
    let wipDocuments: Set<String>
    let calendarDocuments: Set<String>
    let visibleColumns: Set<String>
    let dateFilterType: DateFilterType
    let onPin: (String) -> Void
    let onWIP: (String) -> Void
    let onCalendar: (String) -> Void
    let onOpen: (Letterspace_CanvasDocument) -> Void
    let onShowDetails: (Letterspace_CanvasDocument) -> Void
    let onDelete: ([String]) -> Void
    let onCalendarAction: (Letterspace_CanvasDocument) -> Void
    let refreshID: UUID
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    @State private var activeTooltip: (text: String, position: CGPoint)?
    
    // Add helper function for status priority
    private func getStatusPriority(_ doc: Letterspace_CanvasDocument) -> Int {
        var priority = 0
        if pinnedDocuments.contains(doc.id) { priority += 4 }
        if wipDocuments.contains(doc.id) { priority += 2 }
        if calendarDocuments.contains(doc.id) { priority += 1 }
        return priority
    }
    
    init(documents: Binding<[Letterspace_CanvasDocument]>,
         selectedDocuments: Binding<Set<String>>,
         isSelectionMode: Bool,
         pinnedDocuments: Set<String>,
         wipDocuments: Set<String>,
         calendarDocuments: Set<String>,
         visibleColumns: Set<String>,
         dateFilterType: DateFilterType,
         onPin: @escaping (String) -> Void,
         onWIP: @escaping (String) -> Void,
         onCalendar: @escaping (String) -> Void,
         onOpen: @escaping (Letterspace_CanvasDocument) -> Void,
         onShowDetails: @escaping (Letterspace_CanvasDocument) -> Void,
         onDelete: @escaping ([String]) -> Void,
         onCalendarAction: @escaping (Letterspace_CanvasDocument) -> Void,
         refreshID: UUID) {
        self._documents = documents
        self._selectedDocuments = selectedDocuments
        self.isSelectionMode = isSelectionMode
        self.pinnedDocuments = pinnedDocuments
        self.wipDocuments = wipDocuments
        self.calendarDocuments = calendarDocuments
        self.visibleColumns = visibleColumns
        self.dateFilterType = dateFilterType
        self.onPin = onPin
        self.onWIP = onWIP
        self.onCalendar = onCalendar
        self.onOpen = onOpen
        self.onShowDetails = onShowDetails
        self.onDelete = onDelete
        self.onCalendarAction = onCalendarAction
        self.refreshID = refreshID
    }
    
    // Store reference to the table view
    fileprivate var tableView: NSTableView?
    
    private func deleteSelectedDocuments() {
        print("deleteSelectedDocuments called")
        let fileManager = FileManager.default
        // Use the same directory resolution as the rest of the app (iCloud-aware)
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("🗑️ ERROR: Could not determine app documents directory")
            return
        }
        let trashURL = appDirectory.appendingPathComponent(".trash", isDirectory: true)
        
        // Create trash directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: trashURL, withIntermediateDirectories: true, attributes: nil)
            print("Created or verified trash directory")
        } catch {
            print("Error creating trash directory: \(error)")
            return
        }
        
        print("Attempting to move \(selectedDocuments.count) documents to trash at: \(trashURL.path)")
        
        for docId in selectedDocuments {
            print("Processing document ID: \(docId)")
            if let document = documents.first(where: { $0.id == docId }) {
                let sourceURL = appDirectory.appendingPathComponent("\(document.id).canvas")
                let destinationURL = trashURL.appendingPathComponent("\(document.id).canvas")
                print("Moving document to trash: \(document.title) (\(document.id))")
                print("From: \(sourceURL.path)")
                print("To: \(destinationURL.path)")
                do {
                    // If destination file exists, remove it first
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                        print("Removed existing file at destination")
                    }
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                    // Set the modification date to track when it was moved to trash
                    try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: destinationURL.path)
                    print("Successfully moved document to trash")
                } catch {
                    print("Error moving document to trash: \(error)")
                }
            } else {
                print("Could not find document with ID: \(docId)")
            }
        }
        
        // Clear selection
        selectedDocuments.removeAll()
        
        // Post notification that documents have been updated
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        print("Posted DocumentListDidUpdate notification")
    }
    
    mutating func setTableView(_ view: NSTableView) {
        self.tableView = view
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let customTableView = TrackingTableView()
        customTableView.coordinator = context.coordinator
        customTableView.parent = self
        customTableView.isDarkMode = colorScheme == .dark
        
        // Enhanced scroll view configuration for smooth scrolling
        scrollView.scrollerStyle = .legacy // Changed to legacy for consistent width
        scrollView.horizontalScroller?.controlSize = .small
        scrollView.verticalScroller?.controlSize = .small
        scrollView.hasHorizontalScroller = false // Disable horizontal scrolling
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false // Always show scrollbar
        
        // Configure scroll behavior for smooth scrolling
        scrollView.scrollsDynamically = true
        
        // Set content insets to prevent content from going under the scrollbar
        // Set right inset to 44 points for comfortable spacing
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 44)
        
        // Customize scrolling physics for smoother experience
        if let verticalScroller = scrollView.verticalScroller {
            verticalScroller.alphaValue = 1.0 // Fully opaque
            verticalScroller.knobStyle = .light // Light style for gray appearance
            
            // Set custom appearance for consistent light gray color
            verticalScroller.appearance = NSAppearance(named: .aqua)
            
            // Improved acceleration values
            scrollView.verticalScrollElasticity = .automatic
        }
        
        // Configure table view
        customTableView.style = .plain
        customTableView.backgroundColor = .clear
        customTableView.allowsColumnReordering = false  // Prevent column reordering
        customTableView.intercellSpacing = NSSize(width: 0, height: 8)
        customTableView.delegate = context.coordinator
        customTableView.dataSource = context.coordinator
        customTableView.usesAlternatingRowBackgroundColors = false
        customTableView.enclosingScrollView?.backgroundColor = .clear
        customTableView.selectionHighlightStyle = .regular
        customTableView.rowHeight = 55  // Reduced to 55
        customTableView.wantsLayer = true
        customTableView.enclosingScrollView?.wantsLayer = true
        customTableView.headerView?.wantsLayer = true
        customTableView.headerView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Use standard header view for now to ensure headers are visible
        customTableView.headerView = NSTableHeaderView()
        
        // Set up context menu handlers
        customTableView.onPin = onPin
        customTableView.onWIP = onWIP
        customTableView.onCalendar = onCalendar
        customTableView.onCalendarAction = { documentId in
            if let document = context.coordinator.documents.first(where: { $0.id == documentId }) {
                onCalendarAction(document)
            }
        }
        customTableView.onDetails = { documentId in
            if let document = context.coordinator.documents.first(where: { $0.id == documentId }) {
                onShowDetails(document)
            }
        }
        customTableView.onDuplicate = { documentId in
            if let document = context.coordinator.documents.first(where: { $0.id == documentId }) {
                var newDoc = document
                newDoc.id = UUID().uuidString
                newDoc.title += " (Copy)"
                newDoc.createdAt = Date()
                newDoc.modifiedAt = Date()
                newDoc.save()
                NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
            }
        }
        customTableView.onDelete = { documentIds in
            print("onDelete callback called with document IDs: \(documentIds)")
            context.coordinator.selectedDocuments = Set(documentIds)
            print("Selected documents set to: \(context.coordinator.selectedDocuments)")
            deleteSelectedDocuments()
        }
        
        // Add status column
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Quick Actions"
        statusColumn.width = 110
        statusColumn.minWidth = 110
        statusColumn.maxWidth = 110
        statusColumn.resizingMask = [] // Lock width
        statusColumn.headerCell.alignment = .left
        statusColumn.headerCell.attributedStringValue = NSAttributedString(
            string: "Quick Actions",
            attributes: [NSAttributedString.Key.paragraphStyle: NSParagraphStyle.leftAligned(withPadding: 8),
                        NSAttributedString.Key.font: NSFont(name: "InterTight-Medium", size: 11)!,
                        NSAttributedString.Key.kern: 0.3])
        statusColumn.headerCell.backgroundColor = .clear  // Set header cell background to clear
        customTableView.addTableColumn(statusColumn)
        
        // Add name column
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = ListColumn.name.width
        nameColumn.minWidth = 100
        nameColumn.headerCell.alignment = .left
        nameColumn.headerCell.attributedStringValue = NSAttributedString(
            string: "Name",
            attributes: [NSAttributedString.Key.paragraphStyle: NSParagraphStyle.leftAligned(withPadding: 8),
                        NSAttributedString.Key.font: NSFont(name: "InterTight-Medium", size: 11)!,
                        NSAttributedString.Key.kern: 0.3])
        customTableView.addTableColumn(nameColumn)
        
        // Configure scroll view
        scrollView.documentView = customTableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false // Remove horizontal scroller
        scrollView.autohidesScrollers = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.backgroundColor = .clear  // Ensure scroll view background is clear
        
        // Ensure all header cells have clear backgrounds
        for column in customTableView.tableColumns {
            column.headerCell.backgroundColor = .clear
        }
        
        // Configure vertical scroller to be always visible with legacy style
        if let verticalScroller = scrollView.verticalScroller {
            verticalScroller.controlSize = .regular
            verticalScroller.scrollerStyle = .legacy
        }
        
        // Set up hover tracking
        customTableView.onHover = { row in
            context.coordinator.hoveredRow = row
            if row >= 0 {
                customTableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<customTableView.numberOfColumns))
            }
        }
        
        // Add notification observer for window resize
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.windowDidResize),
            name: NSWindow.didResizeNotification,
            object: nil)
        
        // Initialize column widths after the view is loaded
        DispatchQueue.main.async {
            context.coordinator.updateColumnWidths()
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }
        
        // Disable animations during update
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Update coordinator state with a local copy of documents to avoid state modification during view updates
        let localDocuments = documents
        context.coordinator.documents = localDocuments
        context.coordinator.selectedDocuments = selectedDocuments
        context.coordinator.isSelectionMode = isSelectionMode
        context.coordinator.pinnedDocuments = pinnedDocuments
        context.coordinator.wipDocuments = wipDocuments
        context.coordinator.calendarDocuments = calendarDocuments
        context.coordinator.visibleColumns = visibleColumns
        context.coordinator.dateFilterType = dateFilterType
        context.coordinator.colorScheme = colorScheme
        context.coordinator.tableView = tableView
        
        // Enhanced scroll view performance settings
        if let scrollView = tableView.enclosingScrollView {
            // Configure scrolling behavior for smoother experience
            scrollView.scrollsDynamically = true
            
            // Use optimized scrolling modes
            scrollView.usesPredominantAxisScrolling = true
            scrollView.verticalScrollElasticity = .automatic
            
            // Remove horizontal elasticity
            scrollView.horizontalScrollElasticity = .none
            
            // Set scroller appearance for better UX
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScroller?.knobStyle = .light
            
            // Configure content view for better scrolling
            let clipView = scrollView.contentView
            clipView.drawsBackground = false
            clipView.postsBoundsChangedNotifications = true
            
            // Set optimized scrolling options
            if #available(macOS 13.0, *) {
                clipView.automaticallyAdjustsContentInsets = true
            }
        }
        
        // Enable layer-backed views for better performance
        tableView.wantsLayer = true
        if let layer = tableView.layer {
            layer.drawsAsynchronously = true
        }
        
        // Fixed row height for better performance
        tableView.usesAutomaticRowHeights = false
        
        // Track whether we need to reload data (only reload if necessary)
        var needsReload = false
        
        // Check if refreshID changed
        if context.coordinator.refreshID != refreshID {
            context.coordinator.refreshID = refreshID
            needsReload = true
        }

        // Check for color scheme changes
        if context.coordinator.colorScheme != colorScheme {
            context.coordinator.colorScheme = colorScheme
            (tableView as? TrackingTableView)?.isDarkMode = (colorScheme == .dark)
            
            // Ensure header view maintains clear background
            if let headerView = tableView.headerView {
                headerView.layer?.backgroundColor = NSColor.clear.cgColor
            }
            
            needsReload = true
        }

        // Detect changes in selection mode
        if context.coordinator.isSelectionMode != isSelectionMode {
            context.coordinator.isSelectionMode = isSelectionMode
            needsReload = true
        }
        
        // Batch column updates
        let currentColumns = Set(tableView.tableColumns.map { $0.identifier.rawValue })
        let wantedColumns = Set(visibleColumns).union(["status", "name"]) // Status and name are always visible
        
        // Determine columns to add and remove
        let columnsToRemove = currentColumns.subtracting(wantedColumns)
        let columnsToAdd = wantedColumns.subtracting(currentColumns)
        
        // Remove columns that should be hidden
        if !columnsToRemove.isEmpty {
            for column in tableView.tableColumns {
                let columnId = column.identifier.rawValue
                if columnId != "status" && columnId != "name" && !visibleColumns.contains(columnId) {
                    tableView.removeTableColumn(column)
                    needsReload = true
                }
            }
        }
        
        // Add columns that should be visible
        if !columnsToAdd.isEmpty {
            for columnId in defaultColumnOrder {
                // Skip status and name columns as they're always present
                if columnId == "status" || columnId == "name" { continue }
                
                // Check if column should be visible
                if visibleColumns.contains(columnId) && !currentColumns.contains(columnId) {
                    // Check if column already exists
                    if !tableView.tableColumns.contains(where: { $0.identifier.rawValue == columnId }) {
                        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnId))
                        column.title = {
                            switch columnId {
                            case "series": return "Series"
                            case "location": return "Location"
                            case "date": return "Last Modified"
                            case "createdDate": return "Created On"
                            case "presentedDate": return "Last Presented On"
                            default: return ""
                            }
                        }()
                        
                        // Initialize with flex-based width (this will be adjusted by updateColumnWidths)
                        let listColumn = ListColumn.allColumns.first { $0.id == columnId } ?? ListColumn.series
                        column.width = listColumn.width
                        column.minWidth = 100
                        column.headerCell.alignment = .left
                        column.headerCell.attributedStringValue = NSAttributedString(
                            string: column.title,
                            attributes: [NSAttributedString.Key.paragraphStyle: NSParagraphStyle.leftAligned(withPadding: 8),
                                        NSAttributedString.Key.font: NSFont(name: "InterTight-Medium", size: 11)!,
                                        NSAttributedString.Key.kern: 0.3])
                        column.resizingMask = .userResizingMask
                        
                        // Find where this column should be inserted based on defaultColumnOrder
                        let targetIndex = defaultColumnOrder.firstIndex(of: columnId) ?? tableView.tableColumns.count
                        let currentIndex = min(targetIndex, tableView.tableColumns.count)
                        
                        // Add the column and move it to the correct position
                        tableView.addTableColumn(column)
                        if currentIndex < tableView.tableColumns.count - 1 {
                            tableView.moveColumn(tableView.tableColumns.count - 1, toColumn: currentIndex)
                        }
                        needsReload = true
                    }
                }
            }
        }
        
        // Create a local copy of documents for sorting to avoid modifying state during view updates
        var sortedDocuments = localDocuments
        
        // Sort documents based on coordinator's current sort settings
        sortedDocuments.sort { (doc1, doc2) in
            // Use the coordinator's sort settings
            switch context.coordinator.currentSortColumn {
            case "status":
                let status1 = context.coordinator.getStatusPriority(doc1)
                let status2 = context.coordinator.getStatusPriority(doc2)
                if status1 != status2 {
                    return context.coordinator.isAscending ? status1 < status2 : status1 > status2
                }
                // Fall through to name sorting if status is equal
                let title1 = doc1.title.isEmpty ? "Untitled" : doc1.title
                let title2 = doc2.title.isEmpty ? "Untitled" : doc2.title
                return context.coordinator.isAscending ? 
                    title1.localizedCompare(title2) == .orderedAscending :
                    title1.localizedCompare(title2) == .orderedDescending
                
            case "name":
                let title1 = doc1.title.isEmpty ? "Untitled" : doc1.title
                let title2 = doc2.title.isEmpty ? "Untitled" : doc2.title
                return context.coordinator.isAscending ? 
                    title1.localizedCompare(title2) == .orderedAscending :
                    title1.localizedCompare(title2) == .orderedDescending
                
            case "series":
                let series1 = doc1.series?.name ?? ""
                let series2 = doc2.series?.name ?? ""
                return context.coordinator.isAscending ? 
                    series1.localizedCompare(series2) == .orderedAscending :
                    series1.localizedCompare(series2) == .orderedDescending
                
            case "location":
                let loc1 = doc1.variations.first?.location ?? ""
                let loc2 = doc2.variations.first?.location ?? ""
                return context.coordinator.isAscending ? 
                    loc1.localizedCompare(loc2) == .orderedAscending :
                    loc1.localizedCompare(loc2) == .orderedDescending
                
            case "date":
                return context.coordinator.isAscending ?
                    doc1.modifiedAt < doc2.modifiedAt :
                    doc1.modifiedAt > doc2.modifiedAt
                
            case "createdDate":
                return context.coordinator.isAscending ?
                    doc1.createdAt < doc2.createdAt :
                    doc1.createdAt > doc2.createdAt
                
            case "presentedDate":
                let date1 = doc1.variations.first?.datePresented
                let date2 = doc2.variations.first?.datePresented
                if date1 == nil && date2 == nil {
                    return false  // Keep relative order unchanged
                } else if date1 == nil {
                    return !context.coordinator.isAscending  // Put nil dates at the end
                } else if date2 == nil {
                    return context.coordinator.isAscending  // Put nil dates at the end
                } else {
                    return context.coordinator.isAscending ? date1! < date2! : date1! > date2!
                }
                
            default:
                // Default to name sorting
                let title1 = doc1.title.isEmpty ? "Untitled" : doc1.title
                let title2 = doc2.title.isEmpty ? "Untitled" : doc2.title
                return title1.localizedCaseInsensitiveCompare(title2) == .orderedAscending
            }
        }
        
        // Check if documents have changed
        if context.coordinator.documents.map({ $0.id }) != sortedDocuments.map({ $0.id }) {
            needsReload = true
        }
        
        // Always check if document count has changed - this is crucial for filtering
        if context.coordinator.documents.count != sortedDocuments.count {
            needsReload = true
        }
        
        // Update the coordinator with the sorted documents
        context.coordinator.documents = sortedDocuments
        
        // Recalculate column widths based on the available width
        context.coordinator.updateColumnWidths()
        
        // Only reload if necessary
        if needsReload {
            tableView.reloadData()
            
            // Also update the scroll view's content size to match the actual number of rows
            if let scrollView = tableView.enclosingScrollView {
                let contentHeight = CGFloat(tableView.numberOfRows) * tableView.rowHeight
                scrollView.documentView?.frame.size.height = contentHeight
            }
        }
        
        // Finish transaction
        CATransaction.commit()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: DocumentTable
        var documents: [Letterspace_CanvasDocument]
        var selectedDocuments: Set<String>
        var isSelectionMode: Bool
        var pinnedDocuments: Set<String>
        var wipDocuments: Set<String>
        var calendarDocuments: Set<String>
        var visibleColumns: Set<String>
        var dateFilterType: DateFilterType
        var hoveredRow: Int = -1
        var colorScheme: ColorScheme
        var refreshID: UUID
        var tableView: NSTableView?  // Make this optional
        private var lastSelectedRow: Int?  // Add this to track last selected row for shift+click
        
        // Add helper function for status priority
        func getStatusPriority(_ doc: Letterspace_CanvasDocument) -> Int {
            var priority = 0
            if pinnedDocuments.contains(doc.id) { priority += 4 }
            if wipDocuments.contains(doc.id) { priority += 2 }
            if calendarDocuments.contains(doc.id) { priority += 1 }
            return priority
        }
        
        // Update default sort to name column and ascending order
        var currentSortColumn: String = "name"
        var isAscending: Bool = true
        
        init(_ parent: DocumentTable) {
            self.parent = parent
            self.documents = parent.documents // Don't sort here, we'll sort in updateNSView
            self.selectedDocuments = parent.selectedDocuments
            self.isSelectionMode = parent.isSelectionMode
            self.pinnedDocuments = parent.pinnedDocuments
            self.wipDocuments = parent.wipDocuments
            self.calendarDocuments = parent.calendarDocuments
            self.visibleColumns = parent.visibleColumns
            self.dateFilterType = parent.dateFilterType
            self.colorScheme = parent.colorScheme
            self.refreshID = parent.refreshID
            super.init()
        }
        
        // Add the didAdd method after numberOfRows method
        func numberOfRows(in tableView: NSTableView) -> Int {
            // Initialize column widths after table is loaded
            DispatchQueue.main.async {
                self.updateColumnWidths()
            }
            return documents.count
        }
        
        func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
            // Only update on the first row to avoid multiple updates
            if row == 0 {
                DispatchQueue.main.async {
                    self.updateColumnWidths()
                }
            }
        }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            // Save a reference to the table view for column width adjustments
            self.tableView = tableView
            
            // Add bounds check to prevent index out of range errors
            guard row >= 0, row < documents.count else {
                return nil
            }
            
            let document = documents[row]
            let isSelected = selectedDocuments.contains(document.id)
            let isHovered = row == hoveredRow
            
            // Get the visible non-status columns
            let visibleNonStatusColumns = tableView.tableColumns.filter { col in
                let columnId = col.identifier.rawValue
                return columnId != "status" && self.visibleColumns.contains(columnId)
            }
            
            // Determine if this is the leftmost or rightmost visible non-status column
            let isLeftmostColumn = visibleNonStatusColumns.first?.identifier == tableColumn?.identifier
            let isRightmostColumn = visibleNonStatusColumns.last?.identifier == tableColumn?.identifier
            
            // Get the background color based on state
            let backgroundColor: NSColor? = {
                if isSelected {
                    return NSColor(parent.theme.accent.opacity(0.1))
                } else if isHovered && tableColumn?.identifier.rawValue != "status" {
                    return NSColor(parent.theme.accent.opacity(0.1))
                }
                return nil
            }()
            
            // Create cell views based on column identifier
            switch tableColumn?.identifier.rawValue {
                case "status":
                    let statusView = DocumentStatusView(
                        document: document,
                        pinnedDocuments: pinnedDocuments,
                        wipDocuments: wipDocuments,
                        calendarDocuments: calendarDocuments,
                        onPin: self.parent.onPin,
                        onWIP: self.parent.onWIP,
                        onCalendar: self.parent.onCalendar,
                        onOpen: self.parent.onOpen,
                        onShowDetails: self.handleShowDetails,
                        onCalendarAction: { documentId in
                            if let doc = self.documents.first(where: { $0.id == documentId }) {
                                self.parent.onCalendarAction(doc)
                            }
                        },
                        isHovering: isHovered
                    )
                    let cell = NSHostingView(rootView: statusView)
                    cell.wantsLayer = true
                    cell.layer?.backgroundColor = NSColor.clear.cgColor
                    return cell
                    
                default:
                    let cell = NSHostingView(rootView: createCellContent(for: tableColumn?.identifier.rawValue ?? "", document: document))
                    cell.wantsLayer = true
                    if let bgColor = backgroundColor {
                        cell.layer?.backgroundColor = bgColor.cgColor
                        if isLeftmostColumn {
                            cell.layer?.cornerRadius = 13
                            cell.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
                        } else if isRightmostColumn {
                            cell.layer?.cornerRadius = 13
                            cell.layer?.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
                        } else {
                            cell.layer?.cornerRadius = 0
                            cell.layer?.maskedCorners = []
                        }
                    } else {
                        cell.layer?.backgroundColor = NSColor.clear.cgColor
                        cell.layer?.cornerRadius = 0
                        cell.layer?.maskedCorners = []
                    }
                    return cell
            }
        }
        
        private func createCellContent(for columnId: String, document: Letterspace_CanvasDocument) -> AnyView {
            switch columnId {
                case "name":
                    return AnyView(
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 14))
                                .foregroundStyle(colorScheme == .dark ? .white : Color(.sRGB, white: 0.3))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.title.isEmpty ? "Untitled" : document.title)
                                    .font(.custom("InterTight-Regular", size: 13))
                                    .tracking(0.3)
                                    .foregroundStyle(colorScheme == .dark ? .white : Color(.sRGB, white: 0.3))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                if !document.subtitle.isEmpty {
                                    Text(document.subtitle)
                                        .font(.custom("InterTight-Regular", size: 11))
                                        .tracking(0.5)
                                        .foregroundStyle(colorScheme == .dark ? Color(.sRGB, white: 0.6) : Color(.sRGB, white: 0.5))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                    )
                default:
                    let text: String = {
                        switch columnId {
                            case "series": return document.series?.name ?? ""
                            case "location": return document.variations.first?.location ?? ""
                            case "date": return formatDate(document.modifiedAt)
                            case "createdDate": return formatDate(document.createdAt)
                            case "presentedDate": return document.variations.first?.datePresented != nil ?
                                formatDate(document.variations.first!.datePresented!) : ""
                            default: return ""
                        }
                    }()
                    
                    return AnyView(
                        Text(text)
                            .font(.custom("InterTight-Regular", size: 11))
                            .tracking(0.5)
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : Color(.sRGB, white: 0.3))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 8)
                    )
            }
        }
        
        private func formatDate(_ date: Date) -> String {
            let calendar = Calendar.current
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            
            if calendar.isDateInToday(date) {
                return "Today, \(timeFormatter.string(from: date))"
            }
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        
        func handleSingleClick(_ document: Letterspace_CanvasDocument) {
            // Clear existing selection and select only the clicked document
            selectedDocuments = Set([document.id])
            
            // Update last selected row for potential shift+click
            if let row = documents.firstIndex(where: { $0.id == document.id }) {
                lastSelectedRow = row
            }
            
            // Update parent's selection state
            parent.selectedDocuments = selectedDocuments
            
            // Force immediate update of the table view
            if let tableView = self.tableView {
                tableView.reloadData()
            }
        }
        
        func handleDoubleClick(_ document: Letterspace_CanvasDocument) {
            parent.onOpen(document)
        }
        
        func handleLongPress(_ document: Letterspace_CanvasDocument) {
            isSelectionMode = true
            selectedDocuments.insert(document.id)
            parent.selectedDocuments = selectedDocuments
        }
        
        // Remove selection handling from delegate
        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            return false
        }
        
        func handleShowDetails(_ document: Letterspace_CanvasDocument) {
            // Send just the document ID instead of the whole document
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowDocumentDetails"),
                object: nil,
                userInfo: ["documentId": document.id]
            )
        }
        
        func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
            guard let columnId = tableColumn.identifier.rawValue as String? else { return }
            
            // Skip sorting for the Quick Actions column
            if columnId == "status" {
                return
            }
            
            // Toggle sort direction if clicking the same column
            if currentSortColumn == columnId {
                isAscending.toggle()
            } else {
                currentSortColumn = columnId
                isAscending = true
            }
            
            // Update all column headers
            for column in tableView.tableColumns {
                let baseTitle: String
                switch column.identifier.rawValue {
                case "status": baseTitle = "Quick Actions"
                case "name": baseTitle = "Name"
                case "series": baseTitle = "Series"
                case "location": baseTitle = "Location"
                case "date": baseTitle = "Last Modified"
                case "createdDate": baseTitle = "Created On"
                case "presentedDate": baseTitle = "Last Presented On"
                default: baseTitle = column.title
                }
                
                let isCurrentSortColumn = currentSortColumn == column.identifier.rawValue
                let headerText = isCurrentSortColumn ? "\(baseTitle) \(isAscending ? "↑" : "↓")" : baseTitle
                
                column.headerCell.attributedStringValue = NSAttributedString(
                    string: headerText,
                    attributes: [NSAttributedString.Key.paragraphStyle: NSParagraphStyle.leftAligned(withPadding: 8),
                               NSAttributedString.Key.font: NSFont(name: "InterTight-Medium", size: 11)!,
                               NSAttributedString.Key.kern: 0.3])
            }
            
            // Sort only the coordinator's documents array
            documents.sort { (doc1, doc2) in
                switch currentSortColumn {
                case "status":
                    let status1 = self.getStatusPriority(doc1)
                    let status2 = self.getStatusPriority(doc2)
                    if status1 != status2 {
                        return self.isAscending ? status1 < status2 : status1 > status2
                    }
                    // Fall through to name sorting if status is equal
                    let title1 = doc1.title.isEmpty ? "Untitled" : doc1.title
                    let title2 = doc2.title.isEmpty ? "Untitled" : doc2.title
                    return self.isAscending ?
                        title1.localizedCompare(title2) == .orderedAscending :
                        title1.localizedCompare(title2) == .orderedDescending
                    
                case "name":
                    let title1 = doc1.title.isEmpty ? "Untitled" : doc1.title
                    let title2 = doc2.title.isEmpty ? "Untitled" : doc2.title
                    return self.isAscending ?
                        title1.localizedCompare(title2) == .orderedAscending :
                        title1.localizedCompare(title2) == .orderedDescending
                    
                case "series":
                    let series1 = doc1.series?.name ?? ""
                    let series2 = doc2.series?.name ?? ""
                    return self.isAscending ?
                        series1.localizedCompare(series2) == .orderedAscending :
                        series1.localizedCompare(series2) == .orderedDescending
                    
                case "location":
                    let loc1 = doc1.variations.first?.location ?? ""
                    let loc2 = doc2.variations.first?.location ?? ""
                    return self.isAscending ?
                        loc1.localizedCompare(loc2) == .orderedAscending :
                        loc1.localizedCompare(loc2) == .orderedDescending
                    
                case "date":
                    return self.isAscending ?
                        doc1.modifiedAt < doc2.modifiedAt :
                        doc1.modifiedAt > doc2.modifiedAt
                    
                case "createdDate":
                    return self.isAscending ?
                        doc1.createdAt < doc2.createdAt :
                        doc1.createdAt > doc2.createdAt
                    
                case "presentedDate":
                    let date1 = doc1.variations.first?.datePresented
                    let date2 = doc2.variations.first?.datePresented
                    if date1 == nil && date2 == nil {
                        return false  // Keep relative order unchanged
                    } else if date1 == nil {
                        return !self.isAscending  // Put nil dates at the end
                    } else if date2 == nil {
                        return self.isAscending  // Put nil dates at the end
                    } else {
                        return self.isAscending ? date1! < date2! : date1! > date2!
                    }
                    
                default:
                    // Default to sorting by modified date
                    return self.isAscending ?
                        doc1.modifiedAt < doc2.modifiedAt :
                        doc1.modifiedAt > doc2.modifiedAt
                }
            }
            
            // Reload the table view with sorted documents
            tableView.reloadData()
        }
        
        func handleCommandClick(_ document: Letterspace_CanvasDocument) {
            // Toggle selection for the clicked document
            if selectedDocuments.contains(document.id) {
                selectedDocuments.remove(document.id)
            } else {
                selectedDocuments.insert(document.id)
            }
            
            // Update last selected row for potential shift+click
            if let row = documents.firstIndex(where: { $0.id == document.id }) {
                lastSelectedRow = row
            }
            
            // Update parent's selection state
            parent.selectedDocuments = selectedDocuments
            
            // Force immediate update of the table view
            if let tableView = self.tableView {
                tableView.reloadData()
            }
        }
        
        func handleShiftClick(_ document: Letterspace_CanvasDocument) {
            guard let currentRow = documents.firstIndex(where: { $0.id == document.id }) else { return }
            
            // If there's no last selected row or no current selection, treat as single click
            if lastSelectedRow == nil || selectedDocuments.isEmpty {
                handleSingleClick(document)
                return
            }
            
            // Calculate range
            let startRow = min(lastSelectedRow!, currentRow)
            let endRow = max(lastSelectedRow!, currentRow)
            
            // Add all documents in range to selection
            for row in startRow...endRow {
                selectedDocuments.insert(documents[row].id)
            }
            
            // Update parent's selection state
            parent.selectedDocuments = selectedDocuments
            
            // Force immediate update of the table view
            if let tableView = self.tableView {
                tableView.reloadData()
            }
        }
        
        // Prevent reordering of Quick Actions and Name columns
        func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn: Int) -> Bool {
            let column = tableView.tableColumns[columnIndex]
            let targetColumn = tableView.tableColumns[toColumn]
            
            // Prevent moving Quick Actions or Name columns
            if column.identifier.rawValue == "status" || column.identifier.rawValue == "name" {
                return false
            }
            
            // Prevent moving other columns to before Quick Actions or Name
            if targetColumn.identifier.rawValue == "status" || targetColumn.identifier.rawValue == "name" {
                return false
            }
            
            return true
        }
        
        @objc func windowDidResize(_ notification: Notification) {
            updateColumnWidths()
        }
        
        // Add a deinit method to clean up resources
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        func updateColumnWidths() {
            // Ensure tableView and scrollView exist
            guard let tableView = tableView, let scrollView = tableView.enclosingScrollView else { return }

            // Get the total available width, accounting for content insets
            let availableWidth = scrollView.contentView.bounds.width - scrollView.contentInsets.left - scrollView.contentInsets.right
            
            // Fixed width for status column and padding
            let statusWidth: CGFloat = 110
            let columnPadding: CGFloat = 24 // Padding between last column and edge
            
            // Calculate remaining width for other columns, accounting for padding
            let remainingWidth = max(0, availableWidth - statusWidth - columnPadding)

            // Get visible columns excluding status
            let visibleColumns = tableView.tableColumns.filter {
                $0.identifier.rawValue != "status" && parent.visibleColumns.contains($0.identifier.rawValue)
            }

            if visibleColumns.isEmpty || remainingWidth <= 0 {
                return
            }

            // Calculate total flex proportion
            let totalFlexProportion: CGFloat = visibleColumns.reduce(0) { sum, column in
                let columnId = column.identifier.rawValue
                let listColumn = ListColumn.allColumns.first { $0.id == columnId } ?? ListColumn.name
                return sum + listColumn.flexProportion()
            }

            guard totalFlexProportion > 0 else { return }

            // Find name column
            let nameColumn = visibleColumns.first { $0.identifier.rawValue == "name" }
            var remainingFlexWidth = remainingWidth

            // Configure animation
            NSAnimationContext.beginGrouping()
            let context = NSAnimationContext.current
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            // Assign widths to non-name columns
            for column in visibleColumns where column.identifier.rawValue != "name" {
                let columnId = column.identifier.rawValue
                guard let listColumn = ListColumn.allColumns.first(where: { $0.id == columnId }) else { continue }
                
                let proportion = listColumn.flexProportion() / totalFlexProportion
                let calculatedWidth = remainingWidth * proportion
                let newWidth = max(listColumn.width, calculatedWidth)
                
                column.width = newWidth
                remainingFlexWidth -= newWidth
            }

            // Assign remaining width to name column
            if let nameColumn = nameColumn {
                let minNameWidth: CGFloat = 200
                let newWidth = max(minNameWidth, remainingFlexWidth)
                nameColumn.width = newWidth
            }
            
            NSAnimationContext.endGrouping()
        }
    }
}
#endif
