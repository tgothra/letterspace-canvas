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
    
    // Computed property to determine if navigation padding should be added
    private var shouldAddNavigationPadding: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad && showFloatingSidebar
        #else
        return false
        #endif
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
            isCarouselMode: true // Enable carousel mode
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
            isCarouselMode: true // Enable carousel mode
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
            isCarouselMode: true // Enable carousel mode
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
        GeometryReader { geometry in
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dashboard")
                        .font(.system(size: {
                            // Responsive dashboard title size
                            let screenWidth = geometry.size.width
                            return screenWidth * 0.022 // 2.2% of screen width
                        }(), weight: .bold))
                        .foregroundStyle(theme.primary.opacity(0.7))
                        .padding(.bottom, 8)
                    
                    Text(getTimeBasedGreeting())
                        .font(.custom("InterTight-Regular", size: {
                            // Responsive greeting size based on screen width
                            let screenWidth = geometry.size.width
                            let calculatedSize = screenWidth * 0.065 // 6.5% of screen width
                            return max(45, min(85, calculatedSize)) // Constrain between 45-85pt
                        }()))
                        .tracking(0.5)
                        .foregroundStyle(theme.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
        }
        .padding(.top, -20)
        .padding(.horizontal, 8)
        // Apply blur effect when DocumentDetailsCard or calendar modal is shown
        .blur(radius: showDetailsCard || calendarModalData != nil ? 3 : 0)
        .opacity(showDetailsCard || calendarModalData != nil ? 0.7 : 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            let isIPad = geometry.size.width > 700 // Rough iPad detection
            
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
            .blur(radius: isModalPresented ? 3 : 0)
            .opacity(isModalPresented ? 0.7 : 1.0)
            .overlay { modalOverlayView } // Apply overlay first
            .animation(.easeInOut(duration: 0.2), value: isModalPresented)
            .ignoresSafeArea(isPortrait && isIPad ? .all : [], edges: isPortrait && isIPad ? .top : [])
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
                        // iPad default: only modified date and location, never both date columns
                        visibleColumns = Set(["date", "location"])
                    } else {
                        // iPhone default
                    visibleColumns = Set(["date", "location"])
                    }
                    #else
                    // macOS default
                    visibleColumns = Set(["date", "location"])
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
    }
    
    // NEW: Extracted computed property for the main dashboard layout
    private var dashboardContent: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            let isIPad = geometry.size.width > 700 // Rough iPad detection
            
            if isPortrait && isIPad {
                // iPad Portrait: Special layout that respects navigation
                    VStack(alignment: .leading, spacing: 0) {
                    // Header with responsive positioning for navigation
                    iPadDashboardHeaderView
                    .padding(.horizontal, 20)
                        .padding(.top, {
                            // Responsive header positioning based on percentage of screen height
                            let screenHeight = geometry.size.height
                            return screenHeight * 0.12 // 12% of screen height for header positioning
                        }())
                        
                        // iPad Carousel for sections
                        iPadSectionCarousel
                        .padding(.horizontal, 20)
                        
                    // All Documents section - with responsive spacing and height for different iPad sizes
                        allDocumentsSectionView
                        .padding(.top, {
                            // Responsive spacing based on percentage of screen height
                            let screenHeight = geometry.size.height
                            return screenHeight * 0.02 // 2% of screen height for tighter spacing
                        }())
                        .padding(.horizontal, 20) // Proper padding on iPad to show corner radius
                        .padding(.leading, {
                                    #if os(macOS)
                                    return 24 // Fixed alignment with carousel sections on macOS
                                    #else
                                    return shouldAddNavigationPadding ? responsiveSize(base: 180, min: 120, max: 240) : responsiveSize(base: 36, min: 20, max: 50)
                                    #endif
                                }()) // Platform-specific alignment
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showFloatingSidebar)
                        
                    Spacer(minLength: 0)
                    }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Non-iPad or Landscape: Original layout
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
                                return 260 // Original spacing for iOS
                                #endif
                            }()) // Platform-specific spacing
                            allDocumentsSectionView
                                .padding(.leading, {
                                    #if os(macOS)
                                    return 0 // Remove left padding to align with carousel sections
                                    #else
                                    return shouldAddNavigationPadding ? responsiveSize(base: 180, min: 120, max: 240) : responsiveSize(base: 36, min: 20, max: 50)
                                    #endif
                                }()) // Platform-specific alignment
                                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showFloatingSidebar)
                        }

                        // Top containers (top layer)
                        VStack(spacing: 0) {
                            topContainers
                                .padding(.top, 30) // Increased positive padding to create more space below greeting
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
        #else
        let isIPad = false
        #endif
        
        return HStack(spacing: 8) {
            // Left side - Title
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.custom("InterTight-Regular", size: 18))  // Increased from 14 to 18
                    .foregroundStyle(theme.primary)
                Text("All Documents")
                    .font(.custom("InterTight-Medium", size: 20))  // Increased from 16 to 20
                    .foregroundStyle(theme.primary)
                Text("(\(filteredDocuments.count))")
                    .font(.custom("InterTight-Regular", size: 18))  // Increased from 14 to 18
                    .foregroundStyle(theme.secondary)
                    .frame(width: 50, alignment: .leading)  // Increased width from 40 to 50
                
                Menu {
                    ForEach(ListColumn.allColumns) { column in
                        #if os(iOS)
                        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                        #else
                        let isIPad = false
                        #endif
                        
                        // Always show name column, and exclude "Presented On" on iPad
                        if column.id != "name" && !(isIPad && column.id == "presentedDate") {
                            Toggle(column.title, isOn: Binding(
                                get: { visibleColumns.contains(column.id) },
                                set: { isOn in
                                    #if os(iOS)
                                    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                                    #else
                                    let isIPad = false
                                    #endif
                                    
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
                    HStack(spacing: 4) {
                        Text("My List View")
                            .font(.system(size: 15))  // Increased from 13 to 15
                            .foregroundStyle(colorScheme == .dark ? .white : Color(.sRGB, white: 0.3))
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 12))  // Increased from 10 to 12
                            .foregroundStyle(colorScheme == .dark ? .white : Color(.sRGB, white: 0.3))
                    }
                    .padding(.horizontal, 10)  // Increased from 8 to 10
                    .padding(.vertical, 5)  // Increased from 4 to 5
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
                // Spacer to push tags to the right a bit
                Spacer().frame(width: 32)
                
                // Tags section
                HStack(spacing: 8) {
                    Text("Tags")
                        .font(.custom("InterTight-Medium", size: 15))  // Increased from 13 to 15
                        .tracking(0.3)
                        .foregroundStyle(theme.primary)
                    
                    Button(action: {
                        showTagManager = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))  // Increased from 13 to 15
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
                                        .font(.custom("InterTight-Medium", size: 12))  // Increased from 10 to 12
                                        .tracking(0.7)
                                        .foregroundStyle(tagColor(for: tag))
                                        .padding(.horizontal, 12)  // Increased from 10 to 12
                                        .padding(.vertical, 4)  // Increased from 3 to 4
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(tagColor(for: tag), lineWidth: 1.5)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
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
            return 28 // Reduced from 72 to 28 to align with Pinned header on macOS
            #else
            return isIPad ? 40 : 72 // Keep original iPad and iOS padding
            #endif
        }())
        .padding(.top, isIPad ? 20 : 12) // More breathing room on iPad: 20 vs 12
        .padding(.bottom, isIPad ? 16 : 8) // More breathing room on iPad: 16 vs 8
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
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
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
        #else
        let isIPad = false
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
            .padding(.horizontal, isIPad ? 20 : 16) // Add breathing room on the sides
            .padding(.bottom, isIPad ? 20 : 16) // Add breathing room at the bottom
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
            maxWidth: isIPad ? 1200 : 1600
        ) // Fixed width constraint on iPad to ensure corners are visible, original width for other platforms
        .frame(height: isIPad ? nil : 400)
        .frame(maxHeight: isIPad ? {
            // Create responsive max height based on percentage of screen height
            #if os(iOS)
            let screenHeight = UIScreen.main.bounds.height
            return screenHeight * 0.35 // 35% of screen height for content area
            #else
            return 400
            #endif
        }() : 400) // Responsive max height for iPad sizes to prevent overlap
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
    }

    // iOS Column Header Row
    #if os(iOS)
    private var iosColumnHeaderRow: some View {
        HStack(spacing: 0) {
            // Status indicators column (icons)
            Button(action: {}) {
                HStack(spacing: 4) {
                    let useThemeColors = colorScheme == .dark ? 
                        gradientManager.selectedDarkGradientIndex != 0 :
                        gradientManager.selectedLightGradientIndex != 0
                    
                    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                    
                    Image(systemName: "pin.fill")
                        .font(.system(size: isIPad ? 10 : 14))
                        .foregroundColor(useThemeColors ? theme.accent : .orange)
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: isIPad ? 10 : 14))
                        .foregroundColor(useThemeColors ? theme.primary : .blue)
                    Image(systemName: "calendar")
                        .font(.system(size: isIPad ? 10 : 14))
                        .foregroundColor(useThemeColors ? theme.secondary : .green)
                }
            }
            .buttonStyle(.plain)
            .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 30 : 80, alignment: UIDevice.current.userInterfaceIdiom == .pad ? .center : .leading)
            
            // Add breathing room between status indicators and name column on iPad (to match row)
            #if os(iOS)
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            if isIPad {
                Spacer().frame(width: 24)
            }
            #endif
            
            // Name column (sortable) - icon should align with document icons in rows
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
                    Text("Name")
                        .font(.system(size: 16, weight: .medium))  // Increased from 12 to 16
                        .foregroundColor(theme.secondary)
                    
                    if selectedColumn == .name {
                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))  // Increased from 8 to 12
                            .foregroundColor(theme.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: 120, alignment: .leading)
            
            Spacer()
            
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
                        Text("Series")
                            .font(.system(size: 16, weight: .medium))  // Increased from 12 to 16
                            .foregroundColor(theme.secondary)
                        
                        if selectedColumn == .series {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))  // Increased from 8 to 12
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 100, alignment: .leading)
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
                        Text("Location")
                            .font(.system(size: 16, weight: .medium))  // Increased from 12 to 16
                            .foregroundColor(theme.secondary)
                        
                        if selectedColumn == .location {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))  // Increased from 8 to 12
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 120, alignment: .leading)
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
                        Text("Modified")
                            .font(.system(size: 16, weight: .medium))  // Increased from 12 to 16
                            .foregroundColor(theme.secondary)
                        
                        if selectedColumn == .date {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))  // Increased from 8 to 12
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 90, alignment: .leading)
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
                        Text("Created")
                            .font(.system(size: 16, weight: .medium))  // Increased from 12 to 16
                            .foregroundColor(theme.secondary)
                        
                        if selectedColumn == .createdDate {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))  // Increased from 8 to 12
                                .foregroundColor(theme.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 80, alignment: .leading)
            }
            
            // Add spacing before Actions column
            Spacer().frame(width: 16)
            
            // Actions column
            Text("Actions")
                .font(.system(size: 16, weight: .medium))  // Increased from 12 to 16
                .foregroundColor(theme.secondary)
                .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .bottom
        )
    }
    #endif

    // iPad Carousel Component
    private var iPadSectionCarousel: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.6
            let cardSpacing: CGFloat = 40
            let totalWidth = geometry.size.width
            let shadowPadding: CGFloat = 40
            
            ZStack {
                // Background tap area to exit reorder mode
                if reorderMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("🔄 Exiting reorder mode via background tap")
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                reorderMode = false
                                draggedCardIndex = nil
                                draggedCardOffset = .zero
                            }
                        }
                        .zIndex(-1) // Behind the cards
                }
                
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
            // Responsive carousel height based on percentage of screen height
            #if os(iOS)
            let screenHeight = UIScreen.main.bounds.height
            let percentageHeight = screenHeight * 0.70 // 70% of screen height for more prominent carousel
            return max(400, percentageHeight) // Only minimum constraint to ensure usability
            #else
            return responsiveSize(base: 550, min: 400, max: 650) // macOS default
            #endif
        }())
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
                let basePosition = startX + CGFloat(index) * (reorderCardWidth + reorderSpacing) + reorderCardWidth / 2
                let constrainedX = max(startX + reorderCardWidth / 2, 
                                     min(startX + totalCardsWidth - reorderCardWidth / 2, 
                                         basePosition + draggedCardOffset.width))
                return CGPoint(
                    x: constrainedX,
                    y: 280 + draggedCardOffset.height * 0.2 // Limit vertical movement
                )
            } else {
                // Other cards slide to their effective positions smoothly
                let effectiveIndex = effectiveCardIndex(for: index)
                let xPosition = startX + CGFloat(effectiveIndex) * (reorderCardWidth + reorderSpacing) + reorderCardWidth / 2
                return CGPoint(
                    x: xPosition,
                    y: 280
                )
            }
        } else {
            // Normal carousel mode - only show center card prominently
            let offsetFromCenter = CGFloat(index - selectedCarouselIndex)
            let xOffset = offsetFromCenter * (cardWidth + cardSpacing)
            return CGPoint(
                x: (totalWidth - shadowPadding * 2) / 2 + xOffset + shadowPadding - 60 + dragOffset,
                y: 280
            )
        }
    }
    
    // Extract carousel card into separate function
    @ViewBuilder
    private func carouselCard(for index: Int, cardWidth: CGFloat, cardSpacing: CGFloat, totalWidth: CGFloat, shadowPadding: CGFloat) -> some View {
        let isCenter = index == selectedCarouselIndex
        let isDragged = index == draggedCardIndex
        // In reorder mode, make cards much smaller so all are visible
        let cardScale: CGFloat = reorderMode ? (isDragged ? 0.65 : 0.6) : 1.0 // 60% size for overview, 65% for dragged
        let cardOpacity: Double = reorderMode ? (isDragged ? 1.0 : 0.8) : (isCenter ? 1.0 : 0.8)
        
        ZStack(alignment: .topTrailing) {
            // Main card content
            carouselSections[index].view
                .frame(width: cardWidth, height: 450)
                .padding(.top, 0)
            
            // Reorder mode overlay
            if reorderMode && !isDragged {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.15))
                    .frame(width: cardWidth, height: 450)
            }
            
            // Reorder handle
            reorderHandle(for: index, isCenter: isCenter)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: cardShadowColor, radius: isDragged ? 20 : (reorderMode ? 8 : 12), x: 0, y: isDragged ? 8 : 4)
        .scaleEffect(cardScale) // Apply scale first
        .opacity(cardOpacity) // Then opacity
        .position(cardPosition(for: index, cardWidth: cardWidth, cardSpacing: cardSpacing, totalWidth: totalWidth, shadowPadding: shadowPadding))
        .zIndex(isDragged ? 1000 : Double(index))
        .onTapGesture {
            if reorderMode {
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
        // Add drag gesture to the entire card when in reorder mode
        .simultaneousGesture(
            reorderMode ? 
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
            if reorderMode {
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
            // Long press to enter reorder mode
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
                        #if os(iOS)
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        #endif
                    }
                }
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
            isExpanded: $isPinnedExpanded
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
            isExpanded: $isWIPExpanded
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
            }
        )
        .frame(maxWidth: CGFloat.infinity)
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
        return UIScreen.main.bounds.width * 0.014
        #else
        return 14 // Fixed size for macOS
        #endif
    }
    
    private var headerPadding: CGFloat {
        #if os(iOS)
        return UIScreen.main.bounds.width * 0.011
        #else
        return 11 // Fixed size for macOS
        #endif
    }
    
    func body(content: Content) -> some View {
        content
            .environment(\.carouselHeaderFont, .custom("InterTight-Medium", size: content.responsiveSize(base: 21, min: 18, max: 26)))
            .environment(\.carouselIconSize, {
                #if os(iOS)
                return UIScreen.main.bounds.width * 0.014
                #else
                return 14 // Fixed size for macOS
                #endif
            }())
            .environment(\.carouselHeaderPadding, {
                #if os(iOS)
                return UIScreen.main.bounds.width * 0.011
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
