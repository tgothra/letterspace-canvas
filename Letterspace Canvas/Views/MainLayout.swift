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

public enum ActivePopup {
    case none
    case search
    case newDocument
    case folders
    case userProfile
    case recentlyDeleted
    case organizeDocuments  // New case for document organization
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
    @State private var isHoveringPopup = false
    @State private var documentsExpanded = true
    @State private var viewMode: ViewMode = .normal
    @State private var isHeaderExpanded: Bool = false
    @State private var selectedElement: UUID? = nil
    @State private var sidebarMode: RightSidebar.SidebarMode = .allDocuments
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass // For iPadOS adaptation
    @State private var isDarkMode = UserDefaults.standard.bool(forKey: "prefersDarkMode")
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
    @State private var showScriptureSearchModal = false // New state variable for Scripture Search modal
    @State private var showBibleReaderModal = false  // New state variable for Bible Reader modal
    @State private var showLeftSidebarSheet: Bool = false // Added missing state variable for iPad sidebar sheet
    @State private var showFoldersModal = false // New state variable for Folders modal
    @State private var showTemplateBrowser = false // New state variable for template browser modal
    @State private var showExportModal = false // New state variable for Export modal
    @State private var showSettingsModal = false // New state variable for Settings modal
    @State private var showSearchModal = false // New state variable for Search modal on iPhone
    
    // Floating sidebar states for iPad/iPhone
    @State private var showFloatingSidebar = {
        #if os(iOS)
        // Show floating sidebar on iPad only (iPhone uses circular menu)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }()
    @State private var sidebarDragAmount = CGSize.zero
    @State private var sidebarOffset: CGFloat = -140 // Start off-screen - updated for new width
    @State private var isManuallyShown = false  // Track when user manually shows navigation
    @State private var isDocked = {
        #if os(iOS)
        // Default to docked on both iPad and iPhone (iPhone now uses iPad interface)
        return UserDefaults.standard.object(forKey: "sidebarIsDocked") as? Bool ?? true
        #else
        return UserDefaults.standard.bool(forKey: "sidebarIsDocked")
        #endif
    }()
    @State private var isNavigationCollapsed = {
        #if os(iOS)
        // Default to not collapsed on both iPad and iPhone (iPhone now uses iPad interface)
        return UserDefaults.standard.object(forKey: "navigationIsCollapsed") as? Bool ?? false
        #else
                    return UserDefaults.standard.object(forKey: "navigationIsCollapsed") as? Bool ?? false
        #endif
    }()
    
    // Floating contextual toolbar state for iPad
    @State private var isFloatingToolbarCollapsed = {
        UserDefaults.standard.object(forKey: "floatingToolbarIsCollapsed") as? Bool ?? false
    }()
    @State private var toolbarDragAmount: CGSize = .zero
    
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
    
    // Gradient wallpaper manager
    @StateObject private var gradientManager = GradientWallpaperManager.shared
    
    let rightSidebarWidth: CGFloat = 240
    let settingsWidth: CGFloat = 220
    let collapsedWidth: CGFloat = 56
    // Responsive floating sidebar width based on iPad screen size
    private var floatingSidebarWidth: CGFloat {
        #if os(iOS)
        let screenWidth = UIScreen.main.bounds.width
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if isPhone {
            return screenWidth * 0.06 // 6% of screen width for iPhone (more compact)
        } else {
            return screenWidth * 0.08 // 8% of screen width for iPad (existing)
        }
        #else
        return 80 // Fixed width for macOS
        #endif
    }
    
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
        content
            .sheet(isPresented: $showBibleReaderModal) {
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
            .sheet(isPresented: $showSmartStudyModal) {
                SmartStudyView(onDismiss: {
                    showSmartStudyModal = false
                })
                .presentationBackground(.ultraThinMaterial)
            }

            .sheet(isPresented: $showRecentlyDeletedModal) {
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
                loadFolders()
                
                // Preload haptic feedback generators to eliminate first-tap delays
                HapticFeedback.prepareAll()
                
                // Preload user profile asynchronously
                Task.detached(priority: .background) {
                    _ = UserProfileManager.shared.userProfile
                }
                
                // UserLibraryService will be initialized lazily when needed
                
                // Preload Smart Study specifically for iPhone to eliminate keyboard delay
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Task.detached(priority: .background) {
                        print("🔄 Additional Smart Study preloading...")
                        
                        // Force creation of key Smart Study objects
                        let _ = UserLibraryService()
                        let _ = TokenUsageService.shared
                        
                        // Preload UserDefaults access patterns
                        _ = UserDefaults.standard.data(forKey: "savedSmartStudyQAs")
                        _ = UserDefaults.standard.bool(forKey: "Letterspace_FirstClickHandled")
                        
                        print("✅ Additional Smart Study preloading complete")
                    }
                }
                #endif
                
                // Preload folder data in background
                Task.detached(priority: .background) {
                    // Pre-load folder data from UserDefaults to warm up the cache
                    if let _ = UserDefaults.standard.data(forKey: "SavedFolders") {
                        // Just accessing it loads it into memory cache
                    }
                }
                
                // Preload modal views to eliminate first-time delays on iPhone
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    // Comprehensive iPhone sheet preloading - eliminate ALL cold start delays
                    Task.detached(priority: .utility) {
                        print("🔄 Starting comprehensive iPhone sheet preloading...")
                        
                        // 1. Bible Reader preloading
                        Task.detached(priority: .utility) {
                            // Preload Bible reader UserDefaults with correct keys
                            _ = UserDefaults.standard.data(forKey: "bible_reader_bookmarks")
                            _ = UserDefaults.standard.dictionary(forKey: "bible_reader_last_read")
                            
                            // Force BibleReaderData creation to warm up the system
                            let _ = BibleReaderData()
                            
                            print("📖 Bible Reader preloaded")
                        }
                        
                        // 2. Folders View preloading  
                        Task.detached(priority: .utility) {
                            // Preload folder data structure with correct keys
                            _ = UserDefaults.standard.data(forKey: "SavedFolders")
                            _ = UserDefaults.standard.data(forKey: "FolderDocuments")
                            
                            // Pre-warm document cache patterns
                            let _ = DocumentCacheManager.shared
                            
                            print("📁 Folders View preloaded")
                        }
                        
                        // 3. Search View preloading
                        Task.detached(priority: .utility) {
                            // Pre-warm document directory access and cache document list
                            if let appDir = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                                let _ = try? FileManager.default.contentsOfDirectory(at: appDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                                    .filter { $0.pathExtension == "canvas" }
                                
                                // Pre-cache a few recent documents to warm up JSON decoder
                                let recentFiles = (try? FileManager.default.contentsOfDirectory(at: appDir, includingPropertiesForKeys: [.contentModificationDateKey]))?.filter { $0.pathExtension == "canvas" }.prefix(3)
                                
                                for file in recentFiles ?? [] {
                                    guard let data = try? Data(contentsOf: file),
                                          let _ = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) else { continue }
                                    // Just loading to warm up decoder pipeline
                                }
                            }
                            
                            print("🔍 Search View preloaded with document cache warming")
                        }
                        
                        // 4. Recently Deleted preloading
                        Task.detached(priority: .utility) {
                            // Recently Deleted doesn't seem to use persistent storage currently
                            // Pre-warm document directory and general UserDefaults patterns
                            _ = UserDefaults.standard.array(forKey: "PinnedDocuments")
                            _ = UserDefaults.standard.array(forKey: "WIPDocuments")
                            _ = UserDefaults.standard.array(forKey: "CalendarDocuments")
                            
                            print("🗑️ Recently Deleted preloaded")
                        }
                        
                        // 5. General sheet infrastructure preloading
                        Task.detached(priority: .utility) {
                            // Pre-warm UI components frequently used in sheets
                            await MainActor.run {
                                // Create minimal throwaway views to warm up SwiftUI's sheet system
                                let _ = AnyView(Text(""))
                                let _ = NavigationView { EmptyView() }
                                let _ = VStack { EmptyView() }
                                let _ = ScrollView { EmptyView() }
                                let _ = HStack { EmptyView() }
                            }
                            
                            // Pre-warm common UserDefaults access patterns
                            _ = UserDefaults.standard.array(forKey: "VisibleColumns")
                            _ = UserDefaults.standard.integer(forKey: "SelectedCarouselIndex")
                            _ = UserDefaults.standard.data(forKey: "savedSmartStudyQAs")
                            
                            print("🏗️ Sheet infrastructure preloaded")
                        }
                        
                        // 6. Aggressive view system preloading (iPhone-specific)
                        Task.detached(priority: .utility) {
                            // Delay this slightly to not conflict with initial app load
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            
                            await MainActor.run {
                                // Pre-instantiate minimal versions of sheet views to warm up view system
                                // This forces SwiftUI to cache view rendering pipelines
                                
                                // Bible Reader warm-up
                                let _ = VStack {
                                    Text("Genesis")
                                    Text("Chapter 1")
                                    ScrollView(.vertical) {
                                        Text("In the beginning...")
                                    }
                                }.frame(width: 1, height: 1).opacity(0)
                                
                                // Folders warm-up
                                let _ = NavigationView {
                                    List {
                                        Text("Sermons")
                                        Text("Bible Studies")
                                    }
                                }.frame(width: 1, height: 1).opacity(0)
                                
                                // Search warm-up
                                let _ = VStack {
                                    TextField("Search", text: .constant(""))
                                    List {
                                        Text("Search Result")
                                    }
                                }.frame(width: 1, height: 1).opacity(0)
                                
                                print("📱 Aggressive iPhone view preloading complete")
                            }
                        }
                        
                        print("✅ Comprehensive iPhone sheet preloading complete")
                    }
                }
                #endif
                
                // Global folder data preloading for all platforms
                Task.detached(priority: .background) {
                    // Pre-load folder data from UserDefaults to warm up the cache
                    if let _ = UserDefaults.standard.data(forKey: "SavedFolders") {
                        // Just accessing it loads it into memory cache
                    }
                }
                
                // Preload Smart Study after a short delay to avoid first-tap freeze
                if !smartStudyPreloaded {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        preloadSmartStudy()
                    }
                }
                
                // Debug logging for iOS navigation (both iPad and iPhone now use iPad interface)
                #if os(iOS)
                // Apply iPad-style navigation setup to both iPad and iPhone
                print("🐛 iOS Navigation Debug (iPad interface for both iPad and iPhone):")
                print("🐛 isDocked: \(isDocked)")
                print("🐛 isNavigationCollapsed: \(isNavigationCollapsed)")
                print("🐛 viewMode.isDistractionFreeMode: \(viewMode.isDistractionFreeMode)")
                print("🐛 sidebarMode: \(sidebarMode)")
                
                // Force reset navigation state to ensure sidebar shows
                if isNavigationCollapsed {
                    print("🐛 Force resetting navigation collapsed state")
                    isNavigationCollapsed = false
                    UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                }
                
                // Force dock navigation to be visible
                if !isDocked {
                    print("🐛 Force setting isDocked to true")
                    isDocked = true
                    UserDefaults.standard.set(isDocked, forKey: "sidebarIsDocked")
                }
                
                // If this is the first time, default to docked mode
                if UserDefaults.standard.object(forKey: "sidebarIsDocked") == nil {
                    isDocked = true
                    UserDefaults.standard.set(true, forKey: "sidebarIsDocked")
                    print("🐛 Set isDocked to true for first time use")
                }
                // Also ensure navigation is not collapsed by default
                if UserDefaults.standard.object(forKey: "navigationIsCollapsed") == nil {
                    isNavigationCollapsed = false
                    UserDefaults.standard.set(false, forKey: "navigationIsCollapsed")
                    print("🐛 Set isNavigationCollapsed to false for first time use")
                }
                #endif
            }
            .onChange(of: sidebarMode) { _ in
                // If switching to the dashboard view, refresh document list
                if sidebarMode == .allDocuments {
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
                            BibleReaderView(onDismiss: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showBibleReaderModal = false
                                }
                            })
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
                                searchFieldFocused = true; 
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
                                                    icon: isDarkMode ? "sun.max.fill" : "moon.fill",
                                                    action: {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                    transitionOpacity = 0; 
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        isDarkMode.toggle(); 
                                        UserDefaults.standard.set(isDarkMode, forKey: "prefersDarkMode")
                                        UserDefaults.standard.synchronize()
                                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                                    transitionOpacity = 1
                                                                }
                                                            }
                                }; 
                                if horizontalSizeClass == .compact { showLeftSidebarSheet = false }
                            },
                            tooltip: "Toggle Dark Mode", activePopup: $activePopup, document: $document,
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
                                withAnimation(.easeInOut(duration: 0.2)) {
                                                        showUserProfileModal = true
                                }
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

    // New Left Sidebar for iPad using List
    @ViewBuilder
    private var leftSidebarContentForPad: some View {
        List {
            Section(header: Text("Actions").font(.caption).foregroundColor(.secondary)) {
                NavigationLink(destination: EmptyView()) {
                    Label("Dashboard", systemImage: "rectangle.3.group")
                        .font(.system(size: 16))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    sidebarMode = .allDocuments
                    isRightSidebarVisible = false
                    viewMode = .normal
                })
                
                NavigationLink(destination: EmptyView()) {
                    Label("Search Documents", systemImage: "magnifyingglass")
                        .font(.system(size: 16))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    searchFieldFocused = true
                })
                
                NavigationLink(destination: EmptyView()) {
                    Label("Create New Document", systemImage: "square.and.pencil")
                        .font(.system(size: 16))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    let docId = UUID().uuidString
                    var d = Letterspace_CanvasDocument(title: "Untitled", subtitle: "", elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], id: docId, markers: [], series: nil, variations: [],isVariation: false, parentVariationId: nil, createdAt: Date(), modifiedAt: Date(), tags: nil, isHeaderExpanded: false, isSubtitleVisible: true, links: [])
                    d.save()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        document = d
                        sidebarMode = .details
                        isRightSidebarVisible = true
                        activePopup = .none
                    }
                })
                
                NavigationLink(destination: EmptyView()) {
                    Label("Folders", systemImage: "folder")
                        .font(.system(size: 16))
                }
                
                NavigationLink(destination: EmptyView()) {
                    Label("Smart Study", systemImage: "sparkles")
                        .font(.system(size: 16))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSmartStudyModal = true
                    }
                })
                
                NavigationLink(destination: EmptyView()) {
                    Label("Bible Reader", systemImage: "book.closed")
                        .font(.system(size: 16))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBibleReaderModal = true
                    }
                })
                

            }
            .headerProminence(.increased)

            Section(header: Text("Settings").font(.caption).foregroundColor(.secondary)) {
                NavigationLink(destination: EmptyView()) {
                    Label("Toggle Dark Mode", systemImage: isDarkMode ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 16))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        transitionOpacity = 0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            isDarkMode.toggle()
                            UserDefaults.standard.set(isDarkMode, forKey: "prefersDarkMode")
                            UserDefaults.standard.synchronize()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                transitionOpacity = 1
                            }
                        }
                    }
                })
                
                NavigationLink(destination: EmptyView()) {
                    Label("Recently Deleted", systemImage: "trash")
                        .font(.system(size: 16))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRecentlyDeletedModal = true
                    }
                })
                
                NavigationLink(destination: EmptyView()) {
                    Label("User Profile", systemImage: "person.crop.circle.fill")
                        .font(.system(size: 16))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showUserProfileModal = true
                    }
                })
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
    
    // Compact floating navigation for document mode (current implementation)
    @ViewBuilder
    private var compactFloatingNavigation: some View {
        floatingSidebarContent
            .frame(width: 45)  // Ultra-compact for document mode
            .scaleEffect(0.85)  // Additional scale reduction for minimal footprint
    }
    
    // Expanded floating navigation for dashboard mode
    @ViewBuilder
    private var expandedFloatingNavigation: some View {
        floatingSidebarContent
            .frame(width: floatingSidebarWidth)  // Use responsive sidebar width
            .scaleEffect(1.1)   // Subtle but noticeable scaling for dashboard
    }
    
    // Animated floating navigation that smoothly transitions between compact and expanded states
    @ViewBuilder
    private var animatedFloatingNavigation: some View {
        #if os(iOS)
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        let isLandscape = screenWidth > screenHeight
        #else
        let screenHeight: CGFloat = 900 // Default for macOS
        let screenWidth: CGFloat = 1200 // Default for macOS
        let isLandscape = true // macOS is typically landscape
        #endif
        
        floatingSidebarContent
            .frame(width: {
                #if os(iOS)
                if isLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                    // Wider width in iPad landscape for better visibility
                    return responsiveSize(base: shouldUseExpandedNavigation ? 100 : 50, min: 45, max: 110) // Increased from 85/40 to 100/50
                } else {
                    // Original width for portrait and other devices
                    return responsiveSize(base: shouldUseExpandedNavigation ? 105 : 45, min: 40, max: 120)
                }
                #else
                // macOS default width
                return responsiveSize(base: shouldUseExpandedNavigation ? 105 : 45, min: 40, max: 120)
                #endif
            }())
            .scaleEffect({
                #if os(iOS)
                if isLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                    // Smaller scale in iPad landscape - further reduced for more compact appearance
                    return shouldUseExpandedNavigation ? 0.8 : 0.65 // Reduced from 0.9/0.75 to 0.8/0.65
                } else {
                    // Original scale for portrait and other devices
                    return shouldUseExpandedNavigation ? 1.1 : 0.85
                }
                #else
                // macOS default scale
                return shouldUseExpandedNavigation ? 1.1 : 0.85
                #endif
            }(), anchor: .center)  // Scale from center for better collapse animation
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: shouldUseExpandedNavigation)
            .animation(.spring(response: 1.8, dampingFraction: 0.85), value: sidebarMode)  // Slower transition for dashboard to document
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: navigationCornerRadius)  // Animate corner radius changes
    }

    // Floating sidebar for iOS with glassmorphism
    @ViewBuilder
    private var floatingSidebarContent: some View {
        VStack(alignment: .center, spacing: 0) {
            // Removed header section - no spacers or extra content
            
            VStack(spacing: shouldUseExpandedNavigation ? 4 : 2) {  // Minimal spacing between sections 
                // Top buttons section
                VStack(spacing: shouldUseExpandedNavigation ? 3 : 2) {  // Minimal spacing between buttons
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
                        .frame(width: 320, height: 200)
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
                        .frame(width: 320, height: 420)
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
                        icon: isDarkMode ? "sun.max.fill" : "moon.fill",
                        title: "Toggle Dark Mode",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                transitionOpacity = 0
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    isDarkMode.toggle()
                                    UserDefaults.standard.set(isDarkMode, forKey: "prefersDarkMode")
                                    UserDefaults.standard.synchronize()
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
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showUserProfileModal = true
                            }
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
                        .onChange(of: currentBottomNavIndex) { newIndex in
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
                searchFieldFocused = true
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFoldersModal = true
                }
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
                            .fill(isSelected ? theme.accent : theme.primary)
                            .frame(width: 8, height: 3)
                            .cornerRadius(0.5)
                        Rectangle()
                            .fill(isSelected ? theme.accent : theme.primary)
                            .frame(width: 12, height: 4)
                            .cornerRadius(0.5)
                        Rectangle()
                            .fill(isSelected ? theme.accent : theme.primary)
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

// Extracted Main Content View (original content)
@ViewBuilder
private func mainContentView(availableWidth: CGFloat) -> some View {
                            if sidebarMode == .allDocuments {
                                    DashboardView(
                document: $document, // Pass document binding
                onSelectDocument: { selectedDoc in
                                            self.loadAndOpenDocument(id: selectedDoc.id)
                                        },
                showFloatingSidebar: $showFloatingSidebar, // Pass floating sidebar state
                floatingSidebarWidth: floatingSidebarWidth, // Pass floating sidebar width
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
                                        // Navigate back to dashboard on swipe with smooth slide animation
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            sidebarMode = .allDocuments
                                            isRightSidebarVisible = false
                                            viewMode = .normal
                                        }
                                    }
                                )
                                .id(document.id)
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .trailing)
                                ))
                                .animation(.easeOut(duration: 0.3), value: sidebarMode)
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
                        .background(colorScheme == .light ? Color.white : Color.clear)
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
            // iOS: Add floating sidebar overlay for iPad only (iPhone uses bottom navigation)
            if !viewMode.isDistractionFreeMode && UIDevice.current.userInterfaceIdiom == .pad {
                                VStack(alignment: .leading) {
                HStack {
                        // Unified floating navigation with responsive size transitions
                        animatedFloatingNavigation
                            .padding(.leading, {
                                // Center between screen edge and All Documents section
                                let screenWidth = UIScreen.main.bounds.width
                                let allDocumentsLeftEdge = screenWidth * 0.065 // Approximate left edge of All Documents (based on padding)
                                let centerPoint = allDocumentsLeftEdge / 2 // Center between screen edge and All Documents
                                
                                #if os(iOS)
                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                if isPhone {
                                    // iPhone: Add more breathing room from left edge
                                    return shouldUseExpandedNavigation ? centerPoint + 8 : 20
                                } else {
                                    // iPad: Keep original positioning
                                    return shouldUseExpandedNavigation ? centerPoint : 20
                                }
                                #else
                                return shouldUseExpandedNavigation ? centerPoint : 20
                                #endif
                            }())
                            .padding(.top, {
                                // Responsive top padding based on screen height and orientation
                                let screenHeight = UIScreen.main.bounds.height
                                let screenWidth = UIScreen.main.bounds.width
                                let isLandscape = screenWidth > screenHeight
                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                
                                if shouldUseExpandedNavigation {
                                    if isLandscape && UIDevice.current.userInterfaceIdiom == .pad {
                                        // In iPad landscape, move navigation lower
                                        return screenHeight * 0.14 + 35 // Adjusted to 14% + 35 for optimal positioning
                                    } else if isLandscape {
                                        // Other landscape devices
                                        return screenHeight * 0.05 + 10 // Original landscape value
                                    } else if isPhone {
                                        // iPhone portrait mode - positioned lower for better visual balance
                                        return screenHeight * 0.26 + 40 // 26% + 40pt for iPhone (brought down from 22% + 35pt)
                                    } else {
                                        // iPad portrait mode - keep original calculation
                                        return screenHeight * 0.28 // 28% of screen height when expanded for iPad
                                    }
                                } else {
                                    return 20 // Compact mode
                                }
                            }())
                            .offset(x: (showFloatingSidebar && (shouldShowNavigationPanel || isManuallyShown)) ? 0 : -200) // Hide when viewing documents unless manually shown
                            .animation(.spring(response: showFloatingSidebar ? 0.6 : 2.5, dampingFraction: showFloatingSidebar ? 0.75 : 0.9), value: showFloatingSidebar)
                            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: shouldShowNavigationPanel)
                            .onChange(of: sidebarMode) { newMode in
                                // Automatically show/hide navigation based on mode (iPad only)
                                #if os(iOS)
                                if UIDevice.current.userInterfaceIdiom == .pad {
                                if newMode == .allDocuments {
                                    showFloatingSidebar = true  // Show when going to dashboard
                                    isManuallyShown = false  // Reset manual flag when auto-showing
                                } else {
                                    showFloatingSidebar = false // Hide when going to document mode
                                    isManuallyShown = false  // Reset manual flag when auto-hiding
                                }
                                }
                                #else
                                // macOS behavior
                                if newMode == .allDocuments {
                                    showFloatingSidebar = true
                                    isManuallyShown = false
                                } else {
                                    showFloatingSidebar = false
                                    isManuallyShown = false
                                }
                                #endif
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
                
                // Swipe indicator - interactive vertical bar on left edge
                // Show on iPad only when navigation is dismissed (iPhone uses circular menu)
                if UIDevice.current.userInterfaceIdiom == .pad && (!showFloatingSidebar || !shouldShowNavigationPanel) {
                VStack {
                    Spacer()
                    HStack {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: 3, height: 60)
                            .padding(.leading, 8)
                            .scaleEffect(sidebarDragAmount.width > 0 ? 1.2 : 1.0) // Visual feedback when dragging
                            .opacity((showFloatingSidebar && (shouldShowNavigationPanel || isManuallyShown)) ? 0.0 : 1.0) // Fade away when sidebar is open (auto or manual)
                            .animation(.easeOut(duration: 0.1), value: sidebarDragAmount.width)
                            .animation(.easeInOut(duration: 0.3), value: showFloatingSidebar) // Smooth fade animation
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
                .allowsHitTesting(true) // Allow interaction with the indicator
                
                    // Invisible gesture area for swiping from left edge
                    // Show on iPhone when in floating mode, or on iPad when navigation is dismissed
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
            }
            
            // iPhone: Bottom Navigation Bar - Disabled (using circular menu instead)
            // if UIDevice.current.userInterfaceIdiom == .phone {
            //     iPhoneBottomNavigation
            //         .zIndex(99) // Below floating sidebar but above content
            // }
            
            // Swipe indicator when floating navigation is dismissed (iPad only)
            if UIDevice.current.userInterfaceIdiom == .pad && !viewMode.isDistractionFreeMode && (!showFloatingSidebar || (!shouldShowNavigationPanel && !isManuallyShown)) {
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
            
            // Floating contextual toolbar for both iPad and iPhone - positioned in gutter area outside document
            if (UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .phone) && sidebarMode != .allDocuments {
                HStack {
                    Spacer()
                    
                    // Position in gutter between document and screen edge
                    FloatingContextualToolbar(
                        document: $document,
                        sidebarMode: .constant(.details),
                        isRightSidebarVisible: .constant(false),
                        isCollapsed: $isFloatingToolbarCollapsed,
                        dragAmount: $toolbarDragAmount,
                        isDistractionFreeMode: viewMode.isDistractionFreeMode
                    )
                    .padding(.trailing, isFloatingToolbarCollapsed ? 8 : 24) // Closer to edge when collapsed
                }
            }
            
            // Add swipe gesture area for showing collapsed toolbar
            if (UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .phone) && sidebarMode != .allDocuments && isFloatingToolbarCollapsed {
                HStack {
                    Spacer()
                    
                    // Invisible gesture area for swiping from right edge
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.width < 0 {
                                        // Slow down the manual drag by applying a damping factor
                                        toolbarDragAmount = CGSize(
                                            width: value.translation.width * 0.4, // 40% of actual drag distance
                                            height: value.translation.height
                                        )
                                    }
                                }
                                .onEnded { value in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        toolbarDragAmount = .zero
                                        // Swipe left to show toolbar (using original translation for threshold)
                                        if value.translation.width < -50 {
                                            isFloatingToolbarCollapsed = false
                                            UserDefaults.standard.set(false, forKey: "floatingToolbarIsCollapsed")
                                        }
                                    }
                                }
                        )
                }
                .ignoresSafeArea()
            }
            #endif
            }
            // Apply blur to main content area when any modal is shown
            .blur(radius: showUserProfileModal || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal || showExportModal || showSettingsModal || showSearchModal || isCircularMenuOpen ? 4 : 0)
            .opacity(showUserProfileModal || showRecentlyDeletedModal || showSmartStudyModal || showFoldersModal || showExportModal || showSettingsModal || showSearchModal || isCircularMenuOpen ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: showUserProfileModal || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal || showExportModal || showSettingsModal || showSearchModal || isCircularMenuOpen)
            
            // Floating Action Buttons (iPhone only)
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            // Show distraction-free button when in document mode (top position)
                            if sidebarMode != .allDocuments {
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
                            
                            // Circular Menu Button (bottom position) - hidden in distraction-free mode
                            if !viewMode.isDistractionFreeMode {
                                CircularMenuButton(isMenuOpen: $isCircularMenuOpen)
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
            
            // Circular Menu Overlay (iPhone only)
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                CircularMenuOverlay(
                    isMenuOpen: $isCircularMenuOpen,
                    onDashboard: {
                        sidebarMode = .allDocuments
                        isRightSidebarVisible = false
                        viewMode = .normal
                    },
                    onSearch: {
                        #if os(iOS)
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            showSearchModal = true
                        } else {
                            searchFieldFocused = true
                        }
                        #else
                        searchFieldFocused = true
                        #endif
                    },
                    onNewDocument: {
                        // Create new document directly for iPhone (same logic as floating sidebar)
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
                            // No need to show right sidebar on iPhone
                        }
                    },
                    onFolders: {
                        showFoldersModal = true
                    },
                    onBibleReader: {
                        showBibleReaderModal = true
                    },
                    onSmartStudy: {
                        // Small delay to prevent gesture conflicts
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            showSmartStudyModal = true
                        }
                    },
                    onRecentlyDeleted: {
                        showRecentlyDeletedModal = true
                    },
                    onSettings: {
                        showUserProfileModal = true
                    }
                )
            }
            #endif
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
                // Disable right sidebar for both iPhone and iPad since they both use floating toolbar
                if false { // Disabled: Both iPad and iPhone use floating toolbar instead
                    rightSidebarContent
                        .frame(width: rightSidebarWidth)
                        .transition(.move(edge: .trailing))
                }
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
                
                // Force UserDefaults to save immediately
                UserDefaults.standard.synchronize()
                
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
                    .frame(width: 320, height: 420)
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
                    icon: isDarkMode ? "sun.max.fill" : "moon.fill",
                    title: "Toggle Dark Mode",
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            transitionOpacity = 0
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                isDarkMode.toggle()
                                UserDefaults.standard.set(isDarkMode, forKey: "prefersDarkMode")
                                UserDefaults.standard.synchronize()
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
            .onChange(of: isVisible.wrappedValue) { _ in
                if isVisible.wrappedValue {
                    // Animate scroll position reset when sidebar becomes visible
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollOffset.wrappedValue = 0
                    }
                }
            }
            .onChange(of: selectedElement.wrappedValue) { _ in
                if selectedElement.wrappedValue != nil {
                    // Animate scroll position reset when an element is selected
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollOffset.wrappedValue = 0
                    }
                }
            }
            .onChange(of: viewMode.wrappedValue) { _ in
                // Animate scroll position reset when view mode changes
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    scrollOffset.wrappedValue = 0
                }
            }
            .onChange(of: isHeaderExpanded.wrappedValue) { _ in
                if isHeaderExpanded.wrappedValue {
                    // Animate scroll position reset when header is expanded
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollOffset.wrappedValue = 0
                    }
                }
            }
            .onChange(of: isSubtitleVisible.wrappedValue) { _ in
                if isSubtitleVisible.wrappedValue {
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
            .onChange(of: isShowing) { _ in
                if !isShowing {
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
    @ObservedObject var gradientManager: GradientWallpaperManager
    
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





