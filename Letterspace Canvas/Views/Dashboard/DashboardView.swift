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
    @Binding var showFloatingSidebar: Bool // Add floating sidebar state
    var floatingSidebarWidth: CGFloat // Add floating sidebar width parameter
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var gradientManager = GradientWallpaperManager.shared
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
    @State private var showTagManager = false
    @State private var isHoveringInfo = false
    @State private var hoveredTag: String? = nil
    @StateObject private var colorManager = TagColorManager.shared
    @State private var isViewButtonHovering = false
    @State private var showDetailsCard = false
    @State private var selectedDetailsDocument: Letterspace_CanvasDocument?
    @State private var showShareSheet = false
    // Add a refresh trigger state variable
    @State private var refreshTrigger: Bool = false
    // Add state variable for table refresh ID
    @State private var tableRefreshID = UUID()
    
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
    
    // NEW: State for All Documents sheet behavior (iPhone only)
    @State private var allDocumentsOffset: CGFloat = 0
    @State private var isDraggingAllDocuments: Bool = false
    @State private var allDocumentsPosition: AllDocumentsPosition = .default
    
    // Sheet position states
    enum AllDocumentsPosition {
        case collapsed  // Minimum height, carousel expanded
        case `default`  // Current default position
        case expanded   // Full screen like iOS sheet
        
        var offset: CGFloat {
            switch self {
            case .collapsed:
                // No offset - All Documents section stays at same position as default
                return 0  // No spacing change from carousel buttons
            case .default:
                return 0    // No offset
            case .expanded:
                return -200 // Pull up by 200 points
            }
        }
        
        var carouselHeight: CGFloat {
            switch self {
            case .collapsed:
                return 420  // Much taller expanded carousel height (increased from 350)
            case .default:
                return 200  // Default carousel height
            case .expanded:
                return 140  // Minimized carousel height
            }
        }
    }
    
    // Computed property to determine if navigation padding should be added
    private var shouldAddNavigationPadding: Bool {
        #if os(iOS)
        // Only add padding when navigation is actually shown in dashboard mode for both iPad and iPhone
        let isIPadOrPhone = UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .phone
        return isIPadOrPhone && showFloatingSidebar && sidebarMode == .allDocuments
        #else
        return false
        #endif
    }
    
    // NEW: Computed property for responsive navigation padding
    private var navPadding: CGFloat {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if isPhone {
            // iPhone: Extra breathing room between nav and content
            return floatingSidebarWidth + 60 // Sidebar width + 60pt buffer (increased from 55pt)
        } else {
            // iPad: More breathing room between nav and content
            return floatingSidebarWidth + 70 // Sidebar width + 70pt buffer for more breathing room
        }
        #else
        return 0
        #endif
    }
    
    // iPad detection helper
    private var isIPadDevice: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return true // macOS always supports reorder
        #endif
    }
    
    // Helper function to calculate flexible column widths for iPhone
    private func calculateFlexibleColumnWidths() -> (statusWidth: CGFloat, nameWidth: CGFloat, seriesWidth: CGFloat, locationWidth: CGFloat, dateWidth: CGFloat, createdDateWidth: CGFloat) {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if isPhone {
            // Get available width (93% of screen width minus padding)
            let availableWidth = UIScreen.main.bounds.width * 0.93 - 32 // Account for container padding
            
            // Fixed width for status column
            let statusWidth: CGFloat = 55
            
            // Calculate remaining width for other columns
            let remainingWidth = availableWidth - statusWidth
            
            // Get visible columns (excluding status)
            let visibleNonStatusColumns = visibleColumns.filter { $0 != "status" }
            
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
        }
        #endif
        
        // Default values for non-iPhone devices
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
            isCarouselMode: isLandscapeMode, // Use state variable for orientation
            showExpandButtons: shouldShowExpandButtons, // separate parameter for expand buttons
            onShowModal: {
                showPinnedModal = true
            },
            allDocumentsPosition: allDocumentsPosition // Pass the position for iPhone dynamic heights
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
            isCarouselMode: isLandscapeMode, // Use state variable for orientation
            showExpandButtons: shouldShowExpandButtons, // separate parameter for expand buttons
            onShowModal: {
                showWIPModal = true
            },
            allDocumentsPosition: allDocumentsPosition // Pass the position for iPhone dynamic heights
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
            isCarouselMode: isLandscapeMode, // Use state variable for orientation
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
        if pinnedDocuments.contains(docId) {
            pinnedDocuments.remove(docId)
        } else {
            pinnedDocuments.insert(docId)
        }
        saveDocumentState()
    }
    
    private func toggleWIP(_ docId: String) {
        if wipDocuments.contains(docId) {
            wipDocuments.remove(docId)
        } else {
            wipDocuments.insert(docId)
        }
        saveDocumentState()
    }
    
    private func deleteSelectedDocuments() {
        print("deleteSelectedDocuments called")
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let appDirectory = documentsURL.appendingPathComponent("Letterspace Canvas")
        
        print("Attempting to delete \(selectedDocuments.count) documents from: \(appDirectory.path)")
        
        for docId in selectedDocuments {
            print("Processing document ID: \(docId)")
            if let document = documents.first(where: { $0.id == docId }) {
                let fileURL = appDirectory.appendingPathComponent("\(document.id).canvas")
                print("Deleting document at: \(fileURL.path)")
                do {
                    try fileManager.removeItem(at: fileURL)
                    print("Successfully deleted document: \(document.title)")
                } catch {
                    print("Error deleting document: \(error)")
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
    
    private func saveDocumentState() {
        let defaults = UserDefaults.standard
        defaults.set(Array(pinnedDocuments), forKey: "PinnedDocuments")
        defaults.set(Array(wipDocuments), forKey: "WIPDocuments")
        
        // Refresh carousel sections when document states change
        initializeCarouselSections()
        
        // Post notification that documents have been updated
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
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
            }
        // Apply blur effect when DocumentDetailsCard or calendar modal is shown
        .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
        .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
    }
    
    // Extracted computed property for the dashboard header (iPad version)
    private var iPadDashboardHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 8 : 12 // iPhone: closer spacing, iPad: original spacing
                #else
                return 12
                #endif
            }()) {
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
                            // iPad: original sizing
                            let calculatedSize = screenWidth * 0.065 // 6.5% of screen width
                            return max(45, min(85, calculatedSize)) // Constrain between 45-85pt
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
        }
        .padding(.horizontal, 8)
        // Apply blur effect when DocumentDetailsCard or calendar modal is shown
        .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
        .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
    }
    
    // Landscape-specific header with bigger greeting
    private var iPadLandscapeHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) { // Increased spacing from 8 to 12 for more breathing room
                Text("Dashboard")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.primary.opacity(0.7))
                    .padding(.bottom, 2)
                
                Text(getTimeBasedGreeting())
                    .font(.custom("InterTight-Regular", size: 62)) // Increased from 52 to 62 for bigger greeting
                    .tracking(0.5)
                    .foregroundStyle(theme.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        // Apply blur effect when DocumentDetailsCard or calendar modal is shown
        .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
        .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            let isIPad: Bool = {
                #if os(iOS)
                return UIDevice.current.userInterfaceIdiom == .pad
                #else
                return false // macOS is never an iPad
                #endif
            }()
            
            ZStack { // Main ZStack for overlay handling
                dashboardContent // Use the extracted content view
                
                // Floating selection bar for All Documents multi-select (iPad only)
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad && isAllDocumentsEditMode {
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
                #endif
            }
            .blur(radius: isModalPresented || showPinnedModal || showWIPModal || showSchedulerModal ? 3 : 0)
            .opacity(isModalPresented || showPinnedModal || showWIPModal || showSchedulerModal ? 0.7 : 1.0)
            .overlay { modalOverlayView } // Apply overlay first
            .animation(.easeInOut(duration: 0.2), value: isModalPresented || showPinnedModal || showWIPModal || showSchedulerModal)
            .ignoresSafeArea(isIPad ? .all : [], edges: isIPad ? .top : [])
        }
        .onAppear {
                loadFolders()
                
                // Load pinned documents
                if let pinnedArray = UserDefaults.standard.array(forKey: "PinnedDocuments") as? [String] {
                    pinnedDocuments = Set(pinnedArray)
                }
                
                // Load WIP documents
                if let wipArray = UserDefaults.standard.array(forKey: "WIPDocuments") as? [String] {
                    wipDocuments = Set(wipArray)
                }
                
                // Load calendar documents
                if let calendarArray = UserDefaults.standard.array(forKey: "CalendarDocuments") as? [String] {
                    calendarDocuments = Set(calendarArray)
                }
                
                // iPhone-specific: Clear filters by default on app open for clean startup experience
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                if isPhone {
                    // Always start with cleared filters on iPhone
                    selectedTags.removeAll()
                    selectedFilterColumn = nil
                    selectedFilterCategory = "Filter"
                    updateVisibleColumns() // Update UI to reflect cleared filters
                }
                #endif
                
                // Load visible columns
                if let savedColumns = UserDefaults.standard.array(forKey: "VisibleColumns") as? [String] {
                    visibleColumns = Set(savedColumns)
                    
                    // iPad validation: ensure only one date column is visible
                    #if os(iOS)
                    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                    if isIPad && visibleColumns.contains("date") && visibleColumns.contains("createdDate") {
                        // If both date columns are saved, prefer modified date and remove created date
                        visibleColumns.remove("createdDate")
                        // Save the corrected preferences
                        UserDefaults.standard.set(Array(visibleColumns), forKey: "VisibleColumns")
                    }
                    #endif
                } else {
                    // Set default visible columns if none are saved
                    #if os(iOS)
                    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                    if isIPad {
                        // iPad default: only name column
                        visibleColumns = Set(["name"])
                    } else {
                        // iPhone default: only name column
                        visibleColumns = Set(["name"])
                    }
                    #else
                    // macOS default: only name column
                    visibleColumns = Set(["name"])
                    #endif
                }
                
                // Load carousel position (only if not first launch)
                if !isFirstLaunch {
                    selectedCarouselIndex = UserDefaults.standard.integer(forKey: "SelectedCarouselIndex")
                } else {
                    // On first launch, check if there's a saved position
                    let savedIndex = UserDefaults.standard.integer(forKey: "SelectedCarouselIndex")
                    // If no saved position exists (new user), start at 0, otherwise use saved position
                    if UserDefaults.standard.object(forKey: "SelectedCarouselIndex") == nil {
                        selectedCarouselIndex = 0 // New user - start at first card
                    } else {
                        selectedCarouselIndex = savedIndex // Returning user - use saved position
                    }
                    isFirstLaunch = false // Mark as no longer first launch
                }
                
                loadDocuments()
                
                // Initialize carousel sections AFTER all data is loaded
                initializeCarouselSections()
                
                // Listen for document unscheduling to refresh the calendar icons
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("DocumentUnscheduled"),
                    object: nil,
                    queue: .main
                ) { notification in
                    // When a document is explicitly unscheduled by user action
                    if let documentId = notification.userInfo?["documentId"] as? String {
                        // When a user explicitly chooses to remove scheduling,
                        // we remove the blue indicator by removing from calendarDocuments
                        self.calendarDocuments.remove(documentId)
                        
                        // Save updated blue indicator state
                        UserDefaults.standard.set(Array(self.calendarDocuments), forKey: "CalendarDocuments")
                        UserDefaults.standard.synchronize()
                        
                        // Post a notification to tell SermonCalendar to remove this document
                        // from its display list as well (different from just turning off the blue icon)
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RemoveFromCalendarList"),
                            object: nil,
                            userInfo: ["documentId": documentId]
                        )
                        
                        // Force refresh of the document list to update calendar icons
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
                    
                    // Find the document
                    if let doc = self.documents.first(where: { $0.id == documentId }) {
                        // Set this document for presentation manager
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.documentToShowInSheet = doc
                            
                            // The PresentationManager will need to look up the presentation by ID
                            // and set isEditingPresentation = true and editingPresentationId = presentationId
                            // We'll add this code in PresentationManager.swift
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
                        // Update selectedDetailsDocument
                        selectedDetailsDocument = document
                        // IMPORTANT: Also update selectedDocuments for the modal overlay condition
                        selectedDocuments = [documentId]
                        // Then show the card with animation
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDetailsCard = true
                        }
                    }
                }
                
                // Timer to periodically check for past dates and update UI
                // This ensures calendar icons are updated when dates become past
                Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in
                    // Update calendarDocuments to reflect ONLY documents with UPCOMING schedules
                    // This controls which icons are blue in the document list
                    // Note: We're not removing past events from the SermonCalendar list itself
                    
                    // Check all documents to see which should have blue calendar icons
                    var docsWithFutureSchedules = Set<String>()
                    
                    for document in self.documents {
                        if self.hasUpcomingSchedules(for: document) {
                            docsWithFutureSchedules.insert(document.id)
                        }
                    }
                    
                    // Only update if the set has changed to avoid unnecessary UI refreshes
                    if docsWithFutureSchedules != self.calendarDocuments {
                        // Update calendarDocuments
                        self.calendarDocuments = docsWithFutureSchedules
                        
                        // Save updated calendarDocuments
                        UserDefaults.standard.set(Array(self.calendarDocuments), forKey: "CalendarDocuments")
                        UserDefaults.standard.synchronize()
                        
                        // Refresh carousel sections when calendar documents change
                        initializeCarouselSections()
                        
                        // Force UI update
                        DispatchQueue.main.async {
                            // Post notification to update views
                            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                        }
                    }
                }
                
                // NEW: Observer for ShowPresentationManager
                NotificationCenter.default.addObserver(
                    forName: .showPresentationManager,
                    object: nil,
                    queue: .main
                ) { notification in
                    guard let userInfo = notification.userInfo,
                          let documentId = userInfo["documentId"] as? String else {
                        print("❌ ShowPresentationManager notification received without documentId")
                        return
                    }
                    
                    print("🔔 Received ShowPresentationManager notification for document ID: \(documentId)")
                    // Find the document and set it to be shown in the overlay
                    if let doc = self.documents.first(where: { $0.id == documentId }) {
                        // Use DispatchQueue to avoid modifying state during view update
                        DispatchQueue.main.async {
                             print("🔄 Setting documentToShowInSheet for ID: \(documentId)")
                            self.documentToShowInSheet = doc
                        }
                    } else {
                         print("❌ Document with ID \(documentId) not found for PresentationManager")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentListDidUpdate"))) { _ in
                loadDocuments()
                // Refresh carousel sections when document list updates
                initializeCarouselSections()
            }
            .overlay( // Keep the MultiSelectionActionBar overlay here
                Group {
                    if selectedDocuments.count >= 2 {
                        VStack {
                            Spacer()
                            MultiSelectionActionBar(
                                selectedCount: selectedDocuments.count,
                                onPin: {
                                    // Check if all selected documents are already pinned
                                    let allPinned = selectedDocuments.allSatisfy { pinnedDocuments.contains($0) }
                                    
                                    if allPinned {
                                        // If all are pinned, unpin all of them
                                        for docId in selectedDocuments {
                                            pinnedDocuments.remove(docId)
                                        }
                                    } else {
                                        // Otherwise, pin any that aren't pinned yet
                                        for docId in selectedDocuments {
                                            pinnedDocuments.insert(docId)
                                        }
                                    }
                                    saveDocumentState()
                                },
                                onWIP: {
                                    // Check if all selected documents are already WIP
                                    let allWIP = selectedDocuments.allSatisfy { wipDocuments.contains($0) }
                                    
                                    if allWIP {
                                        // If all are WIP, remove all of them
                                        for docId in selectedDocuments {
                                            wipDocuments.remove(docId)
                                        }
                                    } else {
                                        // Otherwise, add any that aren't WIP yet
                                        for docId in selectedDocuments {
                                            wipDocuments.insert(docId)
                                        }
                                    }
                                    saveDocumentState()
                                },
                                onDelete: deleteSelectedDocuments
                            )
                            .padding(.bottom, 24)
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.8)
                                        .combined(with: .offset(y: 50))
                                        .combined(with: .opacity),
                                    removal: .scale(scale: 0.8)
                                        .combined(with: .offset(y: 50))
                                        .combined(with: .opacity)
                                )
                            )
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: selectedDocuments.count > 1)
            )
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentScheduledUpdate"))) { notification in
            guard let userInfo = notification.userInfo,
                  let documentId = userInfo["documentId"] as? String else {
                return
            }
            
            // First find the document with this ID
            if let document = documents.first(where: { $0.id == documentId }) {
                // Only add to calendarDocuments if it has upcoming schedules
                if hasUpcomingSchedules(for: document) {
                    // Make sure the document is added to calendarDocuments
                    if !calendarDocuments.contains(documentId) {
                        calendarDocuments.insert(documentId)
                        // Save calendar documents state
                        UserDefaults.standard.set(Array(calendarDocuments), forKey: "CalendarDocuments")
                        UserDefaults.standard.synchronize()
                        
                        // Refresh carousel sections when calendar documents change
                        initializeCarouselSections()
                        
                        // Force UI update
                        DispatchQueue.main.async {
                            // Post notification to update views
                            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                        }
                    }
                }
            }
        }
        .onDisappear {
            // Remove notification observer when view disappears
            NotificationCenter.default.removeObserver(self)
        }
        .onChange(of: refreshTrigger) { _, _ in
            // This empty handler is sufficient to trigger a refresh
        }
        .onChange(of: colorScheme) {
            // Explicitly trigger table refresh when color scheme changes
            tableRefreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleWIP"))) { notification in
            if let documentId = notification.userInfo?["documentId"] as? String {
                toggleWIP(documentId)
            }
        }
        // iPad Modal Overlays
        .overlay(
            Group {
                // Pinned Modal
                if showPinnedModal {
                    iPadModalOverlay(
                        isPresented: $showPinnedModal,
                        title: "Pinned",
                        icon: "pin.fill"
                    ) {
                        PinnedSection(
                            documents: documents,
                            pinnedDocuments: $pinnedDocuments,
                            onSelectDocument: { selectedDoc in
                                onSelectDocument(selectedDoc)
                                showPinnedModal = false
                            },
                            document: $document,
                            sidebarMode: $sidebarMode,
                            isRightSidebarVisible: $isRightSidebarVisible,
                            isExpanded: .constant(true), // Always expanded in modal
                            isCarouselMode: false, // Disable carousel mode in modal
                            showExpandButtons: false, // No expand buttons in modal
                            hideHeader: true // Hide internal header since we have modal header
                        )
                    }
                }
                
                // WIP Modal
                if showWIPModal {
                    iPadModalOverlay(
                        isPresented: $showWIPModal,
                        title: "Work in Progress",
                        icon: "clock.badge.checkmark"
                    ) {
                        WIPSection(
                            documents: documents,
                            wipDocuments: $wipDocuments,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            isRightSidebarVisible: $isRightSidebarVisible,
                            isExpanded: .constant(true), // Always expanded in modal
                            isCarouselMode: false, // Disable carousel mode in modal
                            showExpandButtons: false, // No expand buttons in modal
                            hideHeader: true // Hide internal header since we have modal header
                        )
                    }
                }
                
                // Scheduler Modal
                if showSchedulerModal {
                    iPadModalOverlay(
                        isPresented: $showSchedulerModal,
                        title: "Document Schedule",
                        icon: "calendar"
                    ) {
                        SermonCalendar(
                            documents: documents,
                            calendarDocuments: calendarDocuments,
                            isExpanded: .constant(true), // Always expanded in modal
                            onShowModal: { data in
                                self.calendarModalData = data 
                            },
                            isCarouselMode: false, // Disable carousel mode in modal
                            showExpandButtons: false, // No expand buttons in modal
                            hideHeader: false, // Keep header area for padding, but hide content below
                            showMonthSelectorOnly: true // ONLY show month selector
                        )
                    }
                }
            }
        )
    }
    
    // iPad Modal Overlay Helper
    @ViewBuilder
    private func iPadModalOverlay<Content: View>(
        isPresented: Binding<Bool>,
        title: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            // Background blur similar to smart study modals
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented.wrappedValue = false
                    }
                }
            
            // Modal content centered on screen
            VStack(spacing: 0) {
                // Modal header with icon support
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(theme.primary)
                    }
                    
                    Text(title)
                        .font(.custom("InterTight-Medium", size: 22))
                        .foregroundStyle(theme.primary)
                    
                    Spacer()
                    
                    Button("Done") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented.wrappedValue = false
                        }
                    }
                    .font(.custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 24)
                .padding(.top, title == "Document Schedule" ? 100 : 20) // Extra top padding for Document Schedule
                .padding(.bottom, 20)
                .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
                
                // Divider after header
                Rectangle()
                    .fill(.separator)
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                
                // Content
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
            }
            .frame(width: 600, height: 500)
            .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
            ))
        }
    }
    
    // NEW: Extracted computed property for the main dashboard layout
    private var dashboardContent: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            let isIPad: Bool = {
                #if os(iOS)
                return UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .phone // iPhone now uses iPad interface
                #else
                return false // macOS is never an iPad
                #endif
            }()
            
            // Update landscape mode state for carousel sections
            let _ = DispatchQueue.main.async {
                #if os(macOS)
                isLandscapeMode = false // macOS doesn't use carousel styling
                shouldShowExpandButtons = true // but does show expand buttons
                #else
                isLandscapeMode = !isPortrait && isIPad // Both iPad and iPhone in landscape
                shouldShowExpandButtons = !isPortrait && isIPad // Both iPad and iPhone in landscape
                #endif
            }
            
            if isPortrait && isIPad {
                // iPad & iPhone Portrait: Special layout that respects navigation
                    VStack(alignment: .leading, spacing: 0) {
                    // Header with responsive positioning for navigation
                    iPadDashboardHeaderView
                    .padding(.horizontal, 20)
                        .padding(.top, {
                            // Responsive header positioning based on percentage of screen height
                            let screenHeight = geometry.size.height
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                return screenHeight * 0.10 // Slightly less top padding on iPhone (reduced from 12%)
                            } else {
                                return screenHeight * 0.08 // Original iPad padding
                            }
                            #else
                            return screenHeight * 0.08
                            #endif
                        }())
                        
                        // iPad & iPhone Carousel for sections
                        iPadSectionCarousel
                        .padding(.horizontal, {
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                return 20 // iPhone: centered with breathing room
                            } else {
                                return 10 // iPad: reduced from 20 to 10 to make carousel wider
                            }
                            #else
                            return 10
                            #endif
                        }())
                        .padding(.top, {
                            // Position carousel with comfortable breathing room from greeting
                            let screenHeight = geometry.size.height
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                // Adjust to keep carousel's absolute position the same after lowering the greeting
                                return screenHeight * 0.06
                            } else {
                                return screenHeight * 0.10 // Original iPad padding
                            }
                            #else
                            return screenHeight * 0.10
                            #endif
                        }())
                        
                        // Carousel Navigation Pills (iPhone only)
                        #if os(iOS)
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            carouselNavigationPills
                        }
                        #endif
                        
                        allDocumentsSectionView
                        .padding(.top, {
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                return 110 // Increased breathing room for iPhone between carousel and All Documents
                            } else {
                                return 60 // Optimal breathing room for iPad carousel cards
                            }
                            #else
                            return 10 // Keep reduced spacing for other platforms
                            #endif
                        }()) // Device-specific spacing between carousel and All Documents
                        .padding(.horizontal, {
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                // iPhone: Calculate padding to center 93% width content
                                let screenWidth = UIScreen.main.bounds.width
                                return screenWidth * 0.035 // 3.5% on each side for 93% centered content
                            } else {
                                return 10 // iPad: reduced from 20 to 10 to make All Documents wider
                            }
                            #else
                            return 10 // Keep reduced spacing for other platforms
                            #endif
                        }())
                        .padding(.leading, {
                                    #if os(macOS)
                                    return 24 // Fixed alignment with carousel sections on macOS
                                    #else
                                    #if os(iOS)
                                    if UIDevice.current.userInterfaceIdiom == .phone {
                                        return 0 // iPhone: no additional leading padding for centering
                                    } else {
                                        // Use the new responsive navPadding for iPad
                                        return shouldAddNavigationPadding ? navPadding : 10
                                    }
                                    #else
                                    return shouldAddNavigationPadding ? navPadding : 10
                                    #endif
                                    #endif
                                }()) // Platform-specific alignment - iPhone centered, iPad aligned
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showFloatingSidebar)
                        
                    // Remove Spacer to let All Documents fill remaining space
                    }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !isPortrait && isIPad {
                // iPad Landscape: Mirror the portrait layout structure
                VStack(alignment: .leading, spacing: 0) {
                    // Header with full width positioning - no longer affected by navigation
                    iPadLandscapeHeaderView
                        .padding(.horizontal, 20)
                        .padding(.top, 65) // Fixed top padding for consistent header positioning
                        
                    // iPad Landscape: Use horizontal layout like macOS but with iPad styling
                    iPadLandscapeSections
                        .padding(.horizontal, 20)
                        .padding(.leading, {
                            // Push cards over when navigation is visible (landscape only)
                            return shouldAddNavigationPadding ? 165 : 0  // Use fixed value for consistency
                        }())
                        .padding(.top, 45) // Increased from 25 to 45 for more breathing room between greeting and cards
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showFloatingSidebar)
                        
                    // Carousel Navigation Pills for Landscape (iPhone only)
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        carouselNavigationPills
                            .padding(.horizontal, 20) // Consistent padding for centering in landscape
                    }
                    #endif
                    
                    // All Documents section - with responsive spacing and height for different iPad sizes
                    allDocumentsSectionView
                        .padding(.top, {
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                return 110 // Increased breathing room for iPhone between carousel and All Documents in landscape
                            } else {
                                return 30 // Reduced space between carousel and All Documents for iPad landscape
                            }
                            #else
                            return 30 // Keep original spacing for other platforms
                            #endif
                        }()) // Device-specific spacing between carousel and All Documents
                        .padding(.trailing, 20) // Match right alignment with cards
                        .padding(.leading, {
                            #if os(macOS)
                            return 44 // Fixed alignment with carousel sections on macOS (24 + 20 base padding)
                            #else
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                // iPhone: Calculate padding to center 93% width content
                                let screenWidth = UIScreen.main.bounds.width
                                return screenWidth * 0.035 // 3.5% on each side for 93% centered content
                            } else {
                            // Match the cards' padding logic for better alignment - use fixed value for consistency
                            return shouldAddNavigationPadding ? 185 : 20  // 165 (cards) + 20 (base padding)
                            }
                            #else
                            return shouldAddNavigationPadding ? 185 : 20
                            #endif
                            #endif
                        }()) // Platform-specific alignment - iPhone centered, iPad aligned
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showFloatingSidebar)
                        
                    // Remove Spacer to let All Documents fill remaining space
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Non-iPad or other cases: Original layout
                VStack(alignment: .leading, spacing: 0) {
                    // Remove top spacing for iPad portrait to bring header to the top
                    Spacer().frame(minHeight: 0)
                    
                    // Use GeometryReader to dynamically center the header
                    GeometryReader { geometry in
                        let availableHeight = geometry.size.height
                        let sectionsHeight: CGFloat = 220 // Height needed for sections
                        let availableForHeader = availableHeight - sectionsHeight
                        let centerOffset = availableForHeader * 0.6 // Position at 60% down the available space
                        
                        VStack {
                            Spacer().frame(height: centerOffset)
                            
                            macDashboardHeaderView
                            
                            Spacer()
                        }
                    }
                    
                    // Wrap topContainers and allDocumentsSectionView in a ZStack for overlay effect
                    ZStack(alignment: .top) {
                        // Layer 0: Click-outside catcher (only active when a section is expanded)
                        if isPinnedExpanded || isWIPExpanded || isSchedulerExpanded {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Collapse all sections with animation
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isPinnedExpanded = false
                                        isWIPExpanded = false
                                        isSchedulerExpanded = false
                                    }
                                }
                                .zIndex(-1) // Ensure it's behind interactive elements
                        }

                        // Documents list (bottom layer)
                        VStack {
                            Spacer().frame(height: {
                                #if os(macOS)
                                return 290 // Reduced by 10 points to bring sections closer to All Documents
                                #else
                                // Responsive spacing for iOS/iPad - eliminating spacer for iPad
                                let screenHeight = UIScreen.main.bounds.height
                                return screenHeight * 0.01 // Minimal spacing to eliminate gap
                                #endif
                            }()) // Platform-specific spacing
                            HStack {
                                if shouldAddNavigationPadding {
                                    Spacer().frame(width: 185) // Fixed spacer width to reserve navigation space
                                } else {
                                    #if os(macOS)
                                    Spacer().frame(width: 0) // Extend to left edge for macOS to align with cards
                                    #else
                                    Spacer().frame(width: 20) // Minimal left margin when navigation hidden
                                    #endif
                                }
                                
                            allDocumentsSectionView
                                    .frame(maxWidth: .infinity, alignment: .trailing) // Align to right edge
                                
                                    #if os(macOS)
                                Spacer().frame(width: 0) // Extend to right edge for macOS to align with cards
                                    #else
                                Spacer().frame(width: 20) // Fixed right margin
                                    #endif
                            }
                                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showFloatingSidebar)
                        }

                        // Top containers (top layer)
                        VStack(spacing: 0) {
                            topContainers
                                .padding(.top, {
                                    #if os(iOS)
                                    return -10  // Negative padding to bring carousel much closer to greeting
                                    #else
                                    return 30  // Keep original spacing on macOS
                                    #endif
                                }())
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .top)  // Align content to top
                .scrollDismissesKeyboard(.immediately)
                .coordinateSpace(name: "dashboard")
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 24)
            }
        }
    }

    // NEW: Computed property to determine if any modal is presented
    private var isModalPresented: Bool {
        showDetailsCard || calendarModalData != nil || documentToShowInSheet != nil
    }

    // NEW: Extracted computed property for modal overlays
    @ViewBuilder
    private var modalOverlayView: some View {
        // Overlay for DocumentDetailsCard
        if showDetailsCard, let selectedDoc = selectedDetailsDocument,
           let currentIndex = documents.firstIndex(where: { $0.id == selectedDoc.id }) {
            // Dismiss layer
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetailsCard = false
                    }
                }

            // Modal Content
            DocumentDetailsCard(
                document: $documents[currentIndex],
                allLocations: allLocations,
                onNext: navigateToNextDocument,
                onPrevious: navigateToPreviousDocument,
                canNavigateNext: canNavigateNext,
                canNavigatePrevious: canNavigatePrevious,
                onDismiss: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetailsCard = false
                    }
                }
            )
            .frame(width: 600, height: 700)
            #if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #elseif os(iOS)
            .background(Color(UIColor.systemBackground))
            #endif
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: 10)
            .id(selectedDoc.id)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
            ))
        }
        // Overlay for PresentationNotesModal (Calendar Modal)
        else if let data = calendarModalData {
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
        // Overlay for PresentationManager
        else if let doc = documentToShowInSheet {
            // Dismiss layer
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        documentToShowInSheet = nil
                        UserDefaults.standard.removeObject(forKey: "editingPresentationId")
                        UserDefaults.standard.removeObject(forKey: "openToNotesStep")
                    }
                }

            // Modal Content
            PresentationManager(document: doc, isPresented: Binding(
                get: { self.documentToShowInSheet != nil },
                set: { show in
                    if !show {
                        UserDefaults.standard.removeObject(forKey: "editingPresentationId")
                        UserDefaults.standard.removeObject(forKey: "openToNotesStep")
                        self.documentToShowInSheet = nil
                    }
                }
            ))
            .environment(\.themeColors, theme)
            .environment(\.colorScheme, colorScheme)
            .frame(maxHeight: 600) // Add a height constraint to make the modal more compact
            .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: 10)
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
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("❌ Could not find documents directory")
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
                // Force refresh UI
                self.tableRefreshID = UUID()
                // Refresh carousel sections after documents are loaded
                self.initializeCarouselSections()
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
                // iPad/macOS: Original horizontal layout
                iPadMacDocumentHeader
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
                    Text("All Documents")
                        .font(.custom("InterTight-Medium", size: 16)) // Match carousel header font size
                        .foregroundStyle(theme.primary)
                    Text("(\(filteredDocuments.count))")
                        .font(.custom("InterTight-Regular", size: 14)) // Proportionally smaller
                        .foregroundStyle(theme.secondary)
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
    }
    
    // iPad/macOS header (original layout)
    private var iPadMacDocumentHeader: some View {
                        #if os(iOS)
                        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                        #else
                        let isIPad = false
                        #endif
                        
        return HStack(spacing: 6) {
            // Left side - Title
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.custom("InterTight-Regular", size: 16))
                    .foregroundStyle(theme.primary)
                Text("All Documents")
                    .font(.custom("InterTight-Medium", size: 18))
                    .foregroundStyle(theme.primary)
                Text("(\(filteredDocuments.count))")
                    .font(.custom("InterTight-Regular", size: 16))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 45, alignment: .leading)
                
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
                    .opacity(isHoveringInfo ? 0.6 : 1.0)
                    .onHover { hovering in
                        isHoveringInfo = hovering
                    }
                    .popover(isPresented: $showTagManager, arrowEdge: .bottom) {
                        TagManager(allTags: allTags)
                            .frame(width: 280)
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
                }
            }

            Spacer()
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
        
        // Refresh carousel sections when calendar documents change
        initializeCarouselSections()
        
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
        if selectedTags.isEmpty {
            return documents
        }
        return documents.filter { doc in
            guard let docTags = doc.tags else { return false }
            return !selectedTags.isDisjoint(with: docTags)
        }
    }
    
    // Add sorted version of filteredDocuments for consistent navigation
    private var sortedFilteredDocuments: [Letterspace_CanvasDocument] {
        // Sort the same way as in the DocumentTable display
        return filteredDocuments.sorted {
            // First sort by pinned status
            let isPinned1 = pinnedDocuments.contains($0.id)
            let isPinned2 = pinnedDocuments.contains($1.id)
            
            if isPinned1 != isPinned2 {
                return isPinned1
            }
            
            // Then sort alphabetically by title
            let title1 = $0.title.isEmpty ? "Untitled" : $0.title
            let title2 = $1.title.isEmpty ? "Untitled" : $1.title
            return title1.localizedCompare(title2) == .orderedAscending
        }
    }
    
    private func tagColor(for tag: String) -> Color {
        return colorManager.color(for: tag)
    }

    // Add this function to handle showing details
    private func showDetails(for document: Letterspace_CanvasDocument) {
        // Set the document first
        selectedDetailsDocument = document
        // Update selectedDocuments to include this document's ID
        selectedDocuments = [document.id]
        // Then show the sheet with animation
        withAnimation(.easeInOut(duration: 0.2)) {
            showDetailsCard = true
        }
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
    private func documentRowForIndex(_ index: Int, document: Letterspace_CanvasDocument) -> some View {
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
    
    // Extracted computed property for the "All Documents" section (header + table)
    private var allDocumentsSectionView: some View {
        #if os(iOS)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #else
        let isIPad = false
        let isPhone = false
        #endif
        
        return VStack(spacing: 0) {
            // Call the extracted header view - THIS SHOULD STAY FIXED
            documentSectionHeader

            #if os(macOS)
            DocumentTable(
                documents: Binding(
                    get: { filteredDocuments },
                    set: { documents = $0 }
                ),
                selectedDocuments: $selectedDocuments,
                isSelectionMode: isSelectionMode,
                pinnedDocuments: pinnedDocuments,

                wipDocuments: wipDocuments,
                calendarDocuments: calendarDocuments,
                visibleColumns: visibleColumns,
                dateFilterType: dateFilterType,
                onPin: togglePin,
                onWIP: toggleWIP,
                onCalendar: toggleCalendar,
                onOpen: { doc in
                    self.document = doc
                    self.sidebarMode = .details
                    self.isRightSidebarVisible = true
                },
                onShowDetails: showDetails,
                onDelete: { docIds in
                    selectedDocuments = Set(docIds)
                    deleteSelectedDocuments()
                },
                onCalendarAction: { document in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        documentToShowInSheet = document
                    }
                },
                refreshID: tableRefreshID
            )
            // Apply the height adjustment only to the table instead of the whole container
            .frame(height: 325)
            #elseif os(iOS)
            // iOS: SwiftUI-based document list optimized for touch
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            
            if isPhone {
                // iPhone: Table always fills full width, no horizontal scrolling needed
                VStack(alignment: .leading, spacing: 0) {
                    // Column Header Row
                    iosColumnHeaderRow
                    
                    // Document Rows
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(filteredDocuments.enumerated()), id: \.element.id) { index, document in
                                documentRowForIndex(index, document: document)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 435)
                }
                .padding(.horizontal, 0) // iPhone: Remove padding to allow table to fill full width
            } else {
                // iPad: Original layout without horizontal scrolling
            VStack(spacing: 0) {
                // Column Header Row
                iosColumnHeaderRow
                
                // Document Rows
                ScrollView {
                    LazyVStack(spacing: isIPad ? -4 : 0) {
                        ForEach(Array(filteredDocuments.enumerated()), id: \.element.id) { index, document in
                            documentRowForIndex(index, document: document)
                        }
                    }
                }
                .frame(height: isIPad ? nil : 435) // Remove fixed height on iPad to allow expansion
                .frame(maxHeight: isIPad ? .infinity : 435) // Allow it to fill available space on iPad
            }
                .padding(.horizontal, isIPad ? 20 : 16) // iPad: original padding
                }
            #endif
        }
        .glassmorphismBackground(cornerRadius: 12)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.17) : .black.opacity(0.07),
            radius: 8,
            x: 0,
            y: 1
        )

        .frame(
            maxWidth: {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                if isPhone {
                    // iPhone: 93% width to match carousel cards
                    return UIScreen.main.bounds.width * 0.93
                } else {
                    return .infinity // iPad: allow full width expansion
                }
                #else
                return .infinity // macOS: allow full width expansion
                #endif
            }()
        )
        .frame(height: isIPad ? nil : 400)
        .frame(maxHeight: isIPad ? .infinity : 400) // Allow All Documents to fill remaining space on iPad
        .blur(radius: isSchedulerExpanded || isPinnedExpanded || isWIPExpanded ? 3 : 0)
        .opacity(isSchedulerExpanded || isPinnedExpanded || isWIPExpanded ? 0.7 : 1.0)
        .onChange(of: selectedAllDocuments) { newSelection in
            // Auto-exit edit mode when all items are deselected
            if newSelection.isEmpty && isAllDocumentsEditMode {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAllDocumentsEditMode = false
                }
            }
        }
        // iPhone-specific sheet behavior
        .offset(y: isPhone ? allDocumentsPosition.offset + allDocumentsOffset : 0)
        .gesture(
            isPhone ? DragGesture()
                .onChanged { value in
                    // Allow dragging
                    allDocumentsOffset = value.translation.height
                    isDraggingAllDocuments = true
                }
                .onEnded { value in
                    let velocity = value.predictedEndTranslation.height
                    let dragThreshold: CGFloat = 100
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        let previousPosition = allDocumentsPosition
                        
                        // Determine final position based on drag distance and velocity
                        if allDocumentsPosition == .default {
                            if value.translation.height < -dragThreshold || velocity < -200 {
                                // Swipe up from default -> expanded
                                allDocumentsPosition = .expanded
                            } else if value.translation.height > dragThreshold || velocity > 200 {
                                // Swipe down from default -> collapsed
                                allDocumentsPosition = .collapsed
                            }
                        } else if allDocumentsPosition == .expanded {
                            if value.translation.height > dragThreshold || velocity > 200 {
                                // Swipe down from expanded -> default
                                allDocumentsPosition = .default
                            }
                        } else if allDocumentsPosition == .collapsed {
                            if value.translation.height < -dragThreshold || velocity < -200 {
                                // Swipe up from collapsed -> default
                                allDocumentsPosition = .default
                            }
                        }
                        
                        // Add haptic feedback if position changed
                        if previousPosition != allDocumentsPosition {
                            HapticFeedback.impact(.medium)
                        }
                        
                        // Reset offset
                        allDocumentsOffset = 0
                        isDraggingAllDocuments = false
                    }
                } : nil
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: allDocumentsPosition)
    }

    // iOS Column Header Row
    #if os(iOS)
    private var iosColumnHeaderRow: some View {
        let columnWidths = calculateFlexibleColumnWidths()
        
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
            .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 30 : columnWidths.statusWidth, alignment: UIDevice.current.userInterfaceIdiom == .pad ? .center : .leading)
            .padding(.leading, UIDevice.current.userInterfaceIdiom == .phone ? 10 : 0) // Add breathing room from left edge on iPhone to match document rows
            
            // Add breathing room between status indicators and name column on iPad (to match row)
            #if os(iOS)
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            if isIPad {
                Spacer().frame(width: 24)
            } else if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: Reduce spacing between status icons and name column
                Spacer().frame(width: 2)
            }
            #endif
            
            // Name column (sortable) - icon should align with document icons in rows
            if visibleColumns.contains("name") {
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
                            .font(.system(size: isPhone ? 13 : 16, weight: .medium))  // Smaller for iPhone
                            .foregroundColor(theme.secondary)
                        
                        if selectedColumn == .name {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))  // Smaller for iPhone
                                .foregroundColor(theme.secondary)
                        }
                        
                        Spacer() // This will push sort indicator to the right side of name column
                    }
                }
                .buttonStyle(.plain)
                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? nil : columnWidths.nameWidth, alignment: .leading)
            }
            
            // Series column (sortable) - if visible
            if visibleColumns.contains("series") {
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
                        
                        if selectedColumn == .series {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))  // Smaller for iPhone
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 100 : columnWidths.seriesWidth, alignment: .leading)
            }
            
            // Location column (sortable) - if visible
            if visibleColumns.contains("location") {
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
                        
                        if selectedColumn == .location {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))  // Smaller for iPhone
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 120 : columnWidths.locationWidth, alignment: .leading)
            }
            
            // Date column (sortable) - if visible (moved after location)
            if visibleColumns.contains("date") {
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
                        
                        if selectedColumn == .date {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))  // Smaller for iPhone
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 90 : columnWidths.dateWidth, alignment: .leading)
            }
            
            // Created date column - if visible
            if visibleColumns.contains("createdDate") {
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
                        
                        if selectedColumn == .createdDate {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: isPhone ? 10 : 12))  // Smaller for iPhone
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 80 : columnWidths.createdDateWidth, alignment: .leading)
            }
            
            // Add spacing before Actions column (iPad only)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            if !isPhone {
            Spacer().frame(width: 16)
            
                // Actions column (iPad only)
            Text("Actions")
                    .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.secondary)
                    .frame(width: 80, alignment: .center)
            }
        }
        .padding(.horizontal, 0) // iPhone: Remove padding to match table content
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
            if isPhone {
                // Use dynamic height based on All Documents position
                return allDocumentsPosition.carouselHeight
            } else {
                return 380 // iPad keeps fixed height
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
                        if isPhone {
                            // Use half of dynamic height
                            return (allDocumentsPosition.carouselHeight / 2) + draggedCardOffset.height * 0.2
                        } else {
                            return 190 + draggedCardOffset.height * 0.2 // iPad keeps fixed position
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
                        if isPhone {
                            // Use half of dynamic height
                            return allDocumentsPosition.carouselHeight / 2
                        } else {
                            return 190 // iPad keeps fixed position
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
                    if isPhone {
                        // Use half of dynamic height
                        return allDocumentsPosition.carouselHeight / 2
                    } else {
                        return 190 // iPad keeps fixed position
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
            carouselSections[index].view
                .frame(width: adjustedCardWidth, height: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if isPhone {
                        // Use dynamic height based on All Documents position
                        return allDocumentsPosition.carouselHeight
                    } else {
                        return 380 // iPad keeps fixed height
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
                        if isPhone {
                            // Use dynamic height based on All Documents position
                            return allDocumentsPosition.carouselHeight
                        } else {
                            return 380 // iPad keeps fixed height
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
        HStack(spacing: 6) {
            ForEach(0..<carouselSections.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                        selectedCarouselIndex = index
                        saveCarouselPosition()
                    }
                }) {
                    HStack(spacing: 5) {
                        // Icon for each section
                        Image(systemName: {
                            switch index {
                            case 0: return "pin.fill"
                            case 1: return "clock.badge.checkmark"
                            case 2: return "calendar"
                            default: return "doc.text"
                            }
                        }())
                        .font(.system(size: 11, weight: .medium)) // Slightly smaller icon
                        
                        // Title for each section
                        Text({
                            switch index {
                            case 0: return "Pinned"
                            case 1: return "WIP"
                            case 2: return "Schedule"
                            default: return "Section"
                            }
                        }())
                        .font(.custom("InterTight-Medium", size: 12)) // Slightly smaller text
                    }
                    .foregroundStyle(selectedCarouselIndex == index ? .white : theme.primary)
                    .padding(.horizontal, 10) // Slightly smaller horizontal padding
                    .padding(.vertical, 7) // Slightly smaller vertical padding
                    .background(
                        RoundedRectangle(cornerRadius: 14) // Slightly smaller corner radius
                            .fill(selectedCarouselIndex == index ? theme.accent : theme.accent.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity) // Center the pills in the available space
        .padding(.horizontal, 20) // Consistent horizontal padding for centering
        .padding(.vertical, 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showFloatingSidebar)
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

class DashboardViewModel: ObservableObject {
    @Published var folders: [Folder] = [
        Folder(id: UUID(), name: "Sermons", isEditing: false),
        Folder(id: UUID(), name: "Bible Studies", isEditing: false),
        Folder(id: UUID(), name: "Notes", isEditing: false),
        Folder(id: UUID(), name: "Archive", isEditing: false)
    ]
    @Published var folderSwipeOffsets: [UUID: CGFloat] = [:]
    
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
            .environment(\.carouselHeaderFont, .custom("InterTight-Medium", size: content.responsiveSize(base: 18, min: 18, max: 26)))
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
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        return _path(rect)
    }
}
