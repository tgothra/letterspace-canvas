import SwiftUI
import Combine
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit // Needed for UIImage for profile picture and haptic feedback
#endif

// MARK: - Responsive Sizing Helper
extension View {
    /// Calculate responsive size based on a reference iPad Pro 11" (1194pt width)
    /// This ensures consistent visual appearance across all iPad sizes
    func responsiveSize(base: CGFloat, min: CGFloat? = nil, max: CGFloat? = nil) -> CGFloat {
        let referenceWidth: CGFloat = 1194 // iPad Pro 11" width in points
        let currentWidth = {
            #if os(iOS)
            // iPhone now uses iPad interface, so apply responsive sizing to both
            return UIScreen.main.bounds.width
            #else
            return CGFloat(1194) // macOS uses fixed sizing (no scaling)
            #endif
        }()
        let scaleFactor = currentWidth / referenceWidth
        
        // Calculate scaled size
        var scaledSize = base * scaleFactor
        
        // Apply min/max constraints
        if let minSize = min {
            scaledSize = Swift.max(scaledSize, minSize)
        }
        if let maxSize = max {
            scaledSize = Swift.min(scaledSize, maxSize)
        }
        
        return scaledSize
    }
}

// MARK: - Shared Enums (Public for use across files)

public enum ViewMode {
    case normal      // Everything visible
    case minimal     // Just the lips visible
    case focus      // Everything hidden
    case distractionFree // Everything hidden
    case markers     // Like minimal but with smaller offset
    
    var isDistractionFreeMode: Bool {
        self == .distractionFree
    }
    
    var shouldHideSidebars: Bool {
        self == .distractionFree
    }
}

public enum SidebarMode {
    case details
    case series
    case tags
    case variations
    case bookmarks
    case files
    case search
    case allDocuments
    case recentlyDeleted
}

// Native sidebar destinations for iOS 26
enum SidebarDestination: Hashable {
    case dashboard
    case search
    case createDocument
    case folders
    case smartStudy
    case bibleReader
    case colorScheme
    case recentlyDeleted
    case userProfile
}

public enum ActivePopup {
    case none
    case search
    case newDocument
    case folders
    case userProfile
    case recentlyDeleted
    case organizeDocuments  // New case for document organization
    #if os(iOS)
    case siri  // iOS 26 Enhancement: Siri integration popup
    #endif
}

// DocumentCacheManager has been moved to Letterspace Canvas/Shared/DocumentCacheManager.swift

struct SpringyButton: ButtonStyle {
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isHovering ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
    }
}

// Move SearchResultButtonStyle outside of MainLayout
struct SearchResultButtonStyle: ButtonStyle {
    @Environment(\.themeColors) var theme
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.primary.opacity(configuration.isPressed ? 0.1 : (isHovered ? 0.05 : 0)))
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension ButtonStyle where Self == SearchResultButtonStyle {
    static var searchResult: SearchResultButtonStyle { SearchResultButtonStyle() }
}

struct MainLayout: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var activeToolbarId: UUID?
    @State private var isRightSidebarVisible = false
    @State private var isHovering = false
    @State private var isHoveringSettings = false
    @State private var isHoveringDistraction = false
    @State private var isHoveringFullScreen = false
    @State private var isHoveringPopup = false
    @State private var isHoveringBookmark = false
    @State private var showBookmarksSheet = false
    @Namespace private var buttonTransition
    @Namespace private var documentToolsTransition
    @State private var documentsExpanded = true
    @State private var viewMode: ViewMode = .normal
    @State private var isHeaderExpanded: Bool = false
    @State private var selectedElement: UUID? = nil
    @State private var sidebarMode: RightSidebar.SidebarMode = .allDocuments
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass // For iPadOS adaptation
    private let appearanceController = AppearanceController.shared
    @State private var transitionOpacity = 1.0
    @State private var isScrolling = false
    @State private var scrollTimer: Timer?
    @State private var scrollOffset: CGFloat = 0
    @State private var documentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var isSearchPopupVisible = false
    @State private var isSearchActive = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFieldFocused: Bool
    @State private var folders: [Folder] = []  // Updated to use Folder from Models
    @State private var activePopup: ActivePopup = .none
    @State private var showRecentlyDeletedModal = false
    @State private var showUserProfileModal = false  // New state variable for user profile modal
    @State private var showSmartStudyModal = false   // New state variable for Smart Study modal
    @State private var smartStudyPreloaded = false // Track if Smart Study has been preloaded
    @State private var selectedSidebarDestination: SidebarDestination? = nil // Native sidebar navigation state
    #if os(iOS)
    @State private var showSiriModal = false // iOS 26 Enhancement: Siri integration modal
    #endif
    @State private var showScriptureSearchModal = false // New state variable for Scripture Search modal
    @State private var showBibleReaderModal = false  // New state variable for Bible Reader modal
    @State private var showLeftSidebarSheet: Bool = false // Added missing state variable for iPad sidebar sheet
    @State private var showFoldersModal = false // New state variable for Folders modal
    @State private var showTemplateBrowser = false // New state variable for template browser modal
    @State private var showExportModal = false // New state variable for Export modal
    @State private var showSettingsModal = false // New state variable for Settings modal
    @State private var showSearchModal = false // New state variable for Search modal on iPhone
    @State private var showUserProfileSheet = false // New state variable for User Profile sheet
    
    // Dummy state variables for compatibility (no longer used functionally)
    @State private var showFloatingSidebar = false
    @State private var sidebarDragAmount = CGSize.zero
    @State private var isManuallyShown = false
    @State private var isDocked = false
    @State private var isNavigationCollapsed = false
    // Floating toolbar state removed - now using Document Tools button instead
    private var floatingSidebarWidth: CGFloat { 0 }
    private var animatedFloatingNavigation: some View { EmptyView() }
    
    // iPhone Bottom Navigation State
    @State private var bottomNavOffset: CGFloat = 0
    @State private var currentBottomNavIndex: Int = 0
    @State private var showBottomNavigation: Bool = {
        #if os(iOS)
        return false // Disabled - using circular menu instead
        #else
        return false
        #endif
    }()
    
    // Circular Menu State
    @State private var isCircularMenuOpen: Bool = false
    
    // Swipe-down dismiss tracking
    @State private var isSwipeDownDismissing: Bool = false
    
    // Gradient wallpaper manager
    private let gradientManager = GradientWallpaperManager.shared
    
    let rightSidebarWidth: CGFloat = 240
    let settingsWidth: CGFloat = 220
    let collapsedWidth: CGFloat = 56
    // Removed floatingSidebarWidth - no longer needed
    
    private var effectiveContentWidth: CGFloat {
        var width: CGFloat = 0
        if !viewMode.isDistractionFreeMode {
            width += collapsedWidth
            if isRightSidebarVisible {
                width += rightSidebarWidth
            }
        }
        return width
    }
    
    // iPad detection
    private var isIPad: Bool {
            #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
            #endif
    }
    
    var body: some View {
        Group {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Use native NavigationSplitView for iOS 26
                NavigationSplitView {
                    // Sidebar content
                    nativeSidebarContent
                        .navigationDestination(for: SidebarDestination.self) { destination in
                            // Handle navigation destinations
                            switch destination {
                            case .dashboard:
                                EmptyView() // Dashboard is handled by sidebarMode
                            case .search:
                                EmptyView() // Search is handled by searchFieldFocused
                            case .createDocument:
                                EmptyView() // Document creation is handled by onTapGesture
                            case .folders:
                                EmptyView() // Folders modal is handled by showFoldersModal
                            case .smartStudy:
                                EmptyView() // Smart Study modal is handled by showSmartStudyModal
                            case .bibleReader:
                                EmptyView() // Bible Reader modal is handled by showBibleReaderModal
                            case .colorScheme:
                                EmptyView() // Color scheme is handled by onTapGesture
                            case .recentlyDeleted:
                                EmptyView() // Recently Deleted modal is handled by showRecentlyDeletedModal
                            case .userProfile:
                                EmptyView() // User Profile modal is handled by showUserProfileModal
                            }
                        }
                } detail: {
                    // Main content area
                    content
                }
            } else {
                // iPhone: Keep existing floating sidebar
                content
            }
            #else
            // macOS: Keep existing layout
            content
            #endif
        }
            .sheet(isPresented: Binding(
                get: { 
                    #if os(iOS)
                    return showBibleReaderModal && UIDevice.current.userInterfaceIdiom == .phone
                    #else
                    return showBibleReaderModal
                    #endif
                },
                set: { showBibleReaderModal = $0 }
            )) {
                BibleReaderView(onDismiss: {
                    showBibleReaderModal = false
                })
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showFoldersModal) {
                FoldersView(onDismiss: {
                    showFoldersModal = false
                })
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showSearchModal) {
                SearchView(onDismiss: {
                    showSearchModal = false
                })
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showUserProfileSheet) {
                UserProfileView(onDismiss: {
                    showUserProfileSheet = false
                })
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: Binding(
                get: { 
                    #if os(iOS)
                    return showSmartStudyModal && UIDevice.current.userInterfaceIdiom == .phone
                    #else
                    return showSmartStudyModal
                    #endif
                },
                set: { showSmartStudyModal = $0 }
            )) {
                SmartStudyView(onDismiss: {
                    showSmartStudyModal = false
                })
                .presentationBackground(.ultraThinMaterial)
            }

            .sheet(isPresented: Binding(
                get: { 
                    #if os(iOS)
                    return showRecentlyDeletedModal
                    #else
                    return false // Use overlay instead of sheet on macOS
                    #endif
                },
                set: { showRecentlyDeletedModal = $0 }
            )) {
                RecentlyDeletedView(isPresented: $showRecentlyDeletedModal)
                    .presentationBackground(.ultraThinMaterial)
            }
            .overlay {
                #if os(macOS)
                if showBibleReaderModal {
                    ZStack {
                        // Clear background - no dark overlay
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showBibleReaderModal = false
                                }
                            }
                        
                        // Bible Reader Modal
                        BibleReaderView(onDismiss: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showBibleReaderModal = false
                            }
                        })
                        .frame(maxWidth: 1000, maxHeight: 700)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                            removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                        ))
                    }
                }
                #endif
            }
            .onAppear {
                // Only do essential initialization - like Apple Notes and Craft
                // Load folders in background (minimal work)
                Task.detached(priority: .utility) {
                    await MainActor.run {
                        loadFolders()
                    }
                }
                
                // Preload haptic feedback (fast operation)
                HapticFeedback.prepareAll()
                
                // iOS navigation setup (minimal UserDefaults access)
                #if os(iOS)
                // Only set defaults if they don't exist (fast check)
                if UserDefaults.standard.object(forKey: "sidebarIsDocked") == nil {
                    UserDefaults.standard.set(true, forKey: "sidebarIsDocked")
                }
                if UserDefaults.standard.object(forKey: "navigationIsCollapsed") == nil {
                    UserDefaults.standard.set(false, forKey: "navigationIsCollapsed")
                }
                #endif
                
                // Listen for swipe-down dismiss notifications
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("SwipeDownDismissStarted"),
                    object: nil,
                    queue: .main
                ) { _ in
                    isSwipeDownDismissing = true
                }
            }
            .onChange(of: sidebarMode) { oldValue, newValue in
                // If switching to the dashboard view, refresh document list
                if newValue == .allDocuments {
                    // Post notification to refresh document list
                    NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                    print("🔄 Posted DocumentListDidUpdate notification after switching to dashboard")
                }
            }
            // Apply overlays directly, one after another
            .overlay {
                if showUserProfileModal {
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showUserProfileModal = false
                                }
                            }
                        UserProfilePopupContent(
                            activePopup: $activePopup,
                            isPresented: $showUserProfileModal,
                            gradientManager: gradientManager
                        )
                        .fixedSize()
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                            removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                        ))
                    }
                }
            }
            .overlay {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom != .phone {
                    if showRecentlyDeletedModal {
                        ZStack {
                            Color.clear
                                .contentShape(Rectangle())
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showRecentlyDeletedModal = false
                                    }
                                }
                            RecentlyDeletedView(isPresented: $showRecentlyDeletedModal)
                                .fixedSize()
                                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                                ))
                        }
                    }
                }
                #else
                if showRecentlyDeletedModal {
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showRecentlyDeletedModal = false
                                }
                            }
                        RecentlyDeletedView(isPresented: $showRecentlyDeletedModal)
                            .fixedSize()
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                            ))
                    }
                }
                #endif
            }
            .overlay {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom != .phone {
                    if showSmartStudyModal {
                        ZStack {
                            Color.clear
                                .contentShape(Rectangle())
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showSmartStudyModal = false
                                    }
                                }
                            LazyModalContainer {
                                SmartStudyView(onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showSmartStudyModal = false
                                    }
                                })
                            }
                            .fixedSize()
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                            ))
                        }
                    }
                }
                #else
                if showSmartStudyModal {
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSmartStudyModal = false
                                }
                            }
                        LazyModalContainer {
                            SmartStudyView(onDismiss: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSmartStudyModal = false
                                }
                            })
                        }
                        .fixedSize()
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                            removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                        ))
                    }
                }
                
                // iOS 26 Enhancement: Siri Integration Modal
                #if os(iOS)
                if #available(iOS 26.0, *), showSiriModal {
                    ZStack {
                        // Background overlay
                        Rectangle()
                            .fill(.black.opacity(0.3))
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSiriModal = false
                                }
                            }
                        LazyModalContainer {
                            SiriIntegrationView()
                        }
                        .fixedSize()
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                            removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                        ))
                    }
                }
                #endif
                #endif
            }
            .overlay {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom != .phone {
                    if showBibleReaderModal {
                        ZStack {
                            Color.clear
                                .contentShape(Rectangle())
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showBibleReaderModal = false
                                    }
                                }
                            LazyModalContainer {
                                BibleReaderView(onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showBibleReaderModal = false
                                    }
                                })
                            }
                            .fixedSize()
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                            ))
                        }
                    }
                }
                #endif
            }
    }
    
    // Extracted Left Sidebar Content
    @ViewBuilder
    private var leftSidebarContent: some View {
        // This is the original VStack-based sidebar used by macOSLayout
                                GeometryReader { geo in
                                    VStack(spacing: 0) {
                Spacer().frame(height: 48)
                VStack(spacing: 16) { // Top buttons section
                                            Group {
                                                SidebarButton(
                                                    icon: "rectangle.3.group",
                                                    action: {
                                sidebarMode = .allDocuments; 
                                isRightSidebarVisible = false; 
                                viewMode = .normal; 
                                if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                            },
                            tooltip: "Dashboard", activePopup: $activePopup, document: $document,
                            sidebarMode: $sidebarMode, isRightSidebarVisible: $isRightSidebarVisible,
                            folders: $folders, onAddFolder: addFolder
                        )
                                                SidebarButton(
                                                    icon: "magnifyingglass",
                                                    action: {
                                showSearchModal = true
                                if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                            },
                            tooltip: "Search Documents", activePopup: $activePopup, document: $document,
                            sidebarMode: $sidebarMode, isRightSidebarVisible: $isRightSidebarVisible,
                            folders: $folders, onAddFolder: addFolder
                        )
                                                SidebarButton(
                                                    icon: "square.and.pencil",
                                                    action: {
                                let docId = UUID().uuidString; 
                                var d = Letterspace_CanvasDocument(title: "Untitled", subtitle: "", elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], id: docId, markers: [], series: nil, variations: [],isVariation: false, parentVariationId: nil, createdAt: Date(), modifiedAt: Date(), tags: nil, isHeaderExpanded: false, isSubtitleVisible: true, links: []); 
                                d.save(); 
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    document = d; 
                                    sidebarMode = .details;
                                    isRightSidebarVisible = true; 
                                    activePopup = .none; 
                                    if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                                } 
                            },
                            tooltip: "Create New Document", activePopup: $activePopup, document: $document,
                            sidebarMode: $sidebarMode, isRightSidebarVisible: $isRightSidebarVisible,
                            folders: $folders, onAddFolder: addFolder
                        )
                                                SidebarButton(
                            icon: "folder", action: { 
                                showFoldersModal = true
                                if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                            },
                            tooltip: "Folders", activePopup: $activePopup, document: $document,
                            sidebarMode: $sidebarMode, isRightSidebarVisible: $isRightSidebarVisible,
                            folders: $folders, onAddFolder: addFolder
                        )
                                                SidebarButton(
                            icon: "sparkles", action: { 
                                withAnimation(.easeInOut(duration: 0.2)) {
                                                        showSmartStudyModal = true
                                }
                                if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                            },
                            tooltip: "Smart Study", activePopup: $activePopup, document: $document,
                            sidebarMode: $sidebarMode, isRightSidebarVisible: $isRightSidebarVisible,
                            folders: $folders, onAddFolder: addFolder
                        )
                                                SidebarButton(
                            icon: "book.closed", action: { 
                                withAnimation(.easeInOut(duration: 0.2)) {
                                                        showBibleReaderModal = true
                                }
                                if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                            },
                            tooltip: "Bible Reader", activePopup: $activePopup, document: $document,
                            sidebarMode: $sidebarMode, isRightSidebarVisible: $isRightSidebarVisible,
                            folders: $folders, onAddFolder: addFolder
                        )

                    }
                    .frame(width: 72)
                }
                .padding(.horizontal, 12)
                                        .frame(maxHeight: .infinity, alignment: .top)
                                        
                VStack(spacing: 16) { // Bottom buttons section
                                            Group {
                                                SidebarButton(
                                                    icon: appearanceController.selectedScheme.icon,
                                                    action: {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            transitionOpacity = 0
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                                                // Cycle through the color scheme options
                                                                let allCases = AppColorScheme.allCases
                                                                if let currentIndex = allCases.firstIndex(of: appearanceController.selectedScheme) {
                                                                    let nextIndex = (currentIndex + 1) % allCases.count
                                                                    appearanceController.selectedScheme = allCases[nextIndex]
                                                                }
                                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                                    transitionOpacity = 1
                                                                }
                                                            }
                                                        }
                                if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                            },
                            tooltip: "Color Scheme: \(appearanceController.selectedScheme.rawValue)", activePopup: $activePopup, document: $document,
                            sidebarMode: $sidebarMode, isRightSidebarVisible: $isRightSidebarVisible,
                            folders: $folders, onAddFolder: addFolder
                        )
                                                SidebarButton(
                            icon: "trash", action: { 
                                withAnimation(.easeInOut(duration: 0.2)) {
                                                        showRecentlyDeletedModal = true
                                }
                                if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                            },
                            tooltip: "Recently Deleted", activePopup: $activePopup, document: $document,
                            sidebarMode: $sidebarMode, isRightSidebarVisible: $isRightSidebarVisible,
                            folders: $folders, onAddFolder: addFolder
                        )
                        Divider().padding(.vertical, 4).padding(.horizontal, 16)
                                                SidebarButton(
                            icon: "person.crop.circle.fill", action: { 
                                showUserProfileSheet = true
                                if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                            },
                            tooltip: "User Profile", activePopup: $activePopup, document: $document,
                            sidebarMode: $sidebarMode, isRightSidebarVisible: $isRightSidebarVisible,
                            folders: $folders, onAddFolder: addFolder
                        )
                    }
                    .frame(width: 72)
                }
                .padding(.horizontal, 12)
                                        .padding(.bottom, 30)
                                    }
                                    .frame(maxHeight: geo.size.height)
                                }
                            }

    // Native iOS 26 Sidebar for iPad
    @ViewBuilder
    private var nativeSidebarContent: some View {
        List {
            Section(header: Text("Actions").font(.caption).foregroundColor(.secondary)) {
                Label {
                    NavigationLink("Dashboard", value: SidebarDestination.dashboard)
                        .onTapGesture {
                            sidebarMode = .allDocuments
                            isRightSidebarVisible = false
                            viewMode = .normal
                        }
                } icon: {
                    // Custom dashboard icon - sized to match system icons
                    VStack(spacing: 1.5) {
                        Rectangle()
                            .fill(.black)
                            .frame(width: 12, height: 4)
                            .cornerRadius(1)
                        Rectangle()
                            .fill(.black)
                            .frame(width: 16, height: 5)
                            .cornerRadius(1)
                        Rectangle()
                            .fill(.black)
                            .frame(width: 14, height: 4)
                            .cornerRadius(1)
                    }
                    .frame(width: 16, height: 16) // Match system icon size
                }
                
                Label {
                    NavigationLink("Search Documents", value: SidebarDestination.search)
                        .onTapGesture {
                            showSearchModal = true
                        }
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
                
                Label {
                    NavigationLink("Create New Document", value: SidebarDestination.createDocument)
                        .onTapGesture {
                            let docId = UUID().uuidString
                            var d = Letterspace_CanvasDocument(title: "Untitled", subtitle: "", elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], id: docId, markers: [], series: nil, variations: [],isVariation: false, parentVariationId: nil, createdAt: Date(), modifiedAt: Date(), tags: nil, isHeaderExpanded: false, isSubtitleVisible: true, links: [])
                            d.save()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                document = d
                                sidebarMode = .details
                                isRightSidebarVisible = true
                                activePopup = .none
                            }
                        }
                } icon: {
                    Image(systemName: "square.and.pencil")
                }
                
                Label {
                    NavigationLink("Folders", value: SidebarDestination.folders)
                        .onTapGesture {
                            showFoldersModal = true
                        }
                } icon: {
                    Image(systemName: "folder")
                }
                
                Label {
                    NavigationLink("Smart Study", value: SidebarDestination.smartStudy)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSmartStudyModal = true
                            }
                        }
                } icon: {
                    Image(systemName: "sparkles")
                }
                
                Label {
                    NavigationLink("Bible Reader", value: SidebarDestination.bibleReader)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showBibleReaderModal = true
                            }
                        }
                } icon: {
                    Image(systemName: "book.closed")
                }
            }
            .headerProminence(.increased)

            Section(header: Text("Settings").font(.caption).foregroundColor(.secondary)) {
                Label {
                    NavigationLink("Color Scheme: \(appearanceController.selectedScheme.rawValue)", value: SidebarDestination.colorScheme)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                transitionOpacity = 0
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    // Cycle through the color scheme options
                                    let allCases = AppColorScheme.allCases
                                    if let currentIndex = allCases.firstIndex(of: appearanceController.selectedScheme) {
                                        let nextIndex = (currentIndex + 1) % allCases.count
                                        appearanceController.selectedScheme = allCases[nextIndex]
                                    }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        transitionOpacity = 1
                                    }
                                }
                            }
                        }
                } icon: {
                    Image(systemName: appearanceController.selectedScheme.icon)
                }
                
                Label {
                    NavigationLink("Recently Deleted", value: SidebarDestination.recentlyDeleted)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showRecentlyDeletedModal = true
                            }
                        }
                } icon: {
                    Image(systemName: "trash")
                }
                
                Label {
                    NavigationLink("User Profile", value: SidebarDestination.userProfile)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showUserProfileModal = true
                            }
                        }
                } icon: {
                    Image(systemName: "person.crop.circle.fill")
                }
            }
            .headerProminence(.increased)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 250) // Ensure adequate width for iPad
    }

    // Navigation is always expanded when visible, but hides completely during document editing
    private var shouldUseExpandedNavigation: Bool {
        return true  // Always expanded when visible
    }
    
    // Computed property to determine if navigation should be visible
    private var shouldShowNavigationPanel: Bool {
        return sidebarMode == .allDocuments
    }
    
    // Dynamic corner radius for navigation - consistent across all iPad sizes
    private var navigationCornerRadius: CGFloat {
        return responsiveSize(base: shouldUseExpandedNavigation ? 40 : 32, min: 28, max: 44)
    }
    
    // Removed floating navigation views - now using native NavigationSplitView on iPad
    
    // Removed animatedFloatingNavigation - no longer needed

    // Removed floatingSidebarContent - no longer needed since iPhone uses circular menu and iPad uses native NavigationSplitView
    // Placeholder function to maintain compilation
    @ViewBuilder
    private var floatingSidebarContent: some View {
        EmptyView() // No longer used - iPhone uses circular menu, iPad uses native NavigationSplitView
    }
    
    // Remove the rest of the old floatingSidebarContent function
    /*
                    FloatingSidebarButton(
                        icon: "rectangle.3.group",
                        title: "Dashboard",
                        action: {
                            sidebarMode = .allDocuments
                            isRightSidebarVisible = false
                            viewMode = .normal
                            // Removed: // showFloatingSidebar = false - KEEP SIDEBAR OPEN
                        }
                    )
                    
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    FloatingSidebarButton(
                        icon: "magnifyingglass",
                        title: "Search Documents",
                        action: {
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                // Use popup system for iPad
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if activePopup == .search {
                                        activePopup = .none
                                    } else {
                                        activePopup = .search
                                    }
                                }
                            } else {
                                // Use direct search for iPhone
                            searchFieldFocused = true
                            }
                            #else
                            // Use direct search for macOS
                            searchFieldFocused = true
                            #endif
                            // Removed: // showFloatingSidebar = false - KEEP SIDEBAR OPEN
                        }
                    )
                    #if os(iOS)
                    .popover(
                        isPresented: Binding(
                            get: { activePopup == .search && UIDevice.current.userInterfaceIdiom == .pad },
                            set: { if !$0 { activePopup = .none } }
                        ),
                        arrowEdge: .leading
                    ) {
                        SearchPopupContent(
                            activePopup: $activePopup,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            isRightSidebarVisible: $isRightSidebarVisible,
                            onDismiss: {
                                activePopup = .none
                            }
                        )
                        .frame(width: 400, height: 600)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    #endif
                    
                    FloatingSidebarButton(
                        icon: "square.and.pencil",
                        title: "Create New Document",
                        action: {
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                // Use popup system for iPad
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if activePopup == .newDocument {
                                        activePopup = .none
                                    } else {
                                        activePopup = .newDocument
                                    }
                                }
                            } else {
                                // Use direct creation for iPhone
                            let docId = UUID().uuidString
                            var d = Letterspace_CanvasDocument(
                                title: "Untitled", 
                                subtitle: "", 
                                elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], 
                                id: docId, 
                                markers: [], 
                                series: nil, 
                                variations: [],
                                isVariation: false, 
                                parentVariationId: nil, 
                                createdAt: Date(), 
                                modifiedAt: Date(), 
                                tags: nil, 
                                isHeaderExpanded: false, 
                                isSubtitleVisible: true, 
                                links: []
                            )
                            d.save()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                document = d
                                sidebarMode = .details
                                #if os(macOS)
                                isRightSidebarVisible = true  // Only auto-show on macOS
                                #endif
                                activePopup = .none
                                }
                            }
                            #else
                            // Use direct creation for macOS
                            let docId = UUID().uuidString
                            var d = Letterspace_CanvasDocument(
                                title: "Untitled", 
                                subtitle: "", 
                                elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], 
                                id: docId, 
                                markers: [], 
                                series: nil, 
                                variations: [],
                                isVariation: false, 
                                parentVariationId: nil, 
                                createdAt: Date(), 
                                modifiedAt: Date(), 
                                tags: nil, 
                                isHeaderExpanded: false, 
                                isSubtitleVisible: true, 
                                links: []
                            )
                            d.save()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                document = d
                                sidebarMode = .details
                                isRightSidebarVisible = true
                                activePopup = .none
                            }
                            #endif
                                // Removed: // showFloatingSidebar = false - KEEP SIDEBAR OPEN
                            }
                    )
                    #if os(iOS)
                    .popover(
                        isPresented: Binding(
                            get: { activePopup == .newDocument && UIDevice.current.userInterfaceIdiom == .pad },
                            set: { if !$0 { activePopup = .none } }
                        ),
                        arrowEdge: .leading
                    ) {
                        NewDocumentPopupContent(
                            showTemplateBrowser: $showTemplateBrowser,
                            activePopup: $activePopup,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            isRightSidebarVisible: $isRightSidebarVisible
                        )
                        .frame(width: 350, height: 120)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    #endif
                    
                    FloatingSidebarButton(
                        icon: "folder",
                        title: "Folders",
                        action: {
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                // Use popup system for iPad
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if activePopup == .folders {
                                        activePopup = .none
                                    } else {
                                        activePopup = .folders
                                    }
                                }
                            } else {
                                // Use modal for iPhone
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFoldersModal = true
                            }
                            }
                            #else
                            // Use modal for macOS
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFoldersModal = true
                            }
                            #endif
                            // Removed: // showFloatingSidebar = false - KEEP SIDEBAR OPEN
                        }
                    )
                    #if os(iOS)
                    .popover(
                        isPresented: Binding(
                            get: { activePopup == .folders && UIDevice.current.userInterfaceIdiom == .pad },
                            set: { if !$0 { activePopup = .none } }
                        ),
                        arrowEdge: .leading
                    ) {
                        FoldersPopupContent(
                            activePopup: $activePopup,
                            folders: $folders,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            isRightSidebarVisible: $isRightSidebarVisible,
                            onAddFolder: addFolder,
                            showHeader: true // Show header for iPad popover
                        )
                        .frame(width: 400, height: 500)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    }
                    #endif
                    
                    FloatingSidebarButton(
                        icon: "sparkles",
                        title: "Smart Study",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSmartStudyModal = true
                            }
                            // Removed: // showFloatingSidebar = false - KEEP SIDEBAR OPEN
                        }
                    )
                    
                    FloatingSidebarButton(
                        icon: "book.closed",
                        title: "Bible Reader",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showBibleReaderModal = true
                            }
                            // Removed: // showFloatingSidebar = false - KEEP SIDEBAR OPEN
                        }
                    )
                }
                .padding(.horizontal, 8)
                .padding(.top, {
                    #if os(iOS)
                    let screenWidth = UIScreen.main.bounds.width
                    let screenHeight = UIScreen.main.bounds.height
                    let isLandscape = screenWidth > screenHeight
                    if isLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                        return 8 // Reduced top padding for iPad landscape
                    } else {
                        return 16 // Original padding for other cases
                    }
                    #else
                    return 16 // Original padding for macOS
                    #endif
                }())  // Dynamic top padding based on device and orientation
                
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)  // Match other separators
                
                // Bottom buttons section
                VStack(spacing: shouldUseExpandedNavigation ? 6 : 4) {  // Minimal spacing when expanded
                    FloatingSidebarButton(
                        icon: appearanceController.selectedScheme.icon,
                        title: "Color Scheme: \(appearanceController.selectedScheme.rawValue)",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                transitionOpacity = 0
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    // Cycle through the color scheme options
                                    let allCases = AppColorScheme.allCases
                                    if let currentIndex = allCases.firstIndex(of: appearanceController.selectedScheme) {
                                        let nextIndex = (currentIndex + 1) % allCases.count
                                        appearanceController.selectedScheme = allCases[nextIndex]
                                    }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        transitionOpacity = 1
                                    }
                                }
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                // showFloatingSidebar = false - KEEP SIDEBAR OPEN
                            }
                        }
                    )
                    
                    FloatingSidebarButton(
                        icon: "trash",
                        title: "Recently Deleted",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showRecentlyDeletedModal = true
                            }
                            // Removed: // showFloatingSidebar = false - KEEP SIDEBAR OPEN
                        }
                    )
                    
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)   // Match other separators
                    
                    FloatingSidebarButton(
                        icon: "person.crop.circle.fill",
                        title: "User Profile",
                        action: {
                            showUserProfileSheet = true
                            // Removed: // showFloatingSidebar = false - KEEP SIDEBAR OPEN
                        }
                    )
                    

                    
                    // Back arrow button to close panel
                    VStack {
                    FloatingSidebarButton(
                        icon: "arrow.left",
                        title: "Hide Navigation",
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if isNavigationCollapsed {
                                    // If navigation was collapsed, just hide the floating sidebar and transition to docked on iPad
                                    showFloatingSidebar = false
                                    #if os(iOS)
                                    if UIDevice.current.userInterfaceIdiom == .pad {
                                        isDocked = true
                                        UserDefaults.standard.set(isDocked, forKey: "sidebarIsDocked")
                                    }
                                    #endif
                                } else {
                                    // If navigation wasn't collapsed, collapse it (but keep floating mode on iPhone)
                                    #if os(iOS)
                                    if UIDevice.current.userInterfaceIdiom == .pad {
                                        // On iPad, transition to docked mode and collapse
                                        isDocked = true
                                        showFloatingSidebar = false
                                        isNavigationCollapsed = true
                                        UserDefaults.standard.set(isDocked, forKey: "sidebarIsDocked")
                                        UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                                    } else {
                                        // On iPhone, just collapse navigation
                                    isNavigationCollapsed = true
                                    UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                                    }
                                    #else
                                    // On macOS, just collapse navigation
                                    isNavigationCollapsed = true
                                    UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                                    #endif
                                }
                            }
                        }
                    )
                        
                        // Add spacer to center the back button between separator and bottom
                        Spacer()
                            .frame(height: {
                                #if os(iOS)
                                let screenWidth = UIScreen.main.bounds.width
                                let screenHeight = UIScreen.main.bounds.height
                                let isLandscape = screenWidth > screenHeight
                                if isLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                                    return 4 // Reduced spacer for iPad landscape
                                } else {
                                    return 12 // Original spacer for other cases
                                }
                                #else
                                return 12 // Original spacer for macOS
                                #endif
                            }()) // Dynamic spacer based on device and orientation
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 0)        // Keep top padding removed to eliminate gap
                .padding(.bottom, {
                    #if os(iOS)
                    let screenWidth = UIScreen.main.bounds.width
                    let screenHeight = UIScreen.main.bounds.height
                    let isLandscape = screenWidth > screenHeight
                    if isLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                        return 0 // No bottom padding for iPad landscape
                    } else {
                        return 2 // Original padding for other cases
                    }
                    #else
                    return 2 // Original padding for macOS
                    #endif
                }())     // Dynamic bottom padding based on device and orientation
            }
        }
        // Width is now set by compact/expanded navigation wrappers
        // Dynamic height: moderate height when expanded, content-sized for compact
        .frame(maxHeight: shouldUseExpandedNavigation ? {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: Slightly shorter navigation container but with room for all icons
                return responsiveSize(base: 665, min: 515, max: 715)
            } else {
                // iPad: Keep original height
                return responsiveSize(base: 800, min: 600, max: 900)
            }
            #else
            return responsiveSize(base: 800, min: 600, max: 900)
            #endif
        }() : .infinity)
        .fixedSize(horizontal: false, vertical: shouldUseExpandedNavigation ? false : true)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: shouldUseExpandedNavigation)
        .background(
            // Glassmorphism effect
            ZStack {
                // Base blur
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.background.opacity(0.3),
                        theme.background.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            // Border
            RoundedRectangle(cornerRadius: navigationCornerRadius)  // Dynamic corner radius
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: navigationCornerRadius))  // Dynamic corner radius
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 5, y: 0)
        .offset(x: showFloatingSidebar ? 0 : -100)  // Adjusted offset for new width
        .offset(x: sidebarDragAmount.width)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showFloatingSidebar)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    // Only track movement if swiping right (opening gesture)
                    if value.translation.width > 0 {
                        sidebarDragAmount = value.translation
                    } else if value.translation.width < -30 {
                        // Immediately dismiss when swiping left past threshold
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showFloatingSidebar = false
                            // Set navigation as collapsed so user can swipe to bring it back
                            isNavigationCollapsed = true
                            UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                        }
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        sidebarDragAmount = .zero
                        // Also handle the case where user ends drag with left swipe
                        if value.translation.width < -50 {
                            showFloatingSidebar = false
                            // Set navigation as collapsed so user can swipe to bring it back
                            isNavigationCollapsed = true
                            UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                        }
                    }
                }
        )
    }

    // iPhone Bottom Navigation Bar
@ViewBuilder
private var iPhoneBottomNavigation: some View {
    #if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .phone {
        VStack(spacing: 0) {
            Spacer()
            
            // Bottom navigation container
            ZStack {
                // Background with glassmorphism
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.15),
                        radius: 12,
                        x: 0,
                        y: -2
                    )
                
                // Horizontal scrollable navigation items
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Navigation items
                            ForEach(Array(bottomNavigationItems.enumerated()), id: \.offset) { index, item in
                                BottomNavButton(
                                    icon: item.icon,
                                    title: item.title,
                                    isSelected: currentBottomNavIndex == index,
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            currentBottomNavIndex = index
                                        }
                                        item.action()
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .onChange(of: currentBottomNavIndex) { oldIndex, newIndex in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .frame(height: 60)
                }
                
                // Scroll indicators (dots)
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<max(1, (bottomNavigationItems.count + 4) / 5), id: \.self) { pageIndex in
                            Circle()
                                .fill(currentBottomNavIndex / 5 == pageIndex ? theme.accent : theme.accent.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(height: 80)
            .padding(.horizontal, 16)
            .padding(.bottom, 34) // Safe area bottom padding
            .offset(y: bottomNavOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            bottomNavOffset = min(value.translation.height, 100)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if value.translation.height > 40 {
                                bottomNavOffset = 100 // Hide
                            } else {
                                bottomNavOffset = 0 // Show
                            }
                        }
                    }
            )
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
    #endif
}

// Bottom navigation items configuration
private var bottomNavigationItems: [(icon: String, title: String, action: () -> Void)] {
    [
        (
            icon: "rectangle.3.group",
            title: "Dashboard",
            action: {
                sidebarMode = .allDocuments
                isRightSidebarVisible = false
                viewMode = .normal
            }
        ),
        (
            icon: "magnifyingglass", 
            title: "Document Search",
            action: {
                showSearchModal = true
            }
        ),
        (
            icon: "square.and.pencil",
            title: "New Doc",
            action: {
                let docId = UUID().uuidString
                var d = Letterspace_CanvasDocument(
                    title: "Untitled", 
                    subtitle: "", 
                    elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], 
                    id: docId, 
                    markers: [], 
                    series: nil, 
                    variations: [],
                    isVariation: false, 
                    parentVariationId: nil, 
                    createdAt: Date(), 
                    modifiedAt: Date(), 
                    tags: nil, 
                    isHeaderExpanded: false, 
                    isSubtitleVisible: true, 
                    links: []
                )
                d.save()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    document = d
                    sidebarMode = .details
                    isRightSidebarVisible = true
                }
            }
        ),
                    (
            icon: "folder",
            title: "Folders", 
            action: {
                showFoldersModal = true
            }
        ),
        (
            icon: "sparkles",
            title: "Smart Study",
            action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSmartStudyModal = true
                }
            }
        ),
        (
            icon: "book.closed",
            title: "Bible",
            action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBibleReaderModal = true
                }
            }
        ),
        (
            icon: "square.and.arrow.up",
            title: "Export",
            action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showExportModal = true
                }
            }
        ),
        (
            icon: "gear",
            title: "Settings",
            action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettingsModal = true
                }
            }
        )
    ]
}

// Bottom navigation button component
@ViewBuilder
private func BottomNavButton(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        VStack(spacing: 4) {
            ZStack {
                // Background circle for selected state
                if isSelected {
                    Circle()
                        .fill(theme.accent.opacity(0.2))
                        .frame(width: 32, height: 32)
                }
                
                // Icon
                if icon == "rectangle.3.group" {
                    // Custom dashboard icon
                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(isSelected ? theme.accent : .black)
                            .frame(width: 8, height: 3)
                            .cornerRadius(0.5)
                        Rectangle()
                            .fill(isSelected ? theme.accent : .black)
                            .frame(width: 12, height: 4)
                            .cornerRadius(0.5)
                        Rectangle()
                            .fill(isSelected ? theme.accent : .black)
                            .frame(width: 10, height: 3)
                            .cornerRadius(0.5)
                    }
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? theme.accent : theme.primary)
                }
            }
            .frame(width: 32, height: 32)
            
            // Title
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? theme.accent : theme.secondary)
                .lineLimit(1)
        }
    }
    .buttonStyle(.plain)
    .frame(width: 60)
}
*/

// Extracted Main Content View (original content)
@ViewBuilder
private func mainContentView(availableWidth: CGFloat) -> some View {
                            if sidebarMode == .allDocuments {
                                    DashboardView(
                document: $document, // Pass document binding
                onSelectDocument: { selectedDoc in
                                            self.loadAndOpenDocument(id: selectedDoc.id)
                                        },
                sidebarMode: $sidebarMode, // Pass sidebarMode binding
                isRightSidebarVisible: $isRightSidebarVisible // Pass isRightSidebarVisible binding
                                    )
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                                        removal: .opacity.combined(with: .scale(scale: 1.05, anchor: .center))
                                    ))
                                    .animation(.spring(response: 1.8, dampingFraction: 0.85), value: sidebarMode)
            // .frame(maxWidth: .infinity) // Already applied by parent ZStack
            // .frame(maxHeight: dashboardGeo.size.height) // Use available height
                            } else {
                                DocumentArea(
                                    document: $document,
                                    isHeaderExpanded: $isHeaderExpanded,
                                    isSubtitleVisible: Binding(
                                        get: { document.isSubtitleVisible },
                    set: { newValue in document.isSubtitleVisible = newValue; document.save() }
                                    ),
                                    documentHeight: $documentHeight,
                                    viewportHeight: $viewportHeight,
                                    isDistractionFreeMode: viewMode == .distractionFree,
                                    viewMode: $viewMode,
                availableWidth: availableWidth, // Pass dynamic width
                onHeaderClick: { withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { scrollOffset = 0 } },
                                    isSearchActive: $isSearchActive,
                                    shouldPauseHover: isSearchActive,
                                    onNavigateBack: {
                                        // Check if this is a swipe-down dismiss vs regular navigation
                                        if isSwipeDownDismissing {
                                            // No animation for swipe-down dismiss
                                            sidebarMode = .allDocuments
                                            isRightSidebarVisible = false
                                            viewMode = .normal
                                            
                                            // Reset flag after brief delay
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                isSwipeDownDismissing = false
                                            }
                                        } else {
                                            // Navigate back to dashboard on swipe with smooth slide animation
                                            withAnimation(.easeOut(duration: 0.3)) {
                                                sidebarMode = .allDocuments
                                                isRightSidebarVisible = false
                                                viewMode = .normal
                                            }
                                        }
                                    }
                                )
                                .id(document.id)
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: isSwipeDownDismissing ? .opacity : .move(edge: .trailing)
                                ))
                                .animation(isSwipeDownDismissing ? .none : .easeOut(duration: 0.3), value: sidebarMode)
                            }
    }
    
    // Extracted Right Sidebar Content (original content)
    @ViewBuilder
    private var rightSidebarContent: some View {
        // The original content of the right sidebar area
        Rectangle() // Original was a Rectangle + overlay
                             .fill(Color.clear)
            // .frame(minWidth: rightSidebarWidth, maxWidth: rightSidebarWidth) // Frame applied by parent
                             .overlay {
                                 VStack(spacing: 0) {
                                     ScrollView(showsIndicators: true) {
                                         RightSidebar(
                                             document: $document,
                            isVisible: .constant(true), // isVisible is managed by parent now
                                             selectedElement: $selectedElement,
                                             scrollOffset: $scrollOffset,
                                             documentHeight: $documentHeight,
                                             viewportHeight: $viewportHeight,
                                             viewMode: $viewMode,
                                             isHeaderExpanded: $isHeaderExpanded,
                                             isSubtitleVisible: Binding(
                                                 get: { document.isSubtitleVisible },
                                set: { newValue in document.isSubtitleVisible = newValue; document.save() }
                                             )
                                         )
                                     }
                                 }
                .padding(.trailing, 16) // Original padding
                             }
                             .modifier(ConditionalSidebarTransition(sidebarMode: sidebarMode))
            // .padding(.trailing, 15) // This padding was on the Rectangle, apply to content if needed or remove if redundant
    }

    // Helper to calculate main content width
    private func calculateMainContentWidth(overallWidth: CGFloat) -> CGFloat {
        let isLeftSidebarActuallyVisible = horizontalSizeClass == .regular && !viewMode.isDistractionFreeMode
        return calculateMainContentWidth(
            overallWidth: overallWidth,
            isIPadContext: false,
            isLeftSidebarVisibleForContext: isLeftSidebarActuallyVisible
        )
    }

    private func calculateMainContentWidth(overallWidth: CGFloat, isIPadContext: Bool, isLeftSidebarVisibleForContext: Bool) -> CGFloat {
        var widthTaken: CGFloat = 0
        
        if isIPadContext {
            // For iPad NavigationView, the NavigationView handles the primary sidebar's width.
            // We only need to account for our manually added right sidebar if it's visible in the detail pane.
            if !viewMode.shouldHideSidebars && isRightSidebarVisible {
                widthTaken += rightSidebarWidth // rightSidebarWidth is a property of MainLayout (e.g., 240)
            }
        } else {
            // macOS context (or iPhone if it falls through to this logic)
            if isLeftSidebarVisibleForContext { // Use the passed parameter
                #if os(iOS)
                // On iOS, use the floating sidebar width when docked
                widthTaken += floatingSidebarWidth
                #else
                // On macOS, use the traditional sidebar width
                widthTaken += 72 // macOS Left sidebar fixed width
                #endif
            }
            if !viewMode.shouldHideSidebars && isRightSidebarVisible {
                widthTaken += rightSidebarWidth
            }
        }
        
        let calculated = overallWidth - widthTaken
        // Ensure a minimum sensible width, e.g., 320 points
        return max(calculated, 320)
    }

    private var content: some View {
        GeometryReader { geometry in
            #if os(iOS)
            // For both iPad and iPhone, use the macOSLayout which includes floating sidebar
            // iPhone now defaults to iPad-style interface
                macOSLayout(geometry: geometry)
            #else
            // macOS
            macOSLayout(geometry: geometry)
            #endif
        }
    }

    // Helper view for the macOS (and current iPhone fallback) layout
    @ViewBuilder
    private func macOSLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            // Main content area (background + content) - this gets blurred for modals
            Group {
                // Gradient wallpaper background
                Rectangle()
                    .fill(gradientManager.getCurrentGradient(for: colorScheme))
                    .ignoresSafeArea()
                
                HStack(spacing: 0) {
                let isLeftSidebarActuallyVisible = !viewMode.isDistractionFreeMode
                
                #if os(macOS)
                // macOS: Show traditional fixed sidebar
                if isLeftSidebarActuallyVisible {
                    leftSidebarContent
                        .frame(width: 72)
                        .background(Color.clear)
                        .zIndex(1)
                        .transition(.move(edge: .leading))
                }
                #elseif os(iOS)
                // iOS: Show docked sidebar only on devices that don't use floating navigation
                // Skip docked sidebar on both iPad and iPhone since they now both use floating navigation
                if false { // Disable docked sidebar completely for iOS since both iPad and iPhone use floating navigation
                    dockedSidebarContent
                        .zIndex(1)
                        .transition(.move(edge: .leading))
                }
                
                // TEMPORARY: Force show docked sidebar on iPad for debugging - DISABLED
                /*
                #if DEBUG
                if UIDevice.current.userInterfaceIdiom == .pad && isDocked && !viewMode.isDistractionFreeMode {
                    dockedSidebarContent
                        .zIndex(2)
                        .transition(.move(edge: .leading))
                }
                #endif
                */
                #endif
                
                // Main content area + Right sidebar
                HStack(spacing:0) {
                    ZStack(alignment: .trailing) {
                        mainContentView(availableWidth: calculateMainContentWidth(
                            overallWidth: geometry.size.width,
                            isIPadContext: false,
                            isLeftSidebarVisibleForContext: {
                                #if os(iOS)
                                // Both iPad and iPhone use floating navigation, so no docked sidebar
                                return false // Disabled: Both iPad and iPhone use floating navigation only
                                #else
                                return isLeftSidebarActuallyVisible
                                #endif
                            }()
                        ))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        #if os(macOS)
                        if viewMode.isDistractionFreeMode && !document.markers.filter({ $0.type == "bookmark" }).isEmpty {
                             VerticalBookmarkTimelineView(activeDocument: document)
                                .frame(width: 170)
                             .padding(.trailing, 15)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .identity
                                ))
                                .animation(viewMode.isDistractionFreeMode ? .spring(response: 0.4, dampingFraction: 0.7) : nil, value: viewMode)
                        }
                        #endif
                    }
                    .frame(maxWidth: .infinity)

                    #if os(macOS)
                    if !viewMode.shouldHideSidebars && isRightSidebarVisible {
                         rightSidebarContent
                             .frame(width: rightSidebarWidth)
                             .transition(.move(edge: .trailing))
                     }
                     #elseif os(iOS)
                     // iOS: Both iPhone and iPad use floating toolbar instead of traditional sidebar
                     if false { // Disabled: Both iPhone and iPad use floating toolbar only
                         rightSidebarContent
                             .frame(width: rightSidebarWidth)
                             .transition(.move(edge: .trailing))
                     }
                     #endif
                }
                .frame(maxWidth: .infinity)
            }
            
            #if os(iOS)
            // iOS: Both iPad and iPhone now use different navigation systems
            if false { // Disabled: iPhone uses circular menu, iPad uses native NavigationSplitView
                                VStack(alignment: .leading) {
                HStack {
                        // Unified floating navigation with responsive size transitions
                        animatedFloatingNavigation
                            .padding(.leading, {
                                // Center between screen edge and All Documents section
                                let screenWidth = UIScreen.main.bounds.width
                                let allDocumentsLeftEdge = screenWidth * 0.065 // Approximate left edge of All Documents (based on padding)
                                let centerPoint = allDocumentsLeftEdge / 2 // Center between screen edge and All Documents
                                
                                // iPhone: Add more breathing room from left edge
                                return shouldUseExpandedNavigation ? centerPoint + 8 : 20
                            }())
                            .padding(.top, {
                                // Responsive top padding based on screen height and orientation
                                let screenHeight = UIScreen.main.bounds.height
                                let screenWidth = UIScreen.main.bounds.width
                                let isLandscape = screenWidth > screenHeight
                                if shouldUseExpandedNavigation {
                                    if isLandscape {
                                        // iPhone landscape
                                        return screenHeight * 0.05 + 10
                                    } else {
                                        // iPhone portrait mode - positioned lower for better visual balance
                                        return screenHeight * 0.26 + 40 // 26% + 40pt for iPhone
                                    }
                                } else {
                                    return 20 // Compact mode
                                }
                            }())
                            .offset(x: (showFloatingSidebar && (shouldShowNavigationPanel || isManuallyShown)) ? 0 : -200) // Hide when viewing documents unless manually shown
                            .animation(.spring(response: showFloatingSidebar ? 0.6 : 2.5, dampingFraction: showFloatingSidebar ? 0.75 : 0.9), value: showFloatingSidebar)
                            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: shouldShowNavigationPanel)
                            .onChange(of: sidebarMode) { oldMode, newMode in
                                // Automatically show/hide navigation based on mode (iPhone only)
                                if newMode == .allDocuments {
                                    showFloatingSidebar = true  // Show when going to dashboard
                                    isManuallyShown = false  // Reset manual flag when auto-showing
                                } else {
                                    showFloatingSidebar = false // Hide when going to document mode
                                    isManuallyShown = false  // Reset manual flag when auto-hiding
                                }
                            }
                            .gesture(
                                // Add swipe-to-dismiss gesture for iPad
                                UIDevice.current.userInterfaceIdiom == .pad ? 
                                DragGesture()
                                    .onEnded { value in
                                        if value.translation.width < -100 { // Swipe left to dismiss
                                            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                                                showFloatingSidebar = false
                                                isManuallyShown = false  // Reset manual flag when user dismisses
                                            }
                                        }
                                    } : nil
                            )
                    
                    Spacer()
                    }
                    
                    Spacer() // Push everything to the top
                }
                .ignoresSafeArea()
                
                // No swipe indicators needed - iPad uses native sidebar, iPhone uses circular menu
                // Removed all gesture code - no longer needed
            }
            
            // iPhone: Bottom Navigation Bar - Disabled (using circular menu instead)
            // if UIDevice.current.userInterfaceIdiom == .phone {
            //     iPhoneBottomNavigation
            //         .zIndex(99) // Below floating sidebar but above content
            // }
            
            // No swipe indicators needed - iPad uses native NavigationSplitView  
            if false { // Disabled
                VStack {
                    Spacer()
                    HStack {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: 3, height: 60)
                            .padding(.leading, 8)
                            .scaleEffect(sidebarDragAmount.width > 0 ? 1.2 : 1.0) // Visual feedback when dragging
                            .animation(.easeOut(duration: 0.1), value: sidebarDragAmount.width)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if value.translation.width > 0 {
                                            sidebarDragAmount = value.translation
                                            if value.translation.width > 30 && !showFloatingSidebar {
                                                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                                                    showFloatingSidebar = true
                                                    isManuallyShown = true  // User manually showed navigation
                                                }
                                            }
                                        }
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                                            if value.translation.width > 50 {
                                                showFloatingSidebar = true
                                                isManuallyShown = true  // User manually showed navigation
                                            }
                                            sidebarDragAmount = .zero
                                        }
                                    }
                            )
                        
                        Spacer()
                    }
                    Spacer()
                }
                .ignoresSafeArea()
                .allowsHitTesting(true)
                
                // Invisible gesture area for swiping from left edge on iPad when navigation dismissed
                HStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.width > 50 {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                                            showFloatingSidebar = true
                                            isManuallyShown = true  // User manually showed navigation
                                        }
                                    }
                                }
                        )
                    
                    Spacer()
                }
                .ignoresSafeArea()
            }
            
            // Add swipe indicator for collapsed navigation in docked mode (iPhone only, iPad uses floating)
            // Disabled for iPhone since it now uses circular menu instead
            if false && !viewMode.isDistractionFreeMode && isDocked && isNavigationCollapsed && UIDevice.current.userInterfaceIdiom != .pad {
                VStack {
                    Spacer()
                    HStack {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: 3, height: 60)
                            .padding(.leading, 8)
                            .scaleEffect(sidebarDragAmount.width > 0 ? 1.2 : 1.0) // Visual feedback when dragging
                            .animation(.easeOut(duration: 0.1), value: sidebarDragAmount.width)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if value.translation.width > 0 {
                                            sidebarDragAmount = value.translation
                                        }
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            sidebarDragAmount = .zero
                                            // Swipe right to show docked navigation
                                            if value.translation.width > 50 {
                                                isNavigationCollapsed = false
                                                UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                                            }
                                        }
                                    }
                            )
                        
                        Spacer()
                    }
                    Spacer()
                }
                .ignoresSafeArea()
                .allowsHitTesting(true)
                
                // Also add invisible gesture area for easier swiping
                HStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.width > 0 {
                                        sidebarDragAmount = value.translation
                                    }
                                }
                                .onEnded { value in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        sidebarDragAmount = .zero
                                        // Swipe right to show docked navigation
                                        if value.translation.width > 50 {
                                            isNavigationCollapsed = false
                                            UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                                        }
                                    }
                                }
                        )
                    
                    Spacer()
                }
                .ignoresSafeArea()
            }
            
            // Floating contextual toolbar removed for iPhone/iPad - now using Document Tools button instead
            #endif
            }
            // Apply blur to main content area when any modal is shown
            // iPhone: Only apply blur for circular menu, not for modal sheets
            // Other platforms: Apply blur for all modals
            .blur(radius: {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    // iPhone: Only blur for circular menu navigation, not modal sheets
                    return isCircularMenuOpen ? 4 : 0
                } else {
                    // iPad: Apply blur for all modals
                    return showUserProfileModal || showUserProfileSheet || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal || showExportModal || showSettingsModal || showSearchModal || isCircularMenuOpen ? 4 : 0
                }
                #else
                // macOS: Apply blur for all modals
                return showUserProfileModal || showUserProfileSheet || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal || showExportModal || showSettingsModal || showSearchModal || isCircularMenuOpen ? 4 : 0
                #endif
            }())
            .opacity({
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    // iPhone: Only dim for circular menu navigation, not modal sheets
                    return isCircularMenuOpen ? 0.8 : 1.0
                } else {
                    // iPad: Apply opacity change for all modals
                    return showUserProfileModal || showUserProfileSheet || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal || showExportModal || showSettingsModal || showSearchModal || isCircularMenuOpen ? 0.8 : 1.0
                }
                #else
                // macOS: Apply opacity change for all modals
                return showUserProfileModal || showUserProfileSheet || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal || showExportModal || showSettingsModal || showSearchModal || isCircularMenuOpen ? 0.8 : 1.0
                #endif
            }())
            .animation(.easeInOut(duration: 0.15), value: showUserProfileModal || showUserProfileSheet || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal || showExportModal || showSettingsModal || showSearchModal || isCircularMenuOpen)
            
            // Floating Action Buttons (iPhone only)
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            // DISABLED: Show distraction-free button when in document mode (top position) - now using inline button
                            if false && sidebarMode != .allDocuments {
                                Button(action: {
                                    HapticFeedback.impact(.medium)
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        if viewMode.isDistractionFreeMode {
                                            viewMode = .normal
                                            // Restore right sidebar when exiting distraction-free mode
                                            isRightSidebarVisible = true
                                        } else {
                                            viewMode = .distractionFree
                                            isRightSidebarVisible = false
                                        }
                                    }
                                }) {
                                    Image(systemName: viewMode.isDistractionFreeMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(theme.primary)
                                        .frame(width: 56, height: 56)
                                        .background(
                                            ZStack {
                                                // Base blur
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                                
                                                // Gradient overlay
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                theme.background.opacity(0.3),
                                                                theme.background.opacity(0.1)
                                                            ]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                            }
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.05)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                                }
                                .frame(width: 65, height: 65) // Increased tappable area
                                .contentShape(Rectangle()) // Makes entire frame tappable
                                .buttonStyle(.plain)
                                .scaleEffect(isHoveringDistraction ? 1.05 : 1.0)
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isHoveringDistraction = hovering
                                    }
                                }
                            }
                            
                            // iOS 26 Button Cluster (bottom position) - adaptive based on mode
                            if viewMode.isDistractionFreeMode {
                                HStack(spacing: 16) {
                                    // Empty space where document tools button was (left position)
                                    Color.clear.frame(width: 64, height: 64)
                                    
                                    // Bookmark launcher in middle position (where full screen was)
                                    if sidebarMode != .allDocuments {
                                        Button(action: {
                                            HapticFeedback.impact(.light)
                                            showBookmarksSheet = true
                                        }) {
                                            // Bookmark icon on top of glass
                                            Image(systemName: "bookmark.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(Color.primary)
                                                .frame(width: 56, height: 56)
                                                .background(
                                                    Circle()
                                                        .fill(.clear)
                                                        .glassEffect(.regular, in: Circle())
                                                )
                                        }
                                        .frame(width: 64, height: 64)
                                        .contentShape(Circle())
                                        .buttonStyle(.plain)
                                        .scaleEffect(isHoveringBookmark ? 1.05 : 1.0)
                                        .animation(.easeInOut(duration: 0.1), value: isHoveringBookmark)
                                        .onHover { hovering in
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                isHoveringBookmark = hovering
                                            }
                                        }
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                                        .matchedGeometryEffect(id: "documentToolsButton", in: documentToolsTransition)
                                        .sheet(isPresented: $showBookmarksSheet) {
                                            BookmarksSheet(document: $document)
                                        }
                                    } else {
                                        // Empty space if no document tools
                                        Color.clear.frame(width: 64, height: 64)
                                    }
                                    
                                    // Exit button in exact menu position (rightmost)
                                    Button(action: {
                                        HapticFeedback.impact(.medium)
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            viewMode = .normal
                                            isRightSidebarVisible = true
                                        }
                                    }) {
                                        // Exit full screen icon on top of glass
                                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                            .frame(width: 56, height: 56)
                                            .background(
                                                Circle()
                                                    .fill(.clear)
                                                    .glassEffect(.regular, in: Circle())
                                            )
                                    }
                                    .frame(width: 64, height: 64)
                                    .contentShape(Circle())
                                    .buttonStyle(.plain)
                                    .scaleEffect(isHoveringDistraction ? 1.05 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: isHoveringDistraction)
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            isHoveringDistraction = hovering
                                        }
                                    }
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                                    .matchedGeometryEffect(id: "fullScreenButton", in: buttonTransition)
                                }
                            } else {
                                // Normal mode: Show all buttons 
                                HStack(spacing: 16) {
                                    // Document Tools Button (left)
                                    if sidebarMode != .allDocuments {
                                        LiquidDocumentToolsButton(
                                            document: $document,
                                            selectedElement: $selectedElement,
                                            scrollOffset: $scrollOffset,
                                            documentHeight: $documentHeight,
                                            viewportHeight: $viewportHeight,
                                            viewMode: $viewMode,
                                            isHeaderExpanded: $isHeaderExpanded,
                                            isSubtitleVisible: Binding(
                                                get: { document.isSubtitleVisible },
                                                set: { newValue in document.isSubtitleVisible = newValue; document.save() }
                                            )
                                        )
                                        .matchedGeometryEffect(id: "documentToolsButton", in: documentToolsTransition)
                                    }
                                    
                                    // Full Screen Button (middle) - using existing distraction-free button
                                    if sidebarMode != .allDocuments {
                                        Button(action: {
                                            HapticFeedback.impact(.medium)
                                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                                viewMode = .distractionFree
                                                isRightSidebarVisible = false
                                            }
                                        }) {
                                            // Enter full screen icon on top of glass
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(Color.primary)
                                                .frame(width: 56, height: 56)
                                                .background(
                                                    Circle()
                                                        .fill(.clear)
                                                        .glassEffect(.regular, in: Circle())
                                                )
                                        }
                                        .frame(width: 64, height: 64)
                                        .contentShape(Circle())
                                        .buttonStyle(.plain)
                                        .scaleEffect(isHoveringFullScreen ? 1.05 : 1.0)
                                        .animation(.easeInOut(duration: 0.1), value: isHoveringFullScreen)
                                        .onHover { hovering in
                                            withAnimation(.easeInOut(duration: 0.1)) {
                                                isHoveringFullScreen = hovering
                                            }
                                        }
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                                        .matchedGeometryEffect(id: "fullScreenButton", in: buttonTransition)
                                    }
                                    
                                    // Glass Menu Button (right) - morphing effect
                                    GlassCircularMenuButton(
                                        isMenuOpen: $isCircularMenuOpen,
                                        onDashboard: {
                                            sidebarMode = .allDocuments
                                            isRightSidebarVisible = false
                                            viewMode = .normal
                                        },
                                        onSearch: {
                                            showSearchModal = true
                                        },
                                        onNewDocument: {
                                            let docId = UUID().uuidString
                                            var d = Letterspace_CanvasDocument(
                                                title: "Untitled", 
                                                subtitle: "", 
                                                elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], 
                                                id: docId, 
                                                markers: [], 
                                                series: nil, 
                                                variations: [],
                                                isVariation: false, 
                                                parentVariationId: nil, 
                                                createdAt: Date(), 
                                                modifiedAt: Date(), 
                                                tags: nil, 
                                                isHeaderExpanded: false, 
                                                isSubtitleVisible: true, 
                                                links: []
                                            )
                                            d.save()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                document = d
                                                sidebarMode = .details
                                                isRightSidebarVisible = true
                                            }
                                        },
                                        onFolders: {
                                            showFoldersModal = true
                                        },
                                        onBibleReader: {
                                            showBibleReaderModal = true
                                        },
                                        onSmartStudy: {
                                            showSmartStudyModal = true
                                        },
                                        onRecentlyDeleted: {
                                            showRecentlyDeletedModal = true
                                        },
                                        onSettings: {
                                            showUserProfileModal = true
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
                .allowsHitTesting(true)
            }
            #else
            // Non-iPhone devices: Keep original distraction-free button for iPad/macOS
            if sidebarMode != .allDocuments {
                VStack {
                    Spacer()
                    HStack {
                                            Spacer()
                    
                    Button(action: {
                        HapticFeedback.impact(.medium)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            if viewMode.isDistractionFreeMode {
                                viewMode = .normal
                                // Restore right sidebar when exiting distraction-free mode
                                isRightSidebarVisible = true
                            } else {
                                viewMode = .distractionFree
                                isRightSidebarVisible = false
                            }
                        }
                    }) {
                        Image(systemName: viewMode.isDistractionFreeMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(theme.primary)
                                .frame(width: 48, height: 48)
                            .background(
                                    ZStack {
                                        // Base blur
                                Circle()
                                            .fill(.ultraThinMaterial)
                                        
                                        // Gradient overlay
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        theme.background.opacity(0.3),
                                                        theme.background.opacity(0.1)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                )
                                    .overlay(
                                        Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.2),
                                                    Color.white.opacity(0.05)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                    )
                            )
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .help(viewMode.isDistractionFreeMode ? "Exit Distraction-Free Mode" : "Enter Distraction-Free Mode")
                    .scaleEffect(isHoveringDistraction ? 1.05 : 1.0)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isHoveringDistraction = hovering
                        }
                    }
                        .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .allowsHitTesting(true)
            }
            #endif
            
            // REMOVED: Old CircularMenuOverlay - now using GlassCircularMenuButton with morphing effect
        }
    }

    // Helper view for iPad detail and right sidebar combination
    @ViewBuilder  
    private func detailAndRightSidebarView(geometry: GeometryProxy) -> some View {
        ZStack {
            HStack(spacing: 0) {
                // Main content area
                ZStack(alignment: .trailing) {
                    mainContentView(availableWidth: calculateMainContentWidth(
                        overallWidth: geometry.size.width,
                        isIPadContext: true,
                        isLeftSidebarVisibleForContext: false // NavigationView handles the primary sidebar
                    ))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if viewMode.isDistractionFreeMode && !document.markers.filter({ $0.type == "bookmark" }).isEmpty {
                        #if os(macOS)
                        VerticalBookmarkTimelineView(activeDocument: document)
                            .frame(width: 170)
                            .padding(.trailing, 15)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .identity
                            ))
                            .animation(viewMode.isDistractionFreeMode ? .spring(response: 0.4, dampingFraction: 0.7) : nil, value: viewMode)
                        #endif
                    }
                    
                }
                .frame(maxWidth: .infinity)


                // Right sidebar (macOS always, iPad when explicitly shown)
                #if os(macOS)
                if !viewMode.shouldHideSidebars && isRightSidebarVisible {
                    rightSidebarContent
                        .frame(width: rightSidebarWidth)
                        .transition(.move(edge: .trailing))
                }
                #elseif os(iOS)
                // iPad right sidebar removed - now using Document Tools button instead
                #endif
            }
            
            // Floating Distraction-Free Mode Button - only show when in document mode
            if sidebarMode != .allDocuments {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            HapticFeedback.impact(.medium)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if viewMode.isDistractionFreeMode {
                                    viewMode = .normal
                                    // Restore right sidebar when exiting distraction-free mode
                                    isRightSidebarVisible = true
                                } else {
                                    viewMode = .distractionFree
                                    isRightSidebarVisible = false
                                }
                            }
                        }) {
                            Image(systemName: viewMode.isDistractionFreeMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.8))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help(viewMode.isDistractionFreeMode ? "Exit Distraction-Free Mode" : "Enter Distraction-Free Mode")
                        .scaleEffect(isHoveringDistraction ? 1.05 : 1.0)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isHoveringDistraction = hovering
                            }
                        }
                        .padding(.trailing, 20) // Position in far right corner
                        .padding(.bottom, 20)
                    }
                }
                .allowsHitTesting(true)
            }
        }
    }

    private func loadFolders() {
        // Load folders
        if let savedData = UserDefaults.standard.data(forKey: "SavedFolders"),
           let decodedFolders = try? JSONDecoder().decode([Folder].self, from: savedData) {
            folders = decodedFolders
        } else {
            // Initialize with default folders if none are saved
            folders = [
                Folder(id: UUID(), name: "Sermons", isEditing: false, subfolders: [], documentIds: Set<String>()),
                Folder(id: UUID(), name: "Bible Studies", isEditing: false, subfolders: [], documentIds: Set<String>()),
                Folder(id: UUID(), name: "Notes", isEditing: false, subfolders: [], documentIds: Set<String>()),
                Folder(id: UUID(), name: "Archive", isEditing: false, subfolders: [], documentIds: Set<String>())
            ]
        }
        
        // Load folder documents
        if let data = UserDefaults.standard.data(forKey: "FolderDocuments"),
           let decoded = try? JSONDecoder().decode([String: Set<String>].self, from: data) {
            // Convert String keys back to UUIDs and update folder documentIds
            var updatedFolders = folders
            for (key, value) in decoded {
                if let uuid = UUID(uuidString: key),
                   let index = updatedFolders.firstIndex(where: { $0.id == uuid }) {
                    var updatedFolder = updatedFolders[index]
                    updatedFolder.documentIds = value
                    updatedFolders[index] = updatedFolder
                }
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                folders = updatedFolders
            }
            
            // Save the updated folders to ensure consistency
            saveFolders()
        } else {
            print("❌ No folder documents data found")
        }
    }
    
    private func saveFolders() {
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: "SavedFolders")
            
            // Also save folder documents mapping
            let folderDocuments = folders.reduce(into: [String: Set<String>]()) { result, folder in
                result[folder.id.uuidString] = folder.documentIds
            }
            if let encodedDocs = try? JSONEncoder().encode(folderDocuments) {
                UserDefaults.standard.set(encodedDocs, forKey: "FolderDocuments")
            }
        }
    }
    
    private func addFolder(_ folder: Folder, to parentId: UUID?) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // Add to root level only
                folders.append(folder)
                
                // Force immediate save
                saveFolders()
                
                // Remove synchronize() to prevent main thread hangs
                
                // Notify that folders have been updated
                NotificationCenter.default.post(name: NSNotification.Name("FoldersDidUpdate"), object: nil)
            }
        }
    }

    // Docked sidebar for iOS - inline version
    @ViewBuilder
    private var dockedSidebarContent: some View {
        VStack(spacing: 0) {
            // Move top buttons down - add more top padding
            VStack(spacing: 16) {  // Reduced spacing from 24 to 16 to fit all icons
                FloatingSidebarButton(
                    icon: "rectangle.3.group",
                    title: "Dashboard",
                    action: {
                        sidebarMode = .allDocuments
                        isRightSidebarVisible = false
                        viewMode = .normal
                    }
                )
                
                FloatingSidebarButton(
                    icon: "magnifyingglass",
                    title: "Search Documents",
                    action: {
                        showSearchModal = true
                    }
                )
                #if os(iOS)
                .popover(
                    isPresented: Binding(
                        get: { activePopup == .search && UIDevice.current.userInterfaceIdiom == .pad },
                        set: { if !$0 { activePopup = .none } }
                    ),
                    arrowEdge: .leading
                ) {
                    SearchPopupContent(
                        activePopup: $activePopup,
                        document: $document,
                        sidebarMode: $sidebarMode,
                        isRightSidebarVisible: $isRightSidebarVisible,
                        onDismiss: {
                            activePopup = .none
                        }
                    )
                    .frame(width: 350, height: 500)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                }
                #endif
                
                FloatingSidebarButton(
                    icon: "square.and.pencil",
                    title: "Create New Document",
                    action: {
                        #if os(iOS)
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            // Use popup system for iPad
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if activePopup == .newDocument {
                                    activePopup = .none
                                } else {
                                    activePopup = .newDocument
                                }
                            }
                        } else {
                            // Use direct creation for iPhone
                        let docId = UUID().uuidString
                        var d = Letterspace_CanvasDocument(
                            title: "Untitled", 
                            subtitle: "", 
                            elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], 
                            id: docId, 
                            markers: [], 
                            series: nil, 
                            variations: [],
                            isVariation: false, 
                            parentVariationId: nil, 
                            createdAt: Date(), 
                            modifiedAt: Date(), 
                            tags: nil, 
                            isHeaderExpanded: false, 
                            isSubtitleVisible: true, 
                            links: []
                        )
                        d.save()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            document = d
                            sidebarMode = .details
                            isRightSidebarVisible = true
                            activePopup = .none
                        }
                    }
                        #else
                        // Use direct creation for macOS
                        let docId = UUID().uuidString
                        var d = Letterspace_CanvasDocument(
                            title: "Untitled", 
                            subtitle: "", 
                            elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], 
                            id: docId, 
                            markers: [], 
                            series: nil, 
                            variations: [],
                            isVariation: false, 
                            parentVariationId: nil, 
                            createdAt: Date(), 
                            modifiedAt: Date(), 
                            tags: nil, 
                            isHeaderExpanded: false, 
                            isSubtitleVisible: true, 
                            links: []
                        )
                        d.save()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            document = d
                            sidebarMode = .details
                            isRightSidebarVisible = true
                            activePopup = .none
                        }
                        #endif
                    }
                )
                #if os(iOS)
                .popover(
                    isPresented: Binding(
                        get: { activePopup == .newDocument && UIDevice.current.userInterfaceIdiom == .pad },
                        set: { if !$0 { activePopup = .none } }
                    ),
                    arrowEdge: .leading
                ) {
                    NewDocumentPopupContent(
                        showTemplateBrowser: $showTemplateBrowser,
                        activePopup: $activePopup,
                        document: $document,
                        sidebarMode: $sidebarMode,
                        isRightSidebarVisible: $isRightSidebarVisible
                    )
                    .frame(width: 320, height: 200)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                #endif
                
                FloatingSidebarButton(
                    icon: "folder",
                    title: "Folders",
                    action: {
                        showFoldersModal = true
                    }
                )
                #if os(iOS)
                .popover(
                    isPresented: Binding(
                        get: { activePopup == .folders && UIDevice.current.userInterfaceIdiom == .pad },
                        set: { if !$0 { activePopup = .none } }
                    ),
                    arrowEdge: .leading
                ) {
                    FoldersPopupContent(
                        activePopup: $activePopup,
                        folders: $folders,
                        document: $document,
                        sidebarMode: $sidebarMode,
                        isRightSidebarVisible: $isRightSidebarVisible,
                        onAddFolder: addFolder,
                        showHeader: true // Show header for iPad popover
                    )
                    .frame(width: 400, height: 500)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                #endif
                
                FloatingSidebarButton(
                    icon: "sparkles",
                    title: "Smart Study",
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSmartStudyModal = true
                        }
                    }
                )
                
                FloatingSidebarButton(
                    icon: "book.closed",
                    title: "Bible Reader",
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showBibleReaderModal = true
                        }
                    }
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 80)  // Increased from 24 to 80 to move buttons down
            
            // Spacer to push bottom buttons up more
            Spacer()
            
            // Bottom section - Settings and profile buttons with tighter spacing
            VStack(spacing: 28) {  // Increased spacing from 20 to 28 for more space between bottom icons
                FloatingSidebarButton(
                    icon: appearanceController.selectedScheme.icon,
                    title: "Color Scheme: \(appearanceController.selectedScheme.rawValue)",
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            transitionOpacity = 0
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                // Cycle through the color scheme options
                                let allCases = AppColorScheme.allCases
                                if let currentIndex = allCases.firstIndex(of: appearanceController.selectedScheme) {
                                    let nextIndex = (currentIndex + 1) % allCases.count
                                    appearanceController.selectedScheme = allCases[nextIndex]
                                }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    transitionOpacity = 1
                                }
                            }
                        }
                    }
                )
                
                FloatingSidebarButton(
                    icon: "trash",
                    title: "Recently Deleted",
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRecentlyDeletedModal = true
                        }
                    }
                )
                
                FloatingSidebarButton(
                    icon: "person.crop.circle.fill",
                    title: "User Profile",
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showUserProfileModal = true
                        }
                    }
                )
                

                
                // Collapse arrow button - same as floating toolbar, placed under dock button
                FloatingSidebarButton(
                    icon: "arrow.left",
                    title: "Hide Navigation",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isNavigationCollapsed = true
                            UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed") // Save collapsed state
                        }
                    }
                )
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 60)  // Reduced from 120 to 60 to ensure arrow button is visible
        }
        .frame(width: floatingSidebarWidth)
        .frame(maxHeight: .infinity)
        .background(
            // Conditional background: solid white for default gradients, glassmorphism for custom gradients
            ZStack {
                let useGlassmorphism = colorScheme == .dark ? 
                    gradientManager.selectedDarkGradientIndex != 0 :
                    gradientManager.selectedLightGradientIndex != 0
                
                if useGlassmorphism {
                    // Glassmorphism effect for custom gradients
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.background.opacity(0.3),
                        theme.background.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                } else {
                    // Solid background for default gradients
                    Rectangle()
                        .fill(colorScheme == .light ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.12))
                }
            }
        )
        .overlay(
            // Border only on the right side for inline mode
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
                .offset(x: floatingSidebarWidth / 2)
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe left to hide docked navigation
                    if value.translation.width < -50 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isNavigationCollapsed = true
                            UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                        }
                    }
                }
        )
    }
}

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// Lazy modal container for performance optimization
struct LazyModalContainer<Content: View>: View {
    let content: () -> Content
    @State private var isContentLoaded = false
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        Group {
            if isContentLoaded {
                content()
            } else {
                // Lightweight placeholder while content loads
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 50, height: 50)
                    .onAppear {
                        // Defer content creation to next run loop
                        DispatchQueue.main.async {
                            self.isContentLoaded = true
                        }
                    }
            }
        }
    }
}

struct DocumentTransitionModifier: ViewModifier {
    let isVisible: Binding<Bool>
    let selectedElement: Binding<UUID?>
    let scrollOffset: Binding<CGFloat>
    let documentHeight: Binding<CGFloat>
    let viewportHeight: Binding<CGFloat>
    let viewMode: Binding<ViewMode>
    let isHeaderExpanded: Binding<Bool>
    let isSubtitleVisible: Binding<Bool>
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible.wrappedValue ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: isVisible.wrappedValue)
            .onChange(of: isVisible.wrappedValue) { oldValue, newValue in
                if newValue {
                    // Animate scroll position reset when sidebar becomes visible
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollOffset.wrappedValue = 0
                    }
                }
            }
            .onChange(of: selectedElement.wrappedValue) { oldValue, newValue in
                if newValue != nil {
                    // Animate scroll position reset when an element is selected
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollOffset.wrappedValue = 0
                    }
                }
            }
            .onChange(of: viewMode.wrappedValue) { oldValue, newValue in
                // Animate scroll position reset when view mode changes
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    scrollOffset.wrappedValue = 0
                }
            }
            .onChange(of: isHeaderExpanded.wrappedValue) { oldValue, newValue in
                if newValue {
                    // Animate scroll position reset when header is expanded
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollOffset.wrappedValue = 0
                    }
                }
            }
            .onChange(of: isSubtitleVisible.wrappedValue) { oldValue, newValue in
                if newValue {
                    // Animate scroll position reset when subtitle is visible
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollOffset.wrappedValue = 0
                    }
                }
            }
    }
}

struct FolderListItem {
    let name: String
    let isFolder: Bool
    let item: Any
}

extension View {
    func folderPulse(id: UUID) -> some View {
        let isPulsing = UserDefaults.standard.bool(forKey: "pulse_\(id.uuidString)")
        return self.overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.blue.opacity(isPulsing ? 0.5 : 0), lineWidth: 2)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
        )
    }
}

// Extension for MainLayout to add document loading functionality
extension MainLayout {
    // Function to load and open a document by ID
    func loadAndOpenDocument(id: String) {
        print("🔍 Loading document with ID: \(id)")
        
        // Check if document is in cache
        if let cachedDocument = DocumentCacheManager.shared.getDocument(id: id) {
            print("📂 Using cached document: \(cachedDocument.title)")
            
            // If document has a header image, ensure it's preloaded
            preloadHeaderImage(for: cachedDocument) {
                // Update the document binding from cache
                DispatchQueue.main.async {
                    // Setting the document and sidebar mode immediately without animation
                    // for better performance
                    document = cachedDocument
                    sidebarMode = .details
                    isRightSidebarVisible = true
                    
                    // Post notification that document has loaded
                    NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                }
            }
            return
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        let fileURL = appDirectory.appendingPathComponent("\(id).canvas")
        print("📂 Looking for file at: \(fileURL.path)")
        
        // Load document in a background thread to improve performance
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: fileURL)
                print("📂 Successfully read data from file: \(fileURL.lastPathComponent)")
                let loadedDocument = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                print("📂 Successfully decoded document: \(loadedDocument.title)")
                
                // Preload the header image before showing the document
                self.preloadHeaderImage(for: loadedDocument) {
                    // Update cache
                    DispatchQueue.main.async {
                        DocumentCacheManager.shared.cacheDocument(id: id, document: loadedDocument)
                        
                        // Setting the document and sidebar mode without animation
                        // for better performance
                        document = loadedDocument
                        sidebarMode = .details
                        isRightSidebarVisible = true
                        
                        // Post notification that document has loaded
                        NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                    }
                }
            } catch {
                print("❌ Error loading document with ID \(id): \(error)")
            }
        }
    }
    
    // Helper function to preload header image before showing document
    private func preloadHeaderImage(for document: Letterspace_CanvasDocument, completion: @escaping () -> Void) {
        // Only try to preload if document has header image and header is expanded
        if document.isHeaderExpanded,
           let headerElement = document.elements.first(where: { $0.type == .headerImage }),
           !headerElement.content.isEmpty {
            
            // Check if image is already in cache
            let cacheKey = "\(document.id)_\(headerElement.content)"
            if ImageCache.shared.image(for: cacheKey) != nil {
                print("📸 Header image already in cache, showing document immediately")
                completion()
                return
            }
            
            // Image not in cache, load it first
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                completion()
                return
            }
            
            let documentPath = documentsPath.appendingPathComponent("\(document.id)")
            let imagesPath = documentPath.appendingPathComponent("Images")
            let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
            
            print("📸 Preloading header image before showing document")
            DispatchQueue.global(qos: .userInitiated).async {
                #if os(macOS)
                if let headerImage = NSImage(contentsOf: imageUrl) {
                    // Cache both with document-specific key and generic key
                    ImageCache.shared.setImage(headerImage, for: cacheKey)
                    ImageCache.shared.setImage(headerImage, for: headerElement.content)
                    print("📸 Header image preloaded successfully")
                }
                #elseif os(iOS)
                if let imageData = try? Data(contentsOf: imageUrl),
                   let headerImage = UIImage(data: imageData) {
                    // Cache both with document-specific key and generic key
                    ImageCache.shared.setImage(headerImage, for: cacheKey)
                    ImageCache.shared.setImage(headerImage, for: headerElement.content)
                    print("📸 Header image preloaded successfully")
                }
                #endif
                
                // Always complete, even if image load fails
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            // No header image to preload
            completion()
        }
    }
    
    // Add the appropriate lifecycle modifier to the body property
    func bodySidebarModeChanged(oldValue: RightSidebar.SidebarMode, newValue: RightSidebar.SidebarMode) {
        // If switching to the dashboard view, refresh document list
        if newValue == .allDocuments {
            // Post notification to refresh document list
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
            print("🔄 Posted DocumentListDidUpdate notification after switching to dashboard")
        }
    }
}

// MARK: - Sidebar Transition Modifier
struct ConditionalSidebarTransition: ViewModifier {
    let sidebarMode: RightSidebar.SidebarMode
    
    func body(content: Content) -> some View {
        // Use instant transition for all views, no animations
        content.transition(.identity)
    }
}

// MARK: - ScriptureModalContainer
struct ScriptureModalContainer<Content: View>: View {
    let content: Content
    let isShowing: Bool
    @Environment(\.colorScheme) var colorScheme
    
    @State private var modalOpacity: Double = 0.0
    @State private var modalScale: Double = 0.95
    
    init(isShowing: Bool, @ViewBuilder content: () -> Content) {
        self.isShowing = isShowing
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.12) : Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 14, x: 0, y: 8)
            )
            .opacity(modalOpacity)
            .scaleEffect(modalScale)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    modalOpacity = 1.0
                    modalScale = 1.0
                }
            }
            .onChange(of: isShowing) { oldValue, newValue in
                if !newValue {
                    withAnimation(.easeOut(duration: 0.2)) {
                        modalOpacity = 0.0
                        modalScale = 0.95
                    }
                }
            }
    }
}

// MARK: - Glassmorphism Background Modifier

struct GlassmorphismBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    let gradientManager: GradientWallpaperManager
    
    let cornerRadius: CGFloat
    let isActive: Bool // Whether to show glassmorphism or default background
    let carouselMode: Bool // Whether this is in carousel mode (iPad)
    
    init(cornerRadius: CGFloat = 8, isActive: Bool = true, carouselMode: Bool = false, gradientManager: GradientWallpaperManager = GradientWallpaperManager.shared) {
        self.cornerRadius = cornerRadius
        self.isActive = isActive
        self.carouselMode = carouselMode
        self.gradientManager = gradientManager
    }
    
    // Check if we should use glassmorphism (when not using default gradients)
    private var shouldUseGlassmorphism: Bool {
        isActive && (colorScheme == .dark ? 
            gradientManager.selectedDarkGradientIndex != 0 :
            gradientManager.selectedLightGradientIndex != 0)
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    // Remove background entirely for iPad carousel mode
                    if carouselMode {
                        Color.clear
                    } else if shouldUseGlassmorphism {
                        // Glassmorphism effect
                        ZStack {
                            // Base blur
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.ultraThinMaterial)
                            
                            // Gradient overlay
                            RoundedRectangle(cornerRadius: cornerRadius)
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
                            // Border
                            RoundedRectangle(cornerRadius: cornerRadius)
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
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
                    }
                }
            )
    }
}

extension View {
    func glassmorphismBackground(cornerRadius: CGFloat = 8, isActive: Bool = true, carouselMode: Bool = false) -> some View {
        self.modifier(GlassmorphismBackground(cornerRadius: cornerRadius, isActive: isActive, carouselMode: carouselMode))
    }
}

// MARK: - Smart Study Preloading Extension
extension MainLayout {
    private func preloadSmartStudy() {
        guard !smartStudyPreloaded else { return }
        
        print("🔄 Preloading Smart Study to avoid first-tap delay...")
        
        // Preload heavy components in background
        Task {
            // Initialize UserLibraryService in background to warm up the service
            let _ = UserLibraryService()
            
            // Preload saved QAs
            if let savedData = UserDefaults.standard.data(forKey: "savedSmartStudyQAs") {
                let _ = try? JSONDecoder().decode([SmartStudyEntry].self, from: savedData)
            }
            
            await MainActor.run {
                smartStudyPreloaded = true
                print("✅ Smart Study preloading completed")
            }
        }
    }
}






