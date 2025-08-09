#if os(macOS) || os(iOS)
import SwiftUI
#if os(macOS)
import PDFKit
import AppKit
#elseif os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers
import CoreGraphics


// Add ResizableHeaderScrollView helper at the top of the file, after imports
struct ResizableHeaderScrollView<Header: View, Content: View>: View {
    var minimumHeight: CGFloat
    var maximumHeight: CGFloat
    var ignoresSafeAreaTop: Bool = false
    var isSticky: Bool = false
    /// Resize Progress, SafeArea Values
    @ViewBuilder var header: (CGFloat, EdgeInsets) -> Header
    @ViewBuilder var content: Content
    /// View Properties
    @State private var offsetY: CGFloat = 0
    var body: some View {
        GeometryReader {
            let safeArea = ignoresSafeAreaTop ? $0.safeAreaInsets : .init()
            
            ScrollView(.vertical) {
                LazyVStack(pinnedViews: [.sectionHeaders]) {
                    Section {
                        content
                    } header: {
                        GeometryReader { _ in
                            let progress: CGFloat = min(max(offsetY / (maximumHeight - minimumHeight), 0), 1)
                            let resizedHeight = (maximumHeight + safeArea.top) - (maximumHeight - minimumHeight) * progress
                            
                            header(progress, safeArea)
                                .frame(height: resizedHeight, alignment: .bottom)
                                /// Making it Sticky
                                .offset(y: isSticky ? (offsetY < 0 ? offsetY : 0) : 0)
                        }
                        .frame(height: maximumHeight + safeArea.top)
                    }
                }
            }
            .ignoresSafeArea(.container, edges: ignoresSafeAreaTop ? [.top] : [])
            /// Offset is needed to calculate the progress value
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { oldValue, newValue in
                offsetY = newValue
            }
        }
    }
}

struct DashboardView: View {
    @Binding var document: Letterspace_CanvasDocument
    var onSelectDocument: (Letterspace_CanvasDocument) -> Void // Added this property
    var onMenuTap: (() -> Void)? = nil // Callback to trigger the morph menu
    @Binding var isCircularMenuOpen: Bool // Binding to track circular menu state
    
    // Individual menu action callbacks for morphing bottom bar
    var onDashboard: (() -> Void)? = nil
    var onSearch: (() -> Void)? = nil
    var onNewDocument: (() -> Void)? = nil
    var onFolders: (() -> Void)? = nil
    var onBibleReader: (() -> Void)? = nil
    var onSmartStudy: (() -> Void)? = nil
    var onRecentlyDeleted: (() -> Void)? = nil
    var onSettings: (() -> Void)? = nil
    
    // Removed floating sidebar parameters - iPhone uses circular menu, iPad uses native NavigationSplitView
    // Dummy property for compatibility
    private var showFloatingSidebar: Bool { false }
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    private let gradientManager = GradientWallpaperManager.shared
    @State private var selectedColumn: ListColumn = .name
    @State private var sortAscending = true
    @State private var dateFilterType: DateFilterType = .modified
    @State private var scrollOffset: CGFloat = 0
    @Namespace private var scrollSpace
    @State private var documents: [Letterspace_CanvasDocument] = []
    @State private var selectedDocuments: Set<String> = []
    @State private var pinnedDocuments: Set<String> = []
    @State private var isSelectionMode: Bool = false
    @State private var pinnedScrollOffset: CGFloat = 0
    @State private var wipScrollOffset: CGFloat = 0
    @State private var calendarScrollOffset: CGFloat = 0
    @State private var shouldFlashPinnedScroll = false
    @State private var wipDocuments: Set<String> = []
    @State private var visibleColumns: Set<String> = Set(ListColumn.allColumns.map { $0.id })
    @State private var calendarDocuments: Set<String> = []
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @State private var folders: [Folder] = []
    @State private var selectedTags: Set<String> = []
    @State private var selectedFilterColumn: String? = nil
    @State private var selectedFilterCategory: String = "Filter" // "Filter" or "Tags" - Filter is now first
    @State private var selectedSortColumn: String = "name"
    @State private var isAscendingSortOrder: Bool = true
    @State private var isDateFilterExplicitlySelected: Bool = false // Track if date filter was explicitly chosen
    @State private var showTagManager = false
    @State private var showSermonJournalSheet = false
    @State private var selectedJournalDocument: Letterspace_CanvasDocument?
    @State private var showReflectionSelectionSheet = false
    @State private var showPreachItAgainDetailsSheet = false
    @State private var selectedPreachItAgainDocument: Letterspace_CanvasDocument?
    
    // Consolidated sheet state
    @State private var activeSheet: ActiveSheet?
    
    enum ActiveSheet: Identifiable {
        case tagManager
        case sermonJournal(Letterspace_CanvasDocument)
        case reflectionSelection
        case preachItAgainDetails(Letterspace_CanvasDocument)
        case documentDetails(Letterspace_CanvasDocument)
        case curatedCategory(CurationType)
        case tallyLabel
        
        var id: String {
            switch self {
            case .tagManager: return "tagManager"
            case .sermonJournal(let doc): return "sermonJournal-\(doc.id)"
            case .reflectionSelection: return "reflectionSelection"
            case .preachItAgainDetails(let doc): return "preachItAgainDetails-\(doc.id)"
            case .documentDetails(let doc): return "documentDetails-\(doc.id)"
            case .curatedCategory(let type): return "curatedCategory-\(type.rawValue)"
            case .tallyLabel: return "tallyLabel"
            }
        }
    }
    @StateObject private var journalService = SermonJournalService.shared
    @State private var isHoveringInfo = false
    @State private var hoveredTag: String? = nil
    private let colorManager = TagColorManager.shared
    @State private var isViewButtonHovering = false
    @State private var showDetailsCard = false
    @State private var activeBottomBarTab: DashboardTab = .pinned
    
    // iOS 26 detection
    private var isiOS26: Bool {
        if #available(iOS 26, *) {
            return true
        } else {
            return false
        }
    }
    @State private var selectedDetailsDocument: Letterspace_CanvasDocument?
    @State private var showShareSheet = false
    // Add a refresh trigger state variable
    @State private var refreshTrigger: Bool = false
    // Add state variable for table refresh ID
    @State private var tableRefreshID = UUID()
    // Add state to track loading status
    @State private var isLoadingDocuments: Bool = true
    // Add state to track if this is a swipe-down navigation
    @State private var isSwipeDownNavigation: Bool = false
    
    // Add state variables for Presentation Manager sheet
    @State private var documentToShowInSheet: Letterspace_CanvasDocument?
    
    // Add state variables for section expansion
    @State private var isPinnedExpanded: Bool = false
    @State private var isWIPExpanded: Bool = false
    @State private var isSchedulerExpanded: Bool = false
    
    // iPad modal overlay states
    @State private var showPinnedModal = false
    @State private var showWIPModal = false
    @State private var showSchedulerModal = false
    
    // NOTE: Shared sheet system removed - using tabs within All Documents sheet instead
    
    // State for calendar modal - Managed by DashboardView
    @State private var calendarModalData: ModalDisplayData? = nil
    
    // Add state for carousel
    @State private var selectedCarouselIndex: Int = 0 // Start with first card on app launch
    @State private var carouselOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0 // Track real-time drag offset
    @State private var isReordering: Bool = false // Track if we're in reorder mode
    @State private var reorderDragOffset: CGSize = .zero // Track reorder drag
    
    // Track if this is the first app launch to reset to first card
    @State private var isFirstLaunch: Bool = true
    
    // Track orientation for carousel sections
    @State private var isLandscapeMode: Bool = false
    
    // Track whether expand buttons should be shown (separate from carousel styling)
    @State private var shouldShowExpandButtons: Bool = false
    
    // Carousel sections in order: Pinned, WIP, Document Schedule (now mutable)
    @State private var carouselSections: [(title: String, view: AnyView)] = []
    
    // Add state for drag-to-reorder
    @State private var draggedCardIndex: Int? = nil
    @State private var draggedCardOffset: CGSize = .zero
    @State private var reorderMode: Bool = false
    
    // Multi-select state for All Documents section
    @State private var isAllDocumentsEditMode: Bool = false
    @State private var selectedAllDocuments: Set<String> = []
    @State private var justLongPressed: Bool = false
    
    // State for Talle logo sheet
    @State private var showTallyLabelModal: Bool = false
    
    // NEW: State for All Documents sheet behavior (iPhone and iPad)
    @State private var isDraggingAllDocuments: Bool = false
    @State private var allDocumentsPosition: AllDocumentsPosition = .default
    @State private var showAllDocumentsSheet = true // Start with sheet open
    @State private var wasAllDocumentsSheetOpenBeforeMenu = false // Track sheet state before menu opens

    @State private var allDocumentsSheetDetent: PresentationDetent = .height(350) // Start at medium
    // Unified card sizing for sermon journal cards
    private let journalCardHeight: CGFloat = 160
    
    // Sheet position states
    enum AllDocumentsPosition {
        case collapsed  // Minimum height, carousel expanded
        case `default`  // Current default position
        case expanded   // Full screen like iOS sheet
        
        var carouselHeight: CGFloat {
            #if os(iOS)
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            if isIPad {
                // iPad-specific heights - more compact
                switch self {
                case .collapsed:
                    return 550  // Extended collapsed height for iPad carousel cards
                case .default:
                    return 320  // Extended default height for iPad carousel cards
                case .expanded:
                    return 120  // Smaller minimized height for iPad
                }
            } else {
                // iPhone heights
                switch self {
                case .collapsed:
                    return 420  // Much taller expanded carousel height
                case .default:
                    return 200  // Default carousel height
                case .expanded:
                    return 5    // Essentially hidden - just enough to maintain layout structure
                }
            }
            #else
            // macOS and other platforms
            switch self {
            case .collapsed:
                return 420
            case .default:
                return 200
            case .expanded:
                return 140
            }
            #endif
        }
    }
    
    // Computed property to determine if navigation padding should be added
    private var shouldAddNavigationPadding: Bool {
        // No navigation padding needed - iPhone uses circular menu, iPad uses native NavigationSplitView
        return false
    }
    
    // Navigation padding no longer needed
    private var navPadding: CGFloat {
        return 0 // No navigation padding needed
    }
    
    // iPad detection helper
    private var isIPadDevice: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return true // macOS always supports reorder
        #endif
    }
    
    // Helper function to calculate flexible column widths for iPhone and iPad
    private func calculateFlexibleColumnWidths(availableWidth: CGFloat? = nil) -> (statusWidth: CGFloat, nameWidth: CGFloat, seriesWidth: CGFloat, locationWidth: CGFloat, dateWidth: CGFloat, createdDateWidth: CGFloat) {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isPhone {
            // Get available width (93% of screen width minus padding)
            let availableWidth = UIScreen.main.bounds.width * 0.93 - 32 // Account for container padding
            
            // Fixed width for status column
            let statusWidth: CGFloat = 55
            
            // Calculate remaining width for other columns
            let remainingWidth = availableWidth - statusWidth
            
            // Get visible columns (excluding status) - ensure name is always included
            let effectiveVisibleColumns = visibleColumns.union(["name"])
            let visibleNonStatusColumns = effectiveVisibleColumns.filter { $0 != "status" }
            
            // If only name column is visible, it takes all remaining space
            if visibleNonStatusColumns.count == 1 && visibleNonStatusColumns.contains("name") {
                return (statusWidth: statusWidth, nameWidth: remainingWidth, seriesWidth: 0, locationWidth: 0, dateWidth: 0, createdDateWidth: 0)
            }
            
            // Define flex ratios for each column type
            let flexRatios: [String: CGFloat] = [
                "name": 2.0,        // Name gets double space
                "series": 1.2,      // Series gets slightly more
                "location": 1.4,    // Location gets more space
                "date": 0.8,        // Date columns get less space
                "createdDate": 0.8
            ]
            
            // Calculate total flex ratio for visible columns
            let totalFlexRatio = visibleNonStatusColumns.reduce(0) { sum, columnId in
                sum + (flexRatios[columnId] ?? 1.0)
            }
            
            // Calculate individual widths
            let nameWidth = visibleNonStatusColumns.contains("name") ? 
                max(120, remainingWidth * (flexRatios["name"] ?? 1.0) / totalFlexRatio) : 0
            let seriesWidth = visibleNonStatusColumns.contains("series") ? 
                max(80, remainingWidth * (flexRatios["series"] ?? 1.0) / totalFlexRatio) : 0
            let locationWidth = visibleNonStatusColumns.contains("location") ? 
                max(90, remainingWidth * (flexRatios["location"] ?? 1.0) / totalFlexRatio) : 0
            let dateWidth = visibleNonStatusColumns.contains("date") ? 
                max(70, remainingWidth * (flexRatios["date"] ?? 1.0) / totalFlexRatio) : 0
            let createdDateWidth = visibleNonStatusColumns.contains("createdDate") ? 
                max(70, remainingWidth * (flexRatios["createdDate"] ?? 1.0) / totalFlexRatio) : 0
            
            return (statusWidth: statusWidth, nameWidth: nameWidth, seriesWidth: seriesWidth, locationWidth: locationWidth, dateWidth: dateWidth, createdDateWidth: createdDateWidth)
        } else if isIPad {
            // iPad: Use same flex ratio system as iPhone but with iPad-specific sizing
            let effectiveWidth = availableWidth ?? UIScreen.main.bounds.width
            
            // Fixed width columns that don't flex
            let statusWidth: CGFloat = 60
            let actionsWidth: CGFloat = 80 // Actions column always visible on iPad
            
            // Calculate remaining width for flexible columns
            let remainingWidth = effectiveWidth - statusWidth - actionsWidth
            
            // Get visible columns (excluding status and actions) - ensure name is always included
            let effectiveVisibleColumns = visibleColumns.union(["name"])
            let visibleFlexColumns = effectiveVisibleColumns.filter { $0 != "status" && $0 != "actions" }
            
            // If only name column is visible, it takes all remaining space
            if visibleFlexColumns.count == 1 && visibleFlexColumns.contains("name") {
                return (statusWidth: statusWidth, nameWidth: remainingWidth, seriesWidth: 0, locationWidth: 0, dateWidth: 0, createdDateWidth: 0)
            }
            
            // Define flex ratios for each column type (iPad gets more generous minimums)
            let flexRatios: [String: CGFloat] = [
                "name": 2.5,        // Name gets even more space on iPad
                "series": 1.3,      // Series gets good space
                "location": 1.4,    // Location gets good space
                "date": 1.0,        // Date columns get standard space
                "createdDate": 1.0
            ]
            
            // Calculate total flex ratio for visible columns
            let totalFlexRatio = visibleFlexColumns.reduce(0) { sum, columnId in
                sum + (flexRatios[columnId] ?? 1.0)
            }
            
            // Calculate individual widths with iPad-appropriate minimums
            let nameWidth = visibleFlexColumns.contains("name") ? 
                max(200, remainingWidth * (flexRatios["name"] ?? 1.0) / totalFlexRatio) : 0
            let seriesWidth = visibleFlexColumns.contains("series") ? 
                max(120, remainingWidth * (flexRatios["series"] ?? 1.0) / totalFlexRatio) : 0
            let locationWidth = visibleFlexColumns.contains("location") ? 
                max(130, remainingWidth * (flexRatios["location"] ?? 1.0) / totalFlexRatio) : 0
            let dateWidth = visibleFlexColumns.contains("date") ? 
                max(100, remainingWidth * (flexRatios["date"] ?? 1.0) / totalFlexRatio) : 0
            let createdDateWidth = visibleFlexColumns.contains("createdDate") ? 
                max(100, remainingWidth * (flexRatios["createdDate"] ?? 1.0) / totalFlexRatio) : 0
            
            return (statusWidth: statusWidth, nameWidth: nameWidth, seriesWidth: seriesWidth, locationWidth: locationWidth, dateWidth: dateWidth, createdDateWidth: createdDateWidth)
        }
        #endif
        // Default values for other devices
        return (statusWidth: 55, nameWidth: 120, seriesWidth: 100, locationWidth: 120, dateWidth: 90, createdDateWidth: 80)
    }

    // Computed property for selection bar background
    private var selectionBarBackground: some View {
        let useGlassmorphism = colorScheme == .dark ? 
            gradientManager.selectedDarkGradientIndex != 0 :
            gradientManager.selectedLightGradientIndex != 0
        
        if useGlassmorphism {
            return AnyView(Rectangle().fill(.regularMaterial))
        } else {
            #if os(macOS)
            return AnyView(Color(colorScheme == .dark ? NSColor.controlBackgroundColor : NSColor.windowBackgroundColor))
            #else
            return AnyView(Color(colorScheme == .dark ? UIColor.systemGray6 : UIColor.systemBackground))
            #endif
        }
    }
    
    // Carousel-specific section views (without background, shadow, padding)
    private var carouselPinnedSectionView: some View {
        PinnedSection(
            documents: documents,
            pinnedDocuments: $pinnedDocuments,
            onSelectDocument: { selectedDoc in
                onSelectDocument(selectedDoc)
            },
            document: $document,
            sidebarMode: $sidebarMode,
            isRightSidebarVisible: $isRightSidebarVisible,
            isExpanded: .constant(false), // Always collapsed in carousel
            isCarouselMode: true, // Always true for iPhone carousel cards
            showExpandButtons: shouldShowExpandButtons, // separate parameter for expand buttons
            onShowModal: {
                showPinnedModal = true
            },
            allDocumentsPosition: allDocumentsPosition, // Pass the position for iPhone dynamic heights
            isLoadingDocuments: isLoadingDocuments // Pass loading state
        )
        .modifier(CarouselHeaderStyling())
    }
    
    private var carouselWipSectionView: some View {
        WIPSection(
            documents: documents,
            wipDocuments: $wipDocuments,
            document: $document,
            sidebarMode: $sidebarMode,
            isRightSidebarVisible: $isRightSidebarVisible,
            isExpanded: .constant(false), // Always collapsed in carousel
            isCarouselMode: true, // Always true for iPhone carousel cards
            showExpandButtons: shouldShowExpandButtons, // separate parameter for expand buttons
            onShowModal: {
                showWIPModal = true
            },
            allDocumentsPosition: allDocumentsPosition, // Pass the position for iPhone dynamic heights
            isLoadingDocuments: isLoadingDocuments // Pass loading state
        )
        .modifier(CarouselHeaderStyling())
    }
    
    private var carouselSermonCalendarView: some View {
        SermonCalendar(
            documents: documents,
            calendarDocuments: calendarDocuments,
            isExpanded: .constant(false), // Always collapsed in carousel
            onShowModal: { data in
                self.calendarModalData = data 
            },
            isCarouselMode: true, // Always true for iPhone carousel cards
            showExpandButtons: shouldShowExpandButtons, // separate parameter for expand buttons
            onShowExpandModal: {
                showSchedulerModal = true
            },
            allDocumentsPosition: allDocumentsPosition // Pass the position for iPhone dynamic heights
        )
        .modifier(CarouselHeaderStyling())
    }
    
    // Add these functions before the body
    private func initializeCarouselSections() {
        let defaultSections = [
            ("Pinned", AnyView(carouselPinnedSectionView)),
            ("Work in Progress", AnyView(carouselWipSectionView)),
            ("Document Schedule", AnyView(carouselSermonCalendarView))
        ]
        
        // Load saved order or use default
        if let savedOrder = UserDefaults.standard.array(forKey: "CarouselSectionOrder") as? [String] {
            // Reorder sections based on saved order
            var orderedSections: [(String, AnyView)] = []
            for title in savedOrder {
                if let section = defaultSections.first(where: { $0.0 == title }) {
                    orderedSections.append(section)
                }
            }
            // Add any missing sections (in case new sections were added)
            for section in defaultSections {
                if !orderedSections.contains(where: { $0.0 == section.0 }) {
                    orderedSections.append(section)
                }
            }
            carouselSections = orderedSections
        } else {
            carouselSections = defaultSections
        }
    }
    
    private func saveCarouselOrder() {
        let order = carouselSections.map { $0.0 }
        UserDefaults.standard.set(order, forKey: "CarouselSectionOrder")
    }
    
    private func moveCarouselSection(from source: Int, to destination: Int) {
        // Swift's move function works differently - when moving to a higher index,
        // it inserts AFTER that index, so we need to adjust
        let adjustedDestination = source < destination ? destination + 1 : destination
        carouselSections.move(fromOffsets: IndexSet(integer: source), toOffset: adjustedDestination)
        saveCarouselOrder()
        
        // Adjust selected index if needed
        if selectedCarouselIndex == source {
            selectedCarouselIndex = destination
        } else if selectedCarouselIndex > source && selectedCarouselIndex <= destination {
            selectedCarouselIndex -= 1
        } else if selectedCarouselIndex < source && selectedCarouselIndex >= destination {
            selectedCarouselIndex += 1
        }
        
        // Save the new carousel position
        saveCarouselPosition()
    }
    
    private func togglePin(for docId: String) {
        // ✅ FIX: Use transaction to prevent flash during state updates
        var transaction = Transaction()
        transaction.disablesAnimations = true
        
        withTransaction(transaction) {
            if pinnedDocuments.contains(docId) {
                pinnedDocuments.remove(docId)
            } else {
                pinnedDocuments.insert(docId)
            }
            saveDocumentState()
        }
    }
    
    private func toggleWIP(_ docId: String) {
        // ✅ FIX: Use transaction to prevent flash during state updates
        var transaction = Transaction()
        transaction.disablesAnimations = true
        
        withTransaction(transaction) {
            if wipDocuments.contains(docId) {
                wipDocuments.remove(docId)
            } else {
                wipDocuments.insert(docId)
            }
            saveDocumentState()
        }
    }
    
private func deleteSelectedDocuments() {
        print("🗑️ deleteSelectedDocuments called with \(selectedDocuments.count) documents")
        print("🗑️ Selected document IDs: \(Array(selectedDocuments))")
        
        let fileManager = FileManager.default
        
        // Use the same directory resolution as the rest of the app (iCloud-aware)
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("🗑️ ERROR: Could not determine app documents directory")
            return
        }
        
        let trashURL = appDirectory.appendingPathComponent(".trash", isDirectory: true)
        
        print("🗑️ App directory: \(appDirectory.path)")
        print("🗑️ Trash directory: \(trashURL.path)")
        
        // Create trash directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: trashURL, withIntermediateDirectories: true, attributes: nil)
            print("🗑️ Created or verified trash directory")
        } catch {
            print("🗑️ ERROR: Error creating trash directory: \(error)")
            return
        }
        
        print("🗑️ Attempting to move \(selectedDocuments.count) documents to trash at: \(trashURL.path)")
        print("🗑️ Available documents in documents array: \(documents.count)")
        
        var successCount = 0
        var failureCount = 0
        
        for docId in selectedDocuments {
            print("🗑️ Processing document ID: \(docId)")
            if let document = documents.first(where: { $0.id == docId }) {
                let sourceURL = appDirectory.appendingPathComponent("\(document.id).canvas")
                let destinationURL = trashURL.appendingPathComponent("\(document.id).canvas")
                print("🗑️ Moving document to trash: \(document.title) (\(document.id))")
                print("🗑️ From: \(sourceURL.path)")
                print("🗑️ To: \(destinationURL.path)")
                
                // Check if source file exists
                if !fileManager.fileExists(atPath: sourceURL.path) {
                    print("🗑️ ERROR: Source file does not exist at \(sourceURL.path)")
                    failureCount += 1
                    continue
                }
                
                do {
                    // If destination file exists, remove it first
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                        print("🗑️ Removed existing file at destination")
                    }
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                    // Set the modification date to track when it was moved to trash
                    try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: destinationURL.path)
                    print("🗑️ SUCCESS: Successfully moved document to trash")
                    successCount += 1
                } catch {
                    print("🗑️ ERROR: Error moving document to trash: \(error)")
                    failureCount += 1
                }
            } else {
                print("🗑️ ERROR: Could not find document with ID: \(docId) in documents array")
                failureCount += 1
            }
        }
        
        print("🗑️ Delete operation completed. Success: \(successCount), Failures: \(failureCount)")
        
        // Clear selection
        selectedDocuments.removeAll()
        print("🗑️ Cleared selectedDocuments - now contains \(selectedDocuments.count) items")
        
        // Post notification that documents have been updated
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        print("🗑️ Posted DocumentListDidUpdate notification")
    }
    
    private func saveDocumentState() {
        let defaults = UserDefaults.standard
        defaults.set(Array(pinnedDocuments), forKey: "PinnedDocuments")
        defaults.set(Array(wipDocuments), forKey: "WIPDocuments")
        
        // ✅ FIX: Don't rebuild entire carousel - let individual sections update themselves
        // The PinnedSection and WIPSection views will automatically update when their data changes
        // This prevents the flash caused by recreating the entire carousel
        
        // ❌ REMOVED: Do not post a notification that causes this same view to reload itself.
        // The @State wrappers already handle updating the necessary child views.
        // NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
    }
    
    private func saveCarouselPosition() {
        UserDefaults.standard.set(selectedCarouselIndex, forKey: "SelectedCarouselIndex")
        UserDefaults.standard.synchronize()
    }
    
    private func clearAllDocumentSelections() {
        // Clear selections in all carousel sections
        // Note: Each section manages its own selectedDocumentId state
        // We need to send a notification to clear all selections
        NotificationCenter.default.post(
            name: NSNotification.Name("ClearDocumentSelections"),
            object: nil
        )
    }
    
    private func updateVisibleColumns() {
        // Update visible columns based on the selected filter column
        if let selectedColumn = selectedFilterColumn {
            // Show only the name column and the selected filter column
            visibleColumns = Set(["name", selectedColumn])
        } else {
            // Default: only show name column (pinned/wip/calendar icons and actions are always shown)
            visibleColumns = Set(["name"])
        }
        
        // Save column preferences
        UserDefaults.standard.set(Array(visibleColumns), forKey: "VisibleColumns")
    }
    
    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName = UserProfileManager.shared.userProfile.firstName.isEmpty ? "Friend" : UserProfileManager.shared.userProfile.firstName
        
        let greeting: String
        if hour >= 0 && hour < 12 {
            greeting = "Good Morning,"
        } else if hour >= 12 && hour < 17 {
            greeting = "Good Afternoon,"
        } else {
            greeting = "Good Evening,"
        }
        
        return "\(greeting) \(firstName)!"
    }
    
    // Extracted computed property for the dashboard header (Mac version)
    private var macDashboardHeaderView: some View {
            HStack {
            VStack(alignment: .leading, spacing: 4) {
                    Text("Dashboard")
                    .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.primary.opacity(0.7))
                    .padding(.bottom, 2)
                    
                    Text(getTimeBasedGreeting())
                    .font(.custom("InterTight-Regular", size: {
                        #if os(iOS)
                        return max(UIScreen.main.bounds.width * 0.025, 30)
                        #else
                        return 32 // Fixed size for macOS
                        #endif
                    }()))
                    .tracking(0.5)
                        .foregroundStyle(theme.primary)
                    .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                
                // Talle Logo - adapts to light/dark mode and all platforms
                Button(action: {
                    print("🎯 macOS first Talle logo button tapped!")
                    print("🎯 Setting showTallyLabelModal to true")
                    activeSheet = .tallyLabel
                    print("🎯 showTallyLabelModal is now: \(showTallyLabelModal)")
                }) {
                    Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: {
                            #if os(iOS)
                            let screenWidth = UIScreen.main.bounds.width
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            if isPhone {
                                return min(160, screenWidth * 0.3) // bigger on iPhone
                            } else {
                                return min(260, screenWidth * 0.28) // bigger on iPad
                            }
                            #else
                            return 220 // macOS: quite a bit bigger
                            #endif
                        }(), maxHeight: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? 56 : 96 // increase heights
                            #else
                            return 88 // macOS taller
                            #endif
                        }())
                }
                .buttonStyle(PlainButtonStyle())
                .help("About Tallē")
            }
        // Apply blur effect when DocumentDetailsCard or calendar modal is shown
        .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
        .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
    }
    
    // Extracted computed property for the dashboard header (iPad version)
    private var iPadDashboardHeaderView: some View {
        VStack(spacing: 12) {
            // Talle Logo row for iPad - positioned above everything
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                HStack {
                    Spacer()
                    Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: min(180, UIScreen.main.bounds.width * 0.22), maxHeight: 68)
                        .onTapGesture {
                            activeSheet = .tallyLabel
                        }
                }
                .padding(.bottom, 8) // Breathing room between logo and content below
            }
            #endif
            
            HStack {
                VStack(alignment: .leading, spacing: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 8 : 12 // iPhone: closer spacing, iPad: original spacing
                    #else
                    return 12
                    #endif
                }()) {
                    // Talle Logo row above Dashboard for iPhone only
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        HStack {
                            Spacer()
                    Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: min(110, UIScreen.main.bounds.width * 0.22), maxHeight: 40)
                                .onTapGesture {
                                    activeSheet = .tallyLabel
                                }
                        }
                        .padding(.bottom, 8) // Breathing room between logo and Dashboard
                    }
                    #endif
                
                Text("Dashboard")
                    .font(.system(size: {
                        // Responsive dashboard title size using screen bounds
                        #if os(iOS)
                        let screenWidth = UIScreen.main.bounds.width
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        if isPhone {
                            // iPhone: smaller title
                            return max(12, min(16, screenWidth * 0.035)) // 3.5% of screen width, constrained
                        } else {
                            // iPad: original sizing
                            return screenWidth * 0.022 // 2.2% of screen width
                        }
                        #else
                        return 18
                        #endif
                    }(), weight: .bold))
                    .foregroundStyle(theme.primary.opacity(0.7))
                    .padding(.bottom, 2)
                
                Text(getTimeBasedGreeting())
                    .font(.custom("InterTight-Regular", size: {
                        // Responsive greeting size using screen bounds
                        #if os(iOS)
                        let screenWidth = UIScreen.main.bounds.width
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        if isPhone {
                            // iPhone: smaller, more appropriate sizing - reduced slightly
                            let calculatedSize = screenWidth * 0.075 // 7.5% of screen width for iPhone (reduced from 8%)
                            return max(26, min(33, calculatedSize)) // Constrain between 26-33pt for iPhone (reduced from 28-35pt)
                        } else {
                            // iPad: slightly smaller sizing
                            let calculatedSize = screenWidth * 0.055 // 5.5% of screen width (reduced from 6.5%)
                            return max(40, min(70, calculatedSize)) // Constrain between 40-70pt (reduced from 45-85pt)
                        }
                        #else
                        return 52
                        #endif
                    }()))
                    .tracking(0.5)
                    .foregroundStyle(theme.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            
            // Talle Logo - adapts to light/dark mode (macOS only, iPad shows above, iPhone shows on Dashboard row)
            #if os(macOS)
            Button(action: {
                print("🎯 macOS Talle logo button tapped!")
                print("🎯 Setting showTallyLabelModal to true")
                activeSheet = .tallyLabel
                print("🎯 showTallyLabelModal is now: \(showTallyLabelModal)")
            }) {
                Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 220, maxHeight: 88)
            }
            .buttonStyle(PlainButtonStyle())
            .help("About Tallē")
            #endif
            }
        }
        .padding(.horizontal, 8)
        // Apply blur effect when DocumentDetailsCard or calendar modal is shown
        .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
        .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
    }
    
    // Landscape-specific header with bigger greeting
    private var iPadLandscapeHeaderView: some View {
        VStack(spacing: 12) {
            // Talle Logo row for iPad - positioned above everything
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                HStack {
                    Spacer()
                Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: min(180, UIScreen.main.bounds.width * 0.22), maxHeight: 68)
                        .onTapGesture {
                            activeSheet = .tallyLabel
                        }
                }
                .padding(.bottom, 8) // Breathing room between logo and content below
            }
            #endif
            
            HStack {
                VStack(alignment: .leading, spacing: 12) { // Increased spacing from 8 to 12 for more breathing room
                    Text("Dashboard")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.primary.opacity(0.7))
                        .padding(.bottom, 2)
                    
                    Text(getTimeBasedGreeting())
                        .font(.custom("InterTight-Regular", size: 52)) // Reduced from 62 to 52 for smaller greeting
                        .tracking(0.5)
                        .foregroundStyle(theme.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                
                // Talle Logo - adapts to light/dark mode (macOS only, iPad shows above, iPhone shows on Dashboard row)
                #if os(macOS)
            Button(action: {
                print("🎯 macOS Talle logo button tapped!")
                print("🎯 Setting showTallyLabelModal to true")
                activeSheet = .tallyLabel
                print("🎯 showTallyLabelModal is now: \(showTallyLabelModal)")
            }) {
                Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 220, maxHeight: 88)
            }
            .buttonStyle(PlainButtonStyle())
            .help("About Tallē")
            #endif
            }
        }
        .padding(.horizontal, 8)
        // Apply blur effect when DocumentDetailsCard or calendar modal is shown
        .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
        .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
    }
    
        
    // MARK: - macOS Modal
    @ViewBuilder
    private var macOSModal: some View {
        #if os(macOS)
        if showTallyLabelModal {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        print("🎯 macOS modal background tapped - closing")
                        showTallyLabelModal = false
                    }
                
                TallyLabelModal()
                    .frame(width: 600, height: 500)
                    .background(Color(.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .onAppear {
                        print("🎯 macOS TallyLabelModal appeared at top level!")
                    }
            }
            .zIndex(1000)
            .animation(.easeInOut(duration: 0.2), value: showTallyLabelModal)
        }
        #endif
    }
    
var body: some View {
        GeometryReader { geometry in
            let isIPad: Bool = {
                #if os(iOS)
                return UIDevice.current.userInterfaceIdiom == .pad
                #else
                return false // macOS is never an iPad
                #endif
            }()
            
            mainContentWithOverlays(isIPad: isIPad)
        }
        .overlay(macOSModal)
        .onAppear {
            // Only do essential initialization - like Apple Notes and Craft
            // Load basic UserDefaults data (fast operations)
            if let pinnedArray = UserDefaults.standard.array(forKey: "PinnedDocuments") as? [String] {
                pinnedDocuments = Set(pinnedArray)
            }
            if let wipArray = UserDefaults.standard.array(forKey: "WIPDocuments") as? [String] {
                wipDocuments = Set(wipArray)
            }
            if let calendarArray = UserDefaults.standard.array(forKey: "CalendarDocuments") as? [String] {
                calendarDocuments = Set(calendarArray)
            }
            #if os(macOS)
            // Ensure Series and Location columns are always visible by default on macOS
            visibleColumns.insert("series")
            visibleColumns.insert("location")
            // Persist the preference so it sticks across launches
            UserDefaults.standard.set(Array(visibleColumns), forKey: "VisibleColumns")
            #endif
            loadDocuments()
        }
                .onChange(of: refreshTrigger) {
loadDocuments()
        }
        .onChange(of: isCircularMenuOpen) { oldValue, newValue in
            print("🔄 Menu state changed: \(oldValue) -> \(newValue)")
            print("💾 Was sheet open before: \(wasAllDocumentsSheetOpenBeforeMenu)")
            
            // Only handle menu closing - opening is handled by onShowMorphMenu
            if !newValue && wasAllDocumentsSheetOpenBeforeMenu {
                print("✅ Menu closed - restoring sheet")
                // Small delay to ensure menu close animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAllDocumentsSheet = true
                    }
                    // Reset the tracking variable
                    wasAllDocumentsSheetOpenBeforeMenu = false
                }
            }
        }

    }
    
    // MARK: - Extracted Views to Break Up Complex Expression
    
    @ViewBuilder
    private func mainContentWithOverlays(isIPad: Bool) -> some View {
            ZStack { // Main ZStack for overlay handling
                dashboardContent // Use the extracted content view
                
                // Floating selection bar for All Documents multi-select (iPad only)
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad && isAllDocumentsEditMode {
                floatingSelectionBar
            }
            #endif
        }
        .modifier(ContentBlurModifier(isModalPresented: isModalPresented, showPinnedModal: false, showWIPModal: false, showSchedulerModal: false, showDetailsCard: showDetailsCard))
        .overlay { modalOverlayView } // Apply overlay first
        .animation(.easeInOut(duration: 0.2), value: isModalPresented || showDetailsCard)
                          .overlay(alignment: .bottom) {
             // Floating bottom bar with custom sheet overlays
             FloatingDashboardBottomBar(
                 documents: $documents,
                 pinnedDocuments: $pinnedDocuments,
                 wipDocuments: $wipDocuments,
                 calendarDocuments: $calendarDocuments,
                 onSelectDocument: onSelectDocument,
                 onPin: togglePin,
                 onWIP: toggleWIP,
                 onCalendar: toggleCalendar,
                 onDashboard: onDashboard,
                 onSearch: onSearch,
                 onNewDocument: onNewDocument,
                 onFolders: onFolders,
                 onBibleReader: onBibleReader,
                 onSmartStudy: onSmartStudy,
                 onRecentlyDeleted: onRecentlyDeleted,
                 onSettings: onSettings
             )
             .zIndex(1000) // Ensure floating bar is always on top
         }
                 // REMOVED: All Documents sheet - now integrated into scrollable content
                 .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .tallyLabel:
                TallyLabelModal()
                    .presentationBackground(.thinMaterial)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    
            case .tagManager:
                TagManager(allTags: allTags)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
                    
            case .sermonJournal(let document):
                SermonJournalView(document: document, allDocuments: documents) {
                    activeSheet = nil
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                
            case .reflectionSelection:
                ReflectionSelectionView(
                    documents: documents,
                    onSelectDocument: { document in
                        activeSheet = .sermonJournal(document)
                    },
                    onDismiss: {
                        activeSheet = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                
            case .preachItAgainDetails(let document):
                PreachItAgainDetailsView(
                    document: document,
                    onDismiss: {
                        activeSheet = nil
                    },
                    onOpenDocument: { doc in
                        activeSheet = nil
                        onSelectDocument(doc)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                
            case .documentDetails(let document):
                DocumentDetailsCard(
                    document: Binding(
                        get: { document },
                        set: { updatedDocument in
                            if let index = documents.firstIndex(where: { $0.id == updatedDocument.id }) {
                                documents[index] = updatedDocument
                            }
                        }
                    ),
                    allLocations: Array(Set(documents.compactMap { $0.variations.first?.location }.filter { !$0.isEmpty })).sorted(),
                    onDismiss: {
                        activeSheet = nil
                    }
                )
                .environment(\.themeColors, theme)
                .environment(\.colorScheme, colorScheme)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
            
            case .curatedCategory(let type):
                NavigationView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(type.rawValue)
                                .font(.custom("InterTight-Bold", size: 20))
                                .padding(.horizontal, 16)
                            curatedContentViewFor(type)
                                .padding(.horizontal, 16)
                        }
                        .padding(.top, 12)
                    }
                    .navigationTitle(type.rawValue)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { activeSheet = nil }
                        }
                    }
                    #else
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button("Done") { activeSheet = nil }
                        }
                    }
                    #endif
                    .onAppear {
                        selectedCurationType = type
                        updateContentForNewCurationType()
                        if aiCuratedSermons.isEmpty && !isGeneratingInsights {
                            generateAICuratedSermons()
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: Binding(
            get: { documentToShowInSheet != nil },
            set: { show in
                if !show {
                    UserDefaults.standard.removeObject(forKey: "editingPresentationId")
                    UserDefaults.standard.removeObject(forKey: "openToNotesStep")
                    documentToShowInSheet = nil
                }
            }
        )) {
            if let doc = documentToShowInSheet {
                PresentationManager(document: doc, isPresented: Binding(
                    get: { documentToShowInSheet != nil },
                    set: { show in
                        if !show {
                            UserDefaults.standard.removeObject(forKey: "editingPresentationId")
                            UserDefaults.standard.removeObject(forKey: "openToNotesStep")
                            documentToShowInSheet = nil
                        }
                    }
                ))
                .environment(\.themeColors, theme)
                .environment(\.colorScheme, colorScheme)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
            }
        }
        // Automatic journal prompt overlay
        .overlay {
            if journalService.showingAutoPrompt, let document = journalService.currentPromptDocument {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            journalService.dismissCurrentPrompt()
                        }
                    
                    AutomaticJournalPromptView(
                        document: document,
                        onStartJournal: {
                            journalService.dismissCurrentPrompt()
                            showSermonJournal(for: document)
                        },
                        onDismiss: {
                            journalService.dismissCurrentPrompt()
                        }
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.easeInOut(duration: 0.3), value: journalService.showingAutoPrompt)
            }
        }
        // Attach hidden sheets for journal entries list/detail
        .background(journalEntriesSheets)
        // FIXED: No more SafeAreaModifier - let iOS 26 handle safe areas naturally
    }
    
    @ViewBuilder
    private var floatingSelectionBar: some View {
                    VStack {
                        Spacer()
                        
                        HStack {
                            if selectedAllDocuments.isEmpty {
                                Button("Done") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isAllDocumentsEditMode = false
                                    }
                                }
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(theme.accent)
                                .cornerRadius(8)
                                
                                Spacer()
                            } else {
                                Text("\(selectedAllDocuments.count) selected")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button("Delete \(selectedAllDocuments.count)") {
                                    // Perform bulk delete
                                    selectedDocuments = selectedAllDocuments
                                    deleteSelectedDocuments()
                                    selectedAllDocuments.removeAll()
                                }
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(.red)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(selectionBarBackground)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20) // Moved even lower - reduced from 50 to 20
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: 20)),
                        removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: 20))
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isAllDocumentsEditMode)
                    .animation(.easeInOut(duration: 0.15), value: selectedAllDocuments.count)
                }
    
    // MARK: - ViewModifiers to Break Up Complex Expressions
    
    struct ContentBlurModifier: ViewModifier {
        let isModalPresented: Bool
        let showPinnedModal: Bool
        let showWIPModal: Bool
        let showSchedulerModal: Bool
        let showDetailsCard: Bool
        
        func body(content: Content) -> some View {
            content
                .blur(radius: isModalPresented || showPinnedModal || showWIPModal || showSchedulerModal || showDetailsCard ? 3 : 0)
                .opacity(isModalPresented || showPinnedModal || showWIPModal || showSchedulerModal || showDetailsCard ? 0.7 : 1.0)
        }
    }
    
    struct SafeAreaModifier: ViewModifier {
        let isIPad: Bool
        
        func body(content: Content) -> some View {
        #if os(iOS)
            content.modifier(IgnoresSafeAreaModifier(isIPad: isIPad))
            #else
            content.ignoresSafeArea()
        #endif
        }
    }
    
    // NEW: Extracted computed property for the main dashboard layout content
    @ViewBuilder
    private var mainDashboardContent: some View {
        // NEW: Simple dashboard layout with proper iOS 26 safe area handling
        ZStack {
            // No background needed - let the gradient from MainLayout show through
            Color.clear
                .ignoresSafeArea(.all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    // Greeting section that scrolls off naturally
                    greetingSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Curated sermons section (Spotify/Dwell-like)
                    curatedSermonsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                    
                    // Documents section that scrolls naturally
                    VStack(spacing: 0) {
                        // Docs header that scrolls with content
                        docsHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                        
                        documentsSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 100) // Space for bottom bar
                    }
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .safeAreaPadding(.top, 5)
            .contentMargins(.top, 10, for: .scrollContent)
            
            // Liquid Glass Logo Header with proper glassmorphism
            VStack {
                HStack {
                    Spacer()
                    
                    // Liquid Glass Logo Container
                    Group {
        #if os(macOS)
                        Button(action: {
                            activeSheet = .tallyLabel
                        }) {
                            Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 26)
                        }
                        .buttonStyle(.plain)
                        .help("Click to see Tallē label")
        #else
                        Button(action: {
                            activeSheet = .tallyLabel
                        }) {
                            Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 26)
                        }
                        .buttonStyle(.plain)
        #endif
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var dashboardContent: some View {
        if isLoadingDocuments {
            // Show skeleton loading when documents are loading (iOS only)
            #if os(iOS)
            DashboardSkeleton()
            #else
            // On macOS, show content immediately without skeleton
            mainDashboardContent
            #endif
        } else {
            mainDashboardContent
        }
    }

    // NEW: Greeting section that scrolls off naturally
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dashboard")
                .font(.system(size: {
                                        #if os(iOS)
                    let screenWidth = UIScreen.main.bounds.width
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if isPhone {
                        return max(12, min(16, screenWidth * 0.035))
                                        } else {
                        return screenWidth * 0.022
                                        }
                                        #else
                    return 18
                                        #endif
                }(), weight: .bold))
                .foregroundStyle(theme.primary.opacity(0.7))
                .padding(.bottom, 2)

            Text(getTimeBasedGreeting())
                .font(.custom("InterTight-Regular", size: {
                                        #if os(iOS)
                    let screenWidth = UIScreen.main.bounds.width
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if isPhone {
                        let calculatedSize = screenWidth * 0.075
                        return max(26, min(33, calculatedSize))
                                        } else {
                        let calculatedSize = screenWidth * 0.055
                        return max(40, min(70, calculatedSize))
                                        }
                                        #else
                    return 52
                                        #endif
                }()))
                .tracking(0.5)
                .foregroundStyle(theme.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 40) // Reduced space for floating logo
    }
    
        // NEW: Simple docs header that scrolls naturally
    private var docsHeader: some View {
        VStack(spacing: 16) {
            // Main header with icons
            HStack {
                Text("Documents")
                    .font(.custom("InterTight-Bold", size: 24))
                    .foregroundStyle(theme.primary)

                            Spacer()
                            
                // Circular icon controls
                HStack(spacing: 8) {
                    // Search Button
                    Button(action: {
                        // Trigger search sheet
                        onSearch?()
                        HapticFeedback.impact(.light)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.black, in: Circle())
                    }
                    
                    // Filter Dropdown (iOS only)
                    #if os(iOS)
                    Menu {
                        // Title and divider
                        Text("Filter Documents")
                            .font(.custom("InterTight-Bold", size: 14))
                            .foregroundStyle(theme.primary)
                        
                        Divider()
                        
                        ForEach(ListColumn.allColumns) { column in
                            if column.id != "name" && column.id != "date" && column.id != "createdDate" {
                                Button(action: {
                                    // Regular filter columns (dates are handled in Sort)
                                    selectedFilterColumn = selectedFilterColumn == column.id ? nil : column.id
                                    isDateFilterExplicitlySelected = false
                                    selectedTags.removeAll()
                                    updateVisibleColumns()
                                    tableRefreshID = UUID()
                                    HapticFeedback.impact(.light)
                                }) {
                                    Label {
                                        Text(column.title)
                                    } icon: {
                                        Image(systemName: column.icon)
                                    }
                                }
                        .disabled({
                                    // Gray out (disable) the active filter to show it's selected
                                    let isActive = (column.id == "series" && selectedFilterColumn == "series") ||
                                                  (column.id == "location" && selectedFilterColumn == "location") ||
                                                  (column.id == "presentedDate" && selectedFilterColumn == "presentedDate")
                                    return isActive
                                }())
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            selectedFilterColumn = nil
                            selectedTags.removeAll()
                            isDateFilterExplicitlySelected = false
                            updateVisibleColumns()
                            tableRefreshID = UUID()
                            HapticFeedback.impact(.light)
                        }) {
                            Label {
                                Text("Clear")
                            } icon: {
                                Image(systemName: "xmark.circle")
                            }
                        }
                        .disabled({
                            // Gray out Clear when it's the active state (no filters)
                            let isActive = selectedFilterColumn == nil && selectedTags.isEmpty && !isDateFilterExplicitlySelected
                            return isActive
                        }())
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(selectedFilterColumn != nil ? theme.accent : Color.orange, in: Circle())
                    }
                    #endif
                    
                    // Sort Dropdown  
                    Menu {
                        // Title and divider
                        Text("Sort Documents")
                            .font(.custom("InterTight-Bold", size: 14))
                            .foregroundStyle(theme.primary)
                        
                        Divider()
                        
                        Button(action: {
                            selectedSortColumn = "name"
                            updateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: "textformat")
                                Text("Name")
                                if selectedSortColumn == "name" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedSortColumn = "dateModified"
                            updateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                Text("Date Modified")
                                if selectedSortColumn == "dateModified" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }

                        Button(action: {
                            selectedSortColumn = "dateCreated"
                            updateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Date Created")
                                if selectedSortColumn == "dateCreated" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedSortColumn = "status"
                            updateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: "star")
                                Text("Status")
                                if selectedSortColumn == "status" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedSortColumn = "series"
                            updateDocumentSort()
                        }) {
                            HStack {
                                Image(systemName: "square.stack")
                                Text("Series")
                                if selectedSortColumn == "series" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                        Button(action: {
                            selectedSortColumn = "location"
                            updateDocumentSort()
                        }) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text("Location")
                                if selectedSortColumn == "location" {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }

                        Divider()
                        
                        Button(action: {
                            isAscendingSortOrder.toggle()
                            updateDocumentSort()
                            HapticFeedback.impact(.light)
                        }) {
                            HStack {
                                Image(systemName: isAscendingSortOrder ? "arrow.up" : "arrow.down")
                                Text(isAscendingSortOrder ? "Ascending" : "Descending")
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.green, in: Circle())
                    }
                    
                    // Tags Dropdown
                    Menu {
                        // Title and divider
                        Text("Document Tags")
                            .font(.custom("InterTight-Bold", size: 14))
                            .foregroundStyle(theme.primary)
                        
                        Divider()
                        
                        if allTags.isEmpty {
                            Text("No tags available")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(allTags, id: \.self) { tag in
                                Button(action: {
                                    selectedFilterColumn = nil
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                    updateVisibleColumns()
                                    tableRefreshID = UUID()
                                    HapticFeedback.impact(.light)
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(colorManager.color(for: tag))
                                            .frame(width: 8, height: 8)
                                        Text(tag)
                                        if selectedTags.contains(tag) {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.accent)
                                        }
                                    }
                                }
                            }
                            
                            if !selectedTags.isEmpty {
                                Divider()
                                Button("Clear All Tags") {
                                    selectedTags.removeAll()
                                    updateVisibleColumns()
                                    tableRefreshID = UUID()
                                    HapticFeedback.impact(.light)
                                }
                            }
                            
                            Divider()
                            
                            Button(action: {
                                activeSheet = .tagManager
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Manage")
                                    Spacer()
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Image(systemName: "tag")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(!selectedTags.isEmpty ? theme.accent : Color.blue, in: Circle())
                            
                            // Badge for selected tags count
                            if !selectedTags.isEmpty {
                                Text("\(selectedTags.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.red, in: Circle())
                                    .offset(x: 12, y: -12)
                            }
                        }
                    }
                }
            }
            
            // Helpful tooltip
            HStack {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary.opacity(0.7))
                
                Text("Long press on document to assign Pin, WIP, Schedule or view Document Details")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary.opacity(0.7))
                
                Spacer()
            }
            .padding(.top, 8)

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    


    // NEW: Computed property to determine if any modal is presented
    private var isModalPresented: Bool {
        showDetailsCard || calendarModalData != nil || documentToShowInSheet != nil
    }
    
    // NEW: Animated dashboard header that shrinks/grows based on scroll progress
    @ViewBuilder
    private func animatedDashboardHeader(progress: CGFloat, safeArea: EdgeInsets) -> some View {
                        VStack(spacing: 0) {
            // Talle Logo - positioned at top
            
            
            // Main header content
            HStack {
                VStack(alignment: .leading, spacing: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 8 : 12
                    #else
                    return 12
                    #endif
                }()) {
                    // Talle Logo for iPhone only
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        HStack {
                            Spacer()
                            Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: min(80, UIScreen.main.bounds.width * 0.2), maxHeight: 30)
                                    .onTapGesture {
                                    activeSheet = .tallyLabel
                                }
                        }
                        .padding(.bottom, 8)
                    }
                    #endif
                    
                                         // Greeting content that fades away first
                     if progress < 0.6 { // Show greeting until 60% scroll progress
                         VStack(alignment: .leading, spacing: 4) {
                             Text("Dashboard")
                                 .font(.system(size: {
                                        #if os(iOS)
                                     let screenWidth = UIScreen.main.bounds.width
                                     let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                     if isPhone {
                                         return max(12, min(16, screenWidth * 0.035))
                                     } else {
                                         return screenWidth * 0.022
                                     }
                                        #else
                                     return 18
                                        #endif
                                 }(), weight: .bold))
                                 .foregroundStyle(theme.primary.opacity(0.7))
                                 .padding(.bottom, 2)
                             
                             Text(getTimeBasedGreeting())
                                 .font(.custom("InterTight-Regular", size: {
                                     #if os(iOS)
                                     let screenWidth = UIScreen.main.bounds.width
                                     let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                     if isPhone {
                                         let calculatedSize = screenWidth * 0.075
                                         return max(26, min(33, calculatedSize))
                                     } else {
                                         let calculatedSize = screenWidth * 0.055
                                         return max(40, min(70, calculatedSize))
                                     }
                                     #else
                                     return 52
                                     #endif
                                 }()))
                                 .tracking(0.5)
                                 .foregroundStyle(theme.primary)
                                 .lineLimit(2)
                                 .multilineTextAlignment(.leading)
                                 .opacity(1.0 - (progress * 1.7)) // Fade out faster (by 60% progress)
                         }
                     }
                }
                Spacer()
                

                
                // Talle Logo for macOS
                #if os(macOS)
                Button(action: {
                    activeSheet = .tallyLabel
                }) {
                    Image(colorScheme == .dark ? "Talle - Dark" : "Talle - Light")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 150, maxHeight: 60)
                }
                .buttonStyle(PlainButtonStyle())
                .help("About Tallē")
                #endif
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, safeArea.top + 10)
        .background(
            // Add background that becomes more prominent as header shrinks
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(progress * 0.8)
        )
    }
    
    // REMOVED: Carousel sections view - no longer needed
    
        // NEW: Documents section (simplified - header is now sticky)
    private var documentsSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(sortedFilteredDocuments, id: \.id) { document in
                ModernDocumentRow(
                    document: document,
                    onTap: { 
                        // Open document directly like all documents sheet does
                        self.document = document
                        self.sidebarMode = .details
                        self.isRightSidebarVisible = true
                    },
                    onShowDetails: { showDetails(for: document) },
                    onPin: { togglePin(for: document.id) },
                    onWIP: { toggleWIP(document.id) },
                    onCalendar: { toggleCalendar(document.id) },
                    onCalendarAction: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            documentToShowInSheet = document
                        }
                    },
                    onDelete: { deleteSelectedDocuments() },
                    selectedTags: selectedTags,
                    selectedFilterColumn: selectedFilterColumn,
                    dateFilterType: dateFilterType
                )
                .environment(\.documentStatus, DocumentStatus(
                    isPinned: pinnedDocuments.contains(document.id),
                    isWIP: wipDocuments.contains(document.id),
                    isScheduled: calendarDocuments.contains(document.id)
                ))
            }
        }
    }

    // NEW: Extracted computed property for modal overlays
    @ViewBuilder
    private var modalOverlayView: some View {
        // Overlay for DocumentDetailsCard (iPad and macOS only, iPhone uses sheet)
        let shouldShowDetailsCard: Bool = {
            #if os(iOS)
            return UIDevice.current.userInterfaceIdiom == .pad && showDetailsCard
            #else
            return showDetailsCard
            #endif
        }()
        
        if shouldShowDetailsCard, let document = selectedDetailsDocument {
            // Dismiss layer
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetailsCard = false
                    }
                }

            // Document Details Card
            DocumentDetailsCard(
                document: Binding(
                    get: { document },
                    set: { updatedDocument in
                        if let index = documents.firstIndex(where: { $0.id == updatedDocument.id }) {
                            documents[index] = updatedDocument
                        }
                    }
                ),
                allLocations: Array(Set(documents.compactMap { $0.variations.first?.location }.filter { !$0.isEmpty })).sorted(),
                onDismiss: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetailsCard = false
                    }
                }
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
            ))
        }
        // Overlay for PresentationNotesModal (Calendar Modal)
        if let data = calendarModalData {
             // Dismiss layer
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        calendarModalData = nil
                    }
                }

            // Modal Content - Corrected Initialization
            PresentationNotesModal(
                presentationId: data.id, // Use data.id
                document: data.document, // Pass the full document object
                initialNotes: data.notes, // Pass initial notes
                initialTodoItems: data.todoItems, // Pass initial todos
                onDismiss: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        calendarModalData = nil
                    }
                    loadDocuments()
                }
            )
            // Add styling consistent with other overlays if needed
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
            ))
        }


    }

    private func setup() {
        print("📝 Setup function called")
        // Load documents
        loadDocuments()
        
        // Load calendar documents from UserDefaults (these control which icons are blue)
        if let savedCalendarDocuments = UserDefaults.standard.array(forKey: "CalendarDocuments") as? [String] {
            calendarDocuments = Set(savedCalendarDocuments)
        }
        
        // Update blue icons to only show for documents with upcoming schedules
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Create a new set for documents with future schedules
            var docsWithFutureSchedules = Set<String>()
            
            // Go through all documents
            for document in self.documents {
                if self.hasUpcomingSchedules(for: document) {
                    // If the document has upcoming schedules, it should have a blue icon
                    docsWithFutureSchedules.insert(document.id)
                }
            }
            
            // Update calendarDocuments set (controls which icons are blue)
            self.calendarDocuments = docsWithFutureSchedules
            
            // Save the updated calendarDocuments
            UserDefaults.standard.set(Array(self.calendarDocuments), forKey: "CalendarDocuments")
            UserDefaults.standard.synchronize()
            
            // Trigger UI refresh
            self.refreshTrigger.toggle()
        }
    }
    
    private func loadDocuments() {
        // Only set loading state if this isn't a swipe-down navigation
        if !isSwipeDownNavigation {
            isLoadingDocuments = true
        }
        
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("❌ Could not find documents directory")
            isLoadingDocuments = false
            return
        }
        
        print("📝 Loading documents from: \(appDirectory.path)")
        
        do {
            // Create app directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            print("📁 Created or verified app directory at: \(appDirectory.path)")
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📝 Found \(fileURLs.count) document files")
            
            let loadedDocuments = fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    return doc
                } catch {
                    print("❌ Error loading document at \(url): \(error)")
                    return nil
                }
            }
            
            print("📝 Successfully loaded \(loadedDocuments.count) documents")
            
            // Sort documents based on selected column and direction
            let sortedDocuments = sortDocuments(loadedDocuments)
            print("📝 Sorted documents list contains \(sortedDocuments.count) documents")
            
            // Explicitly update documents on the main thread
            DispatchQueue.main.async {
                self.documents = sortedDocuments
                print("📝 Updated documents state with \(self.documents.count) documents")
                
                // Schedule journal prompts for recently preached sermons
                journalService.scheduleJournalPrompts(for: sortedDocuments)
                // Force refresh UI
                self.tableRefreshID = UUID()
                // Refresh carousel sections after documents are loaded
                self.initializeCarouselSections()
                // Set loading complete
                self.isLoadingDocuments = false
            }
            
        } catch {
            print("❌ Error loading documents: \(error)")
            DispatchQueue.main.async {
                self.documents = []
                print("❌ Set documents to empty array due to error")
                // Force refresh UI
                self.tableRefreshID = UUID()
                // Refresh carousel sections even on error to show empty state
                self.initializeCarouselSections()
                // Set loading complete even on error
                self.isLoadingDocuments = false
            }
        }
    }
    
    // Extracted computed property for the "All Documents" section header
    private var documentSectionHeader: some View {
        #if os(iOS)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #else
        let isIPad = false
        let isPhone = false
        #endif
        
        return Group {
            if isPhone {
                // iPhone: Tall header with stacked rows
                iPhoneDocumentHeader
            } else {
                // iPad/macOS: Original horizontal layout, but now with matching horizontal padding
                GeometryReader { geometry in
                    VStack {
                        #if os(macOS)
                        Spacer() // Add spacer above for vertical centering on macOS
                        #endif
                        
                        iPadMacDocumentHeader
                            .padding(.horizontal, {
                                #if os(iOS)
                                let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                                if isIPad {
                                    // Match the table's horizontal padding logic
                                    return showFloatingSidebar ? 24 : 16
                                } else {
                                    return 16
                                }
                                #else
                                return 16
                                #endif
                            }())
                        
                        #if os(macOS)
                        Spacer() // Add spacer below for vertical centering on macOS
                        #endif
                    }
                }
                .frame(height: 90) // Approximate header height
            }
        }
    }
    
    // iPhone-specific header with stacked rows
    private var iPhoneDocumentHeader: some View {
        VStack(spacing: 0) {
            // Grab bar for swipe gestures
            GrabBar()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Toggle between default and expanded on tap
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if allDocumentsPosition == .expanded {
                            allDocumentsPosition = .default
                        } else {
                            allDocumentsPosition = .expanded
                        }
                    }
                    // Add haptic feedback
                    HapticFeedback.impact(.light)
                }
            
            VStack(spacing: 10) { // Increased spacing for better breathing room
                // Title row - matching carousel header style
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12)) // Match carousel icon size
                        .foregroundStyle(theme.primary)
                    Text("All Docs (\(filteredDocuments.count))")
                        .font(.custom("InterTight-Medium", size: 14)) // Match carousel header font size
                        .foregroundStyle(theme.primary)
                    Spacer()
                    
                    // Clear all filters button
                    if !selectedTags.isEmpty || selectedFilterColumn != nil {
                        Button("Clear") {
                            selectedTags.removeAll()
                            selectedFilterColumn = nil
                            updateVisibleColumns()
                            tableRefreshID = UUID()
                            
                            // Haptic feedback
                            HapticFeedback.impact(.light)
                        }
                        .font(.custom("InterTight-Medium", size: 11)) // Smaller clear button
                        .foregroundStyle(theme.accent)
                    }
                }
            
            // Filter selection row - Segmented control on left, filter options on right
            HStack(spacing: 12) {
                // Segmented control for category selection (left side)
                ZStack {
                    // Background container
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.secondary.opacity(0.1))
                        .frame(width: 120, height: 32) // Bigger size
                    
                    // Sliding background indicator
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.accent)
                        .frame(width: 56, height: 28)
                        .offset(x: selectedFilterCategory == "Filter" ? -28 : 28) // Filter left, Tags right
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedFilterCategory)
                    
                    // Category buttons
                    HStack(spacing: 0) {
                        Button(action: {
                            selectedFilterCategory = "Filter"
                            // Haptic feedback
                            HapticFeedback.impact(.light)
                        }) {
                            Text("Filter")
                                .font(.custom("InterTight-Medium", size: 11))
                                .foregroundStyle(selectedFilterCategory == "Filter" ? .white : theme.primary)
                                .frame(width: 56, height: 28)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            selectedFilterCategory = "Tags"
                            // Haptic feedback
                            HapticFeedback.impact(.light)
                        }) {
                            Text("Tags")
                                .font(.custom("InterTight-Medium", size: 11))
                                .foregroundStyle(selectedFilterCategory == "Tags" ? .white : theme.primary)
                                .frame(width: 56, height: 28)
                        }
                        .buttonStyle(.plain)
                        .opacity(allTags.isEmpty ? 0.4 : 1.0) // Dim if no tags available
                        .disabled(allTags.isEmpty)
                    }
                }
                .frame(width: 120, height: 32)
                
                // Info button for tag management (between Tags button and filter area)
                if selectedFilterCategory == "Tags" && !allTags.isEmpty {
                    Button(action: {
                        showTagManager = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }
                
                // Single scrollable filter area (right side)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        if selectedFilterCategory == "Filter" {
                            // Show columns
                    ForEach(ListColumn.allColumns) { column in
                                if column.id != "name" { // Exclude name column
                                    Button(action: {
                                        // Clear any tag selection
                                        selectedTags.removeAll()
                                        
                                        // Toggle column selection (only one at a time)
                                        if selectedFilterColumn == column.id {
                                            selectedFilterColumn = nil
                                        } else {
                                            selectedFilterColumn = column.id
                                        }
                                        
                                        updateVisibleColumns()
                                        tableRefreshID = UUID()
                                        
                                        // Haptic feedback
                                        HapticFeedback.impact(.light)
                                    }) {
                                        HStack(spacing: 3) { // Increased from 2 to 3
                                            Image(systemName: column.icon)
                                                .font(.system(size: 10)) // Increased from 8 to 10
                                            Text(column.title)
                                                .font(.custom("InterTight-Medium", size: 11)) // Increased from 9 to 11
                                        }
                                        .foregroundStyle(selectedFilterColumn == column.id ? .white : theme.primary)
                                        .padding(.horizontal, 10) // Increased from 6 to 10
                                        .padding(.vertical, 6) // Increased from 4 to 6
                                        .background(
                                            RoundedRectangle(cornerRadius: 7) // Increased from 5 to 7
                                                .fill(selectedFilterColumn == column.id ? theme.accent : Color.clear)
                                                .stroke(theme.accent, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else if selectedFilterCategory == "Tags" && !allTags.isEmpty {
                            // Show tags
                            ForEach(allTags, id: \.self) { tag in
                                Button(action: {
                                    // Clear any column selection
                                    selectedFilterColumn = nil
                                    
                                    // Toggle tag selection (only one at a time)
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.removeAll()
                                        selectedTags.insert(tag)
                                    }
                                    
                                    updateVisibleColumns()
                                    tableRefreshID = UUID()
                                    
                                    // Haptic feedback
                                    HapticFeedback.impact(.light)
                                }) {
                                    Text(tag)
                                        .font(.custom("InterTight-Medium", size: 12)) // Increased from 10 to 12
                                        .foregroundStyle(selectedTags.contains(tag) ? .white : tagColor(for: tag))
                                        .padding(.horizontal, 12) // Increased from 8 to 12
                                        .padding(.vertical, 6) // Increased from 4 to 6
                                        .background(
                                            RoundedRectangle(cornerRadius: 7) // Increased from 5 to 7
                                                .fill(selectedTags.contains(tag) ? tagColor(for: tag) : Color.clear)
                                                .stroke(tagColor(for: tag), lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6) // Add vertical padding to prevent clipping
                    .padding(.trailing, 8)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
                .contentMargins(.horizontal, 8, for: .scrollContent)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 4) // Add breathing room above
            .padding(.bottom, 6) // Add breathing room below
            } // Close inner VStack(spacing: 10)
        } // Close outer VStack(spacing: 0)
        .padding(.horizontal, 12) // Reduced from 16 to match carousel padding
        .padding(.top, 12) // Reduced from 16 to match carousel padding
        .padding(.bottom, 12) // Reduced from 20 to match carousel padding
        .onAppear {
            // Default to Filter category
            selectedFilterCategory = "Filter"
        }


        #if os(macOS)
        .background(
            showTallyLabelModal ? Color.red.opacity(0.1) : Color.clear
        )
        #endif
        .overlay {
            #if os(macOS)
            Group {
                if showTallyLabelModal {
                    ZStack {
                        // Semi-transparent background
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                print("🎯 Background tapped - closing modal")
                                showTallyLabelModal = false
                            }
                            .onAppear {
                                print("🎯 Overlay background appeared!")
                            }
                        
                        // Modal content
                        TallyLabelModal()
                            .frame(width: 600, height: 500)
                            .background(Color(.windowBackgroundColor))
                            .cornerRadius(12)
                            .shadow(radius: 20)
                            .onAppear {
                                print("🎯 TallyLabelModal appeared on macOS")
                            }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showTallyLabelModal)
                } else {
                    EmptyView()
                        .onAppear {
                            print("🎯 Overlay condition: showTallyLabelModal is false")
                        }
                }
            }
            .onAppear {
                print("🎯 Overlay block reached on macOS")
            }
            #endif
        }
    }
    
    // iPad/macOS header (original layout)
    private var iPadMacDocumentHeader: some View {
                        #if os(iOS)
                        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                        #else
                        let isIPad = false
                        #endif
                        
        return VStack(spacing: 0) {
            // iPad-specific grab bar at the top of the header
            if isIPad {
                GeometryReader { geometry in
                    HStack {
                        Spacer()
                        GrabBar(width: 160) // Pass width directly to GrabBar component
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Toggle between default and expanded on tap
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if allDocumentsPosition == .expanded {
                                allDocumentsPosition = .default
                            } else {
                                allDocumentsPosition = .expanded
                            }
                        }
                        // Add haptic feedback
                        HapticFeedback.impact(.light)
                    }
                    .padding(.horizontal, {
                        #if os(iOS)
                        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                        if isIPad {
                            return showFloatingSidebar ? 24 : 16
                        } else {
                            return 16
                        }
                        #else
                        return 16
                        #endif
                    }())
                    .padding(.bottom, 12) // Space between grab bar and header content
                }
                .frame(height: 40) // Fixed height for the grab bar area
            }
            
            HStack(spacing: 6) {
            // Left side - Title
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.custom("InterTight-Regular", size: 16))
                    .foregroundStyle(theme.primary)
                Text("All Docs (\(filteredDocuments.count))")
                    .font(.custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.primary)
                
                Menu {
                    ForEach(ListColumn.allColumns) { column in
                        if column.id != "name" && !(isIPad && column.id == "presentedDate") {
                            Toggle(column.title, isOn: Binding(
                                get: { visibleColumns.contains(column.id) },
                                set: { isOn in
                                    if isOn {
                                        visibleColumns.insert(column.id)
                                        
                                        // iPad mutual exclusion: only one date column at a time
                                        if isIPad {
                                            if column.id == "date" && visibleColumns.contains("createdDate") {
                                                visibleColumns.remove("createdDate")
                                            } else if column.id == "createdDate" && visibleColumns.contains("date") {
                                                visibleColumns.remove("date")
                                            }
                                        }
                                    } else {
                                        visibleColumns.remove(column.id)
                                    }
                                    // Save column preferences
                                    UserDefaults.standard.set(Array(visibleColumns), forKey: "VisibleColumns")
                                }
                            ))
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text("My List View")
                            .font(.system(size: 13))
                            .foregroundStyle(colorScheme == .dark ? .white : Color(.sRGB, white: 0.3))
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 11))
                            .foregroundStyle(colorScheme == .dark ? .white : Color(.sRGB, white: 0.3))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ?
                                Color(.sRGB, white: isViewButtonHovering ? 0.25 : 0.22) :
                                Color(.sRGB, white: isViewButtonHovering ? 0.92 : 0.95))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isViewButtonHovering = hovering
                        #if os(macOS)
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                        #endif
                    }
                }
                .fixedSize()
            }
            
            if !allTags.isEmpty {
                Spacer().frame(width: 20)
                
                // Tags section
                HStack(spacing: 6) {
                    Text("Tags")
                        .font(.custom("InterTight-Medium", size: 13))
                        .tracking(0.3)
                        .foregroundStyle(theme.primary)
                    
                    Button(action: {
                        showTagManager = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.primary)
                    }
                    .buttonStyle(.plain)
                    #if os(macOS)
                    .opacity(isHoveringInfo ? 0.6 : 1.0)
                    .onHover { hovering in
                        isHoveringInfo = hovering
                    }
                    #endif
                    .popover(isPresented: $showTagManager, arrowEdge: .bottom) {
                        TagManager(allTags: allTags)
                            #if os(macOS)
                            .background(Color(.windowBackgroundColor))
                            #elseif os(iOS)
                            .background(Color(UIColor.systemBackground))
                            #endif
                    }
                    
                    // Tag filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(allTags, id: \.self) { tag in
                                Button(action: {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                    
                                    // Update refresh ID to trigger table reload
                                    tableRefreshID = UUID()
                                }) {
                                    Text(tag)
                                        .font(.custom("InterTight-Medium", size: 12))
                                        .tracking(0.7)
                                        .foregroundStyle(tagColor(for: tag))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 7) // Increased from 5 to 7
                                                .stroke(tagColor(for: tag), lineWidth: 1.5)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 7) // Increased from 5 to 7
                                                        .fill(Color(colorScheme == .dark ? .black : .white).opacity(0.1))
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .opacity(selectedTags.isEmpty || selectedTags.contains(tag) ? 1.0 : 0.3)
                                .onHover { isHovered in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        hoveredTag = isHovered ? tag : nil
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 2)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .all)
                    .contentMargins(.horizontal, 10, for: .scrollContent)
                }
            }

            Spacer()
            } // Close HStack
        }
        .padding(.horizontal, {
            #if os(macOS)
            return 28
            #else
            return isIPad ? 24 : 72
            #endif
        }())
        .padding(.top, isIPad ? 20 : 12)
        .padding(.bottom, isIPad ? 16 : 8)
    }
    

    
    private var topContainers: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 24) {
                #if os(macOS)
                pinnedSectionView
                    .frame(maxWidth: .infinity)
                    .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
                    .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
                wipSectionView
                    .frame(maxWidth: .infinity)
                    .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
                    .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
                sermonCalendarView
                    .frame(maxWidth: .infinity)
                    .blur(radius: showDetailsCard ? 3 : 0)
                    .opacity(showDetailsCard ? 0.7 : 1.0)
                #else
                pinnedSectionView
                    .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
                    .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
                wipSectionView
                    .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
                    .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
                sermonCalendarView
                    .blur(radius: showDetailsCard ? 3 : 0)
                    .opacity(showDetailsCard ? 0.7 : 1.0)
                #endif
            }
            .frame(minWidth: 1000, maxWidth: 1600) // Restore original width for topContainers
            .frame(minHeight: 238)  // Increased by 10 points from 228 to 238
        }
        .frame(maxWidth: .infinity, alignment: .center) // Changed .infinity
        .frame(minHeight: 250)  // Increased by 10 points from 240 to 250
    }
    
    private func sortDocuments(_ docs: [Letterspace_CanvasDocument]) -> [Letterspace_CanvasDocument] {
        docs.sorted { (doc1: Letterspace_CanvasDocument, doc2: Letterspace_CanvasDocument) -> Bool in
            let result: Bool
            
            if selectedColumn == .name {
                let title1 = doc1.title.isEmpty ? "Untitled" : doc1.title
                let title2 = doc2.title.isEmpty ? "Untitled" : doc2.title
                result = title1.localizedCompare(title2) == .orderedAscending
            }
            else if selectedColumn == .date {
                switch dateFilterType {
                case .modified:
                    result = doc1.modifiedAt < doc2.modifiedAt
                case .created:
                    result = doc1.createdAt < doc2.createdAt
                }
            }
            else if selectedColumn == .series {
                // For now, just compare if series exists
                if doc1.series == nil && doc2.series == nil {
                    result = false
                } else if doc1.series == nil {
                    result = false
                } else if doc2.series == nil {
                    result = true
                } else {
                    result = doc1.series!.name.localizedCompare(doc2.series!.name) == .orderedAscending
                }
            }
            else if selectedColumn == .location {
                // Sort by location if available
                let loc1 = doc1.variations.first?.location ?? ""
                let loc2 = doc2.variations.first?.location ?? ""
                result = loc1.localizedCompare(loc2) == .orderedAscending
            }
            else if selectedColumn == .createdDate {
                result = doc1.createdAt < doc2.createdAt
            }
            else if selectedColumn == .presentedDate {
                let date1 = doc1.variations.first?.datePresented
                let date2 = doc2.variations.first?.datePresented
                if date1 == nil && date2 == nil {
                    result = false
                } else if date1 == nil {
                    result = false
                } else if date2 == nil {
                    result = true
                } else {
                    result = date1! < date2!
                }
            }
            else {
                // Default to sorting by modified date
                result = doc1.modifiedAt < doc2.modifiedAt
            }
            
            return sortAscending ? result : !result
        }
    }
    
    private func toggleCalendar(_ documentId: String) {
        // Find the document first
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        var updatedDoc = documents[index]
        
        if calendarDocuments.contains(documentId) {
            // Remove from calendar
            calendarDocuments.remove(documentId)
            
            // Clear scheduling information
            if var firstVariation = updatedDoc.variations.first {
                firstVariation.datePresented = nil
                firstVariation.serviceTime = nil
                firstVariation.notes = nil
                updatedDoc.variations[0] = firstVariation
            }
        } else {
            // Add to calendar
            calendarDocuments.insert(documentId)
        }
        
        // Update the document in our array
        documents[index] = updatedDoc
        
        // Save the document
        updatedDoc.save()
        
        // Save calendar documents state
        UserDefaults.standard.set(Array(calendarDocuments), forKey: "CalendarDocuments")
        UserDefaults.standard.synchronize()
        
        // ✅ FIX: Don't rebuild entire carousel - let calendar section update itself
        // The SermonCalendar view will automatically update when calendarDocuments changes
        
        // Force UI update
        DispatchQueue.main.async {
            // Post notification to update views
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        }
    }
    
    private func saveFolders() {
        let foldersToSave = folders.map { folder in
            // Create a copy without isEditing state for storage
            Folder(id: folder.id, name: folder.name, isEditing: false)
        }
        if let encoded = try? JSONEncoder().encode(foldersToSave) {
            UserDefaults.standard.set(encoded, forKey: "SavedFolders")
        }
    }
    
    private func loadFolders() {
        if let savedData = UserDefaults.standard.data(forKey: "SavedFolders"),
           let decodedFolders = try? JSONDecoder().decode([Folder].self, from: savedData) {
            // Restore folders with isEditing set to false
            folders = decodedFolders.map { Folder(id: $0.id, name: $0.name, isEditing: false) }
            saveFolders() // Save the default folders
        } else {
            // Initialize with default folders if none are saved
            folders = [
                Folder(id: UUID(), name: "Sermons", isEditing: false),
                Folder(id: UUID(), name: "Bible Studies", isEditing: false),
                Folder(id: UUID(), name: "Notes", isEditing: false),
                Folder(id: UUID(), name: "Archive", isEditing: false)
            ]
            saveFolders() // Save the default folders
        }
    }
    
    private var allTags: [String] {
        var tags: Set<String> = []
        for document in documents {
            if let documentTags = document.tags {
                tags.formUnion(documentTags)
            }
        }
        return Array(tags).sorted()
    }
    
    // Function to update document sorting
    private func updateDocumentSort() {
        // Force table refresh with new sort settings
        tableRefreshID = UUID()
        
        // Post notification for any listening components
        NotificationCenter.default.post(
            name: NSNotification.Name("DocumentSortChanged"),
            object: nil,
            userInfo: [
                "sortColumn": selectedSortColumn,
                "isAscending": isAscendingSortOrder
            ]
        )
    }
    
    // Computed property to get all unique locations
    private var allLocations: [String] {
        var locations: Set<String> = []
        for document in documents {
            // Assuming location is stored in the first variation
            if let location = document.variations.first?.location, !location.isEmpty {
                locations.insert(location)
            }
        }
        return Array(locations).sorted()
    }
    
    private var filteredDocuments: [Letterspace_CanvasDocument] {
        var filtered = documents
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { doc in
                guard let docTags = doc.tags else { return false }
                return !selectedTags.isDisjoint(with: docTags)
            }
        }
        
        // Apply column filter
        if let filterColumn = selectedFilterColumn {
            switch filterColumn {
            case "series":
                filtered = filtered.filter { doc in
                    return doc.series != nil && !doc.series!.name.isEmpty
                }
            case "location":
                filtered = filtered.filter { doc in
                    return doc.variations.first?.location != nil && !doc.variations.first!.location!.isEmpty
                }
            default:
                break
            }
        }
        
        return filtered
    }
    
    // Add sorted version of filteredDocuments for consistent navigation
    private var sortedFilteredDocuments: [Letterspace_CanvasDocument] {
        // Sort using our dropdown selection parameters
        return filteredDocuments.sorted(by: { (doc1: Letterspace_CanvasDocument, doc2: Letterspace_CanvasDocument) -> Bool in
            switch selectedSortColumn {
            case "status":
                let status1 = getStatusPriority(doc1)
                let status2 = getStatusPriority(doc2)
                if status1 != status2 {
                    return isAscendingSortOrder ? status1 < status2 : status1 > status2
                }
                // Fall through to name sorting if status is equal
                let title1 = doc1.title.isEmpty ? "Untitled" : doc1.title
                let title2 = doc2.title.isEmpty ? "Untitled" : doc2.title
                return isAscendingSortOrder ? 
                    title1.localizedCompare(title2) == .orderedAscending :
                    title1.localizedCompare(title2) == .orderedDescending
                
            case "dateModified":
                return isAscendingSortOrder ?
                    doc1.modifiedAt < doc2.modifiedAt :
                    doc1.modifiedAt > doc2.modifiedAt
            case "dateCreated":
                return isAscendingSortOrder ?
                    doc1.createdAt < doc2.createdAt :
                    doc1.createdAt > doc2.createdAt
                
            case "name":
                let title1 = doc1.title.isEmpty ? "Untitled" : doc1.title
                let title2 = doc2.title.isEmpty ? "Untitled" : doc2.title
                return isAscendingSortOrder ? 
                    title1.localizedCompare(title2) == .orderedAscending :
                    title1.localizedCompare(title2) == .orderedDescending
                
            default:
                if selectedSortColumn == "series" {
                    let s1 = doc1.series?.name ?? ""
                    let s2 = doc2.series?.name ?? ""
                    return isAscendingSortOrder ? (s1.localizedCompare(s2) == .orderedAscending) : (s1.localizedCompare(s2) == .orderedDescending)
                }
                if selectedSortColumn == "location" {
                    let l1 = doc1.variations.first?.location ?? ""
                    let l2 = doc2.variations.first?.location ?? ""
                    return isAscendingSortOrder ? (l1.localizedCompare(l2) == .orderedAscending) : (l1.localizedCompare(l2) == .orderedDescending)
                }
                // Fallback to name sorting
                let title1 = doc1.title.isEmpty ? "Untitled" : doc1.title
                let title2 = doc2.title.isEmpty ? "Untitled" : doc2.title
                return isAscendingSortOrder ? 
                    title1.localizedCompare(title2) == .orderedAscending :
                    title1.localizedCompare(title2) == .orderedDescending
            }
        })
    }
    
    // Helper function for status priority
    private func getStatusPriority(_ doc: Letterspace_CanvasDocument) -> Int {
        var priority = 0
        if pinnedDocuments.contains(doc.id) { priority += 4 }
        if wipDocuments.contains(doc.id) { priority += 2 }
        if calendarDocuments.contains(doc.id) { priority += 1 }
        return priority
    }
    
    // Show sermon journal for a specific document
    private func showSermonJournal(for document: Letterspace_CanvasDocument) {
        activeSheet = .sermonJournal(document)
        
        // Mark any pending prompts as completed
        journalService.markPromptCompleted(for: document.id)
    }
    
    // Show preach it again details for a specific document
    private func showPreachItAgainDetails(for document: Letterspace_CanvasDocument) {
        activeSheet = .preachItAgainDetails(document)
    }
    
    private func tagColor(for tag: String) -> Color {
        return colorManager.color(for: tag)
    }

    // Add this function to handle showing details
    private func showDetails(for document: Letterspace_CanvasDocument) {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            // iPhone: Use consolidated sheet
            activeSheet = .documentDetails(document)
        } else {
            // iPad: Use overlay
            selectedDetailsDocument = document
            selectedDocuments = [document.id]
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetailsCard = true
            }
        }
        #else
        // macOS: Use overlay
        selectedDetailsDocument = document
        selectedDocuments = [document.id]
        withAnimation(.easeInOut(duration: 0.2)) {
            showDetailsCard = true
        }
        #endif
    }
    
    // MARK: Helper Functions
    
    private func hasUpcomingSchedules(for document: Letterspace_CanvasDocument) -> Bool {
        // Current date starting at the beginning of today
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if document has any scheduled dates in the future
        if !document.schedules.isEmpty {
            // Check if any schedules are in the future
            for schedule in document.schedules {
                if schedule.startDate >= today {
                    return true
                }
            }
        }
        
        // Check if document has any scheduled presentations in the future via variations
        for variation in document.variations {
            if let scheduledDate = variation.datePresented,
               scheduledDate >= today {
                return true
            }
        }
        
        // No future schedules found
        return false
    }

    // First, add navigation functions in HomeView
    private func navigateToNextDocument() {
        if let currentDoc = selectedDetailsDocument {
            // Get the list of document IDs as they appear in the sorted filtered document list
            let allDocs = sortedFilteredDocuments
            let documentIds = allDocs.map { $0.id }
            
            // Find the current document index in the list
            if let currentIndex = documentIds.firstIndex(of: currentDoc.id),
               currentIndex < documentIds.count - 1 {
                // Get the next document
                let nextDoc = allDocs[currentIndex + 1]
                
                // Update the entire document
                selectedDetailsDocument = nextDoc
                
                // Force refresh if needed
                refreshTrigger.toggle()
            }
        }
    }
    
    private func navigateToPreviousDocument() {
        if let currentDoc = selectedDetailsDocument {
            // Get the list of document IDs as they appear in the sorted filtered document list
            let allDocs = sortedFilteredDocuments
            let documentIds = allDocs.map { $0.id }
            
            // Find the current document index in the list
            if let currentIndex = documentIds.firstIndex(of: currentDoc.id),
               currentIndex > 0 {
                // Get the previous document
                let prevDoc = allDocs[currentIndex - 1]
                
                // Update the entire document
                selectedDetailsDocument = prevDoc
                
                // Force refresh if needed
                refreshTrigger.toggle()
            }
        }
    }

    private func canNavigateNext() -> Bool {
        if let currentDoc = selectedDetailsDocument {
            // Get the list of document IDs as they appear in the sorted filtered document list
            let documentIds = sortedFilteredDocuments.map { $0.id }
            
            // Check if current document is in the list and not the last one
            if let currentIndex = documentIds.firstIndex(of: currentDoc.id) {
                return currentIndex < documentIds.count - 1
            }
        }
        return false
    }

    private func canNavigatePrevious() -> Bool {
        if let currentDoc = selectedDetailsDocument {
            // Get the list of document IDs as they appear in the sorted filtered document list
            let documentIds = sortedFilteredDocuments.map { $0.id }
            
            // Check if current document is in the list and not the first one
            if let currentIndex = documentIds.firstIndex(of: currentDoc.id),
               currentIndex > 0 {
                return currentIndex > 0
            }
        }
        return false
    }
    
    // Helper method to break down complex DocumentRowView initialization 
    @ViewBuilder
    private func documentRowForIndex(_ index: Int, document: Letterspace_CanvasDocument, columnWidths: (statusWidth: CGFloat, nameWidth: CGFloat, seriesWidth: CGFloat, locationWidth: CGFloat, dateWidth: CGFloat, createdDateWidth: CGFloat)) -> some View {
        #if os(iOS)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        DashboardDocumentRow(
            document: document,
            isPinned: pinnedDocuments.contains(document.id),
            isWIP: wipDocuments.contains(document.id),
            hasCalendar: calendarDocuments.contains(document.id),
            isSelected: selectedDocuments.contains(document.id),
            visibleColumns: visibleColumns,
            dateFilterType: dateFilterType,
            isEditMode: isIPad ? isAllDocumentsEditMode : false,
            selectedItems: isIPad ? $selectedAllDocuments : .constant(Set()),
            columnWidths: columnWidths,
            onTap: {
                // Ignore tap if we just long pressed
                if justLongPressed {
                    justLongPressed = false
                    return
                }
                
                if isIPad && isAllDocumentsEditMode {
                    // In edit mode, toggle selection
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if selectedAllDocuments.contains(document.id) {
                            selectedAllDocuments.remove(document.id)
                        } else {
                            selectedAllDocuments.insert(document.id)
                        }
                    }
                } else {
                // Single tap - open document
                self.document = document
                self.sidebarMode = .details
                self.isRightSidebarVisible = true
                }
            },
            onLongPress: {
                if isIPad {
                    // Long press - enter multi-select mode and select this item
                    justLongPressed = true
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAllDocumentsEditMode = true
                        selectedAllDocuments.insert(document.id)
                    }
                    
                    // Add haptic feedback
                    HapticFeedback.impact(.medium)
                } else {
                    // Non-iPad: show details modal
                    showDetails(for: document)
                }
            },
            onShowDetails: {
                // Show details modal (for info button)
                showDetails(for: document)
            },
            onPin: { togglePin(for: document.id) },
            onWIP: { toggleWIP(document.id) },
            onCalendar: { toggleCalendar(document.id) },
            onCalendarAction: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    documentToShowInSheet = document
                }
            },
            onDelete: {
                selectedDocuments = [document.id]
                deleteSelectedDocuments()
            }
        )
        #endif
    }
    
    // Modern All Documents bottom sheet
    private var allDocumentsSectionView: some View {
        AllDocumentsBottomSheet(
            documents: $documents,
            selectedDocuments: $selectedDocuments,
            selectedTags: $selectedTags,
            selectedFilterColumn: $selectedFilterColumn,
            selectedFilterCategory: $selectedFilterCategory,
            sheetDetent: $allDocumentsSheetDetent,
            pinnedDocuments: pinnedDocuments,
            wipDocuments: wipDocuments,
            calendarDocuments: calendarDocuments,
            dateFilterType: dateFilterType,
            onPin: { doc in togglePin(for: doc.id) },
            onWIP: { doc in toggleWIP(doc.id) },
            onCalendar: { doc in toggleCalendar(doc.id) },
            onCalendarAction: { doc in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    documentToShowInSheet = doc
                }
            },
            onOpen: { doc in
                self.document = doc
                self.sidebarMode = .details
                self.isRightSidebarVisible = true
                showAllDocumentsSheet = false // Close sheet when opening document
            },
            onShowDetails: showDetails,
            onDelete: { docIds in
                selectedDocuments = Set(docIds)
                deleteSelectedDocuments()
            },
            onClose: {
                showAllDocumentsSheet = false
            },
                            onShowPinnedSheet: { /* No longer used - tabs handled internally */ },
                onShowWIPSheet: { /* No longer used - tabs handled internally */ },
                onShowScheduleSheet: { /* No longer used - tabs handled internally */ },
                         onShowMorphMenu: {
                 // Only save state if sheet is currently showing
                 if showAllDocumentsSheet {
                     wasAllDocumentsSheetOpenBeforeMenu = true
                     withAnimation(.easeInOut(duration: 0.2)) {
                         showAllDocumentsSheet = false
                     }
                 }
                 onMenuTap?()
             }
         )
     }

    // iOS Column Header Row
    #if os(iOS)
    private func iosColumnHeaderRow(columnWidths: (statusWidth: CGFloat, nameWidth: CGFloat, seriesWidth: CGFloat, locationWidth: CGFloat, dateWidth: CGFloat, createdDateWidth: CGFloat)) -> some View {
        let columnWidths = columnWidths
        let effectiveVisibleColumns = visibleColumns.union(["name"])
        // ... existing code ...
        return HStack(spacing: 0) {
            // Status indicators column (icons)
            Button(action: {}) {
                HStack(spacing: 4) {
                    let useThemeColors = colorScheme == .dark ? 
                        gradientManager.selectedDarkGradientIndex != 0 :
                        gradientManager.selectedLightGradientIndex != 0
                    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                    Image(systemName: "pin.fill")
                        .font(.system(size: isIPad ? 10 : 9))
                        .foregroundColor(useThemeColors ? theme.accent : .orange)
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: isIPad ? 10 : 9))
                        .foregroundColor(useThemeColors ? theme.primary : .blue)
                    Image(systemName: "calendar")
                        .font(.system(size: isIPad ? 10 : 9))
                        .foregroundColor(useThemeColors ? theme.secondary : .green)
                }
            }
            .buttonStyle(.plain)
            .frame(width: columnWidths.statusWidth, alignment: .leading)
            .padding(.leading, UIDevice.current.userInterfaceIdiom == .phone ? 10 : 0) // Add breathing room from left edge on iPhone to match document rows
            
            // Add breathing room between status indicators and name column on iPad (to match row)
            #if os(iOS)
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            if isIPad {
                Spacer().frame(width: 16) // Reduced from 24 to 16 for more compact layout
            } else if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: Reduce spacing between status icons and name column
                Spacer().frame(width: 2)
            }
            #endif
            
            // Name column (sortable) - should align with document content in rows
            if effectiveVisibleColumns.contains("name") {
                Button(action: {
                    if selectedColumn == .name {
                        sortAscending.toggle()
                    } else {
                        selectedColumn = .name
                        sortAscending = true
                    }
                    documents = sortDocuments(documents)
                }) {
                    HStack(spacing: 4) {
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        Text("Name")
                            .font(.system(size: isPhone ? 13 : 16, weight: .medium))
                            .foregroundColor(theme.secondary)
                            .frame(width: columnWidths.nameWidth, alignment: .leading)
                        if selectedColumn == .name {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: columnWidths.nameWidth, alignment: .leading)
            }
            
            // Series column (sortable) - if visible
            if effectiveVisibleColumns.contains("series") {
                Button(action: {
                    if selectedColumn == .series {
                        sortAscending.toggle()
                    } else {
                        selectedColumn = .series
                        sortAscending = true
                    }
                    documents = sortDocuments(documents)
                }) {
                    HStack(spacing: 4) {
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        Text("Series")
                            .font(.system(size: isPhone ? 13 : 16, weight: .medium))  // Smaller for iPhone
                            .foregroundColor(theme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading) // Ensure text fills full width
                        
                        if selectedColumn == .series {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))  // Smaller for iPhone
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: columnWidths.seriesWidth, alignment: .leading)
            }
            
            // Location column (sortable) - if visible
            if effectiveVisibleColumns.contains("location") {
                Button(action: {
                    if selectedColumn == .location {
                        sortAscending.toggle()
                    } else {
                        selectedColumn = .location
                        sortAscending = true
                    }
                    documents = sortDocuments(documents)
                }) {
                    HStack(spacing: 4) {
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        Text("Location")
                            .font(.system(size: isPhone ? 13 : 16, weight: .medium))  // Smaller for iPhone
                            .foregroundColor(theme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading) // Ensure text fills full width
                        
                        if selectedColumn == .location {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))  // Smaller for iPhone
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: columnWidths.locationWidth, alignment: .leading)
            }
            
            // Date column (sortable) - if visible (moved after location)
            if effectiveVisibleColumns.contains("date") {
                Button(action: {
                    if selectedColumn == .date {
                        sortAscending.toggle()
                    } else {
                        selectedColumn = .date
                        sortAscending = true
                    }
                    documents = sortDocuments(documents)
                }) {
                    HStack(spacing: 4) {
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        Text("Modified")
                            .font(.system(size: isPhone ? 13 : 16, weight: .medium))  // Smaller for iPhone
                            .foregroundColor(theme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading) // Ensure text fills full width
                        
                        if selectedColumn == .date {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))  // Smaller for iPhone
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: columnWidths.dateWidth, alignment: .leading)
            }
            
            // Created date column - if visible
            if effectiveVisibleColumns.contains("createdDate") {
                Button(action: {
                    if selectedColumn == .createdDate {
                        sortAscending.toggle()
                    } else {
                        selectedColumn = .createdDate
                        sortAscending = true
                    }
                    documents = sortDocuments(documents)
                }) {
                    HStack(spacing: 4) {
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        Text("Created")
                            .font(.system(size: isPhone ? 13 : 16, weight: .medium))  // Smaller for iPhone
                            .foregroundColor(theme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading) // Ensure text fills full width
                        
                        if selectedColumn == .createdDate {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))  // Smaller for iPhone
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: columnWidths.createdDateWidth, alignment: .leading)
            }
            
            // Add spacing before Actions column (iPad only)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            if !isPhone {
            Spacer().frame(width: 12) // Reduced from 16 to 12 for more compact layout
            
                // Actions column (iPad only) - structured like other columns
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text("Actions")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondary)
                            .frame(maxWidth: .infinity, alignment: .center) // Center text over action buttons
                    }
                }
                .buttonStyle(.plain)
                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 80, alignment: .center)
            }
        }
        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .phone ? 0 : (UIScreen.main.bounds.height > UIScreen.main.bounds.width && UIDevice.current.userInterfaceIdiom == .pad ? 16 : 16)) // Match row padding
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .bottom
        )
    }
    #endif

    // iPad Landscape Sections - horizontal layout like macOS but with iPad carousel styling
    private var iPadLandscapeSections: some View {
        HStack(alignment: .top, spacing: 16) { // Reduced spacing from 24 to 16 for landscape
            // Pinned Section - simplified for landscape
                carouselPinnedSectionView
            .frame(maxWidth: .infinity)
            .frame(height: 260) // Fixed height for landscape cards
            .background(cardBackground) // Use same glassmorphism background as carousel cards
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: cardShadowColor, radius: 12, x: 0, y: 4)
            
            // WIP Section - simplified for landscape
                carouselWipSectionView
            .frame(maxWidth: .infinity)
            .frame(height: 260) // Fixed height for landscape cards
            .background(cardBackground) // Use same glassmorphism background as carousel cards
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: cardShadowColor, radius: 12, x: 0, y: 4)
            
            // Document Schedule Section - simplified for landscape
                carouselSermonCalendarView
            .frame(maxWidth: .infinity)
            .frame(height: 260) // Fixed height for landscape cards
            .background(cardBackground) // Use same glassmorphism background as carousel cards
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: cardShadowColor, radius: 12, x: 0, y: 4)
        }
        .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
        .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
    }

    // iPad Carousel Component
    private var iPadSectionCarousel: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let allDocumentsLeftPadding: CGFloat = shouldAddNavigationPadding ? navPadding : 20
            let allDocumentsLeftEdge = allDocumentsLeftPadding + 20

            let cardWidth: CGFloat = {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                if isPhone {
                    // iPhone: consistent card width with breathing room on both sides
                    return screenWidth * 0.93 // Full width with breathing room (increased to 93%)
                } else {
                    // iPad: original sizing
                    return shouldAddNavigationPadding ? (screenWidth - allDocumentsLeftEdge) * 0.8 : screenWidth * 0.75
                }
                #else
                // Fallback for other platforms
                return shouldAddNavigationPadding ? (screenWidth - allDocumentsLeftEdge) * 0.8 : screenWidth * 0.75
                #endif
            }()

            let cardSpacing: CGFloat = {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 40 : 60 // Tighter spacing for iPhone
                #else
                return 60
                #endif
            }()

            let totalWidth = geometry.size.width
            let shadowPadding: CGFloat = 40
            
            ZStack {
                // Background tap area to exit reorder mode or clear document selections
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                        if reorderMode && isIPadDevice {
                            print("🔄 Exiting reorder mode via background tap")
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                reorderMode = false
                                draggedCardIndex = nil
                                draggedCardOffset = .zero
                            }
                        } else {
                            // Clear any document selections in carousel cards (iPad only)
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                // Clear selections in all carousel sections
                                clearAllDocumentSelections()
                            }
                            #endif
                        }
                        }
                        .zIndex(-1) // Behind the cards
                
                ForEach(0..<carouselSections.count, id: \.self) { index in
                    carouselCard(for: index, cardWidth: cardWidth, cardSpacing: cardSpacing, totalWidth: totalWidth, shadowPadding: shadowPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, shadowPadding)
            // Only apply carousel gesture when not in reorder mode
            .gesture(reorderMode ? nil : carouselDragGesture(cardWidth: cardWidth, cardSpacing: cardSpacing))
        }
        .frame(height: {
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            if isPhone || isIPad {
                // Use dynamic height based on All Documents position for both iPhone and iPad
                return allDocumentsPosition.carouselHeight
            } else {
                return 380 // Fallback for other devices
            }
            #else
            return 380
            #endif
        }())
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showFloatingSidebar)

    }
    
    // Calculate effective index during drag (where cards will end up)
    private func effectiveCardIndex(for index: Int) -> Int {
        guard let draggedIndex = draggedCardIndex else { return index }
        
        // Calculate target position based on drag
        let dragX = draggedCardOffset.width
        let reorderCardWidth: CGFloat = 300 * 0.6 // 60% of normal card width
        let reorderSpacing: CGFloat = 20
        let totalCardWidth = reorderCardWidth + reorderSpacing
        
        // Determine how many positions to move based on drag distance
        let positionChange = Int(round(dragX / totalCardWidth))
        let targetIndex = max(0, min(carouselSections.count - 1, draggedIndex + positionChange))
        
        // Return the effective position for each card
        if index == draggedIndex {
            // Dragged card goes to target position
            return targetIndex
        } else if draggedIndex < targetIndex {
            // Moving right: cards between original and target shift left
            if index > draggedIndex && index <= targetIndex {
                return index - 1
            }
        } else if draggedIndex > targetIndex {
            // Moving left: cards between target and original shift right
            if index >= targetIndex && index < draggedIndex {
                return index + 1
            }
        }
        
        // All other cards stay in their original positions
        return index
    }
    
    // Calculate real-time positions during drag
    private func cardPosition(for index: Int, cardWidth: CGFloat, cardSpacing: CGFloat, totalWidth: CGFloat, shadowPadding: CGFloat) -> CGPoint {
        if reorderMode {
            // In reorder mode, show all cards in view with smaller spacing
            let reorderCardWidth = cardWidth * 0.6 // Cards are 60% of normal size in reorder mode
            let reorderSpacing: CGFloat = 20 // Tighter spacing in reorder mode
            let totalCardsWidth = CGFloat(carouselSections.count) * reorderCardWidth + CGFloat(carouselSections.count - 1) * reorderSpacing
            let startX = (totalWidth - totalCardsWidth) / 2
            
            if index == draggedCardIndex {
                // Dragged card follows finger with constraints
                let basePosition = startX + CGFloat(index) * (reorderCardWidth + reorderSpacing)
                let constrainedX = max(startX, 
                                     min(startX + totalCardsWidth - reorderCardWidth, 
                                         basePosition + draggedCardOffset.width))
                return CGPoint(
                    x: constrainedX,
                    y: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                        if isPhone || isIPad {
                            // Use half of dynamic height for both iPhone and iPad
                            return (allDocumentsPosition.carouselHeight / 2) + draggedCardOffset.height * 0.2
                        } else {
                            return 190 + draggedCardOffset.height * 0.2 // Fallback for other devices
                        }
                        #else
                        return 190 + draggedCardOffset.height * 0.2
                        #endif
                    }()
                )
            } else {
                // Other cards slide to their effective positions smoothly
                let effectiveIndex = effectiveCardIndex(for: index)
                let xPosition = startX + CGFloat(effectiveIndex) * (reorderCardWidth + reorderSpacing)
                return CGPoint(
                    x: xPosition,
                    y: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                        if isPhone || isIPad {
                            // Use half of dynamic height for both iPhone and iPad
                            return allDocumentsPosition.carouselHeight / 2
                        } else {
                            return 190 // Fallback for other devices
                        }
                        #else
                        return 190
                        #endif
                    }()
                )
            }
        } else {
            // Normal carousel mode - different positioning based on navigation state
            let offsetFromCenter = CGFloat(index - selectedCarouselIndex)
            let xOffset = offsetFromCenter * (cardWidth + cardSpacing)
            
            let centerX: CGFloat
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            if isPhone {
                // iPhone: Center the carousel cards with proper spacing, accounting for shadowPadding
                centerX = (totalWidth / 2) + xOffset + dragOffset - shadowPadding
            } else {
                // iPad: Proper alignment with All Documents list
                if shouldAddNavigationPadding {
                    // Navigation visible: align left edge of centered card with All Documents left edge
                    let allDocumentsLeftPadding = navPadding + 10 // navPadding + horizontal padding
                    // Account for the carousel container's shadowPadding (40pt) that shifts everything right
                    let centeredCardLeftEdge = allDocumentsLeftPadding - shadowPadding + 20 // Move more to the right
                    centerX = centeredCardLeftEdge + (cardWidth / 2) + xOffset + dragOffset
                } else {
                    // Navigation hidden: center the cards in the available space, but shift left
                    centerX = (totalWidth / 2) - 30 + xOffset + dragOffset // Move more to the left
                }
            }
            #else
            // macOS and other platforms
            if shouldAddNavigationPadding {
                let allDocumentsLeftPadding = navPadding
                let allDocumentsLeftEdge = allDocumentsLeftPadding + 10
                let centeredCardLeftEdge = allDocumentsLeftEdge - shadowPadding
                centerX = centeredCardLeftEdge + (cardWidth / 2) + xOffset + dragOffset
            } else {
                centerX = totalWidth / 2 + xOffset + dragOffset
            }
            #endif
            return CGPoint(
                x: centerX,
                y: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                    if isPhone || isIPad {
                        // Use half of dynamic height for both iPhone and iPad
                        return allDocumentsPosition.carouselHeight / 2
                    } else {
                        return 190 // Fallback for other devices
                    }
                    #else
                    return 190
                    #endif
                }()
            )
        }
    }
    
    // Extract carousel card into separate function
    @ViewBuilder
    private func carouselCard(for index: Int, cardWidth: CGFloat, cardSpacing: CGFloat, totalWidth: CGFloat, shadowPadding: CGFloat) -> some View {
        let isCenter = index == selectedCarouselIndex
        let isDragged = index == draggedCardIndex
        // Make the focused card wider for better centering
        let adjustedCardWidth = isCenter ? cardWidth * 1.1 : cardWidth // 10% wider when focused
        // In reorder mode, make cards much smaller so all are visible
        let cardScale: CGFloat = reorderMode ? (isDragged ? 0.65 : 0.6) : 1.0 // 60% size for overview, 65% for dragged
        let cardOpacity: Double = reorderMode ? (isDragged ? 1.0 : 0.8) : (isCenter ? 1.0 : 0.8)
        let position = cardPosition(for: index, cardWidth: cardWidth, cardSpacing: cardSpacing, totalWidth: totalWidth, shadowPadding: shadowPadding)
        
        ZStack(alignment: .topTrailing) {
            // Main card content
            Group {
                if isSwipeDownNavigation && isLoadingDocuments {
                    // Show loading placeholder during swipe-down navigation
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.system(size: 16))
                                .foregroundColor(theme.secondary)
                        }
                        Spacer()
                    }
                } else {
                    carouselSections[index].view
                }
            }
            .frame(width: adjustedCardWidth, height: {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                if isPhone || isIPad {
                    // Use dynamic height based on All Documents position for both iPhone and iPad
                    return allDocumentsPosition.carouselHeight
                } else {
                    return 380 // Fallback for other devices
                }
                #else
                return 380
                #endif
            }(), alignment: .top)
            .clipped()  // Clip content that overflows the frame
            
            // Reorder mode overlay
            if reorderMode && !isDragged {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.15))
                    .frame(width: adjustedCardWidth, height: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                        if isPhone || isIPad {
                            // Use dynamic height based on All Documents position for both iPhone and iPad
                            return allDocumentsPosition.carouselHeight
                        } else {
                            return 380 // Fallback for other devices
                        }
                        #else
                        return 380
                        #endif
                    }())
            }
            
            // Reorder handle (iPad only)
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                reorderHandle(for: index, isCenter: isCenter)
            }
            #else
            reorderHandle(for: index, isCenter: isCenter)
            #endif
        }
        .frame(width: adjustedCardWidth)  // Ensure card maintains its adjusted width
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: cardShadowColor, radius: isDragged ? 20 : (reorderMode ? 8 : 12), x: 0, y: isDragged ? 8 : 4)
        .scaleEffect(cardScale) // Apply scale first
        .opacity(cardOpacity) // Then opacity
        .position(x: position.x, y: position.y)  // Use position instead of offset for more precise control
        .zIndex(isDragged ? 1000 : Double(index))
        .onTapGesture {
            if reorderMode && isIPadDevice {
                // In reorder mode, tapping a card exits reorder mode
                print("🔄 Exiting reorder mode via card tap")
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                    reorderMode = false
                    draggedCardIndex = nil
                        draggedCardOffset = .zero
                }
            } else if !isCenter {
                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                    selectedCarouselIndex = index
                    isFirstLaunch = false // Mark that this is no longer first launch
                }
                saveCarouselPosition()
            }
        }
        // Add drag gesture to the entire card when in reorder mode (iPad only)
        .simultaneousGesture(
            (reorderMode && isIPadDevice) ? 
            DragGesture(minimumDistance: 5)
                .onChanged { gesture in
                    // Only drag if this card is already selected
                    if draggedCardIndex == index {
                        draggedCardOffset = gesture.translation
                        print("🔄 Dragging card \(index): \(gesture.translation)")
                    } else {
                        // If no card is selected, select this card for dragging
                        if draggedCardIndex == nil {
                            draggedCardIndex = index
                            draggedCardOffset = .zero
                        }
                    }
                }
                .onEnded { gesture in
                    if draggedCardIndex == index {
                        print("🔄 Card drag ended for index \(index)")
                        // Calculate final position based on where the card actually ended up
                        let reorderCardWidth: CGFloat = cardWidth * 0.6
                        let reorderSpacing: CGFloat = 20
                        let totalCardsWidth = CGFloat(carouselSections.count) * reorderCardWidth + CGFloat(carouselSections.count - 1) * reorderSpacing
                        let startX = (totalWidth - totalCardsWidth) / 2
                        
                        // Calculate the actual final X position of the dragged card
                        let basePosition = startX + CGFloat(index) * (reorderCardWidth + reorderSpacing) + reorderCardWidth / 2
                        let unconstrained = basePosition + draggedCardOffset.width
                        
                        // Apply the same constraints as in cardPosition function
                        let finalCardPosition = max(startX + reorderCardWidth / 2, 
                                                   min(startX + totalCardsWidth - reorderCardWidth / 2, 
                                                       unconstrained))
                        
                        // Find which slot this final position is closest to
                        var targetIndex = index
                        var minDistance = CGFloat.infinity
                        
                        for i in 0..<carouselSections.count {
                            let slotPosition = startX + CGFloat(i) * (reorderCardWidth + reorderSpacing) + reorderCardWidth / 2
                            let distance = abs(finalCardPosition - slotPosition)
                            print("🔄 Slot \(i): position \(slotPosition), distance \(distance)")
                            if distance < minDistance {
                                minDistance = distance
                                targetIndex = i
                            }
                        }
                        
                        print("🔄 Target index: \(targetIndex), original: \(index)")
                        print("🔄 Final position: \(finalCardPosition), startX: \(startX), totalWidth: \(totalCardsWidth)")
                        print("🔄 Drag offset: \(draggedCardOffset.width), unconstrained: \(unconstrained)")
                        
                        if targetIndex != index {
                            // Perform the reorder
                            print("🔄 Performing reorder from \(index) to \(targetIndex)")
                            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                                moveCarouselSection(from: index, to: targetIndex)
                            }
                        }
                        
                        // Reset drag state but stay in reorder mode
                        // No animation - card should stay where dropped
                            draggedCardIndex = nil
                            draggedCardOffset = .zero
                    }
                }
            : nil
        )
        // Only animate mode changes, not drag positions (to avoid glitches)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: reorderMode)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.85, blendDuration: 0), value: selectedCarouselIndex)
    }
    
    // Extract reorder handle
    @ViewBuilder
    private func reorderHandle(for index: Int, isCenter: Bool) -> some View {
        Button(action: {
            if reorderMode && isIPadDevice {
                // Exit reorder mode when tapping handle in reorder mode
                print("🔄 Exiting reorder mode via handle tap")
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                    reorderMode = false
                    draggedCardIndex = nil
                    draggedCardOffset = .zero
                }
            }
        }) {
            VStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(reorderHandleColor)
                        .frame(width: 16, height: 2)
                }
            }
            .padding(16) // Increased padding for easier touch
            .background(reorderHandleBackground)
        }
        .buttonStyle(.plain)
        .opacity(reorderMode ? 1.0 : (isCenter ? 0.8 : 0.4))
        .scaleEffect(reorderMode ? 1.3 : (isCenter ? 1.0 : 0.9)) // Larger scale in reorder mode
        .offset(x: -12, y: 12)
        .simultaneousGesture(
            // Long press to enter reorder mode (iPad only)
            isIPadDevice ? 
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    print("🔄 Long press detected for index \(index)")
                    if !reorderMode {
                        print("🔄 Entering reorder mode via long press")
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                            reorderMode = true
                            draggedCardIndex = nil // Don't auto-select a card
                            draggedCardOffset = .zero
                        }
                        
                        // Add haptic feedback
                        HapticFeedback.impact(.medium)
                    }
                }
            : nil
        )
    }
    
    private func reorderDragGesture(for index: Int) -> some Gesture {
        // This function is no longer needed since we moved the logic to the handle
        DragGesture()
            .onChanged { _ in }
            .onEnded { _ in }
    }
    
    // Extract computed properties for styling
    private var cardBackground: some View {
        Group {
            // Only check gradient for current color scheme
            let useGlassmorphism = colorScheme == .dark ? 
                gradientManager.selectedDarkGradientIndex != 0 :
                gradientManager.selectedLightGradientIndex != 0
            
            if useGlassmorphism {
                // Glassmorphism effect for carousel cards
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    theme.background.opacity(0.2),
                                    theme.background.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
            } else {
                // Default background
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
            }
        }
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.1)
    }
    
    private var reorderHandleColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.4)
    }
    
    private var reorderHandleBackground: some View {
        Circle()
            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
            .blur(radius: 2)
    }
    
    // Extract drag gestures
    private func carouselDragGesture(cardWidth: CGFloat, cardSpacing: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .local) // Reduced from 10 to make it more responsive
            .onChanged { gesture in
                if !reorderMode {
                    let horizontalDistance = abs(gesture.translation.width)
                    let verticalDistance = abs(gesture.translation.height)
                    
                    // Make horizontal swiping much easier - favor horizontal with lower threshold
                    // Allow horizontal movement even if vertical is slightly more, but require minimum horizontal movement
                    if horizontalDistance > 8 && (horizontalDistance > verticalDistance * 0.6) {
                    withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 1.0, blendDuration: 0)) {
                        dragOffset = gesture.translation.width
                        }
                    }
                }
            }
            .onEnded { gesture in
                if !reorderMode {
                    let velocity = gesture.velocity.width
                    let translation = gesture.translation.width
                    let horizontalDistance = abs(gesture.translation.width)
                    let verticalDistance = abs(gesture.translation.height)
                    
                    // Make horizontal gestures very easy to trigger
                    // Even if there's some vertical movement, prioritize horizontal if there's meaningful horizontal movement
                    let isHorizontalGesture = horizontalDistance > 15 && (horizontalDistance > verticalDistance * 0.5)
                    
                    if isHorizontalGesture {
                        let dragThreshold: CGFloat = 25 // Reduced from 40 to make it easier
                        let velocityThreshold: CGFloat = 250 // Reduced from 400 to make it easier
                    
                    let shouldGoToPrevious = (translation > dragThreshold || velocity > velocityThreshold) && selectedCarouselIndex > 0
                    let shouldGoToNext = (translation < -dragThreshold || velocity < -velocityThreshold) && selectedCarouselIndex < carouselSections.count - 1
                    
                    if shouldGoToPrevious {
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                            selectedCarouselIndex -= 1
                            dragOffset = 0
                                isFirstLaunch = false // Mark that this is no longer first launch
                        }
                            saveCarouselPosition()
                    } else if shouldGoToNext {
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                            selectedCarouselIndex += 1
                            dragOffset = 0
                                isFirstLaunch = false // Mark that this is no longer first launch
                        }
                            saveCarouselPosition()
                    } else {
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.9, blendDuration: 0)) {
                                dragOffset = 0
                            }
                        }
                    } else {
                        // If it's not a horizontal gesture, just reset the drag offset
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.9, blendDuration: 0)) {
                            dragOffset = 0
                        }
                    }
                }
            }
    }

    // Extracted computed property for PinnedSection (for non-iPad layout)
    private var pinnedSectionView: some View {
        PinnedSection(
            documents: documents,
            pinnedDocuments: $pinnedDocuments,
            onSelectDocument: { selectedDoc in
                onSelectDocument(selectedDoc)
            },
            document: $document,
            sidebarMode: $sidebarMode,
            isRightSidebarVisible: $isRightSidebarVisible,
            isExpanded: $isPinnedExpanded,
            isCarouselMode: false, // macOS doesn't use carousel styling
            showExpandButtons: shouldShowExpandButtons // separate parameter for expand buttons
        )
        .frame(maxWidth: CGFloat.infinity)
    }
                
    // Extracted computed property for WIPSection (for non-iPad layout)
    private var wipSectionView: some View {
        WIPSection(
            documents: documents,
            wipDocuments: $wipDocuments,
            document: $document,
            sidebarMode: $sidebarMode,
            isRightSidebarVisible: $isRightSidebarVisible,
            isExpanded: $isWIPExpanded,
            isCarouselMode: false, // macOS doesn't use carousel styling
            showExpandButtons: shouldShowExpandButtons // separate parameter for expand buttons
        )
        .frame(maxWidth: CGFloat.infinity)
    }
                
    // Extracted computed property for SermonCalendar (for non-iPad layout)
    private var sermonCalendarView: some View {
        SermonCalendar(
            documents: documents,
            calendarDocuments: calendarDocuments,
            isExpanded: $isSchedulerExpanded,
            onShowModal: { data in
                self.calendarModalData = data 
            },
            isCarouselMode: false, // macOS doesn't use carousel styling
            showExpandButtons: shouldShowExpandButtons // separate parameter for expand buttons
        )
        .frame(maxWidth: CGFloat.infinity)
    }

    // NEW: Carousel Navigation Pills
    private var carouselNavigationPills: some View {
        #if os(iOS)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        #else
        let isIPad = false
        #endif
        
        return HStack(spacing: isIPad ? 12 : 6) {
            ForEach(0..<carouselSections.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                        selectedCarouselIndex = index
                        saveCarouselPosition()
                    }
                }) {
                    HStack(spacing: isIPad ? 8 : 5) {
                        // Icon for each section
                        Image(systemName: {
                            switch index {
                            case 0: return "pin.fill"
                            case 1: return "clock.badge.checkmark"
                            case 2: return "calendar"
                            default: return "doc.text"
                            }
                        }())
                        .font(.system(size: isIPad ? 14 : 11, weight: .medium)) // Larger icon for iPad
                        
                        // Title for each section
                        Text({
                            switch index {
                            case 0: return "Pinned"
                            case 1: return "WIP"
                            case 2: return "Schedule"
                            default: return "Section"
                            }
                        }())
                        .font(.custom("InterTight-Medium", size: isIPad ? 15 : 12)) // Larger text for iPad
                    }
                    .foregroundStyle(selectedCarouselIndex == index ? .white : theme.primary)
                    .padding(.horizontal, isIPad ? 16 : 10) // More horizontal padding for iPad
                    .padding(.vertical, isIPad ? 10 : 7) // More vertical padding for iPad
                    .background(
                        RoundedRectangle(cornerRadius: isIPad ? 18 : 14) // Larger corner radius for iPad
                            .fill(selectedCarouselIndex == index ? theme.accent : theme.accent.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity) // Center the pills in the available space
        .padding(.horizontal, isIPad ? 40 : 20) // More horizontal padding for iPad centering
        .padding(.vertical, isIPad ? 16 : 12) // More vertical padding for iPad
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showFloatingSidebar)
    }

    @State private var cachedFilteredDocuments: [Letterspace_CanvasDocument] = []
    @State private var cachedSortedFilteredDocuments: [Letterspace_CanvasDocument] = []

    // MARK: - Notification Setup
    
    private func setupNotificationObservers() {
        // Listen for document unscheduling to refresh the calendar icons
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DocumentUnscheduled"),
            object: nil,
            queue: .main
        ) { notification in
            if let documentId = notification.userInfo?["documentId"] as? String {
                self.calendarDocuments.remove(documentId)
                UserDefaults.standard.set(Array(self.calendarDocuments), forKey: "CalendarDocuments")
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("RemoveFromCalendarList"),
                    object: nil,
                    userInfo: ["documentId": documentId]
                )
                
                self.refreshTrigger.toggle()
            }
        }
        
        // Listen for edit presentation requests from SermonCalendar
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EditPresentation"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let documentId = userInfo["documentId"] as? String,
                  let presentationId = userInfo["presentationId"] as? UUID else {
                return
            }
            
            if let doc = self.documents.first(where: { $0.id == documentId }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.documentToShowInSheet = doc
                    UserDefaults.standard.set(presentationId.uuidString, forKey: "editingPresentationId")
                    UserDefaults.standard.set(true, forKey: "openToNotesStep")
                }
            }
        }
        
        // Listen for document details request
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowDocumentDetails"),
            object: nil,
            queue: .main
        ) { notification in
            if let documentId = notification.userInfo?["documentId"] as? String,
               let document = documents.first(where: { $0.id == documentId }) {
                selectedDetailsDocument = document
                selectedDocuments = [documentId]
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetailsCard = true
                }
            }
        }
        
        // Timer to periodically check for past dates and update UI
        Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in
            var docsWithFutureSchedules = Set<String>()
            
            for document in self.documents {
                if self.hasUpcomingSchedules(for: document) {
                    docsWithFutureSchedules.insert(document.id)
                }
            }
            
            if docsWithFutureSchedules != self.calendarDocuments {
                self.calendarDocuments = docsWithFutureSchedules
                UserDefaults.standard.set(Array(self.calendarDocuments), forKey: "CalendarDocuments")
                initializeCarouselSections()
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                }
            }
        }
        
        // Observer for ShowPresentationManager
        NotificationCenter.default.addObserver(
            forName: .showPresentationManager,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let documentId = userInfo["documentId"] as? String else {
                return
            }
            
            if let doc = self.documents.first(where: { $0.id == documentId }) {
                DispatchQueue.main.async {
                    self.documentToShowInSheet = doc
                }
            }
        }
    }
    
        // NEW: Enhanced Curated Sermons Section (Spotify/Dwell-like)
    private var curatedSermonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with dropdown
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Curated for You")
                        .font(.custom("InterTight-Bold", size: 20))
                        .foregroundStyle(theme.primary)
                    
                    Text("Handpicked sermon tools and insights")
                        .font(.custom("InterTight-Regular", size: 12))
                        .foregroundStyle(theme.primary.opacity(0.6))
                }
                
                Spacer()
            }

            // Unified “Spotify-like” cards grid (each card opens its sheet)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(CurationType.allCases.filter { $0 != .trending }, id: \.self) { type in
                        curatedCategoryCard(type)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 20)
        .onAppear {
            if aiCuratedSermons.isEmpty && !isGeneratingInsights {
                generateAICuratedSermons()
            }
        }
    }
    
    // Content view that changes based on curation type
    @ViewBuilder
    private var curatedContentView: some View {
        switch selectedCurationType {
        case .insights:
            curatedSermonsCarousel
        case .sermonJournal:
            sermonJournalSection
        case .preachItAgain:
            preachItAgainSection
        case .statistics:
            statisticsView
        case .recent, .trending:
            curatedSermonsCarousel
        }
    }

    // Explicit variant to render for a provided type (avoids stale selected type on first open)
    @ViewBuilder
    private func curatedContentViewFor(_ type: CurationType) -> some View {
        switch type {
        case .insights:
            curatedSermonsCarousel
        case .sermonJournal:
            sermonJournalSection
        case .preachItAgain:
            preachItAgainSection
        case .statistics:
            statisticsView
        case .recent, .trending:
            curatedSermonsCarousel
        }
    }
    
    // Carousel view for sermon cards
    @ViewBuilder
    private var curatedSermonsCarousel: some View {
        if isGeneratingInsights {
            // Loading skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.secondary.opacity(0.1))
                            .frame(width: 280, height: 160)
                            .overlay(
                                VStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(theme.secondary.opacity(0.2))
                                        .frame(height: 20)
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(theme.secondary.opacity(0.2))
                                        .frame(height: 16)
                                }
                                .padding(16)
                            )
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .contentMargins(.horizontal, 10, for: .scrollContent)
        } else if aiCuratedSermons.isEmpty {
            // Empty state
            VStack(spacing: 12) {
                Image(systemName: selectedCurationType.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(theme.primary.opacity(0.3))
                Text("No \(selectedCurationType.rawValue.lowercased()) available")
                    .font(.custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.primary.opacity(0.6))
                Text("Content will appear when you have sermons")
                    .font(.custom("InterTight-Regular", size: 12))
                    .foregroundStyle(theme.primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            // Horizontal scrolling curated sermons
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(aiCuratedSermons, id: \.id) { sermon in
                        CuratedSermonCard(
                            sermon: sermon, 
                            curationType: selectedCurationType,
                            onTap: { selectedSermon in
                                if selectedCurationType == .sermonJournal {
                                    // Open sermon journal for this document
                                    showSermonJournal(for: selectedSermon)
                                } else {
                                    onSelectDocument(selectedSermon)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .contentMargins(.horizontal, 10, for: .scrollContent)
        }
    }

    // Card for a curated category
    @ViewBuilder
    private func curatedCategoryCard(_ type: CurationType) -> some View {
        switch type {
        case .sermonJournal:
            journalEntriesCard
                .frame(width: 280, height: 160)
        default:
            Button(action: {
                activeSheet = .curatedCategory(type)
            }) {
                switch type {
                case .insights:
                    ZStack {
                        LinearGradient(colors: [Color.teal.opacity(0.85), Color.indigo.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                            }
                            Text("Insights")
                                .font(.custom("InterTight-SemiBold", size: 18))
                                .foregroundStyle(.white)
                            Text("AI-powered sermon insights")
                                .font(.custom("InterTight-Regular", size: 12))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(2)
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Open")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        }
                        .padding(16)
                    }
                    .frame(width: 280, height: 160)

                case .preachItAgain:
                    ZStack {
                        LinearGradient(colors: [Color.orange.opacity(0.85), Color.red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                            }
                            Text("Preach it Again")
                                .font(.custom("InterTight-SemiBold", size: 18))
                                .foregroundStyle(.white)
                            Text("Ready to re-preach candidates")
                                .font(.custom("InterTight-Regular", size: 12))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(2)
                            Spacer()
                            HStack(spacing: 6) {
                                let count = documents.filter { doc in
                                    let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                                    return doc.variations.contains { v in (v.datePresented ?? .distantFuture) <= sixMonthsAgo }
                                }.count
                                Image(systemName: "number")
                                Text("\(count) ready")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        }
                        .padding(16)
                    }
                    .frame(width: 280, height: 160)

                case .statistics:
                    ZStack {
                        LinearGradient(colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                            }
                            Text("Statistics")
                                .font(.custom("InterTight-SemiBold", size: 18))
                                .foregroundStyle(.white)
                            Text("Signals, trends, coverage")
                                .font(.custom("InterTight-Regular", size: 12))
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            // Mini bar motif
                            HStack(alignment: .bottom, spacing: 4) {
                                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.8)).frame(width: 10, height: 12)
                                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.9)).frame(width: 10, height: 20)
                                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.7)).frame(width: 10, height: 8)
                                RoundedRectangle(cornerRadius: 2).fill(Color.white).frame(width: 10, height: 24)
                            }
                        }
                        .padding(16)
                    }
                    .frame(width: 280, height: 160)

                case .recent:
                    ZStack {
                        LinearGradient(colors: [Color.gray.opacity(0.6), Color.blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                            }
                            Text("Recently Opened")
                                .font(.custom("InterTight-SemiBold", size: 18))
                                .foregroundStyle(.white)
                            if let first = documents.first {
                                Text(first.title.isEmpty ? "Untitled" : first.title)
                                    .font(.custom("InterTight-Regular", size: 12))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                Text("View list")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        }
                        .padding(16)
                    }
                    .frame(width: 280, height: 160)

                case .trending:
                    ZStack {
                        LinearGradient(colors: [Color.green.opacity(0.75), Color.blue.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                            }
                            Text("Trending")
                                .font(.custom("InterTight-SemiBold", size: 18))
                                .foregroundStyle(.white)
                            Text("Most accessed this month")
                                .font(.custom("InterTight-Regular", size: 12))
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            // Tiny sparkline motif
                            HStack(spacing: 2) {
                                Circle().fill(Color.white.opacity(0.8)).frame(width: 3, height: 3)
                                Circle().fill(Color.white.opacity(0.6)).frame(width: 3, height: 3)
                                Circle().fill(Color.white).frame(width: 3, height: 3)
                                Circle().fill(Color.white.opacity(0.7)).frame(width: 3, height: 3)
                                Circle().fill(Color.white.opacity(0.9)).frame(width: 3, height: 3)
                            }
                        }
                        .padding(16)
                    }
                    .frame(width: 280, height: 160)

                default:
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // Statistics view for analytics
    private var statisticsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Total sermons card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(theme.accent)
                        Text("Total Sermons")
                            .font(.custom("InterTight-Medium", size: 14))
                            .foregroundStyle(theme.primary.opacity(0.7))
                    }
                    Text("\(sortedFilteredDocuments.count)")
                        .font(.custom("InterTight-Bold", size: 24))
                        .foregroundStyle(theme.primary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                
                // This month card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.green)
                        Text("This Month")
                            .font(.custom("InterTight-Medium", size: 14))
                            .foregroundStyle(theme.primary.opacity(0.7))
                    }
                    Text("\(sortedFilteredDocuments.prefix(5).count)")
                        .font(.custom("InterTight-Bold", size: 24))
                        .foregroundStyle(theme.primary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            
            // Popular tags
            VStack(alignment: .leading, spacing: 12) {
                Text("Popular Tags")
                    .font(.custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["Faith", "Hope", "Love", "Grace", "Wisdom"], id: \.self) { tag in
                            Text(tag)
                                .font(.custom("InterTight-Medium", size: 12))
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(theme.accent.opacity(0.1))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
                .contentMargins(.horizontal, 10, for: .scrollContent)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // Curated sermon card component
    private struct CuratedSermonCard: View {
        let sermon: CuratedSermon
        let curationType: CurationType
        let onTap: (Letterspace_CanvasDocument) -> Void
        @Environment(\.themeColors) var theme
        
        var body: some View {
            Button(action: {
                onTap(sermon.document)
            }) {
                VStack(alignment: .leading, spacing: 12) {
                    // Gradient background with overlay
                    ZStack {
                        // Background gradient
                        LinearGradient(
                            colors: [theme.accent.opacity(0.8), theme.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // Content overlay
                        VStack(alignment: .leading, spacing: 8) {
                            // AI-generated insight
                            Text(sermon.aiInsight)
                                .font(.custom("InterTight-Medium", size: 14))
                                .foregroundStyle(.white)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            // Sermon title
                            Text(sermon.document.title)
                                .font(.custom("InterTight-Bold", size: 16))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                        .padding(16)
                    }
                    .frame(width: 280, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Bottom info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sermon.document.title)
                            .font(.custom("InterTight-Medium", size: 14))
                            .foregroundStyle(theme.primary)
                            .lineLimit(1)
                        
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: curationType.icon)
                                    .font(.system(size: 10))
                                Text(sermon.category)
                                    .font(.custom("InterTight-Medium", size: 12))
                            }
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.accent.opacity(0.1))
                            )
                            
                            Spacer()
                            
                            Text("Foundation AI")
                                .font(.custom("InterTight-Regular", size: 10))
                                .foregroundStyle(theme.primary.opacity(0.6))
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // Curated sermon data model
    private struct CuratedSermon {
        let id = UUID()
        let document: Letterspace_CanvasDocument
        let aiInsight: String
        let category: String
    }
    
    // Curation types for different views
    enum CurationType: String, CaseIterable {
        case insights = "Insights"
        case sermonJournal = "Sermon Journal"
        case preachItAgain = "Preach it Again"
        case statistics = "Statistics"
        case recent = "Recently Opened"
        case trending = "Trending"
        
        var icon: String {
            switch self {
            case .insights: return "lightbulb.fill"
            case .sermonJournal: return "book.pages.fill"
            case .preachItAgain: return "arrow.clockwise.circle.fill"
            case .statistics: return "chart.bar.fill"
            case .recent: return "clock.fill"
            case .trending: return "chart.line.uptrend.xyaxis"
            }
        }
        
        var description: String {
            switch self {
            case .insights: return "AI-powered insights for your sermons"
            case .sermonJournal: return "Post-preaching reflections & follow-ups"
            case .preachItAgain: return "Sermons ready for another delivery"
            case .statistics: return "Your sermon statistics and analytics"
            case .recent: return "Recently opened sermons"
            case .trending: return "Most accessed sermons this month"
            }
        }
    }
    
    // Computed property for curated sermons
    private var curatedSermons: [CuratedSermon] {
        // Use AI to curate sermons from user's documents
        let recentDocuments = Array(documents.prefix(10)) // Get recent documents
        
        return recentDocuments.enumerated().prefix(5).map { index, document in
            // Generate AI insight for this sermon
            let aiInsight = generateAIInsight(for: document)
            
            let categories = ["Faith", "Hope", "Wisdom", "Guidance", "Inspiration"]
            
            return CuratedSermon(
                document: document,
                aiInsight: aiInsight,
                category: categories[index % categories.count]
            )
        }
    }
    
    // REMOVED: Duplicate function - using the enhanced version below
    
    // Add state for AI-powered curation
    @State private var aiCuratedSermons: [CuratedSermon] = []
    @State private var isGeneratingInsights: Bool = false
    @State private var selectedCurationType: CurationType = .insights
    @State private var showCurationTypeDropdown = false
    
    // Generate AI insight for a sermon
    private func generateAIInsight(for document: Letterspace_CanvasDocument) -> String {
        // Use the existing AI service to generate insights
        let prompt = """
        Analyze this sermon titled "\(document.title)" and provide a brief, inspiring insight (2-3 sentences) that captures the essence of the message. 
        Focus on the spiritual impact and practical application. Make it engaging and encouraging for someone looking for guidance.
        """
        
        // For now, return a placeholder - in a real implementation, you'd call the AI service
        // AIService.shared.generateText(prompt: prompt) { result in ... }
        
        let insights = [
            "A powerful message about faith and perseverance that resonates with current challenges.",
            "This sermon explores deep biblical truths with practical applications for daily life.",
            "An inspiring message of hope and redemption that speaks to the heart.",
            "A thoughtful exploration of scripture that brings fresh perspective to familiar passages.",
            "This message offers wisdom and guidance for navigating life's complexities."
        ]
        
        // Use document title hash to get consistent insights for the same document
        let hash = abs(document.title.hashValue)
        return insights[hash % insights.count]
    }
    

    
    // Update content for new curation type without regenerating
    private func updateContentForNewCurationType() {
        guard !documents.isEmpty else { return }
        
        let selectedDocuments = getDocumentsForCurationType()
        var updatedCuratedSermons: [CuratedSermon] = []
        
        for document in selectedDocuments {
            let curatedSermon = CuratedSermon(
                document: document,
                aiInsight: getCurationTypeSpecificInsight(for: document),
                category: getCurationTypeSpecificCategory(for: document)
            )
            updatedCuratedSermons.append(curatedSermon)
        }
        
        aiCuratedSermons = updatedCuratedSermons
    }
    
    // Generate AI insights for all sermons using Foundation Models
    private func generateAICuratedSermons() {
        guard !documents.isEmpty else { 
            isGeneratingInsights = false
            return 
        }
        
        isGeneratingInsights = true
        
        Task {
            var newCuratedSermons: [CuratedSermon] = []
            let selectedDocuments = getDocumentsForCurationType()
            
            for document in selectedDocuments {
                do {
                    // Use Foundation Model for insight generation
                    let insight = try await FoundationModelService.shared.generateSermonInsight(for: document)
                    let category = try await FoundationModelService.shared.categorizeSermon(document)
                    
                    let curatedSermon = CuratedSermon(
                        document: document,
                        aiInsight: getCurationTypeSpecificInsight(for: document),
                        category: getCurationTypeSpecificCategory(for: document)
                    )
                    newCuratedSermons.append(curatedSermon)
                } catch {
                    // Fallback to curation-specific insights
                    let curatedSermon = CuratedSermon(
                        document: document,
                        aiInsight: getCurationTypeSpecificInsight(for: document),
                        category: getCurationTypeSpecificCategory(for: document)
                    )
                    newCuratedSermons.append(curatedSermon)
                }
            }
            
            await MainActor.run {
                self.aiCuratedSermons = newCuratedSermons
                self.isGeneratingInsights = false
            }
        }
    }
    
    // Get documents based on selected curation type
    private func getDocumentsForCurationType() -> [Letterspace_CanvasDocument] {
        switch selectedCurationType {
        case .insights:
            return Array(documents.prefix(5))
        case .sermonJournal:
            // Return sermons that have been preached recently (have scheduled dates in the past)
            let now = Date()
            return documents.filter { document in
                return document.variations.contains { variation in
                    if let scheduledDate = variation.datePresented {
                        return scheduledDate <= now
                    }
                    return false
                }
            }.sorted { doc1, doc2 in
                // Sort by most recent preaching date
                let date1 = doc1.variations.compactMap { $0.datePresented }.max() ?? Date.distantPast
                let date2 = doc2.variations.compactMap { $0.datePresented }.max() ?? Date.distantPast
                return date1 > date2
            }.prefix(5).map { $0 }
        case .preachItAgain:
            // Return sermons that have been preached before and are good candidates for re-preaching
            let now = Date()
            let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: now) ?? now
            
            return documents.filter { document in
                // Must have been preached at least once
                return document.variations.contains { variation in
                    if let scheduledDate = variation.datePresented {
                        return scheduledDate <= sixMonthsAgo // At least 6 months ago
                    }
                    return false
                }
            }.sorted { doc1, doc2 in
                // Sort by oldest preaching date (longest time since preached)
                let date1 = doc1.variations.compactMap { $0.datePresented }.max() ?? Date.distantFuture
                let date2 = doc2.variations.compactMap { $0.datePresented }.max() ?? Date.distantFuture
                return date1 < date2
            }.prefix(5).map { $0 }
        case .recent:
            return Array(documents.prefix(5))
        case .trending:
            return Array(documents.sorted { $0.title.count > $1.title.count }.prefix(5))
        case .statistics:
            return []
        }
    }
    
    // Get curation type specific insights
    private func getCurationTypeSpecificInsight(for document: Letterspace_CanvasDocument) -> String {
        let hash = abs(document.title.hashValue)
        
        switch selectedCurationType {
        case .insights:
            let insights = [
                "A powerful message about faith and perseverance that resonates with current challenges.",
                "This sermon explores deep biblical truths with practical applications for daily life.",
                "An inspiring message of hope and redemption that speaks to the heart.",
                "A thoughtful exploration of scripture that brings fresh perspective to familiar passages.",
                "This message offers wisdom and guidance for navigating life's complexities."
            ]
            return insights[hash % insights.count]
            
        case .sermonJournal:
            // Check if this sermon has journal entries and include insights from them
            let baseInsights = [
                "Ready for post-preaching reflection? Capture what God revealed while preaching.",
                "Time to journal about this message's impact and your experience delivering it.",
                "Reflect on how the Spirit moved during this sermon and what you learned.",
                "Document the testimonies and breakthroughs you witnessed with this message.",
                "Record your thoughts and follow-up ideas while they're fresh in your mind."
            ]
            
            // In a real implementation, you'd load actual journal entries here
            // For now, return base insights with potential journal context
            let insight = baseInsights[hash % baseInsights.count]
            
            // TODO: Add actual journal entry integration
            // if hasJournalEntry(for: document.id) {
            //     return "Previous reflection: \(journalEntry.insights). Ready to reflect again?"
            // }
            
            return insight
            
        case .preachItAgain:
            let preachAgainInsights = [
                "This powerful message is ready for another delivery to reach new hearts.",
                "A timeless sermon that could speak powerfully to your current congregation.",
                "Consider revisiting this message with fresh insights and updated applications.",
                "This sermon has proven impact - perfect timing to preach it again.",
                "A classic message that deserves to be heard by today's generation."
            ]
            return preachAgainInsights[hash % preachAgainInsights.count]
            
        case .recent:
            return "Recently created content that reflects current spiritual insights and growth."
            
        case .trending:
            return "Popular content that has resonated with many seeking spiritual guidance."
            
        case .statistics:
            return ""
        }
    }
    
    // Get curation type specific categories
    private func getCurationTypeSpecificCategory(for document: Letterspace_CanvasDocument) -> String {
        let hash = abs(document.title.hashValue)
        
        switch selectedCurationType {
        case .insights:
            let categories = ["Faith", "Hope", "Wisdom", "Guidance", "Inspiration"]
            return categories[hash % categories.count]
            
        case .sermonJournal:
            let journalCategories = ["Reflection", "Follow-Up", "Testimony", "Growth", "Impact"]
            return journalCategories[hash % journalCategories.count]
            
        case .preachItAgain:
            let preachAgainCategories = ["Proven", "Timeless", "Relevant", "Impactful", "Ready"]
            return preachAgainCategories[hash % preachAgainCategories.count]
            
        case .recent:
            return "New"
            
        case .trending:
            return "Popular"
            
        case .statistics:
            return "Data"
        }
    }
    
    // MARK: - Sermon Journal Section
    @ViewBuilder
    private var sermonJournalSection: some View {
        HStack {
            journalEntriesCard
                .frame(width: 280, height: 160)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Journal Entries Sheet State
    @State private var showAllJournalEntriesSheet: Bool = false
    @State private var selectedJournalEntry: SermonJournalEntry? = nil
    @State private var showJournalFeedSheet: Bool = false
    
    // Invisible anchor to attach sheets for journal entries
    private var journalEntriesSheets: some View {
        EmptyView()
            .sheet(isPresented: $showAllJournalEntriesSheet) {
                SermonJournalEntriesList(onSelect: { entry in
                    // Replace the list sheet with the entry detail sheet
                    showAllJournalEntriesSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        selectedJournalEntry = entry
                    }
                }, onDismiss: {
                    showAllJournalEntriesSheet = false
                })
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showJournalFeedSheet) {
                JournalFeedView(onDismiss: { showJournalFeedSheet = false })
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartJournalForDocument"))) { notif in
                        if let doc = notif.object as? Letterspace_CanvasDocument {
                            showJournalFeedSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                activeSheet = .sermonJournal(doc)
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartJournalCustomEntry"))) { _ in
                        showJournalFeedSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            // Start journal without a sermon by using a temporary blank document
                            var temp = Letterspace_CanvasDocument(title: "", subtitle: "", elements: [], id: UUID().uuidString)
                            activeSheet = .sermonJournal(temp)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSermonPickerFromJournal"))) { _ in
                        showJournalFeedSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showAllJournalEntriesSheet = false
                            // Reuse the sermon picker we have via ReflectionSelectionView
                            activeSheet = .reflectionSelection
                        }
                    }
                    .presentationDetents([.large])
            }
            .sheet(item: $selectedJournalEntry) { entry in
                SermonJournalEntryDetail(entry: entry) {
                    selectedJournalEntry = nil
                }
                .presentationDetents([.large])
            }
    }

    // Data sources for journal cards
    private var journalPendingSermons: [Letterspace_CanvasDocument] {
        // Sermons preached in the last 14 days without a journal entry
        let recent = documents.filter { doc in
            guard let last = doc.variations.compactMap({ $0.datePresented }).max() else { return false }
            return Date().timeIntervalSince(last) < 14 * 24 * 3600
        }
        let journalIds = Set(SermonJournalService.shared.entries().map { $0.sermonId })
        return recent.filter { !journalIds.contains($0.id) }
    }

    private var recentCompletedSermons: [Letterspace_CanvasDocument] {
        // Sermons with entries, most recent 3
        let journalIdsOrdered = SermonJournalService.shared.entries()
            .map { $0.sermonId }
        var seen = Set<String>()
        var ordered: [Letterspace_CanvasDocument] = []
        for id in journalIdsOrdered where !seen.contains(id) {
            seen.insert(id)
            if let doc = documents.first(where: { $0.id == id }) {
                ordered.append(doc)
            } else if let loaded = Letterspace_CanvasDocument.load(id: id) {
                ordered.append(loaded)
            }
            if ordered.count >= 3 { break }
        }
        return ordered
    }

    private func latestJournalEntry(for sermonId: String) -> SermonJournalEntry? {
        SermonJournalService.shared.entries().first { $0.sermonId == sermonId }
    }
    
    // MARK: - Preach It Again Section
    @ViewBuilder
    private var preachItAgainSection: some View {
        if getDocumentsForCurationType().isEmpty {
            // Empty state for preach it again
            VStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.primary.opacity(0.3))
                Text("No sermons ready to preach again")
                    .font(.custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.primary.opacity(0.6))
                Text("Sermons will appear here 6+ months after being preached")
                    .font(.custom("InterTight-Regular", size: 12))
                    .foregroundStyle(theme.primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(getDocumentsForCurationType(), id: \.id) { document in
                        PreachItAgainCard(
                            document: document,
                            onTap: { 
                                showPreachItAgainDetails(for: document)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .contentMargins(.horizontal, 10, for: .scrollContent)
        }
    }
    
    // MARK: - Add Reflection Card
    @ViewBuilder
    private var addReflectionCard: some View {
        Button(action: {
            activeSheet = .reflectionSelection
        }) {
            ZStack {
                LinearGradient(colors: [theme.accent.opacity(0.95), theme.accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 10)
                VStack(spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.18))
                                .frame(width: 28, height: 28)
                            Image(systemName: "sparkles")
                                .foregroundStyle(.white)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text("Add Reflection")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    Text("Capture insights from your recent sermons")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .semibold))
                        Text("Start")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .padding(18)
            }
            .frame(height: 170)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Journal Entries Card (Apple Journal style)
    @ViewBuilder
    private var journalEntriesCard: some View {
        Button(action: {
            showJournalFeedSheet = true
        }) {
            ZStack {
                LinearGradient(colors: [Color.indigo.opacity(0.9), Color.purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
                
                VStack(spacing: 8) {
                    HStack(alignment: .center) {
                        Image(systemName: "book.pages")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .semibold))
                        Text("Journal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(SermonJournalService.shared.entries().count)")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Entries")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                        }
                        
                        if let lastEntry = SermonJournalService.shared.entries().first {
                            Text("Last entry \(relativeDate(lastEntry.createdAt))")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.85))
                        } else {
                            Text("No entries yet")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(.white)
                        Text("Open Feed")
                            .foregroundStyle(.white)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white)
                    }
                }
                .padding(14)
            }
            .frame(height: 160)
        }
        .buttonStyle(.plain)
    }
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Custom Card Components

struct SermonJournalCard: View {
    let document: Letterspace_CanvasDocument
    let onTap: () -> Void
    @Environment(\.themeColors) var theme
    
    private var lastPreachedDate: Date? {
        document.variations.compactMap { $0.datePresented }.max()
    }
    
    private var timeSincePreached: String {
        guard let date = lastPreachedDate else { return "Not preached yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Preached \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Modern gradient background
                LinearGradient(colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        // Subtle mesh overlay
                        AngularGradient(gradient: Gradient(colors: [Color.white.opacity(0.15), .clear, .clear, Color.white.opacity(0.15)]), center: .center)
                            .blendMode(.softLight)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Image(systemName: "book.pages.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Text(timeSincePreached)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.15)))
                    }
                    
                    Text(document.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if !document.subtitle.isEmpty {
                        Text(document.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 13))
                        Text("Add Reflection")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .padding(16)
            }
            .frame(width: 280, height: 160)
        }
        .buttonStyle(.plain)
    }
}

struct PreachItAgainCard: View {
    let document: Letterspace_CanvasDocument
    let onTap: () -> Void
    @Environment(\.themeColors) var theme
    
    private var lastPreachedDate: Date? {
        document.variations.compactMap { $0.datePresented }.max()
    }
    
    private var timeSincePreached: String {
        guard let date = lastPreachedDate else { return "Never preached" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var preachingHistory: String {
        let count = document.variations.filter { $0.datePresented != nil }.count
        return "\(count) time\(count == 1 ? "" : "s")"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Gradient background
                ZStack {
                    LinearGradient(
                        colors: [Color.orange.opacity(0.8), Color.red.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Header
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("READY")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.white.opacity(0.2))
                                )
                        }
                        
                        Spacer()
                        
                        // Title
                        Text(document.title)
                            .font(.custom("InterTight-Bold", size: 16))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        // History info
                        HStack {
                            Text("Last preached \(timeSincePreached)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                            
                            Text("Preached \(preachingHistory)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(16)
                }
                .frame(width: 280, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Bottom action
                HStack {
                    Text("View Details")
                        .font(.custom("InterTight-Medium", size: 14))
                        .foregroundColor(theme.primary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(theme.accent)
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recently Completed Sermon Card
struct CompletedSermonCard: View {
    let document: Letterspace_CanvasDocument
    let onTap: () -> Void
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                LinearGradient(colors: [Color.green.opacity(0.85), Color.teal.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .semibold))
                        Text("Reflected")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                        Spacer()
                    }
                    Text(document.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if !document.subtitle.isEmpty {
                        Text(document.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                    }
                }
                .padding(16)
            }
            .frame(width: 280, height: 160)
        }
        .buttonStyle(.plain)
    }
}

// Add this helper view for the button background
struct AddHeaderButtonBackground: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        let strokeColor = colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.1)
        
        let backgroundColor = colorScheme == .dark
            ? Color.black.opacity(0.2)
            : Color.black.opacity(0.03)
        
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                strokeColor,
                style: StrokeStyle(lineWidth: 1, dash: [4])
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
    }
}

#if os(macOS)
struct ScrollViewConfigurator: NSViewRepresentable {
    let shouldFlash: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = nsView.enclosingScrollView {
                scrollView.scrollerStyle = .overlay
                scrollView.scrollerKnobStyle = .light
                scrollView.verticalScroller?.alphaValue = 0.4  // Make it more transparent
                
                
                if let scroller = scrollView.verticalScroller {
                    scroller.controlSize = .mini
                    
                    // Make the scroller even thinner
                    let knobWidth: CGFloat = 2  // Original is usually 3-4px
                    scroller.knobProportion = knobWidth / scroller.bounds.size.height
                }
                
                if shouldFlash {
                    scrollView.flashScrollers()
                }
            }
        }
    }
}
#elseif os(iOS)
struct ScrollViewConfigurator: UIViewRepresentable {
    let shouldFlash: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // iOS implementation - scroll view configuration happens differently
        // For now, we'll keep this minimal as iOS handles scrolling differently
    }
}
#endif

struct CustomScrollModifier: ViewModifier {
    let shouldFlash: Bool
    
    func body(content: Content) -> some View {
        content
            .background(ScrollViewConfigurator(shouldFlash: shouldFlash))
    }
}

extension View {
    func customScroll(shouldFlash: Bool = false) -> some View {
        modifier(CustomScrollModifier(shouldFlash: shouldFlash))
    }
}

// Helper views for table cells

struct DocumentNameView: View {
    let document: Letterspace_CanvasDocument
    @Environment(\.themeColors) var theme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(theme.primary)
                .frame(width: 20)
            
            HStack(spacing: 4) {
                Text(document.title.isEmpty ? "Untitled" : document.title)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                
                if !document.subtitle.isEmpty {
                    Text("•")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.secondary)
                    Text(document.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
    }
}

#if os(macOS)
extension NSParagraphStyle {
    static func leftAligned(withPadding padding: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.headIndent = padding
        style.firstLineHeadIndent = padding
        return style
    }
}
#endif

@Observable
class DashboardViewModel {
    var folders: [Folder] = [
        Folder(id: UUID(), name: "Sermons", isEditing: false),
        Folder(id: UUID(), name: "Bible Studies", isEditing: false),
        Folder(id: UUID(), name: "Notes", isEditing: false),
        Folder(id: UUID(), name: "Archive", isEditing: false)
    ]
    var folderSwipeOffsets: [UUID: CGFloat] = [:]
    
    func resetSwipeOffset(for folderId: UUID) {
        folderSwipeOffsets[folderId] = 0
    }
    
    func updateSwipeOffset(for folderId: UUID, offset: CGFloat) {
        // Limit the offset to -60 (width of delete button) to 0
        folderSwipeOffsets[folderId] = max(-60, min(0, offset))
    }
    
    func saveFolders() {
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: "SavedFolders")
        }
    }
}

// Custom modifier to apply iPad-specific styling to carousel headers
struct CarouselHeaderStyling: ViewModifier {
    private var iconSize: CGFloat {
        #if os(iOS)
        return 14 // Fixed size for consistent alignment across iPad sizes
        #else
        return 14 // Fixed size for macOS
        #endif
    }
    
    private var headerPadding: CGFloat {
        #if os(iOS)
        return 12 // Fixed padding for consistent alignment across iPad sizes
        #else
        return 11 // Fixed size for macOS
        #endif
    }
    
    func body(content: Content) -> some View {
        content
            .environment(\.carouselHeaderFont, .custom("InterTight-Medium", size: 16))
            .environment(\.carouselIconSize, {
                #if os(iOS)
                return 12 // Reduced from 14 for a smaller header
                #else
                return 14 // Fixed size for macOS
                #endif
            }())
            .environment(\.carouselHeaderPadding, {
                #if os(iOS)
                return 12 // Fixed padding for consistent alignment across iPad sizes
                #else
                return 11 // Fixed size for macOS
                #endif
            }())
    }
}

// Custom environment values for carousel styling
private struct CarouselHeaderFontKey: EnvironmentKey {
    static let defaultValue: Font = .custom("InterTight-Medium", size: 16)
}

private struct CarouselIconSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 14
}

private struct CarouselHeaderPaddingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 4
}

extension EnvironmentValues {
    var carouselHeaderFont: Font {
        get { self[CarouselHeaderFontKey.self] }
        set { self[CarouselHeaderFontKey.self] = newValue }
    }
    
    var carouselIconSize: CGFloat {
        get { self[CarouselIconSizeKey.self] }
        set { self[CarouselIconSizeKey.self] = newValue }
    }
    
    var carouselHeaderPadding: CGFloat {
        get { self[CarouselHeaderPaddingKey.self] }
        set { self[CarouselHeaderPaddingKey.self] = newValue }
    }
}

#endif

// Helper structures for custom corner rounding
#if os(iOS)
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif

struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        return _path(rect)
    }
}

// Add this at the bottom of the file:
#if os(iOS)
private struct IgnoresSafeAreaModifier: ViewModifier {
    let isIPad: Bool
    func body(content: Content) -> some View {
        // FIXED: Don't ignore safe area - let iOS 26 handle it properly
        content
    }
}



#endif

    // Foundation Model service for sermon curation (ready for Foundation Models when available)
    private class FoundationModelService {
        static let shared = FoundationModelService()
        
        private var isModelLoaded = false
        
        private init() {}
        
        func loadModel() async throws {
            guard !isModelLoaded else { return }
            
            // TODO: When Foundation Models are available, uncomment this:
            // model = try SystemLanguageModel(useCase: .general)
            isModelLoaded = true
        }
        
        func generateSermonInsight(for document: Letterspace_CanvasDocument) async throws -> String {
            try await loadModel()
            
            // TODO: When Foundation Models are available, use this:
            // let prompt = """
            // Analyze this sermon titled "\(document.title)" and provide a brief, inspiring insight (2-3 sentences) that captures the essence of the message. 
            // Focus on the spiritual impact and practical application. Make it engaging and encouraging for someone looking for guidance.
            // """
            // let response = try await model.generate(prompt)
            // return response.text
            
            // For now, use intelligent fallback based on document title
            let insights = [
                "A powerful message about faith and perseverance that resonates with current challenges.",
                "This sermon explores deep biblical truths with practical applications for daily life.",
                "An inspiring message of hope and redemption that speaks to the heart.",
                "A thoughtful exploration of scripture that brings fresh perspective to familiar passages.",
                "This message offers wisdom and guidance for navigating life's complexities."
            ]
            let hash = abs(document.title.hashValue)
            return insights[hash % insights.count]
        }
        
        func categorizeSermon(_ document: Letterspace_CanvasDocument) async throws -> String {
            try await loadModel()
            
            // TODO: When Foundation Models are available, use this:
            // let prompt = """
            // Categorize this sermon titled "\(document.title)" into one of these categories: Faith, Hope, Wisdom, Guidance, Inspiration.
            // Return only the category name.
            // """
            // let response = try await model.generate(prompt)
            // return response.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // For now, use intelligent categorization based on document title
            let categories = ["Faith", "Hope", "Wisdom", "Guidance", "Inspiration"]
            let hash = abs(document.title.hashValue)
            return categories[hash % categories.count]
        }
    }

enum FoundationModelError: Error {
    case modelNotLoaded
    case generationFailed
}

// MARK: - Latest Entry Card
struct LatestEntryCard: View {
    let entry: SermonJournalEntry
    let onTap: () -> Void
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                LinearGradient(colors: [Color.mint.opacity(0.85), Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.and.text.magnifyingglass")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .semibold))
                        Text("Entry")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                        Spacer()
                    }
                    
                    Text(sermonTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(formatted(entry.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Open")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var sermonTitle: String {
        Letterspace_CanvasDocument.load(id: entry.sermonId)?.title ?? "Untitled Sermon"
    }
    
    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Journal Feed View
struct JournalFeedView: View {
    let onDismiss: () -> Void
    @ObservedObject private var service = SermonJournalService.shared
    @State private var isGenerating: Set<String> = []
    @State private var showPicker = false
    @State private var selectedEntryForDetail: SermonJournalEntry? = nil
    @Environment(\.themeColors) var theme
    
    // Group entries by month (yyyy-MM)
    private var groupedByMonth: [String: [SermonJournalEntry]] {
        Dictionary(grouping: service.entries()) { entry in
            let comps = Calendar.current.dateComponents([.year, .month], from: entry.createdAt)
            let y = comps.year ?? 0, m = comps.month ?? 0
            return String(format: "%04d-%02d", y, m)
        }
    }
    private var groupedByMonthSorted: [(key: String, value: [SermonJournalEntry])] {
        groupedByMonth.sorted { $0.key > $1.key }
    }
    
    private func monthTitle(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return key }
        var comps = DateComponents(); comps.year = y; comps.month = m
        let date = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }
    
    var body: some View {
        NavigationView {
            Group {
                if service.entries().isEmpty {
                    // Clean empty state – no stray timeline dot
                    VStack(spacing: 16) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        Text("No journal entries yet")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Tap + to add a custom reflection or attach one to a sermon.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            HStack(alignment: .top, spacing: 16) {
                                // Left vertical timeline with month nodes and a bottom dot
                                VStack(alignment: .trailing, spacing: 32) {
                                    ForEach(groupedByMonthSorted, id: \.key) { month, _ in
                                        HStack(spacing: 8) {
                                            VStack(spacing: 6) {
                                                Circle()
                                                    .fill(theme.accent)
                                                    .frame(width: 8, height: 8)
                                                Rectangle()
                                                    .fill(theme.accent.opacity(0.3))
                                                    .frame(width: 2, height: 24)
                                            }
                                            Text(monthTitle(month))
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(theme.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    // Bottom terminal dot
                                    Circle()
                                        .fill(theme.accent.opacity(0.7))
                                        .frame(width: 6, height: 6)
                                        .padding(.top, -12)
                                }
                                .frame(width: 120, alignment: .trailing)
                                
                                // Right: month groups with color-coded summary cards
                                VStack(alignment: .leading, spacing: 20) {
                                    ForEach(groupedByMonthSorted, id: \.key) { month, entries in
                                        Text(monthTitle(month))
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(theme.primary)
                                        
                                        VStack(spacing: 12) {
                                            ForEach(entries) { entry in
                                                LatestEntryCard(entry: entry) {
                                                    selectedEntryForDetail = entry
                                                }
                                                .id(entry.id)
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        SermonJournalService.shared.deleteEntry(id: entry.id)
                                                    } label: {
                                                        Label("Delete Entry", systemImage: "trash")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Open custom entry immediately
                        NotificationCenter.default.post(name: NSNotification.Name("StartJournalCustomEntry"), object: nil)
                    }) {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        // Open custom entry immediately
                        NotificationCenter.default.post(name: NSNotification.Name("StartJournalCustomEntry"), object: nil)
                    }) {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Done", action: onDismiss)
                }
                #endif
            }
        }
        .sheet(isPresented: $showPicker) {
            // Allow custom (no sermon) or pick from all documents
            ReflectionSelectionView(
                documents: loadAllDocuments(),
                onSelectDocument: { doc in
                    showPicker = false
                    NotificationCenter.default.post(name: NSNotification.Name("StartJournalForDocument"), object: doc)
                },
                onDismiss: { showPicker = false },
                allowCustom: true,
                onSelectNone: {
                    showPicker = false
                    NotificationCenter.default.post(name: NSNotification.Name("StartJournalCustomEntry"), object: nil)
                }
            )
        }
        .sheet(item: $selectedEntryForDetail) { entry in
            SermonJournalEntryDetail(entry: entry) {
                selectedEntryForDetail = nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
    }
    
    private func loadAllDocuments() -> [Letterspace_CanvasDocument] {
        // Prefer the service/state from dashboard if accessible; fallback to on-disk scan
        var results: [Letterspace_CanvasDocument] = []
        if let appDir = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
            if let files = try? FileManager.default.contentsOfDirectory(at: appDir, includingPropertiesForKeys: nil) {
                for url in files where url.pathExtension == "canvas" {
                    if let data = try? Data(contentsOf: url),
                       let doc = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                        results.append(doc)
                    }
                }
            }
        }
        return results.sorted { ($0.modifiedAt ?? $0.createdAt) > ($1.modifiedAt ?? $1.createdAt) }
    }
}
