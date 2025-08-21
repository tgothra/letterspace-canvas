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
    @EnvironmentObject var colorTheme: ColorThemeManager
    

    private let gradientManager = GradientWallpaperManager.shared
    @State private var selectedColumn: ListColumn = .name
    @State private var sortAscending = true
    @State private var dateFilterType: DateFilterType = .modified
    @State private var scrollOffset: CGFloat = 0
    @Namespace private var scrollSpace
    @State var documents: [Letterspace_CanvasDocument] = []
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
    @State var activeSheet: ActiveSheet?
    
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
    
    // Add state for AI-powered curation

    @State var selectedCurationType: CurationType = .todaysDocuments
    @State private var showCurationTypeDropdown = false
    // Today's Documents selection state
    @State var todayDocumentIds: Set<String> = []
    @State var showTodayPicker: Bool = false
    
    // Today's Documents structure state
    @State var todayStructure: [TodaySectionHeader] = []
    @State var todayStructureDocuments: [TodayStructureDocument] = []
    @State var showAddHeaderSheet: Bool = false
    
    // MARK: - Journal Entries Sheet State
    @State private var showAllJournalEntriesSheet: Bool = false
    @State private var selectedJournalEntry: SermonJournalEntry? = nil
    @State private var showJournalFeedSheet: Bool = false
    
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
            ("Starred", AnyView(carouselPinnedSectionView)),
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
    
  
    
    // Extracted computed property for the dashboard header (Mac version)
 
    
    // Extracted computed property for the dashboard header (iPad version)
  
    
    
        
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
            // Load Today's Docs selection (persist across opens)
            if let savedToday = UserDefaults.standard.array(forKey: "TodayDocumentIds") as? [String] {
                todayDocumentIds = Set(savedToday)
            }
            #if os(macOS)
            // Ensure Series and Location columns are always visible by default on macOS
            visibleColumns.insert("series")
            visibleColumns.insert("location")
            // Persist the preference so it sticks across launches
            UserDefaults.standard.set(Array(visibleColumns), forKey: "VisibleColumns")
            #endif
            loadDocuments()
            loadTodayStructure()
        }
        // Persist Today's selection when it changes
        .onChange(of: todayDocumentIds) { newValue in
            UserDefaults.standard.set(Array(newValue), forKey: "TodayDocumentIds")
            // Update structure documents when selection changes
            let newStructureDocs = newValue.map { docId in
                if let existing = todayStructureDocuments.first(where: { $0.id == docId }) {
                    return existing
                } else {
                    return TodayStructureDocument(id: docId, headerId: nil, order: todayStructureDocuments.count)
                }
            }
            todayStructureDocuments = newStructureDocs
            saveTodayStructure()
        }
        // Sanitize Today's selection when documents list refreshes
        .onChange(of: documents) { _ in
            let available = Set(documents.map { $0.id })
            let filtered = todayDocumentIds.intersection(available)
            if filtered != todayDocumentIds {
                todayDocumentIds = filtered
            }
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
                    #if os(macOS)
                    .frame(width: 600, height: 500)
                    #endif
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    
            case .tagManager:
                TagManager(allTags: allTags)
                    #if os(macOS)
                    .frame(width: 700, height: 600)
                    #endif
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .background(.clear)
                    
            case .sermonJournal(let document):
                SermonJournalView(document: document, allDocuments: documents) {
                    activeSheet = nil
                }
                #if os(macOS)
                .frame(width: 850, height: 700)
                #endif
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .background(.clear)
                
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
                #if os(macOS)
                .frame(width: 650, height: 500)
                #endif
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(.clear)
                
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
                #if os(macOS)
                .frame(width: 750, height: 650)
                #endif
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .background(.clear)
                
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
                #if os(macOS)
                .frame(width: 680, height: 580)
                #endif
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(.clear)
            
            case .curatedCategory(let type):
                Group {
                    #if os(macOS)
                    NavigationStack {
                        curatedCategoryContent(type)
                    }
                    #else
                    NavigationView {
                        curatedCategoryContent(type)
                    }
                    #endif
                }
                #if os(macOS)
                .frame(width: 800, height: 600)
                #endif
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .background(.clear)
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
                .background(.clear)
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
                    GreetingView()
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                    
                    // Curated sermons section (Spotify/Dwell-like)
                    curatedSermonsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 40)
                    
                    // Documents section that scrolls naturally
                    VStack(spacing: 0) {
                        // Docs header that scrolls with content
                        DashboardHeaderView(
                            selectedFilterColumn: $selectedFilterColumn,
                            selectedTags: $selectedTags,
                            isDateFilterExplicitlySelected: $isDateFilterExplicitlySelected,
                            selectedSortColumn: $selectedSortColumn,
                            isAscendingSortOrder: $isAscendingSortOrder,
                            tableRefreshID: $tableRefreshID,
                            activeSheet: $activeSheet,
                            allTags: allTags,
                            colorManager: colorManager,
                            onSearch: onSearch,
                            onUpdateVisibleColumns: updateVisibleColumns,
                            onUpdateDocumentSort: updateDocumentSort
                        )
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
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
                                .frame(height: 36)
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
                                .frame(height: 28)
                        }
                        .buttonStyle(.plain)
        #endif
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        if #available(iOS 26, *) {
                            // No background for iOS 26 - glass effect applied directly
                            Color.clear
                        } else {
                            // Fallback for older iOS
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                    }
                    .modifier(InteractiveGlassEffectModifier(cornerRadius: 12))

                }
                .padding(.horizontal, 35)
                .padding(.top, 35)
                
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
    
        // NEW: Simple docs header that scrolls naturally
  
    


    // NEW: Computed property to determine if any modal is presented
    private var isModalPresented: Bool {
        showDetailsCard || calendarModalData != nil || documentToShowInSheet != nil
    }
    
    // NEW: Animated dashboard header that shrinks/grows based on scroll progress
    @ViewBuilder
 
    
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
        
        return DocumentHeaderView(
            documents: documents,
            selectedFilterColumn: $selectedFilterColumn,
            selectedTags: $selectedTags,
            isDateFilterExplicitlySelected: $isDateFilterExplicitlySelected,
            selectedSortColumn: $selectedSortColumn,
            isAscendingSortOrder: $isAscendingSortOrder,
            tableRefreshID: $tableRefreshID,
            activeSheet: $activeSheet,
            allDocumentsPosition: $allDocumentsPosition,
            allTags: allTags,
            colorManager: colorManager,
            onSearch: onSearch ?? {},
            onUpdateVisibleColumns: updateVisibleColumns,
            onUpdateDocumentSort: updateDocumentSort
        )
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
                    Image(systemName: "star.fill")
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
            // Starred Section - simplified for landscape
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

    // Extract computed properties for styling (needed by landscape sections)
    private var cardBackground: some View {
            // Only check gradient for current color scheme
            let useGlassmorphism = colorScheme == .dark ? 
                gradientManager.selectedDarkGradientIndex != 0 :
                gradientManager.selectedLightGradientIndex != 0
            
        return Group {
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
                // Standard background with platform-specific colors
                RoundedRectangle(cornerRadius: 16)
                    .fill({
                        if colorScheme == .dark {
                            #if os(iOS)
                            return Color(.systemGray6)
                            #else
                            return Color(.controlBackgroundColor)
                            #endif
                        } else {
                            #if os(iOS)
                            return Color(.systemBackground)
                            #else
                            return Color(.windowBackgroundColor)
                            #endif
                        }
                    }())
            }
        }
    }
    
    private var cardShadowColor: Color {
        .black.opacity(0.08)
    }

    // iPad Carousel Component
 

    // Extracted computed property for StarredSection (for non-iPad layout)
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
                            case 0: return "star.fill"
                            case 1: return "clock.badge.checkmark"
                            case 2: return "calendar"
                            default: return "doc.text"
                            }
                        }())
                        .font(.system(size: isIPad ? 14 : 11, weight: .medium)) // Larger icon for iPad
                        
                        // Title for each section
                        Text({
                            switch index {
                            case 0: return "Starred"
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
        CuratedContentView(types: Array(CurationType.allCases)) { type in
                        curatedCategoryCard(type)
                    }
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    ThemeDropdownPicker()
                        .padding(.top, 22)
                        .padding(.trailing, 0)
                }
                Spacer()
            }
        )
    }
    
    // Content view that changes based on curation type
    @ViewBuilder
    private var curatedContentView: some View {
        switch selectedCurationType {
        case .todaysDocuments:
            todaysDocumentsSection
        case .sermonJournal:
            sermonJournalSection
        case .preachItAgain:
            preachItAgainSection
        case .statistics:
            StatisticsView(
                documents: documents,
                onSelectDocument: onSelectDocument,
                onShowStatistics: { }
            )
        case .recent, .trending:
            EmptyView()
        }
    }
    

    
    // Handle document selection in Today's Documents
    private func onSelectDocument(_ document: Letterspace_CanvasDocument) {
        self.document = document
        self.sidebarMode = .details
        self.isRightSidebarVisible = true
    }

        // MARK: - Today's Documents Section
    @ViewBuilder
    var todaysDocumentsSection: some View {
        TodayDocumentsView(
            documents: documents,
            todayDocumentIds: todayDocumentIds,
            todayStructure: todayStructure,
            todayStructureDocuments: todayStructureDocuments,
            onSelectDocument: onSelectDocument,
            onRemoveDocument: removeFromToday,
            onAddHeader: { showAddHeaderSheet = true },
            onUpdateHeaderTitle: updateHeaderTitle,
            onRemoveHeader: removeHeader,
            onReorderStructure: reorderTodayStructure
        )
    }
    
    // MARK: - Helper functions for Today's Documents
    private func removeFromToday(_ documentId: String) {
        todayDocumentIds.remove(documentId)
                    UserDefaults.standard.set(Array(todayDocumentIds), forKey: "TodayDocumentIds")
    }
    
    private func reorderTodayDocuments(from source: IndexSet, to destination: Int) {
        let todayDocs = documents.filter { todayDocumentIds.contains($0.id) }
        var reorderedIds = todayDocs.map { $0.id }
        reorderedIds.move(fromOffsets: source, toOffset: destination)
        
        // Update the todayDocumentIds set with the new order
        todayDocumentIds = Set(reorderedIds)
        UserDefaults.standard.set(Array(todayDocumentIds), forKey: "TodayDocumentIds")
    }
    
    // MARK: - Today's Documents Structure Management
    private func addHeader() {
        let newHeader = TodaySectionHeader(
            id: UUID().uuidString,
            title: "New Section",
            order: todayStructure.count
        )
        todayStructure.append(newHeader)
        saveTodayStructure()
    }
    
    private func removeHeader(_ headerId: String) {
        todayStructure.removeAll { $0.id == headerId }
        // Move any documents that were under this header to the root level
        let documentsUnderHeader = todayStructureDocuments.filter { $0.headerId == headerId }
        for doc in documentsUnderHeader {
            if let index = todayStructureDocuments.firstIndex(where: { $0.id == doc.id }) {
                todayStructureDocuments[index].headerId = nil
            }
        }
        saveTodayStructure()
    }
    
    private func updateHeaderTitle(_ headerId: String, newTitle: String) {
        if let index = todayStructure.firstIndex(where: { $0.id == headerId }) {
            todayStructure[index].title = newTitle
            saveTodayStructure()
        }
    }
    
    private func moveDocumentToHeader(_ documentId: String, headerId: String?) {
        if let index = todayStructureDocuments.firstIndex(where: { $0.id == documentId }) {
            todayStructureDocuments[index].headerId = headerId
            saveTodayStructure()
        }
    }
    
    func saveTodayStructure() {
        let structureData = TodayStructureData(
            headers: todayStructure,
            documents: todayStructureDocuments
        )
        if let encoded = try? JSONEncoder().encode(structureData) {
            UserDefaults.standard.set(encoded, forKey: "TodayStructureData")
        }
    }
    
    private func loadTodayStructure() {
        if let data = UserDefaults.standard.data(forKey: "TodayStructureData"),
           let structureData = try? JSONDecoder().decode(TodayStructureData.self, from: data) {
            todayStructure = structureData.headers
            todayStructureDocuments = structureData.documents
                                } else {
            // Initialize with default structure if none exists
            todayStructure = []
            todayStructureDocuments = documents.filter { todayDocumentIds.contains($0.id) }.map { doc in
                TodayStructureDocument(id: doc.id, headerId: nil, order: 0)
            }
        }
    }
    
    private func renderTodayStructure() -> [TodayStructureItem] {
        var items: [TodayStructureItem] = []
        
        // Add headers first
        for header in todayStructure.sorted(by: { $0.order < $1.order }) {
            items.append(.header(header))
            
            // Add documents under this header
            let documentsUnderHeader = todayStructureDocuments
                .filter { $0.headerId == header.id }
                .sorted(by: { $0.order < $1.order })
            
            for (index, docStruct) in documentsUnderHeader.enumerated() {
                if let document = documents.first(where: { $0.id == docStruct.id }) {
                    items.append(.document(document, index + 1))
                }
            }
        }
        
        // Add documents without headers (root level)
        let rootDocuments = todayStructureDocuments
            .filter { $0.headerId == nil }
            .sorted(by: { $0.order < $1.order })
        
        for (index, docStruct) in rootDocuments.enumerated() {
            if let document = documents.first(where: { $0.id == docStruct.id }) {
                items.append(.document(document, index + 1))
            }
        }
        
        return items
    }
    
    private func reorderTodayStructure(from source: IndexSet, to destination: Int) {
        var items = renderTodayStructure()
        items.move(fromOffsets: source, toOffset: destination)
        
        // Update the structure based on new order
        updateStructureFromItems(items)
    }
    
    private func updateStructureFromItems(_ items: [TodayStructureItem]) {
        var newHeaders: [TodaySectionHeader] = []
        var newDocuments: [TodayStructureDocument] = []
        
        for (index, item) in items.enumerated() {
            switch item {
            case .header(let header):
                var updatedHeader = header
                updatedHeader.order = index
                newHeaders.append(updatedHeader)
            case .document(let document, _):
                let headerId = findHeaderIdForDocument(at: index, in: items)
                let docStruct = TodayStructureDocument(
                    id: document.id,
                    headerId: headerId,
                    order: index
                )
                newDocuments.append(docStruct)
            }
        }
        
        todayStructure = newHeaders
        todayStructureDocuments = newDocuments
        saveTodayStructure()
    }
    
    private func findHeaderIdForDocument(at index: Int, in items: [TodayStructureItem]) -> String? {
        // Find the most recent header before this document
        for i in (0..<index).reversed() {
            if case .header(let header) = items[i] {
                return header.id
            }
        }
        return nil
    }
    
    

    

    // Explicit variant to render for a provided type (avoids stale selected type on first open)
    
    
    // Carousel view placeholder (curation moved out)
    @ViewBuilder
    private var curatedSermonsCarousel: some View {
        EmptyView()
    }

    // Card for a curated category
    
    

    
    // Curated sermon card component
    // (moved to StatisticsView.swift)
    
    // Curated sermons moved to extracted views; legacy helper removed
    

    

    

    

    
    // Get documents based on selected curation type
    private func getDocumentsForCurationType() -> [Letterspace_CanvasDocument] {
        switch selectedCurationType {
        case .todaysDocuments:
            return Array(documents.filter { todayDocumentIds.contains($0.id) }.prefix(5))
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
            // Placeholder: meetings-focused curation could pull from calendar or tagged docs
            return Array(documents.prefix(5))
        case .statistics:
            return []
        }
    }
    
    // Get curation type specific insights
    private func getCurationTypeSpecificInsight(for document: Letterspace_CanvasDocument) -> String {
        let hash = abs(document.title.hashValue)
        
        switch selectedCurationType {
        case .todaysDocuments:
            let notes = [
                "Planned for today's service.",
                "Queued for today's preparation and delivery.",
                "Selected for today's ministry focus.",
                "On deck for today's session.",
                "Curated for today."
            ]
            return notes[hash % notes.count]
            
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
            return "Stay on top of your upcoming and recent meetings at a glance."
            
        case .statistics:
            return ""
        }
    }
    
    // Get curation type specific categories
    private func getCurationTypeSpecificCategory(for document: Letterspace_CanvasDocument) -> String {
        let hash = abs(document.title.hashValue)
        
        switch selectedCurationType {
        case .todaysDocuments:
            let categories = ["Today", "Now", "Service", "Prep", "Focus"]
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
            return "Meeting"
            
        case .statistics:
            return "Data"
        }
    }
    
    // MARK: - Sermon Journal Section
    @ViewBuilder
    var sermonJournalSection: some View {
        SermonJournalSectionView(
            documents: documents,
            onSelectDocument: onSelectDocument,
            onShowSermonJournal: { document in
                activeSheet = .sermonJournal(document)
            },
            onShowAllJournalEntries: {
                showAllJournalEntriesSheet = true
            },
            onShowJournalFeed: {
                showJournalFeedSheet = true
            }
        )
    }
    
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
                #if os(macOS)
                .frame(width: 800, height: 700)
                #endif
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
                    #if os(macOS)
                    .frame(width: 850, height: 750)
                    #endif
                    .presentationDetents([.large])
            }
            .sheet(item: $selectedJournalEntry) { entry in
                SermonJournalEntryDetail(entry: entry) {
                    selectedJournalEntry = nil
                }
                #if os(macOS)
                .frame(width: 750, height: 650)
                #endif
                .presentationDetents([.large])
            }
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
    var preachItAgainSection: some View {
        PreachItAgainView(
            documents: getDocumentsForCurationType(),
            onSelect: { doc in showPreachItAgainDetails(for: doc) }
        )
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






// CompletedSermonCard removed (unused)

// AddHeaderButtonBackground removed (unused)

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

    // End of DashboardView core implementation
}

// MARK: - File-scope helpers and extensions

struct CustomScrollModifier: ViewModifier {
    let shouldFlash: Bool
    
    func body(content: Content) -> some View {
        content
            .background(DashboardView.ScrollViewConfigurator(shouldFlash: shouldFlash))
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

    // FoundationModelService moved to Services/FoundationModelService.swift

       

enum FoundationModelError: Error {
    case modelNotLoaded
    case generationFailed
}
