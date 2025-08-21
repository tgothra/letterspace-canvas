import SwiftUI
// Import existing models and extensions
// Import existing view helpers

/// Sheet Detent Positions
enum SheetDetent {
    case compact
    case medium
    case large
}

/// Dashboard Tab Enum for Bottom Bar
enum DashboardTab: String, CaseIterable {
    case pinned = "Starred"
    case wip = "WIP"
    case schedule = "Schedule"
    
    var symbolImage: String {
        switch self {
        case .pinned:
            return "star.fill"
        case .wip:
            return "clock.badge.checkmark.fill"
        case .schedule:
            return "calendar.badge.plus"
        }
    }
    
    func color(using colorTheme: ColorThemeManager) -> Color {
        switch self {
        case .pinned:
            return colorTheme.currentTheme.bottomNav.starred
        case .wip:
            return colorTheme.currentTheme.bottomNav.wip
        case .schedule:
            return colorTheme.currentTheme.bottomNav.schedule
        }
    }
}

/// Floating Dashboard Bottom Bar with Custom Sheet Overlays
struct FloatingDashboardBottomBar: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var colorTheme: ColorThemeManager
    
    // State management
    @State private var selectedTab: DashboardTab? = nil
    @State private var showSheet: Bool = false
    @State private var currentTabIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isVisible: Bool = false
    
    // Dashboard data bindings
    @Binding var documents: [Letterspace_CanvasDocument]
    @Binding var pinnedDocuments: Set<String>
    @Binding var wipDocuments: Set<String>
    @Binding var calendarDocuments: Set<String>
    
    // Actions
    let onSelectDocument: (Letterspace_CanvasDocument) -> Void
    let onPin: (String) -> Void
    let onWIP: (String) -> Void
    let onCalendar: (String) -> Void
    
    // Menu actions
    let onDashboard: (() -> Void)?
    let onSearch: (() -> Void)?
    let onNewDocument: (() -> Void)?
    let onFolders: (() -> Void)?
    let onBibleReader: (() -> Void)?
    let onSmartStudy: (() -> Void)?
    let onRecentlyDeleted: (() -> Void)?
    let onSettings: (() -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                HStack(spacing: 40) {
                    ForEach(Array(DashboardTab.allCases.enumerated()), id: \.element.rawValue) { index, tab in
                        TabButton(
                            tab: tab,
                            count: getTabCount(tab),
                            isSelected: selectedTab == tab,
                            action: {
                                HapticFeedback.impact(.light)
                                selectedTab = tab
                                currentTabIndex = index
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.1)) {
                                    showSheet = true
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, isiOS26 ? 6 : 8)
                .background {
                    if #available(iOS 26, *) {
                        // No background for iOS 26 - glass effect applied directly
                        Color.clear
                    } else {
                        // Fallback for older iOS
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                }
                .modifier(InteractiveGlassEffectModifier(cornerRadius: isiOS26 ? 24 : 28))
                .padding(.leading, 25)
                .padding(.trailing, 75)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 20 : 40)
                .contentShape(Rectangle())
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            
                            // Handle horizontal drag for tab selection
                            let barWidth = geometry.size.width - 100 // Account for horizontal padding (25 + 75)
                            let tabWidth = barWidth / CGFloat(DashboardTab.allCases.count)
                            let touchX = value.location.x - 25 // Adjust for leading padding
                            
                            // Calculate which tab should be selected based on touch position
                            let tabIndex = max(0, min(DashboardTab.allCases.count - 1, Int(touchX / tabWidth)))
                            
                            if tabIndex != currentTabIndex {
                                currentTabIndex = tabIndex
                                selectedTab = DashboardTab.allCases[tabIndex]
                                HapticFeedback.impact(.light)
                            }
                            
                            // Handle vertical drag to open sheet
                            if value.translation.height < -50 {
                                // Dragging up - prepare to open sheet
                                dragOffset = value.translation.height * 0.3
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            // Check if dragged up enough to open sheet
                            if value.translation.height < -100 || value.predictedEndTranslation.height < -150 {
                                if let selectedTab = selectedTab {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.1)) {
                                        showSheet = true
                                        dragOffset = 0
                                    }
                                }
                            } else {
                                // Return to normal position
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            // 0.3 second delay to let everything load and settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = true
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            if let selectedTab = selectedTab {
                DashboardSheetContent(
                    tab: selectedTab,
                    documents: $documents,
                    pinnedDocuments: $pinnedDocuments,
                    wipDocuments: $wipDocuments,
                    calendarDocuments: $calendarDocuments,
                    onSelectDocument: onSelectDocument,
                    onPin: onPin,
                    onWIP: onWIP,
                    onCalendar: onCalendar,
                    onDashboard: onDashboard,
                    onSearch: onSearch,
                    onNewDocument: onNewDocument,
                    onFolders: onFolders,
                    onBibleReader: onBibleReader,
                    onSmartStudy: onSmartStudy,
                    onRecentlyDeleted: onRecentlyDeleted,
                    onSettings: onSettings
                )
                #if os(macOS)
                .frame(width: 700, height: 550)
                #endif
                .presentationDetents([.medium, .large])
                .presentationBackground(.clear)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.visible)
                .background {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                        .ignoresSafeArea()
                }
            }
        }
    }
    
    private func getTabCount(_ tab: DashboardTab) -> Int? {
        switch tab {
        case .pinned:
            return pinnedDocuments.count
        case .wip:
            return wipDocuments.count
        case .schedule:
            return calendarDocuments.count
        }
    }
}

/// Individual Tab Button for Floating Bar
struct TabButton: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var colorTheme: ColorThemeManager
    
    let tab: DashboardTab
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: isiOS26 ? 2 : 3) {
                ZStack {
                    Group {
                        if #available(iOS 26, *) {
                            // iOS 26 with enhanced symbol rendering - smaller icons
                            Image(systemName: tab.symbolImage)
                                .font(.system(size: isiOS26 ? 16 : 16, weight: .medium))
                                .symbolVariant(isSelected ? .fill : .none)
                                .foregroundStyle(isSelected ? tab.color(using: colorTheme) : theme.secondary)
                                .symbolEffect(.bounce.down, value: isSelected)
                                .contentTransition(.symbolEffect(.replace.downUp))
                        } else {
                            // Fallback for older iOS - smaller icons
                            Image(systemName: tab.symbolImage)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isSelected ? tab.color(using: colorTheme) : theme.secondary)
                                .symbolEffect(.bounce, value: isSelected)
                        }
                    }
                    
                    // iOS 26 style badge with liquid glass effect
                    if let count = count, count > 0 {
                        Group {
                            if #available(iOS 26, *) {
                                Text("\(count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background {
                                        Capsule()
                                            .fill(tab.color(using: colorTheme))
                                            .glassEffect(.regular, in: .capsule)
                                    }
                                    .offset(x: 14, y: -10)
                            } else {
                                Text("\(count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(tab.color(using: colorTheme))
                                    )
                                    .offset(x: 12, y: -8)
                            }
                        }
                    }
                }
                
                Text(tab.rawValue)
                    .font(isiOS26 ? .caption2 : .caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? tab.color(using: colorTheme) : theme.secondary)
                    .scaleEffect(isSelected ? (isiOS26 ? 1.02 : 1.05) : 1.0)
                    .animation(.interpolatingSpring(duration: 0.3, bounce: 0.3), value: isSelected)
            }
            .padding(.vertical, isiOS26 ? 8 : 10)
            .padding(.horizontal, isiOS26 ? 8 : 10)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.interpolatingSpring(duration: 0.15, bounce: 0.2), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

/// Dashboard Sheet Content for Native Sheet
struct DashboardSheetContent: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var colorTheme: ColorThemeManager
    @Environment(\.dismiss) var dismiss
    
    let tab: DashboardTab
    
    // Dashboard data
    @Binding var documents: [Letterspace_CanvasDocument]
    @Binding var pinnedDocuments: Set<String>
    @Binding var wipDocuments: Set<String>
    @Binding var calendarDocuments: Set<String>
    
    // Actions
    let onSelectDocument: (Letterspace_CanvasDocument) -> Void
    let onPin: (String) -> Void
    let onWIP: (String) -> Void
    let onCalendar: (String) -> Void
    
    // Menu actions
    let onDashboard: (() -> Void)?
    let onSearch: (() -> Void)?
    let onNewDocument: (() -> Void)?
    let onFolders: (() -> Void)?
    let onBibleReader: (() -> Void)?
    let onSmartStudy: (() -> Void)?
    let onRecentlyDeleted: (() -> Void)?
    let onSettings: (() -> Void)?
    
    // State for document picker sheet
    @State private var showDocumentPicker = false
    @State private var presentationDocument: Letterspace_CanvasDocument? // Single source of truth
    
    var body: some View {
        Group {
            #if os(macOS)
            NavigationStack {
                content
            }
            #else
            NavigationView {
                content
            }
            #endif
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerSheet(
                tab: tab,
                documents: documents,
                pinnedDocuments: $pinnedDocuments,
                wipDocuments: $wipDocuments,
                calendarDocuments: $calendarDocuments,
                onPin: onPin,
                onWIP: onWIP,
                onCalendar: onCalendar,
                onDismiss: {
                    showDocumentPicker = false
                },
                onSchedule: { document in
                    print("Schedule callback called with document: \(document.title)")
                    
                    // Set the document and dismiss the picker
                    self.presentationDocument = document
                    self.showDocumentPicker = false
                }
            )
        }
        .sheet(item: $presentationDocument) { document in
            PresentationManager(
                document: document,
                isPresented: Binding(
                    get: { presentationDocument != nil },
                    set: { if !$0 { presentationDocument = nil } }
                )
            )
            .id("presentation-\(document.id)")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentListDidUpdate"))) { _ in
            // When documents are updated (like when a presentation is scheduled),
            // refresh the calendar documents list
            refreshCalendarDocuments()
        }
    }
    
    @ViewBuilder
    private var content: some View {
            VStack(spacing: 0) {
                // Header with proper breathing room from top edge
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: tab.symbolImage)
                                .font(.title3)
                                .foregroundColor(tab.color(using: colorTheme))
                            
                            Text(tab.rawValue)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(theme.primary)
                        }
                        
                        Text(getTabSubtitle())
                            .font(.subheadline)
                            .foregroundColor(theme.secondary)
                    }
                    
                    Spacer()
                    
                    // Action buttons with liquid glass styling
                    HStack(spacing: 8) {
                        // Add documents button or Schedule Presentation button
                        Button(action: {
                            if tab == .schedule {
                                // For schedule tab, show document picker to select which document to schedule
                                showScheduleDocumentPicker()
                            } else {
                                // For other tabs, show document picker to add documents
                                showDocumentPicker = true
                            }
                            HapticFeedback.impact(.light)
                        }) {
                            Image(systemName: tab == .schedule ? "calendar.badge.plus" : "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 32, height: 32)
                                .background {
                                    if #available(iOS 26, *) {
                                        Circle()
                                            .fill(Color.white)
                                            .glassEffect(.regular.interactive(), in: .circle)
                                    } else {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                Circle()
                                                    .fill(Color.white.opacity(0.8))
                                            )
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        
                        // Done button with liquid glass effect
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background {
                                    if #available(iOS 26, *) {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white)
                                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white.opacity(0.8))
                                            )
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24) // Added proper top padding for breathing room
                .padding(.bottom, 16)
                
                // Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch tab {
                        case .pinned:
                            StarredSheetContent()
                        case .wip:
                            WIPSheetContent()
                        case .schedule:
                            ScheduleSheetContent()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background {
                if #available(iOS 26, *) {
                    // iOS 26 uses transparent background with glass effect handled by presentation
                    Color.clear
                } else {
                    // Fallback for older iOS
                    theme.background
                }
            }
#if !os(macOS)
            .navigationBarHidden(true)
#endif
    }
    
    private func getTabSubtitle() -> String {
        let count = getTabCount() ?? 0
        switch tab {
        case .pinned:
            return count == 1 ? "1 pinned document" : "\(count) pinned documents"
        case .wip:
            return count == 1 ? "1 work in progress" : "\(count) work in progress"
        case .schedule:
            return count == 1 ? "1 scheduled document" : "\(count) scheduled documents"
        }
    }
    
    private func getTabCount() -> Int? {
        switch tab {
        case .pinned:
            return pinnedDocuments.count
        case .wip:
            return wipDocuments.count
        case .schedule:
            return calendarDocuments.count
        }
    }
    
    // MARK: - Helper Functions
    
    private func showScheduleDocumentPicker() {
        // Show the document picker specifically for scheduling presentations
        showDocumentPicker = true
    }
    
    private func refreshCalendarDocuments() {
        // Check all documents for scheduled presentations and update calendarDocuments
        for document in documents {
            let hasScheduledPresentations = document.presentations.contains { presentation in
                presentation.status == .scheduled && presentation.datetime >= Date()
            }
            
            if hasScheduledPresentations && !calendarDocuments.contains(document.id) {
                // Add to calendar documents
                onCalendar(document.id)
            } else if !hasScheduledPresentations && calendarDocuments.contains(document.id) {
                // Remove from calendar documents if no longer has scheduled presentations
                // Note: We don't automatically remove here to avoid issues, let the parent handle this
            }
        }
    }
    
    // MARK: - Sheet Content Views
    
    @ViewBuilder
    func StarredSheetContent() -> some View {
        let pinnedDocs = documents.filter { pinnedDocuments.contains($0.id) }
        
        if pinnedDocs.isEmpty {
            EmptyStateView(
                icon: "star.fill",
                title: "No Starred Documents",
                subtitle: "Star important documents to access them quickly",
                color: .green
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(pinnedDocs, id: \.id) { document in
                    DocumentSheetCard(
                        document: document,
                        isPinned: true,
                        isWIP: wipDocuments.contains(document.id),
                        hasCalendar: calendarDocuments.contains(document.id),
                        onTap: { 
                            onSelectDocument(document)
                            dismiss()
                        },
                        onPin: { onPin(document.id) },
                        onWIP: { onWIP(document.id) },
                        onCalendar: { onCalendar(document.id) }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    func WIPSheetContent() -> some View {
        let wipDocs = documents.filter { wipDocuments.contains($0.id) }
        
        if wipDocs.isEmpty {
            EmptyStateView(
                icon: "clock.badge.checkmark.fill",
                title: "No Work in Progress",
                subtitle: "Mark documents as WIP to track your active work",
                color: .orange
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(wipDocs, id: \.id) { document in
                    DocumentSheetCard(
                        document: document,
                        isPinned: pinnedDocuments.contains(document.id),
                        isWIP: true,
                        hasCalendar: calendarDocuments.contains(document.id),
                        onTap: { 
                            onSelectDocument(document)
                            dismiss()
                        },
                        onPin: { onPin(document.id) },
                        onWIP: { onWIP(document.id) },
                        onCalendar: { onCalendar(document.id) }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    func ScheduleSheetContent() -> some View {
        let scheduledDocs = documents.filter { calendarDocuments.contains($0.id) }
        
        if scheduledDocs.isEmpty {
            EmptyStateView(
                icon: "calendar.badge.plus",
                title: "No Scheduled Documents",
                subtitle: "Schedule documents for upcoming presentations",
                color: .blue
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(scheduledDocs, id: \.id) { document in
                    ScheduledDocumentCard(
                        document: document,
                        onTap: { 
                            onSelectDocument(document)
                            dismiss()
                        },
                        onRemove: {
                            // Remove all scheduled presentations for this document
                            removeScheduledPresentations(for: document)
                            // Remove from calendar documents set
                            if calendarDocuments.contains(document.id) {
                                onCalendar(document.id) // This should toggle it off
                            }
                        }
                    )
                }
            }
        }
    }
    
    private func removeScheduledPresentations(for document: Letterspace_CanvasDocument) {
        var mutableDoc = document
        
        // Remove all scheduled presentations (keep completed/past ones)
        mutableDoc.presentations.removeAll { presentation in
            presentation.status == .scheduled && presentation.datetime >= Date()
        }
        
        // Save the updated document
        mutableDoc.save()
        
        // Notify that document list should update
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
    }
}

/// Document Card for Sheet
struct DocumentSheetCard: View {
    @Environment(\.themeColors) var theme
    
    let document: Letterspace_CanvasDocument
    let isPinned: Bool
    let isWIP: Bool
    let hasCalendar: Bool
    
    let onTap: () -> Void
    let onPin: () -> Void
    let onWIP: () -> Void
    let onCalendar: () -> Void
    
    @State private var pinAnimationTrigger = 0
    @State private var wipAnimationTrigger = 0
    @State private var calendarAnimationTrigger = 0
    @State private var showingDeleteConfirmation = false
    #if os(iOS)
    @State private var headerImage: UIImage? = nil
    #else
    @State private var headerImage: NSImage? = nil
    #endif
    
    // Get header image from document elements
    private var hasHeaderImage: Bool {
        return document.elements.contains { $0.type == .headerImage && !$0.content.isEmpty }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Document icon or header image
                Group {
                    if let image = headerImage {
                        #if os(iOS)
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        #else
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        #endif
                    } else {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundColor(theme.secondary) 
                            .frame(width: 32, height: 32)
                    }
                }
                
                // Document info
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primary)
                        .lineLimit(1)
                    
                    Text(document.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                }
                
                Spacer()
                
                // Action buttons - Replace with remove button
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.19))
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    isPinned ? "Remove from Starred" : "Remove from WIP",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(isPinned ? "Remove from Starred" : "Remove from WIP", role: .destructive) {
                        if isPinned {
                            onPin() // This should toggle it off
                        } else if isWIP {
                            onWIP() // This should toggle it off
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text(isPinned ? 
                         "This will remove the document from your starred list." :
                         "This will remove the document from your work in progress list.")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            loadHeaderImage()
        }
    }
    
    private func loadHeaderImage() {
        // Load header image if document has one
        guard hasHeaderImage,
              let headerElement = document.elements.first(where: { $0.type == .headerImage }),
              !headerElement.content.isEmpty,
              let documentsPath = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            return
        }
        
        let documentPath = documentsPath.appendingPathComponent(document.id)
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
        
        // Load image from file
        #if os(iOS)
        if let loadedImage = UIImage(contentsOfFile: imageUrl.path) {
            self.headerImage = loadedImage
        }
        #else
        if let loadedImage = NSImage(contentsOfFile: imageUrl.path) {
            self.headerImage = loadedImage
        }
        #endif
    }
}

/// Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(color.opacity(0.6))
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - iOS 26 Helper Extension
extension View {
    var isiOS26: Bool {
        if #available(iOS 26, *) {
            return true
        } else {
            return false
        }
    }
}

// MARK: - Interactive Glass Effect Modifier (iOS 26)
struct InteractiveGlassEffectModifier: ViewModifier {
    let cornerRadius: CGFloat
    @State private var isInteractive = true
    
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(isInteractive), in: .rect(cornerRadius: cornerRadius))
                .onTapGesture {
                    // Toggle interactivity for visual feedback
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isInteractive.toggle()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isInteractive.toggle()
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // Activate interactive mode while dragging
                            if !isInteractive {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isInteractive = true
                                }
                            }
                        }
                        .onEnded { _ in
                            // Deactivate after drag ends
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isInteractive = false
                                }
                            }
                        }
                )
        } else {
            content
        }
    }
}

/// Document Picker Sheet - Similar to Today's Documents functionality
struct DocumentPickerSheet: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var colorTheme: ColorThemeManager
    @Environment(\.dismiss) var dismiss
    
    let tab: DashboardTab
    let documents: [Letterspace_CanvasDocument]
    @Binding var pinnedDocuments: Set<String>
    @Binding var wipDocuments: Set<String>
    @Binding var calendarDocuments: Set<String>
    
    @State private var searchText = ""
    @State private var selectedDocuments: Set<String> = []
    
    let onPin: (String) -> Void
    let onWIP: (String) -> Void
    let onCalendar: (String) -> Void
    let onDismiss: () -> Void
    let onSchedule: (Letterspace_CanvasDocument) -> Void // Add this closure
    
    private var filteredDocuments: [Letterspace_CanvasDocument] {
        let filtered = documents.filter { doc in
            // For schedule tab, show all documents (they can be scheduled multiple times)
            // For other tabs, filter out documents already in the collection
            switch tab {
            case .pinned:
                return !pinnedDocuments.contains(doc.id)
            case .wip:
                return !wipDocuments.contains(doc.id)
            case .schedule:
                return true // Show all documents for scheduling
            }
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { doc in
                doc.title.localizedCaseInsensitiveContains(searchText) ||
                doc.subtitle.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tab == .schedule ? "Schedule Presentation" : "Add to \(tab.rawValue)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(theme.primary)
                            
                            Text(tab == .schedule ? "Select a document to schedule" : "Select documents to add")
                                .font(.subheadline)
                                .foregroundColor(theme.secondary)
                        }
                        
                        Spacer()
                        
                        // Done button with liquid glass effect
                        Button(action: {
                            if tab == .schedule {
                                // For schedule, we don't batch process, just dismiss
                                onDismiss()
                            } else {
                                // For other tabs, add selected documents
                                addSelectedDocuments()
                                onDismiss()
                            }
                        }) {
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background {
                                    if #available(iOS 26, *) {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white)
                                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white.opacity(0.8))
                                            )
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.secondary)
                        
                        TextField("Search documents...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.surface)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // Document list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredDocuments, id: \.id) { document in
                            DocumentPickerRow(
                                document: document,
                                isSelected: tab != .schedule ? selectedDocuments.contains(document.id) : false,
                                isScheduleMode: tab == .schedule,
                                onToggle: {
                                    if tab == .schedule {
                                        // For schedule mode, call the schedule callback
                                        onSchedule(document)
                                    } else {
                                        // For other modes, toggle selection
                                        if selectedDocuments.contains(document.id) {
                                            selectedDocuments.remove(document.id)
                                        } else {
                                            selectedDocuments.insert(document.id)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                if filteredDocuments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(theme.secondary.opacity(0.6))
                        
                        VStack(spacing: 4) {
                            Text(searchText.isEmpty ? 
                                 (tab == .schedule ? "No documents to schedule" : "All documents are already in \(tab.rawValue)") : 
                                 "Try a different search term")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("No matching documents")
                                .font(.subheadline)
                                .foregroundColor(theme.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(theme.background)
        }
#if !os(macOS)
        .navigationBarHidden(true)
#endif
    }
    
    private func addSelectedDocuments() {
        for docId in selectedDocuments {
            switch tab {
            case .pinned:
                onPin(docId)
            case .wip:
                onWIP(docId)
            case .schedule:  
                onCalendar(docId)
            }
        }
        selectedDocuments.removeAll()
    }
}

/// Document Picker Row
struct DocumentPickerRow: View {
    @Environment(\.themeColors) var theme
    
    let document: Letterspace_CanvasDocument
    let isSelected: Bool
    let isScheduleMode: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection circle (only show for non-schedule modes)
                if !isScheduleMode {
                    ZStack {
                        Circle()
                            .strokeBorder(theme.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        
                        if isSelected {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                } else {
                    // For schedule mode, show calendar icon
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(theme.accent)
                        .frame(width: 22, height: 22)
                }
                
                // Document icon
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundColor(theme.accent)
                    .frame(width: 32, height: 32)
                
                // Document info
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !document.subtitle.isEmpty {
                        Text(document.subtitle)
                            .font(.caption)
                            .foregroundColor(theme.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Text(document.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // Arrow for schedule mode
                if isScheduleMode {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? theme.accent.opacity(0.1) : theme.surface)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

/// Scheduled Document Card with Delete Button
struct ScheduledDocumentCard: View {
    @Environment(\.themeColors) var theme
    
    let document: Letterspace_CanvasDocument
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var removeAnimationTrigger = 0
    @State private var showingDeleteConfirmation = false
    @State private var showingNotesSheet = false
    #if os(iOS)
    @State private var headerImage: UIImage? = nil
    #else
    @State private var headerImage: NSImage? = nil
    #endif
    
    // Get the next scheduled presentation for notes/todos
    private var nextScheduledPresentation: DocumentPresentation? {
        document.presentations
            .filter { $0.status == .scheduled && $0.datetime >= Date() }
            .sorted { $0.datetime < $1.datetime }
            .first
    }
    
    // Check if there are any notes or todos
    private var hasNotesOrTodos: Bool {
        guard let presentation = nextScheduledPresentation else { return false }
        let hasNotes = presentation.notes?.isEmpty == false
        let hasTodos = presentation.todoItems?.isEmpty == false
        return hasNotes || hasTodos
    }
    
    // Get header image from document elements
    private var hasHeaderImage: Bool {
        return document.elements.contains { $0.type == .headerImage && !$0.content.isEmpty }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Document icon or header image
                Group {
                    if let image = headerImage {
                        #if os(iOS)
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        #else
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        #endif
                    } else {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundColor(theme.secondary) 
                            .frame(width: 32, height: 32)
                    }
                }
                
                // Document info
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primary)
                        .lineLimit(1)
                    
                    // Show next scheduled date if available - simplified to one line
                    if let nextPresentation = nextScheduledPresentation {
                        Text("\(nextPresentation.datetime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Text(document.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(theme.secondary)
                    }
                }
                
                Spacer()
                
                // Notes button
                Button(action: {
                    showingNotesSheet = true
                }) {
                    Image(systemName: hasNotesOrTodos ? "note.text" : "note.text")
                        .font(.system(size: 18))
                        .foregroundColor(hasNotesOrTodos ? .blue : theme.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                
                // Delete button
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.19))
                        .symbolEffect(.bounce, value: removeAnimationTrigger)
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Remove Scheduled Presentations",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Remove from Schedule", role: .destructive) {
                        onRemove()
                        removeAnimationTrigger += 1
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will remove all scheduled presentations for this document. The document itself will not be deleted.")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            loadHeaderImage()
        }
        .sheet(isPresented: $showingNotesSheet) {
            if let presentation = nextScheduledPresentation {
                PresentationNotesSheet(
                    document: document,
                    presentation: presentation,
                    isPresented: $showingNotesSheet
                )
            } else {
                // Fallback if no scheduled presentation found
                VStack(spacing: 16) {
                    Text("No Scheduled Presentation")
                        .font(.headline)
                    Text("This document doesn't have any scheduled presentations.")
                        .foregroundColor(.secondary)
                    Button("Close") {
                        showingNotesSheet = false
                    }
                }
                .padding()
            }
        }
    }
    
    private func loadHeaderImage() {
        // Load header image if document has one
        guard hasHeaderImage,
              let headerElement = document.elements.first(where: { $0.type == .headerImage }),
              !headerElement.content.isEmpty,
              let documentsPath = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            return
        }
        
        let documentPath = documentsPath.appendingPathComponent(document.id)
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
        
        // Load image from file
        #if os(iOS)
        if let loadedImage = UIImage(contentsOfFile: imageUrl.path) {
            self.headerImage = loadedImage
        }
        #else
        if let loadedImage = NSImage(contentsOfFile: imageUrl.path) {
            self.headerImage = loadedImage
        }
        #endif
    }
}

/// Presentation Notes Sheet for viewing/editing notes and todos
struct PresentationNotesSheet: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    let document: Letterspace_CanvasDocument
    let presentation: DocumentPresentation
    @Binding var isPresented: Bool
    
    @State private var notes: String = ""
    @State private var todoItems: [TodoItem] = []
    @State private var newTodoText: String = ""
    @State private var editingTodoId: UUID? = nil
    @State private var hoveredTodoItem: UUID? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(document.title.isEmpty ? "Untitled" : document.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.primary)
                        
                        Text("Scheduled for \(presentation.datetime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        if let location = presentation.location, !location.isEmpty {
                            Text("Location: \(location)")
                                .font(.subheadline)
                                .foregroundColor(theme.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Notes section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundColor(theme.primary)
                        
                        TextEditor(text: $notes)
                            .font(.system(size: 16))
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .frame(minHeight: 100)
                            .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.96))
                            .cornerRadius(12)
                    }
                    
                    Divider()
                    
                    // Todos section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tasks")
                            .font(.headline)
                            .foregroundColor(theme.primary)
                        
                        // Todo list
                        if todoItems.isEmpty {
                            Text("No tasks yet. Add one below.")
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(todoItems) { item in
                                HStack(spacing: 12) {
                                    // Checkbox
                                    Image(systemName: item.completed ? "checkmark.square.fill" : "square")
                                        .foregroundColor(item.completed ? Color.blue : theme.secondary)
                                        .font(.system(size: 16))
                                        .onTapGesture {
                                            toggleTodoCompletion(item.id)
                                        }
                                    
                                    // Todo Text
                                    if editingTodoId == item.id {
                                        TextField("Edit task", text: Binding(
                                            get: { todoItems.first(where: { $0.id == item.id })?.text ?? "" },
                                            set: { newValue in
                                                if let index = todoItems.firstIndex(where: { $0.id == item.id }) {
                                                    todoItems[index].text = newValue
                                                }
                                            }
                                        ))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(size: 16))
                                        .onSubmit {
                                            editingTodoId = nil
                                            savePresentationData()
                                        }
                                    } else {
                                        Text(item.text)
                                            .font(.system(size: 16))
                                            .foregroundColor(item.completed ? theme.secondary : theme.primary)
                                            .strikethrough(item.completed)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    // Action buttons (visible on hover)
                                    if hoveredTodoItem == item.id && editingTodoId != item.id {
                                        HStack(spacing: 8) {
                                            // Edit button
                                            Button(action: {
                                                editingTodoId = item.id
                                            }) {
                                                Image(systemName: "pencil")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            // Delete button
                                            Button(action: {
                                                deleteTodo(item.id)
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.19))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(hoveredTodoItem == item.id ? 
                                              (colorScheme == .dark ? Color(.sRGB, white: 0.25) : Color(.sRGB, white: 0.9)) : 
                                              Color.clear)
                                )
                                .onHover { hovering in
                                    hoveredTodoItem = hovering ? item.id : nil
                                }
                            }
                        }
                        
                        // Add new todo field
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                            
                            TextField("Add a new task", text: $newTodoText)
                                .font(.system(size: 16))
                                .textFieldStyle(PlainTextFieldStyle())
                                .onSubmit {
                                    addTodoItem()
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.96))
                        )
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(20)
            }
            .navigationTitle("Presentation Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePresentationData()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePresentationData()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #endif
            }
        }
        .onAppear {
            // Load existing data
            notes = presentation.notes ?? ""
            todoItems = presentation.todoItems ?? []
        }
    }
    
    // MARK: - Todo Management
    
    private func addTodoItem() {
        guard !newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let newItem = TodoItem(
            id: UUID(),
            text: newTodoText.trimmingCharacters(in: .whitespacesAndNewlines),
            completed: false
        )
        
        todoItems.append(newItem)
        newTodoText = ""
        savePresentationData()
    }
    
    private func toggleTodoCompletion(_ id: UUID) {
        if let index = todoItems.firstIndex(where: { $0.id == id }) {
            todoItems[index].completed.toggle()
            savePresentationData()
        }
    }
    
    private func deleteTodo(_ id: UUID) {
        todoItems.removeAll { $0.id == id }
        savePresentationData()
    }
    
    private func savePresentationData() {
        var mutableDoc = document
        
        // Find and update the presentation
        if let index = mutableDoc.presentations.firstIndex(where: { $0.id == presentation.id }) {
            mutableDoc.presentations[index].notes = notes.isEmpty ? nil : notes
            mutableDoc.presentations[index].todoItems = todoItems.isEmpty ? nil : todoItems
            
            // Save the document
            mutableDoc.save()
            
            // Post notification for UI updates
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        }
    }
}