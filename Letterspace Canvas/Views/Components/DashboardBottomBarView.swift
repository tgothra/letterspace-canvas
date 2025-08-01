import SwiftUI

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

struct DashboardBottomBarView: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // State management
    @State private var activeTab: DashboardTab = .pinned
    @State private var showBottomBar: Bool = true
    
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
    
    var body: some View {
        // Bottom bar trigger button (positioned to left of green FAB)
        Button(action: {
            withAnimation(.bouncy(duration: 0.5, extraBounce: 0.1)) {
                showBottomBar = true
            }
        }) {
            HStack(spacing: 4) {
                // Show active tab icon
                Image(systemName: activeTab.symbolImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .symbolEffect(.bounce, value: activeTab)
                
                // Show count badge for active tab
                if let count = getTabCount(activeTab), count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(activeTab.color.opacity(0.8))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .glassEffect(.regular.interactive())
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .sheet(isPresented: $showBottomBar) {
            DashboardBottomBarContent(
                activeTab: $activeTab,
                documents: $documents,
                pinnedDocuments: $pinnedDocuments,
                wipDocuments: $wipDocuments,
                calendarDocuments: $calendarDocuments,
                onSelectDocument: onSelectDocument,
                onPin: onPin,
                onWIP: onWIP,
                onCalendar: onCalendar
            )
            .presentationDetents([.height(isiOS26 ? 80 : 130), .fraction(0.6), .large])
            .presentationBackgroundInteraction(.enabled)
            .presentationCornerRadius(20)
        }
    }
    
    // Helper to get count for each tab
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

/// Dashboard Bottom Bar Content (Sheet Content)
struct DashboardBottomBarContent: View {
    @Environment(\.themeColors) var theme
    @Environment(\.dismiss) var dismiss
    
    @Binding var activeTab: DashboardTab
    @Binding var documents: [Letterspace_CanvasDocument]
    @Binding var pinnedDocuments: Set<String>
    @Binding var wipDocuments: Set<String>
    @Binding var calendarDocuments: Set<String>
    
    let onSelectDocument: (Letterspace_CanvasDocument) -> Void
    let onPin: (String) -> Void
    let onWIP: (String) -> Void
    let onCalendar: (String) -> Void
    
    var body: some View {
        GeometryReader {
            let safeArea = $0.safeAreaInsets
            let bottomPadding = safeArea.bottom / 5
            
            VStack(spacing: 0) {
                TabView(selection: $activeTab) {
                    Tab.init(value: .pinned) {
                        IndividualTabView(.pinned)
                    }
                    
                    Tab.init(value: .wip) {
                        IndividualTabView(.wip)
                    }
                    
                    Tab.init(value: .schedule) {
                        IndividualTabView(.schedule)
                    }
                }
                .tabViewStyle(.tabBarOnly)
                .background {
                    if #available(iOS 26, *) {
                        TabViewHelper()
                    }
                }
                .compositingGroup()
                
                CustomTabBar()
                    .padding(.bottom, isiOS26 ? bottomPadding : 0)
            }
            .ignoresSafeArea(.all, edges: isiOS26 ? .bottom : [])
        }
        .interactiveDismissDisabled()
    }
    
    /// Individual Tab View
    @ViewBuilder
    func IndividualTabView(_ tab: DashboardTab) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tab.rawValue)
                            .font(isiOS26 ? .largeTitle : .title)
                            .fontWeight(.bold)
                            .foregroundColor(theme.primary)
                        
                        Text(getTabSubtitle(tab))
                            .font(.subheadline)
                            .foregroundColor(theme.secondary)
                    }
                    
                    Spacer()
                    
                    // Close button with glass effect
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.primary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(isiOS26 ? .glass : .plain)
                    .buttonBorderShape(.circle)
                }
                .padding(.top, isiOS26 ? 15 : 10)
                .padding(.horizontal, 20)
                
                // Tab Content
                switch tab {
                case .pinned:
                    PinnedTabContent()
                case .wip:
                    WIPTabContent()
                case .schedule:
                    ScheduleTabContent()
                }
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
    }
    
    /// Custom Tab Bar
    @ViewBuilder
    func CustomTabBar() -> some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.rawValue) { tab in
                VStack(spacing: 6) {
                    Image(systemName: tab.symbolImage)
                        .font(.title3)
                        .symbolVariant(.fill)
                        .symbolEffect(.bounce, value: activeTab == tab)
                    
                    Text(tab.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                    
                    // Count badge
                    if let count = getTabCount(tab), count > 0 {
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
                    }
                }
                .foregroundStyle(activeTab == tab ? tab.color : .gray)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.bouncy(duration: 0.3)) {
                        activeTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, isiOS26 ? 12 : 5)
        .overlay(alignment: .top) {
            if !isiOS26 {
                Divider()
            }
        }
    }
    
    // Helper functions
    private func getTabSubtitle(_ tab: DashboardTab) -> String {
        let count = getTabCount(tab) ?? 0
        switch tab {
        case .pinned:
            return count == 1 ? "1 pinned document" : "\(count) pinned documents"
        case .wip:
            return count == 1 ? "1 work in progress" : "\(count) work in progress"
        case .schedule:
            return count == 1 ? "1 scheduled document" : "\(count) scheduled documents"
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
    
    // Tab content views
    @ViewBuilder
    func PinnedTabContent() -> some View {
        let pinnedDocs = documents.filter { pinnedDocuments.contains($0.id) }
        
        if pinnedDocs.isEmpty {
            EmptyStateView(
                icon: "pin.fill",
                title: "No Pinned Documents",
                subtitle: "Pin important documents to access them quickly",
                color: .green
            )
        } else {
            LazyVStack(spacing: 8) {
                ForEach(pinnedDocs, id: \.id) { document in
                    DashboardDocumentCard(
                        document: document,
                        isPinned: true,
                        isWIP: wipDocuments.contains(document.id),
                        hasCalendar: calendarDocuments.contains(document.id),
                        onTap: { onSelectDocument(document) },
                        onPin: { onPin(document.id) },
                        onWIP: { onWIP(document.id) },
                        onCalendar: { onCalendar(document.id) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    func WIPTabContent() -> some View {
        let wipDocs = documents.filter { wipDocuments.contains($0.id) }
        
        if wipDocs.isEmpty {
            EmptyStateView(
                icon: "clock.badge.checkmark.fill",
                title: "No Work in Progress",
                subtitle: "Mark documents as WIP to track your active work",
                color: .orange
            )
        } else {
            LazyVStack(spacing: 8) {
                ForEach(wipDocs, id: \.id) { document in
                    DashboardDocumentCard(
                        document: document,
                        isPinned: pinnedDocuments.contains(document.id),
                        isWIP: true,
                        hasCalendar: calendarDocuments.contains(document.id),
                        onTap: { onSelectDocument(document) },
                        onPin: { onPin(document.id) },
                        onWIP: { onWIP(document.id) },
                        onCalendar: { onCalendar(document.id) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    func ScheduleTabContent() -> some View {
        let scheduledDocs = documents.filter { calendarDocuments.contains($0.id) }
        
        if scheduledDocs.isEmpty {
            EmptyStateView(
                icon: "calendar.badge.plus",
                title: "No Scheduled Documents",
                subtitle: "Schedule documents for upcoming presentations",
                color: .blue
            )
        } else {
            LazyVStack(spacing: 8) {
                ForEach(scheduledDocs, id: \.id) { document in
                    DashboardDocumentCard(
                        document: document,
                        isPinned: pinnedDocuments.contains(document.id),
                        isWIP: wipDocuments.contains(document.id),
                        hasCalendar: true,
                        onTap: { onSelectDocument(document) },
                        onPin: { onPin(document.id) },
                        onWIP: { onWIP(document.id) },
                        onCalendar: { onCalendar(document.id) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

/// Empty State View for when sections are empty
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

/// Simplified Document Card for Bottom Bar
struct DashboardDocumentCard: View {
    @Environment(\.themeColors) var theme
    
    let document: Letterspace_CanvasDocument
    let isPinned: Bool
    let isWIP: Bool
    let hasCalendar: Bool
    
    let onTap: () -> Void
    let onPin: () -> Void
    let onWIP: () -> Void
    let onCalendar: () -> Void
    
    // Animation triggers
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
                    .stroke(theme.separator.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// iOS 26 Tab View Helper (from FindMyBottomBar)
@available(iOS 26, *)
fileprivate struct TabViewHelper: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        DispatchQueue.main.async {
            guard let compostingGroup = view.superview?.superview else { return }
            guard let swiftUIWrapperUITabView = compostingGroup.subviews.last else { return }
            
            if let tabBarController = swiftUIWrapperUITabView.subviews.first?.next as? UITabBarController {
                /// Clearing Backgrounds
                tabBarController.view.backgroundColor = .clear
                tabBarController.viewControllers?.forEach {
                    $0.view.backgroundColor = .clear
                }
                
                tabBarController.delegate = context.coordinator
                
                /// Temporary Solution!
                tabBarController.tabBar.removeFromSuperview()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {  }
    
    class Coordinator: NSObject, UITabBarControllerDelegate, UIViewControllerAnimatedTransitioning {
        func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
            return self
        }
        
        func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
            return .zero
        }
        
        func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
            guard let destinationView = transitionContext.view(forKey: .to) else { return }
            let containerView = transitionContext.containerView
            
            containerView.addSubview(destinationView)
            transitionContext.completeTransition(true)
        }
    }
}

// Extension for iOS 26 detection
extension View {
    var isiOS26: Bool {
        if #available(iOS 26, *) {
            return true
        } else {
            return false
        }
    }
} 