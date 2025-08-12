import SwiftUI

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
                                            .fill(Color.white)
                                            .overlay(
                                                Capsule()
                                                    .fill(tab.color(using: colorTheme))
                                            )
                                            .glassEffect(.regular, in: .capsule)
                                    }
                                    .offset(x: 14, y: -10)
                            } else {
                                Text("\(count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.white)
                                            .overlay(
                                                Capsule()
                                                    .fill(tab.color(using: colorTheme))
                                            )
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
    }
    
    @ViewBuilder
    private var content: some View {
            VStack(spacing: 0) {
                // Header
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
                    
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(tab.color(using: colorTheme))
                }
                .padding(.horizontal, 20)
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
                    DocumentSheetCard(
                        document: document,
                        isPinned: pinnedDocuments.contains(document.id),
                        isWIP: wipDocuments.contains(document.id),
                        hasCalendar: true,
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
