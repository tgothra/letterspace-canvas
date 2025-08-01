import SwiftUI

/// Sheet Detent Positions
enum SheetDetent {
    case compact
    case medium
    case large
}

/// Dashboard Tab Enum for Bottom Bar
enum DashboardTab: String, CaseIterable {
    case pinned = "Pinned"
    case wip = "WIP"
    case schedule = "Schedule"
    
    var symbolImage: String {
        switch self {
        case .pinned:
            return "pin.fill"
        case .wip:
            return "clock.badge.checkmark.fill"
        case .schedule:
            return "calendar.badge.plus"
        }
    }
    
    var color: Color {
        switch self {
        case .pinned:
            return .green
        case .wip:
            return .orange
        case .schedule:
            return .blue
        }
    }
}

/// Floating Dashboard Bottom Bar with Custom Sheet Overlays
struct FloatingDashboardBottomBar: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // State management
    @State private var selectedTab: DashboardTab? = nil
    @State private var showSheet: Bool = false
    @State private var currentTabIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
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
            ZStack {
                // Custom sheet overlay
                if showSheet, let selectedTab = selectedTab {
                    DashboardSheetOverlay(
                        tab: selectedTab,
                        isPresented: $showSheet,
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
                    .zIndex(1000)
                }
                
                // Floating bottom bar
                VStack {
                    Spacer()
                    
                    HStack(spacing: 0) {
                        ForEach(Array(DashboardTab.allCases.enumerated()), id: \.element.rawValue) { index, tab in
                            TabButton(
                                tab: tab,
                                count: getTabCount(tab),
                                isSelected: selectedTab == tab,
                                action: {
                                    HapticFeedback.impact(.light)
                                    selectedTab = tab
                                    currentTabIndex = index
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        showSheet = true
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.clear)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 32))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal, 40)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 8 : 20)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let barWidth = geometry.size.width - 80 // Account for horizontal padding
                                let tabWidth = barWidth / CGFloat(DashboardTab.allCases.count)
                                let touchX = value.location.x - 40 // Adjust for horizontal padding
                                
                                // Calculate which tab should be selected based on touch position
                                let tabIndex = max(0, min(DashboardTab.allCases.count - 1, Int(touchX / tabWidth)))
                                
                                if tabIndex != currentTabIndex {
                                    currentTabIndex = tabIndex
                                    selectedTab = DashboardTab.allCases[tabIndex]
                                    HapticFeedback.impact(.light)
                                }
                            }
                            .onEnded { value in
                                isDragging = false
                                // Keep the current selection
                            }
                    )
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
    let tab: DashboardTab
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: tab.symbolImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? tab.color : theme.secondary)
                        .symbolEffect(.bounce, value: isSelected)
                    
                    // Count badge
                    if let count = count, count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(tab.color)
                            )
                            .offset(x: 12, y: -8)
                    }
                }
                
                Text(tab.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? tab.color : theme.secondary)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
                .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tab.color.opacity(0.15))
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clear)
                    }
                }
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
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

/// Custom Sheet Overlay that slides up from bottom
struct DashboardSheetOverlay: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    let tab: DashboardTab
    @Binding var isPresented: Bool
    
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
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var currentDetent: SheetDetent = .medium
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background overlay
                
                // Sheet content
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Handle bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 36, height: 6)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Image(systemName: tab.symbolImage)
                                        .font(.title3)
                                        .foregroundColor(tab.color)
                                    
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
                            
                            Button("Done") {
                                dismissSheet()
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(tab.color)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        
                        // Content
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                switch tab {
                                case .pinned:
                                    PinnedSheetContent()
                                case .wip:
                                    WIPSheetContent()
                                case .schedule:
                                    ScheduleSheetContent()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                    }
                    .frame(height: calculateSheetHeight(geometry: geometry))
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: -5)
                    )
                    .offset(y: dragOffset)
                                         .gesture(
                         DragGesture()
                             .onChanged { value in
                                 isDragging = true
                                 if value.translation.height > 0 {
                                     // Dragging down - allow drag
                                     dragOffset = value.translation.height
                                 } else {
                                     // Dragging up - expand to next detent
                                     dragOffset = value.translation.height * 0.5
                                 }
                             }
                             .onEnded { value in
                                 isDragging = false
                                 let translation = value.translation.height
                                 let velocity = value.predictedEndTranslation.height
                                 
                                 withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                     if translation > 100 || velocity > 300 {
                                         // Dismiss if dragged down significantly
                                         if currentDetent == .medium {
                                             dismissSheet()
                                         } else {
                                             // Move to medium detent
                                             currentDetent = .medium
                                             dragOffset = 0
                                         }
                                     } else if translation < -100 || velocity < -300 {
                                         // Expand to large detent if dragged up
                                         currentDetent = .large
                                         dragOffset = 0
                                     } else {
                                         // Return to current detent
                                         dragOffset = 0
                                     }
                                 }
                             }
                     )
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
    
    private func calculateSheetHeight(geometry: GeometryProxy) -> CGFloat {
        let mediumHeight: CGFloat = geometry.size.height * 0.5
        let largeHeight: CGFloat = geometry.size.height * 0.85
        
        switch currentDetent {
        case .compact:
            return mediumHeight // Fallback to medium
        case .medium:
            return mediumHeight
        case .large:
            return largeHeight
        }
    }
    
    private func dismissSheet() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isPresented = false
            dragOffset = 0
            currentDetent = .medium
        }
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
    
    // MARK: - Sheet Content Views
    
    @ViewBuilder
    func PinnedSheetContent() -> some View {
        let pinnedDocs = documents.filter { pinnedDocuments.contains($0.id) }
        
        if pinnedDocs.isEmpty {
            EmptyStateView(
                icon: "pin.fill",
                title: "No Pinned Documents",
                subtitle: "Pin important documents to access them quickly",
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
                            dismissSheet()
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
                            dismissSheet()
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
                    DocumentSheetCard(
                        document: document,
                        isPinned: pinnedDocuments.contains(document.id),
                        isWIP: wipDocuments.contains(document.id),
                        hasCalendar: true,
                        onTap: { 
                            onSelectDocument(document)
                            dismissSheet()
                        },
                        onPin: { onPin(document.id) },
                        onWIP: { onWIP(document.id) },
                        onCalendar: { onCalendar(document.id) }
                    )
                }
            }
        }
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Document icon
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(theme.accent)
                    .frame(width: 32, height: 32)
                
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
                
                // Action buttons
                HStack(spacing: 8) {
                    Button(action: {
                        onPin()
                        pinAnimationTrigger += 1
                    }) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isPinned ? .green : theme.secondary)
                            .symbolEffect(.bounce, value: pinAnimationTrigger)
                    }
                    
                    Button(action: {
                        onWIP()
                        wipAnimationTrigger += 1
                    }) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isWIP ? .orange : theme.secondary)
                            .symbolEffect(.bounce, value: wipAnimationTrigger)
                    }
                    
                    Button(action: {
                        onCalendar()
                        calendarAnimationTrigger += 1
                    }) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 14))
                            .foregroundColor(hasCalendar ? .blue : theme.secondary)
                            .symbolEffect(.bounce, value: calendarAnimationTrigger)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            )
        }
        .buttonStyle(.plain)
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
