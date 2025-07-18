import SwiftUI
import Combine

#if os(iOS)
import UIKit
#endif

// Define the Identifiable struct for modal data (moved near top)
struct ModalDisplayData: Identifiable {
    let id: UUID // Use presentationId as the stable identifier
    let document: Letterspace_CanvasDocument
    var notes: String
    var todoItems: [TodoItem]
}

// Modern calendar implementation with horizontal month slider
// and list of active dates/documents
// Using internal access level to match the model types
internal struct SermonCalendar: View {
    let documents: [Letterspace_CanvasDocument]
    let calendarDocuments: Set<String>
    @Binding var isExpanded: Bool
    let onShowModal: (ModalDisplayData?) -> Void
    var isCarouselMode: Bool = false // New parameter for carousel mode
    var showExpandButtons: Bool = false // New parameter to control expand button visibility
    var onShowExpandModal: (() -> Void)? = nil  // Callback for showing expand modal on iPad
    var hideHeader: Bool = false // New parameter to hide header in modals
    var showMonthSelectorOnly: Bool = false // New parameter for modal view
    var allDocumentsPosition: DashboardView.AllDocumentsPosition = .default // For iPhone dynamic heights
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.carouselHeaderFont) var carouselHeaderFont
    @Environment(\.carouselIconSize) var carouselIconSize
    @Environment(\.carouselHeaderPadding) var carouselHeaderPadding
    @State private var selectedDate = Date()
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    @State private var availableYears: [Int] = (Calendar.current.component(.year, from: Date())-5...Calendar.current.component(.year, from: Date())+5).map { $0 }
    // Add a ScrollViewProxy reference to control scrolling
    @State private var scrollProxy: ScrollViewProxy? = nil
    // Track newly added document for highlight effect
    @State private var recentlyAddedDocumentId: String? = nil
    @State private var isHighlighting = false
    @State private var isHoveringButton = false // State for hover effect
    @State private var isSectionHovered = false // State for section hover effect
    @State private var selectedDocumentId: String? = nil // State for iPad document selection
    @State private var isEditMode = false // Edit mode state
    @State private var selectedSchedules = Set<UUID>() // Selected schedules for multi-select
    @State private var isHoveringEditButton = false // Hover state for edit button
    // Remove loading state as it's causing issues
    // @State private var isLoading = false
    
    // Create namespace for animations
    @Namespace private var animationNamespace
    
    // Formatter to display year without commas
    private let yearFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }()
    
    // State for the new modal
    // @State private var showNotesModal = false
    // @State private var selectedPresentationIdForModal: UUID? = nil
    // @State private var notesForModal: String = ""
    // @State private var todosForModal: [TodoItem] = []
    // @State private var isModalDataReady = false // Flag to indicate data is loaded
    
    // *** Replace previous modal state with a single optional data object ***
    // @State private var modalDisplayData: ModalDisplayData? = nil
    
    // iPad detection
    private var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    init(documents: [Letterspace_CanvasDocument], calendarDocuments: Set<String>, isExpanded: Binding<Bool>, onShowModal: @escaping (ModalDisplayData?) -> Void, isCarouselMode: Bool = false, showExpandButtons: Bool = false, onShowExpandModal: (() -> Void)? = nil, hideHeader: Bool = false, showMonthSelectorOnly: Bool = false, allDocumentsPosition: DashboardView.AllDocumentsPosition = .default) {
        self.documents = documents
        self.calendarDocuments = calendarDocuments
        _isExpanded = isExpanded
        self.onShowModal = onShowModal
        self.isCarouselMode = isCarouselMode
        self.showExpandButtons = showExpandButtons
        self.onShowExpandModal = onShowExpandModal
        self.hideHeader = hideHeader
        self.showMonthSelectorOnly = showMonthSelectorOnly
        self.allDocumentsPosition = allDocumentsPosition
        let calendar = Calendar.current
        let date = Date()
        _selectedYear = State(initialValue: calendar.component(.year, from: date))
        _selectedMonth = State(initialValue: calendar.component(.month, from: date))
    }
    
    private var scheduledDocuments: [ScheduledDocument] {
        let calendar = Calendar.current
        
        let scheduledFromSchedules = documents.filter { calendarDocuments.contains($0.id) }
            .compactMap { doc -> [ScheduledDocument]? in
                doc.schedules.filter { schedule in
                    schedule.isScheduledFor(date: selectedDate)
                }
            }
            .flatMap { $0 }
            .sorted { $0.startDate < $1.startDate }
        
        // Also check for documents with datePresented matching this date
        let presentedDocuments = documents
            .flatMap { doc -> [ScheduledDocument] in
                doc.variations.compactMap { variation -> ScheduledDocument? in
                    if let presentedDate = variation.datePresented,
                       calendar.isDate(selectedDate, equalTo: presentedDate, toGranularity: .day) {
                        return ScheduledDocument(
                            documentId: doc.id,
                            serviceType: .special,
                            startDate: presentedDate,
                            notes: variation.serviceTime ?? "TBD" // Just store the time
                        )
                    }
                    return nil
                }
            }
        
        return (scheduledFromSchedules + presentedDocuments)
            .sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        // Remove the outer ZStack for modal presentation
        // The main view is now just the VStack
        VStack(alignment: .leading, spacing: hideHeader ? 0 : (isCarouselMode ? 6 : 0)) {  // Match spacing with other carousel sections, no spacing if hiding header
            // Conditionally show header
            if !hideHeader {
            // Header with title only (year picker moved to month row)
                if !showMonthSelectorOnly {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: isCarouselMode ? carouselIconSize : 14))
                    .foregroundStyle(theme.primary)
                Text("Document Schedule")
                    .font(isCarouselMode ? carouselHeaderFont : .custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.primary)
                
                Spacer()

                    // Add Expand Button (show when showExpandButtons is true)
                    if showExpandButtons {
                Button {
                        print("🔄 SermonCalendar expand button tapped")
                        if isCarouselMode && isIPad {
                            // On iPad carousel mode, show modal instead of expanding
                            onShowExpandModal?()
                        } else {
                            // Normal expansion for macOS and non-carousel modes
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                            }
                    }
                } label: {
                    let buttonIconName = isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                    let buttonOpacity = isHoveringButton ? 0.1 : 0.0
                    let buttonScale = isHoveringButton ? 1.15 : 1.0
                    
                    // Update the icon based on the desired expand/collapse symbols
                    Image(systemName: buttonIconName)
                        .contentTransition(.symbolEffect(.replace))
                        .font(.system(size: 12, weight: .medium)) // Make icon smaller
                        .foregroundStyle(theme.secondary)
                        .padding(4) // Add padding around the icon
                        .background( // Add circle background on hover
                            Circle()
                                // Use accent color for hover fill
                                .fill(theme.accent.opacity(buttonOpacity))
                        )
                        .scaleEffect(buttonScale) // Bounce effect on hover
                }
                .buttonStyle(.plain)
                .onHover { hovering in // Track hover state
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { // Apply spring animation
                        isHoveringButton = hovering
                    }
                }
                // Make button visible only when section is hovered
                        .opacity(!isCarouselMode ? (isSectionHovered ? 1 : 0) : 1)  // Always visible in carousel mode
                .animation(.easeInOut(duration: 0.15), value: isSectionHovered)
                }
            }
            .padding(.horizontal, isCarouselMode ? carouselHeaderPadding : 12)
                .padding(.top, isCarouselMode ? 28 : 20)  // Final padding adjustment for precise header alignment
            .padding(.bottom, isCarouselMode ? 0 : 16)  // Remove bottom padding in carousel mode for consistent alignment
            
            Divider()
                .padding(.horizontal, 12)
                    .padding(.vertical, isCarouselMode ? 6 : 4) // Aligned separator padding with other cards
                }
            }
            
            // Month slider with year picker as first item (only show when header is visible)
            if !hideHeader {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // Year picker button as first item
                        Menu {
                            ForEach(availableYears, id: \.self) { year in
                                let isYearSelected = year == selectedYear
                                let yearColor = isYearSelected ? theme.primary : theme.secondary
                                let yearWeight: Font.Weight = isYearSelected ? .bold : .regular
                                
                                Button(action: {
                                    HapticFeedback.impact(.light)
                                    selectedYear = year
                                }) {
                                    Text(yearFormatter.string(from: NSNumber(value: year)) ?? "\(year)")
                                        .foregroundStyle(yearColor)
                                        .fontWeight(yearWeight)
                                }
                            }
                        } label: {
                            let menuBackgroundColor = colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.985)
                            
                            HStack(spacing: 3) {
                                Text(yearFormatter.string(from: NSNumber(value: selectedYear)) ?? "\(selectedYear)")
                                    .font(.system(size: isIPad ? 16 : 12, weight: .medium))
                                    .foregroundStyle(theme.primary)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: isIPad ? 10 : 8)) // Larger for iPad
                                    .foregroundStyle(theme.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(menuBackgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.separator)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 14)
                        
                        // Divider between year and months
                        Rectangle()
                            .fill(.separator)
                            .frame(width: 1, height: 20)
                            .padding(.trailing, 8)
                            
                        ForEach(1...12, id: \.self) { month in
                            MonthButton(
                                month: month,
                                isSelected: month == selectedMonth,
                                action: { selectedMonth = month }
                            )
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 12)
                    .padding(.vertical, 4) // Reduced from 10 to 8
                }
            }
            .padding(.top, showMonthSelectorOnly ? 16 : 0) // Add breathing room for modal only
            .padding(.bottom, showMonthSelectorOnly ? 9 : 0) // Less bottom padding
            
            Divider()
                .padding(.horizontal, showMonthSelectorOnly ? 23 : 12) // Match top separator padding in modal
            }
            
            // Active date/documents list with updated layout
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        // Add extra padding at the top for better breathing room
                        Color.clear.frame(height: 6)
                        
                        // Find the first upcoming day for the selected month and year
                        if let firstUpcomingDayIndex = daysWithSchedules.firstIndex(where: { isCurrentOrFutureDate($0.date) }) {
                            // REVERSED APPROACH: Show upcoming days FIRST, then past days
                            
                            // First show the upcoming days (these will appear at the top)
                            ForEach(daysWithSchedules[firstUpcomingDayIndex...], id: \.date) { dayInfo in
                                DateSection(
                                    dayInfo: dayInfo,
                                    documents: documents,
                                    isSelected: Calendar.current.isDate(dayInfo.date, equalTo: selectedDate, toGranularity: .day),
                                    isPast: isPastDate(dayInfo.date),
                                    onSelect: { date in selectedDate = date },
                                    recentlyAddedDocumentId: isHighlighting ? recentlyAddedDocumentId : nil,
                                    isHighlighting: isHighlighting,
                                    selectedDocumentId: $selectedDocumentId,
                                    isEditMode: isEditMode,
                                    selectedSchedules: $selectedSchedules,
                                    requestModalLoad: { presentationId, document in
                                        print("RequestModalLoad (SermonCalendar): Triggering parent modal show for ID \(presentationId).")
                                        self.loadDataForModal(presentationId: presentationId, document: document)
                                    },
                                    onLongPress: { presentationId in
                                        self.handleLongPress(presentationId: presentationId)
                                    }
                                )
                                .id(dayInfo.date.description)
                            }
                            
                            // Add a separator between upcoming and past events
                            if firstUpcomingDayIndex > 0 {
                                // Combined "Past Events" header with separator line
                                HStack(alignment: .center, spacing: 12) {
                                    Text("Past Events")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(theme.secondary)
                                    
                                    Rectangle()
                                        .fill(.separator)
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 16)
                                .padding(.bottom, 14)
                            }
                            
                            // Then show the past days at the bottom
                            if firstUpcomingDayIndex > 0 {
                                ForEach(daysWithSchedules[0..<firstUpcomingDayIndex], id: \.date) { dayInfo in
                                    DateSection(
                                        dayInfo: dayInfo,
                                        documents: documents,
                                        isSelected: Calendar.current.isDate(dayInfo.date, equalTo: selectedDate, toGranularity: .day),
                                        isPast: isPastDate(dayInfo.date),
                                        onSelect: { date in selectedDate = date },
                                        recentlyAddedDocumentId: isHighlighting ? recentlyAddedDocumentId : nil,
                                        isHighlighting: isHighlighting,
                                        selectedDocumentId: $selectedDocumentId,
                                        isEditMode: isEditMode,
                                        selectedSchedules: $selectedSchedules,
                                        requestModalLoad: { presentationId, document in
                                            print("RequestModalLoad (SermonCalendar): Triggering parent modal show for ID \(presentationId).")
                                            self.loadDataForModal(presentationId: presentationId, document: document)
                                        },
                                        onLongPress: { presentationId in
                                            self.handleLongPress(presentationId: presentationId)
                                        }
                                    )
                                }
                            }
                        } else {
                            // If all dates are past or there are no dates, show them all
                            if daysWithSchedules.isEmpty {
                                // Only show this message when we're completely sure there are no documents
                                // Never during a deletion transition
                                if !isTransitioning() {
                                    // iPad detection for placeholder text
                                    let isIPadLocal: Bool = {
                                        #if os(iOS)
                                        return UIDevice.current.userInterfaceIdiom == .pad
                                        #else
                                        return false
                                        #endif
                                    }()
                                    
                                    Text("No scheduled documents this month")
                                        .font(.system(size: isIPadLocal ? 18 : 13)) // Larger for iPad
                                        .foregroundStyle(theme.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 40)
                                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                                } else {
                                    // During transitions, show an empty spacer to maintain layout
                                    Color.clear
                                        .frame(height: 40)
                                }
                            } else {
                                // If there are dates but they don't match our current view, display them all
                                ForEach(daysWithSchedules, id: \.date) { dayInfo in
                                    DateSection(
                                        dayInfo: dayInfo,
                                        documents: documents,
                                        isSelected: Calendar.current.isDate(dayInfo.date, equalTo: selectedDate, toGranularity: .day),
                                        isPast: isPastDate(dayInfo.date),
                                        onSelect: { date in selectedDate = date },
                                        recentlyAddedDocumentId: isHighlighting ? recentlyAddedDocumentId : nil,
                                        isHighlighting: isHighlighting,
                                        selectedDocumentId: $selectedDocumentId,
                                        isEditMode: isEditMode,
                                        selectedSchedules: $selectedSchedules,
                                        requestModalLoad: { presentationId, document in
                                            print("RequestModalLoad (SermonCalendar): Triggering parent modal show for ID \(presentationId).")
                                            self.loadDataForModal(presentationId: presentationId, document: document)
                                        },
                                        onLongPress: { presentationId in
                                            self.handleLongPress(presentationId: presentationId)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                // Save the scroll proxy for later use
                .onAppear {
                    self.scrollProxy = proxy
                }
                // Listen for notifications about scheduled documents
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentScheduledUpdate"))) { notification in
                    if let documentId = notification.userInfo?["documentId"] as? String,
                       let date = notification.userInfo?["date"] as? Date {
                        // Update state variable but ONLY ANIMATE ONCE
                        self.recentlyAddedDocumentId = documentId
                        
                        // Just toggle the highlighting state once and let SwiftUI handle the rest
                        withAnimation(.easeIn(duration: 0.3)) {
                            isHighlighting = true
                        }
                        
                        // After delay, turn off highlight with single animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.6)) {
                                isHighlighting = false
                                
                                // Wait for animation to complete before clearing ID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    self.recentlyAddedDocumentId = nil
                                }
                            }
                        }
                        
                        // Scroll to the newly added item
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            if let dayInfo = daysWithSchedules.first(where: { 
                                Calendar.current.isDate(date, equalTo: $0.date, toGranularity: .day)
                            }) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    proxy.scrollTo(dayInfo.date.description, anchor: .top)
                                }
                            }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentUnscheduled"))) { notification in
                    if notification.userInfo?["documentId"] != nil {
                        // No longer set loading state - it causes flashing
                        
                        // Immediately clear all highlighting states
                        withAnimation(.easeOut(duration: 0.2)) {
                            // Always clear highlighting for any unscheduled document
                            isHighlighting = false
                            // Reset the recently added document ID
                            recentlyAddedDocumentId = nil
                        }
                        
                        // Check if we need to force a refresh
                        let forceRefresh = notification.userInfo?["forceRefresh"] as? Bool ?? false
                        
                        if forceRefresh {
                            // Trigger a full refresh of the calendar view data
                            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                            
                            // Force a complete refresh of the calendar view by toggling selection
                            // and reverting back to ensure everything updates properly
                            let currentMonth = selectedMonth
                            let currentYear = selectedYear
                            
                            // Set the transitioning flag
                            setTransitioning(true)
                            
                            // Use a delay sequence to ensure proper refresh
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                // First change to a different month/year
                                withAnimation {
                                    if selectedMonth > 1 {
                                        selectedMonth -= 1
                                    } else {
                                        selectedMonth = 12
                                        selectedYear -= 1
                                    }
                                }
                                
                                // Then revert back with a longer delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation {
                                        selectedMonth = currentMonth
                                        selectedYear = currentYear
                                    }
                                    
                                    // Clear transitioning flag
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        setTransitioning(false)
                                    }
                                }
                            }
                        }
                    }
                }
                // No longer need document list update handling since we removed the loading flag
            }
            // Apply dynamic height only to the ScrollView/ScrollViewReader
            .frame(height: isExpanded ? 450 : {
                if isCarouselMode {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if isPhone {
                        // iPhone: Use dynamic height based on All Documents position
                        // Subtract header and month selector space (~65pt) to maximize ScrollView height
                        return max(180, allDocumentsPosition.carouselHeight - 65)
                    } else {
                        return 141 // iPad landscape carousel (keep existing)
                    }
                    #else
                    return 141 // Other platforms
                    #endif
                } else if isIPad && !isCarouselMode && !hideHeader {
                    // iPad portrait cards need more height to fill the 380pt container
                    // Container: 380pt, Header: ~50pt, Month selector: ~40pt, Padding: ~20pt = ~270pt available
                    return 270 // Increased height for iPad portrait cards with extra UI elements
                } else {
                    return 115 // Default height for other cases
                }
            }())
        }
        // Apply styles and animations directly to the VStack (only if not in carousel mode)
        .animation(isCarouselMode ? .none : .easeInOut(duration: 0.35), value: isExpanded)
        .background(
            Group {
                // Remove background for all iPad carousel cards (portrait and landscape)
                if isIPad || isCarouselMode || hideHeader {
                    Color.clear
                } else {
                    colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white
                }
            }
        )
        .modifier(CarouselClipModifier(isCarouselMode: isCarouselMode))
        .zIndex(isCarouselMode ? 0 : (isExpanded ? 10 : 0)) // Keep zIndex for expansion overlap (only if not in carousel mode)
        .scaleEffect(isCarouselMode ? 1.0 : (isExpanded ? 1.02 : 1.0)) // Keep scale effect (only if not in carousel mode)
        .shadow(
            color: (isCarouselMode || hideHeader) ? .clear : (colorScheme == .dark ? .black.opacity(isExpanded ? 0.25 : 0.17) : .black.opacity(isExpanded ? 0.12 : 0.07)),
            radius: (isCarouselMode || hideHeader) ? 0 : (isExpanded ? 12 : 8),
            x: 0,
            y: (isCarouselMode || hideHeader) ? 0 : (isExpanded ? 4 : 1)
        )
        .onHover { hovering in 
            if !isCarouselMode {
                isSectionHovered = hovering
            }
        }
        .onAppear { setTransitioning(false) }
        .onDisappear {
            setTransitioning(false)
            NotificationCenter.default.removeObserver(self)
        }
        // Add tap gesture to clear selection when tapping on empty space (iPad only)
        .contentShape(Rectangle())
        .onTapGesture {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad && selectedDocumentId != nil {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedDocumentId = nil
                }
            }
            #endif
        }
        .onChange(of: selectedSchedules) { newValue in
            if isEditMode && newValue.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditMode = false
                }
            }
        }
        // Listen for clear selection notifications
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearDocumentSelections"))) { _ in
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad && selectedDocumentId != nil {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedDocumentId = nil
                }
            }
            #endif
        }
        // Add selection UI as overlay so it doesn't push content up
        .overlay(alignment: .bottom) {
            if isEditMode && isCarouselMode && isIPad {
                VStack(spacing: 0) {
                    // Divider
                    Rectangle()
                        .fill(.separator)
                        .frame(height: 1)
                        .padding(.top, 4) // Reduced from 8 to 4
                    
                    HStack {
                        if selectedSchedules.isEmpty {
                            // Show Done button when no items selected
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditMode = false
                                }
                            } label: {
                                Text("Done")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(theme.accent)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        } else {
                            // Show selection count and unschedule button when items selected
                            Text("\(selectedSchedules.count) selected")
                                .font(.system(size: 14))
                                .foregroundStyle(theme.secondary)
                            
                            Spacer()
                            
                            Button {
                                // Unschedule selected items
                                for scheduleId in selectedSchedules {
                                    // Find the document and schedule to unschedule
                                    for doc in documents {
                                        if let schedule = doc.schedules.first(where: { $0.id == scheduleId }) {
                                            // Create a copy of the document
                                            var updatedDoc = doc
                                            
                                            // Remove the specific schedule
                                            updatedDoc.removeSchedule(id: scheduleId)
                                            
                                            // Save the document changes
                                            updatedDoc.save()
                                            
                                            // Post notification to update the document list
                                            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                                            
                                            // Post notification about the unscheduling
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("DocumentUnscheduled"),
                                                object: nil,
                                                userInfo: [
                                                    "documentId": doc.id,
                                                    "scheduleId": scheduleId.uuidString,
                                                    "forceRefresh": true
                                                ]
                                            )
                                            break
                                        }
                                    }
                                }
                                
                                // Clear selections and exit edit mode
                                selectedSchedules.removeAll()
                                isEditMode = false
                            } label: {
                                Text("Unschedule")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.red)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, isCarouselMode ? carouselHeaderPadding : 12)
                    .padding(.vertical, 16) // Increased from 8 to 16 to center it
                    .background(
                        Rectangle()
                            .fill(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
                    )
                }
                .offset(y: 4) // Add slight downward offset to move it closer to bottom
            }
        }
    }
    
    // Get all days with schedules in the current month and year
    private var daysWithSchedules: [SermonCalendarDayInfo] {
        // Get all days in month
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: makeDate(day: 1))?.count ?? 30
        
        let days = (1...daysInMonth).compactMap { day -> SermonCalendarDayInfo? in
            let date = makeDate(day: day)
            let schedules = getSchedulesForDate(date)
            if !schedules.isEmpty {
                return SermonCalendarDayInfo(date: date, schedules: schedules)
            }
            return nil
        }
        return days.sorted(by: { $0.date < $1.date })
    }
    
    // Generate date from day, month, and year
    private func makeDate(day: Int) -> Date {
        return Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: day)) ?? Date()
    }
    
    // Get schedules for a specific date
    private func getSchedulesForDate(_ date: Date) -> [ScheduledDocument] {
        let calendar = Calendar.current
        
        let scheduledFromSchedules = documents.filter { calendarDocuments.contains($0.id) }
            .compactMap { doc -> [ScheduledDocument]? in
                doc.schedules.filter { schedule in
                    schedule.isScheduledFor(date: date)
                }
            }
            .flatMap { $0 }
        
        let presentedDocuments = documents
            .flatMap { doc -> [ScheduledDocument] in
                doc.variations.compactMap { variation -> ScheduledDocument? in
                    if let presentedDate = variation.datePresented,
                       calendar.isDate(date, equalTo: presentedDate, toGranularity: .day) {
                        return ScheduledDocument(
                            documentId: doc.id,
                            serviceType: .special,
                            startDate: presentedDate,
                            notes: variation.serviceTime ?? "Add Scheduled Event Notes" // Changed TBD to Add Scheduled Event Notes
                        )
                    }
                    return nil
                }
            }
        
        return (scheduledFromSchedules + presentedDocuments)
            .sorted { $0.startDate < $1.startDate }
    }
    
    // Helper to check if a date is in the past
    private func isPastDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        // Changed to exclude today from past dates
        return targetDate < today
    }
    
    // New helper function to identify current and future dates (including today)
    private func isCurrentOrFutureDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        // Including today as a current/future date
        return targetDate >= today
    }
    
    // Private helper to check if we're actively transitioning
    // Using a static property since we don't need to trigger UI updates when this changes
    private func isTransitioning() -> Bool {
        return UserDefaults.standard.bool(forKey: "SermonCalendar.isTransitioning")
    }
    
    private func setTransitioning(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "SermonCalendar.isTransitioning")
    }
    
    // MARK: - Modal Data Loading Helpers 
    
    // Update loadDataForModal to call the parent callback
    private func loadDataForModal(presentationId: UUID, document: Letterspace_CanvasDocument) {
        print("SermonCalendar: Loading data for parent modal (ID: \(presentationId))")
        if let presentation = document.presentations.first(where: { $0.id == presentationId }) {
            let notes = presentation.notes ?? ""
            let todos = loadTodosFromDirectBackupOrDocument(presentationId: presentationId, document: document)
            print("SermonCalendar: Loaded \(notes.count) chars, \(todos.count) todos for parent")

            let displayData = ModalDisplayData(
                id: presentationId, 
                document: document, 
                notes: notes, 
                todoItems: todos
            )
            
            // Call the parent callback with the prepared data
            self.onShowModal(displayData)
            print("SermonCalendar: Called parent onShowModal with data.")

        } else {
            print("SermonCalendar: ❌ Could not find presentation to load data for parent modal")
            // Call parent callback with nil on failure
            self.onShowModal(nil)
        }
    }

    // Helper function specifically for loading todos (extracted logic)
    private func loadTodosFromDirectBackupOrDocument(presentationId: UUID, document: Letterspace_CanvasDocument) -> [TodoItem] {
        let directKey = "presentation_direct_\(presentationId.uuidString)"
        if let directDict = UserDefaults.standard.object(forKey: directKey) as? [String: Any],
           let todoItemsArray = directDict["todoItems"] as? [[String: Any]] {
            var loadedItems = [TodoItem]()
            for itemDict in todoItemsArray {
                if let text = itemDict["text"] as? String {
                    let id = UUID(uuidString: itemDict["id"] as? String ?? "") ?? UUID()
                    let completed = itemDict["completed"] as? Bool ?? false
                    loadedItems.append(TodoItem(id: id, text: text, completed: completed))
                }
            }
            print("SermonCalendar: Loaded \(loadedItems.count) todos from direct backup for modal")
            return loadedItems
        } else {
            if let presentation = document.presentations.first(where: {$0.id == presentationId}) {
                 let docTodos = presentation.todoItems ?? []
                 print("SermonCalendar: Loading \(docTodos.count) todos from document model for modal")
                 return docTodos
            } else {
                 print("SermonCalendar: No source found for todos for modal")
                 return []
            }
        }
    }

    private func handleLongPress(presentationId: UUID) {
        // Find the schedule that corresponds to this presentation
        if let schedule = documents.flatMap({ $0.schedules }).first(where: { schedule in
            // Check if this schedule has a presentation with the given ID
            documents.contains { doc in
                doc.presentations.contains { $0.id == presentationId }
            }
        }) {
            // Trigger edit mode and select this schedule
            withAnimation(.easeInOut(duration: 0.2)) {
                if !isEditMode {
                    isEditMode = true
                }
                // Add this schedule to selection
                selectedSchedules.insert(schedule.id)
            }
        }
    }
}

// Updated MonthButton implementation
private struct MonthButton: View {
    let month: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    // iPad detection
    private var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    var body: some View {
        Button(action: {
            HapticFeedback.impact(.light)
            action()
        }) {
            Text(Calendar.current.shortMonthSymbols[month - 1])
                .font(.system(size: isIPad ? 16 : 12, weight: isSelected ? .medium : .regular)) // Larger for iPad
                .foregroundStyle(isSelected ? .primary : (isHovered ? theme.primary : theme.secondary))
                .padding(.vertical, 4)
                .padding(.horizontal, 13)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? 
                              (colorScheme == .dark ? theme.accent.opacity(0.18) : theme.accent.opacity(0.08)) : 
                              Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ? theme.accent.opacity(0.5) : 
                            (isHovered ? (colorScheme == .dark ? theme.accent.opacity(0.4) : theme.accent.opacity(0.25)) : Color.clear), 
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            // Apply hover state immediately without animation
            isHovered = hovering
        }
    }
}

// Updated DateSection with the sidebar date layout
private struct DateSection: View {
    let dayInfo: SermonCalendarDayInfo
    let documents: [Letterspace_CanvasDocument]
    let isSelected: Bool
    let isPast: Bool
    let onSelect: (Date) -> Void
    let recentlyAddedDocumentId: String?
    let isHighlighting: Bool
    @Binding var selectedDocumentId: String? // New binding for iPad selection
    let isEditMode: Bool
    @Binding var selectedSchedules: Set<UUID>
    
    // Keep the requestModalLoad closure (signature might be simpler now)
    let requestModalLoad: (UUID, Letterspace_CanvasDocument) -> Void
    
    // Add long press handler
    let onLongPress: (UUID) -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    
    // iPad detection
    private var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left sidebar with date display - with gray background
            VStack(alignment: .center, spacing: 0) {
                Spacer(minLength: 0) // Add spacer at top for vertical centering
                
                // Format day with leading zero for single digits
                Text(formatDayWithLeadingZero(dayInfo.date))
                    .font(.system(size: isIPad ? 28 : 20, weight: .regular)) // Larger for iPad
                    .foregroundStyle(theme.primary)
                
                Text(formatWeekday(dayInfo.date))
                    .font(.system(size: isIPad ? 14 : 10)) // Larger for iPad
                    .foregroundStyle(theme.secondary)
                
                Spacer(minLength: 0) // Add spacer at bottom for vertical centering
            }
            .frame(width: 80)
            
            // Document list - with explicit white background
            VStack(alignment: .leading, spacing: 0) {
                // Document items
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(dayInfo.schedules) { schedule in
                        if let doc = documents.first(where: { $0.id == schedule.documentId }) {
                            DocumentItem(
                                document: doc, 
                                schedule: schedule,
                                isRecentlyAdded: doc.id == recentlyAddedDocumentId && !isPast,
                                isHighlighting: isHighlighting && !isPast,
                                selectedDocumentId: $selectedDocumentId,
                                isEditMode: isEditMode,
                                selectedSchedules: $selectedSchedules,
                                requestModalLoad: requestModalLoad,
                                onLongPress: onLongPress
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
        }
        // Create a GeometryReader to ensure heights match
        .background(
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Date column background - Change fill color
                    Rectangle()
                        // Use low-opacity accent color
                        .fill(colorScheme == .dark ? theme.accent.opacity(0.18) : theme.accent.opacity(0.10))
                        .shadow(color: .black.opacity(0.05), radius: 1, x: 1, y: 0)
                        .frame(width: 80)
                    
                    // Document area background (remains clear)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: geometry.size.width - 80)
                }
                .frame(height: geometry.size.height)
            }
        )
        // Make sure the entire container has no additional background, just the border
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    colorScheme == .dark ? 
                    Color(.sRGB, white: isSelected ? 0.28 : (isHovered ? 0.28 : 0.25)) : 
                    Color(.sRGB, white: isSelected ? 0.80 : (isHovered ? 0.80 : 0.85)),
                    lineWidth: isSelected || isHovered ? 1.2 : 1
                )
        )
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(dayInfo.date)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .onHover { hovering in
            // Apply hover state immediately without animation
            isHovered = hovering
        }
        // Apply opacity to past dates - no animation here
        .opacity(isPast ? 0.6 : 1.0)
        // Add a "Past" label for past dates
        .overlay(
            VStack {
                if isPast {
                    HStack {
                        Spacer()
                        Text("Past")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                            )
                            .padding(.trailing, 20)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        )
        // DO NOT animate appearing - use transition in parent instead
    }
    
    // Format day with leading zero for single digits
    private func formatDayWithLeadingZero(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return String(format: "%02d", day)
    }
    
    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// Updated DocumentItem with improved layout - made smaller
private struct DocumentItem: View {
    let document: Letterspace_CanvasDocument
    let schedule: ScheduledDocument
    let isRecentlyAdded: Bool
    let isHighlighting: Bool
    @Binding var selectedDocumentId: String? // New binding for iPad selection
    let isEditMode: Bool
    @Binding var selectedSchedules: Set<UUID>
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var gradientManager = GradientWallpaperManager.shared
    @State private var isHovered = false
    // Add hover states for individual buttons
    @State private var isOpenButtonHovered = false
    @State private var isDeleteButtonHovered = false
    @State private var isNotesButtonHovered = false
    @State private var justLongPressed = false // Track if we just long pressed
    
    // Keep the requestModalLoad closure
    let requestModalLoad: (UUID, Letterspace_CanvasDocument) -> Void
    
    // Add long press handler
    let onLongPress: (UUID) -> Void
    
    // iPad detection
    private var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    // Check if this item is selected (iPad only)
    private var isSelected: Bool {
        isIPad && selectedDocumentId == document.id
    }
    
    // Check if this schedule is selected in edit mode
    private var isSelectedForRemoval: Bool {
        selectedSchedules.contains(schedule.id)
    }
    
    // Determine when to show action buttons
    private var shouldShowButtons: Bool {
        if isIPad {
            return isSelected && !isEditMode // Don't show buttons in edit mode
        } else {
            return isHovered
        }
    }
    
    // Check if we should use glassmorphism
    private var shouldUseGlassmorphism: Bool {
        gradientManager.selectedLightGradientIndex != 0 || gradientManager.selectedDarkGradientIndex != 0
    }
    
    var body: some View {
        Button(action: {
            // Ignore tap if we just long pressed
            if justLongPressed {
                justLongPressed = false
                return
            }
            
            HapticFeedback.impact(.light)
            
            if isIPad && isEditMode {
                // In edit mode, toggle selection
                withAnimation(.easeInOut(duration: 0.15)) {
                    if selectedSchedules.contains(schedule.id) {
                        selectedSchedules.remove(schedule.id)
                    } else {
                        selectedSchedules.insert(schedule.id)
                    }
                }
            } else if isIPad {
                // iPad: Toggle selection or open if already selected
                if selectedDocumentId == document.id {
                    handleDocumentAction()
                } else {
                    selectedDocumentId = document.id // Select this document
                }
            } else {
                // Mac: Direct action
                handleDocumentAction()
            }
        }) {
            HStack(spacing: 12) {
                // Selection circle in edit mode (iPad only)
                if isIPad && isEditMode {
                ZStack {
                        Circle()
                            .strokeBorder(theme.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        
                        if isSelectedForRemoval {
                        Circle()
                            .fill(theme.accent)
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                    }
                }
                    .animation(.easeInOut(duration: 0.15), value: isSelectedForRemoval)
                }
                
                Image(systemName: "doc.text")
                    .font(.system(size: isIPad ? 16 : 12)) // Larger for iPad
                    .foregroundStyle(theme.primary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: isIPad ? 16 : 13, weight: .medium)) // Larger for iPad
                        .foregroundStyle(theme.primary)
                        .lineLimit(1)
                    
                        SubtitleView(
                        timeString: formatTime(schedule.startDate),
                            document: document,
                            scheduleDate: schedule.startDate
                        )
                }
                
                Spacer()
                
                // Action buttons (appear on hover/selection, not in edit mode)
                if shouldShowButtons {
                    HStack(spacing: 6) {
                        // Notes button
                        if let presentationId = findPresentationIdGlobally(for: schedule, in: document) {
                            // Find the actual presentation to check its content
                            let presentation = document.presentations.first { $0.id == presentationId }
                            // Determine if content exists
                            let hasContent = presentation != nil && (!(presentation?.notes?.isEmpty ?? true) || !(presentation?.todoItems?.isEmpty ?? true))
                            
                            // Define colors
                            let defaultColor = hasContent ? Color.orange : Color.black
                            let hoverColor = Color.orange // Always orange on hover
                            
                            Button(action: {
                                HapticFeedback.impact(.light)
                                // Directly call the passed-in closure
                                requestModalLoad(presentationId, document)
                            }) {
                                ZStack {
                                    Circle()
                                        // iPad: Use hover color when selected, Mac: Use hover color when hovered
                                        .fill((isIPad && isSelected) || isNotesButtonHovered ? hoverColor : defaultColor)
                                        .frame(width: isIPad ? 26 : 15, height: isIPad ? 26 : 15) // Increased to 26x26 for iPad
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: isIPad ? 14 : 7, weight: .semibold)) // Increased to 14pt for iPad
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .help("View Notes & Tasks")
                            .scaleEffect(isNotesButtonHovered ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2), value: isNotesButtonHovered)
                            #if os(macOS)
                            .onHover { hovering in 
                                isNotesButtonHovered = hovering
                            }
                            #endif
                        } else {
                            // Placeholder to maintain consistent layout
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 15, height: 15)
                        }
                        
                        // Green "open" button when hovering
                        Button(action: {
                            HapticFeedback.impact(.light)
                            // Open the document
                            NotificationCenter.default.post(
                                name: NSNotification.Name("OpenDocument"),
                                object: nil,
                                userInfo: ["documentId": document.id]
                            )
                        }) {
                            ZStack {
                                Circle()
                                    // iPad: Use hover color when selected, Mac: Use hover color when hovered
                                    .fill((isIPad && isSelected) || isOpenButtonHovered ? 
                                          Color(hex: "#007AFF") : 
                                          Color.black)
                                    .frame(width: isIPad ? 26 : 15, height: isIPad ? 26 : 15) // Increased to 26x26 for iPad
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: isIPad ? 14 : 8, weight: .semibold)) // Increased to 14pt for iPad
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Open document")
                        .scaleEffect(isOpenButtonHovered ? 1.15 : 1.0)
                        #if os(macOS)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                isOpenButtonHovered = hovering
                            }
                        }
                        #endif
                        
                        // Red delete button
                        Button(action: {
                            HapticFeedback.impact(.light)
                            unscheduleDocument() // Keep this action here
                            // Clear selection when deleting on iPad
                            if isIPad && selectedDocumentId == document.id {
                                selectedDocumentId = nil
                            }
                        }) {
                            ZStack {
                                Circle()
                                    // iPad: Use hover color when selected, Mac: Use hover color when hovered
                                    .fill((isIPad && isSelected) || isDeleteButtonHovered ? 
                                          Color.red : 
                                          Color.black)
                                    .frame(width: isIPad ? 26 : 15, height: isIPad ? 26 : 15) // Increased to 26x26 for iPad
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: isIPad ? 14 : 8, weight: .bold)) // Increased to 14pt for iPad
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Remove from schedule")
                        .scaleEffect(isDeleteButtonHovered ? 1.15 : 1.0)
                        #if os(macOS)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                isDeleteButtonHovered = hovering
                            }
                        }
                        #endif
                    }
                    // Animate the appearance/disappearance of the HStack
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
                }
            }
            .padding(.vertical, isIPad ? 8 : 5) // Increased from 5 to 8 for iPad
            .padding(.horizontal, 10)
            // Overlay for border effect - NO ANIMATION modifiers here
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        isRecentlyAdded && isHighlighting ? theme.accent :
                        (shouldShowButtons && !shouldUseGlassmorphism ? 
                        (colorScheme == .dark ? Color(.sRGB, white: 0.28) : Color(.sRGB, white: 0.80)) : 
                        Color.clear),
                        lineWidth: isRecentlyAdded && isHighlighting ? 1.5 : 1
                    )
            )
            // Background for highlight effect - Updated to use glassmorphism
            .background(
                Group {
                    if isRecentlyAdded && isHighlighting {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(theme.accent.opacity(0.12))
                    } else if shouldShowButtons && !isIPad {
                        // Use glassmorphism when gradients are active, otherwise use default
                        // Remove background entirely on iPad
                        if shouldUseGlassmorphism {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(.ultraThinMaterial)
                                
                                RoundedRectangle(cornerRadius: 5)
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
                                RoundedRectangle(cornerRadius: 5)
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
                            RoundedRectangle(cornerRadius: 5)
                                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.25) : Color(.sRGB, white: 0.95))
                        }
                    } else {
                        Color.clear
                    }
                }
            )
            // Add a simple slide-in transition for item appearance
            .transition(.asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .opacity
            ))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            // Only add long press on iPad
            isIPad ? 
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    print("Long press detected on Calendar iPad") // Debug print
                    justLongPressed = true // Mark that we just long pressed
                    // Trigger long press for edit mode
                    if let presentationId = findPresentationIdGlobally(for: schedule, in: document) {
                        onLongPress(presentationId)
                    }
                }
            : nil
        )
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
                // Reset individual button hovers when main row is no longer hovered
                if !hovering {
                    isOpenButtonHovered = false
                    isDeleteButtonHovered = false
                    isNotesButtonHovered = false
                }
            }
        }
        #endif
    }
    
    // Function to unschedule the document
    private func unscheduleDocument() {
        // Create a copy of the document
        var updatedDoc = document
        
        // Remove date from document variation if this is a variation-based schedule
        if let matchingVariation = updatedDoc.variations.firstIndex(where: { variation in
            if let presentedDate = variation.datePresented {
                return Calendar.current.isDate(presentedDate, equalTo: schedule.startDate, toGranularity: .day)
            }
            return false
        }) {
            var variation = updatedDoc.variations[matchingVariation]
            variation.datePresented = nil
            variation.serviceTime = nil
            updatedDoc.variations[matchingVariation] = variation
        }
        
        // Remove the specific schedule
        updatedDoc.removeSchedule(id: schedule.id)
        
        // IMPORTANT: Save the document changes
        updatedDoc.save()
        
        // Post notification to update the document list
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        
        // Post notification about the unscheduling
        NotificationCenter.default.post(
            name: NSNotification.Name("DocumentUnscheduled"),
            object: nil,
            userInfo: [
                "documentId": document.id,
                "scheduleId": schedule.id.uuidString,
                "forceRefresh": true
            ]
        )
    }
    
    // Helper to find presentation ID (remains)
    private func findPresentationIdGlobally(for schedule: ScheduledDocument, in document: Letterspace_CanvasDocument) -> UUID? {
        return document.presentations.first { pres in
            Calendar.current.isDate(pres.datetime, inSameDayAs: schedule.startDate) && 
            Calendar.current.component(.hour, from: pres.datetime) == Calendar.current.component(.hour, from: schedule.startDate) &&
            Calendar.current.component(.minute, from: pres.datetime) == Calendar.current.component(.minute, from: schedule.startDate)
        }?.id
    }
    
    // Function to handle document action (open)
    private func handleDocumentAction() {
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenDocument"),
            object: nil,
            userInfo: ["documentId": document.id]
        )
    }
    
    // Function to format time from date
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// Helper view to show the time/location subtitle
private struct SubtitleView: View {
    let timeString: String
    let document: Letterspace_CanvasDocument
    let scheduleDate: Date
    @Environment(\.themeColors) var theme
    
    // iPad detection
    private var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    // Add a time formatter
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    var body: some View {
        // Create the location directly in the view body
        let location = getLocation()
        let time = getFormattedTime()
        
        // Use the formatted time if available, otherwise use the provided timeString
        let displayTime = time.isEmpty ? timeString : time
        
        // Simply return the appropriate view based on whether location exists
        if !location.isEmpty {
            locationAndTimeView(location: location, timeString: displayTime)
        } else {
            timeOnlyView(timeString: displayTime)
        }
    }
    
    // Helper method to get the formatted time from the document
    private func getFormattedTime() -> String {
        // Check document variations for matching date and extract time
        if let matchingVariation = document.variations.first(where: { 
            if let presentedDate = $0.datePresented {
                return Calendar.current.isDate(presentedDate, equalTo: scheduleDate, toGranularity: .day)
            }
            return false
        }), let presentedDate = matchingVariation.datePresented {
            return timeFormatter.string(from: presentedDate)
        }
        return ""
    }
    
    // Helper method to get the location from various sources
    private func getLocation() -> String {
        // Try multiple sources for the location in order of priority
        
        // 1. Try document metadata first (new location storage)
        if let metadataLocation = document.getMetadataString(for: "location"), !metadataLocation.isEmpty {
            return metadataLocation
        }
        
        // 2. Check document variations for matching date (this is the main storage for locations)
        // Look for the variation that matches our date
        if let matchingVariation = document.variations.first(where: { 
            if let presentedDate = $0.datePresented {
                return Calendar.current.isDate(presentedDate, equalTo: scheduleDate, toGranularity: .day)
            }
            return false
        }), let varLocation = matchingVariation.location, !varLocation.isEmpty {
            return varLocation
        }
        
        // 3. If no matching variation, use the first variation's location as fallback
        if !document.variations.isEmpty, let firstLocation = document.variations.first?.location, !firstLocation.isEmpty {
            return firstLocation
        }
        
        // No location found
        return ""
    }
    
    // View for when we have both location and time
    private func locationAndTimeView(location: String, timeString: String) -> some View {
        HStack(spacing: 4) {
            Text(location)
                .font(.system(size: isIPad ? 14 : 10.5)) // Larger for iPad
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
            
            Text("•")
                .font(.system(size: isIPad ? 14 : 10.5)) // Larger for iPad
                .foregroundStyle(theme.secondary.opacity(0.7))
            
            Text(timeString)
                .font(.system(size: isIPad ? 14 : 10.5)) // Larger for iPad
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
        }
    }
    
    // View for when we only have time
    private func timeOnlyView(timeString: String) -> some View {
        Text(timeString)
            .font(.system(size: isIPad ? 14 : 10.5)) // Larger for iPad
            .foregroundStyle(theme.secondary)
            .lineLimit(1)
    }
}

// Public struct for DayInfo to ensure it's accessible with a renamed type
internal struct SermonCalendarDayInfo: Identifiable {
    var id: String { date.description }
    let date: Date
    let schedules: [ScheduledDocument]
}

// REMOVED typealiases that were causing conflicts
// public typealias CalendarSection = SermonCalendar
// public typealias CalendarDayInfo = SermonCalendarDayInfo 

// MARK: - Notes Modal View

struct PresentationNotesModal: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Data passed in (now as initial values)
    let presentationId: UUID
    let document: Letterspace_CanvasDocument 
    let initialNotes: String
    let initialTodoItems: [TodoItem]
    let onDismiss: () -> Void
    
    // State managed within the modal 
    @State private var notes: String
    @State private var todoItems: [TodoItem]
    @State private var newTodoText: String = ""
    @State private var editingTodoId: UUID? = nil
    @State private var hoveredTodoItem: UUID? = nil
    @State private var modalOpacity: Double = 0.0
    @State private var modalScale: CGFloat = 0.95
    @State private var isHoveringDone = false // State for Done button hover
    
    // Initializer to set up internal state from passed data
    init(presentationId: UUID, document: Letterspace_CanvasDocument, initialNotes: String, initialTodoItems: [TodoItem], onDismiss: @escaping () -> Void = {}) {
        self.presentationId = presentationId
        self.document = document
        self.initialNotes = initialNotes // Keep initial values if needed elsewhere
        self.initialTodoItems = initialTodoItems
        self.onDismiss = onDismiss
        // Initialize state variables
        _notes = State(initialValue: initialNotes)
        _todoItems = State(initialValue: initialTodoItems)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Scheduled Event • Notes & Tasks")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                Spacer()
                
                // Updated Done button to match modern style
                Button(action: {
                    HapticFeedback.impact(.light)
                    saveChanges() 
                    onDismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        // Apply conditional background for hover effect (reversed)
                        .background(isHoveringDone ? Color.blue.opacity(0.85) : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain) // Use plain style to allow custom background/padding
                .onHover { hovering in
                    isHoveringDone = hovering
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 10)
            
            Divider()
            
            // Content Area - Adjust top padding for more breathing room
            VStack(alignment: .leading, spacing: 24) { 
                // Notes Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Any notes to add?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    
                    // Use ZStack to overlay placeholder text
                    ZStack(alignment: .topLeading) {
                        // Placeholder Text
                        if notes.isEmpty {
                            Text("Jot some quick notes here...")
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondary.opacity(0.6))
                                .padding(.leading, 12)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                        }
                        
                        TextEditor(text: $notes)
                            .font(.system(size: 14))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 100, maxHeight: 260)
                            .background(Color.clear)
                            .foregroundStyle(theme.primary)
                            .transition(.opacity)
                    }
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : .white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 1)
                    )
                    .cornerRadius(6)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.2), value: notes.isEmpty)
                
                // To-Do Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Any tasks to add?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .transition(.move(edge: .top).combined(with: .opacity))
                            
                    // Todo list section
                    ScrollView { 
                        VStack(alignment: .leading, spacing: 4) {
                            if todoItems.isEmpty {
                                Text("No tasks yet.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(theme.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 10)
                                    .transition(.opacity)
                            } else {
                                ForEach($todoItems) { $item in
                                    TodoItemRow(
                                        item: $item,
                                        editingTodoId: $editingTodoId, 
                                        hoveredTodoItem: $hoveredTodoItem,
                                        onToggle: { saveChanges() },
                                        onDelete: { id in 
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                deleteTodo(id: id)
                                                saveChanges()
                                            }
                                        },
                                        onEditSubmit: { saveChanges() }
                                    )
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                                        removal: .scale(scale: 0.95).combined(with: .opacity)
                                    ))
                                }
                            }
                        }
                        .padding(.bottom, 5)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: todoItems)
                    }
                    .padding(10)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.96))
                    .cornerRadius(12)
                    
                    // Add new todo field - outside the gray box
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                        
                        TextField("Add a new task", text: $newTodoText)
                            .font(.system(size: 15))
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundStyle(theme.primary)
                            .onSubmit {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    addTodo()
                                    saveChanges()
                                }
                            }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal)
            .padding(.top, 25)
            .padding(.bottom)
        }
        .frame(width: 400, height: 600)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.25), radius: 25, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.secondary.opacity(0.1), lineWidth: 1)
        )
        .opacity(modalOpacity)
        .scaleEffect(modalScale)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                modalOpacity = 1.0
                modalScale = 1.0
            }
        }
        .onDisappear {
            withAnimation(.easeOut(duration: 0.2)) {
                modalOpacity = 0.0
                modalScale = 0.95
            }
        }
    }
    
    // --- Data Manipulation --- //

    private func addTodo() {
       let trimmedText = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
       guard !trimmedText.isEmpty else { return }
       
       let newItem = TodoItem(text: trimmedText)
       todoItems.append(newItem)
       newTodoText = ""
   }
   
   private func deleteTodo(id: UUID) {
       todoItems.removeAll { $0.id == id }
   }

   // Save changes - uses internal state `notes` and `todoItems`
   private func saveChanges() {
       print("Modal: Saving changes...")
       var mutableDoc = document 
       if let index = mutableDoc.presentations.firstIndex(where: { $0.id == presentationId }) {
           mutableDoc.presentations[index].notes = notes.isEmpty ? nil : notes
           mutableDoc.presentations[index].todoItems = todoItems.isEmpty ? [] : todoItems
           mutableDoc.save()
           print("Modal: ✅ Saved changes to document model")
           saveAsDirectBackup(presentationId: presentationId, todoItems: todoItems)
       } else {
           print("Modal: ❌ Failed to find presentation to save changes")
       }
   }

   // *** Add the missing function definition back here ***
   private func saveAsDirectBackup(presentationId: UUID, todoItems: [TodoItem]) {
       print("Modal: 📌 DIRECT BACKUP: Starting save for \(todoItems.count) todos")
       if let presentation = document.presentations.first(where: { $0.id == presentationId }) {
           var presentationDict: [String: Any] = [
               "id": presentationId.uuidString,
               "documentId": document.id,
               "datetime": presentation.datetime.timeIntervalSince1970,
               "notes": presentation.notes ?? ""
           ]
           if let location = presentation.location { presentationDict["location"] = location }
           var todoItemsArray: [[String: Any]] = []
           for item in todoItems {
               todoItemsArray.append(["id": item.id.uuidString, "text": item.text, "completed": item.completed])
           }
           presentationDict["todoItems"] = todoItemsArray
           let directKey = "presentation_direct_\(presentationId.uuidString)"
           UserDefaults.standard.set(presentationDict, forKey: directKey)
           UserDefaults.standard.synchronize()
           if let savedDict = UserDefaults.standard.object(forKey: directKey) as? [String: Any],
              let savedArray = savedDict["todoItems"] as? [[String: Any]] {
               print("Modal: ✅ DIRECT BACKUP: Verified save successful with \(savedArray.count) todos")
           } else {
               print("Modal: ⚠️ DIRECT BACKUP: Verification failed!")
           }
       }
   }
}

// Row view for individual todo items
struct TodoItemRow: View {
    @Binding var item: TodoItem
    @Binding var editingTodoId: UUID?
    @Binding var hoveredTodoItem: UUID?
    
    // Callbacks for actions
    var onToggle: () -> Void
    var onDelete: (UUID) -> Void
    var onEditSubmit: () -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @State private var deleteHovered = false
    @State private var checkboxHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    item.completed.toggle()
                    onToggle()
                }
            }) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(checkboxHovered ? .blue : (item.completed ? .blue : theme.secondary))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    checkboxHovered = hovering
                }
            }
            
            // Text content
            if editingTodoId == item.id {
                TextField("Task", text: Binding(
                    get: { item.text },
                    set: { item.text = $0 }
                ))
                .font(.system(size: 13))
                .textFieldStyle(.plain)
                .foregroundStyle(theme.primary)
                .onSubmit {
                    editingTodoId = nil
                    onEditSubmit()
                }
            } else {
                Text(item.text)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.primary)
                    .strikethrough(item.completed)
                    .onTapGesture(count: 2) {
                        editingTodoId = item.id
                    }
            }
            
            Spacer()
            
            // Delete button
            Button(action: {
                onDelete(item.id)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(deleteHovered ? .red : theme.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    deleteHovered = hovering
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? 
                    (colorScheme == .dark ? Color(.sRGB, white: 0.25) : Color(.sRGB, white: 0.93)) :
                    Color.clear)
                .opacity(colorScheme == .dark ? 0.8 : 1.0)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
                hoveredTodoItem = hovering ? item.id : nil
            }
        }
        .animation(.easeInOut(duration: 0.2), value: item.completed)
    }
} 
