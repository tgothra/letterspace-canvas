import SwiftUI
import Combine
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit // Needed for UIImage for profile picture
#endif

// MARK: - Responsive Sizing Helper
extension View {
    /// Calculate responsive size based on a reference iPad Pro 11" (1194pt width)
    /// This ensures consistent visual appearance across all iPad sizes
    func responsiveSize(base: CGFloat, min: CGFloat? = nil, max: CGFloat? = nil) -> CGFloat {
        let referenceWidth: CGFloat = 1194 // iPad Pro 11" width in points
        let currentWidth = {
            #if os(iOS)
            // Only use responsive sizing on iPad, not iPhone
            if UIDevice.current.userInterfaceIdiom == .pad {
                return UIScreen.main.bounds.width
            } else {
                return CGFloat(1194) // Default reference width for iPhone (no scaling)
            }
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

struct Logo: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Image(colorScheme == .dark ? "Dark 1 - Logo" : "Light 1 - Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 28)
    }
}

struct SidebarPopupCard: View {
    let title: String
    let content: AnyView
    let position: CGPoint
    var onClose: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    var currentFolder: Folder?
    
    private var verticalOffset: CGFloat {
        switch title {
        case "Search Documents": return 20
        case "Create New Document": return -160
        case "View Folders": return -55
        case "Settings": return -140
        default: return -100
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.primary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Content
            content
                .padding(12)
        }
        .frame(width: 240, height: {
            // Set specific height for search popup on macOS
            if title == "Search Documents" {
                return 320
            } else {
                return nil // Use automatic height for other popups
            }
        }())
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.secondary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 2)
        .position(x: position.x + 140, y: position.y + (title == "View Folders" && currentFolder != nil ? 40 : verticalOffset))
        .opacity(isAnimating ? 1 : 0)
        .scaleEffect(isAnimating ? 1 : 0.95, anchor: .topLeading)
        .offset(x: isAnimating ? 0 : -10)
        .blur(radius: isAnimating ? 0 : 4)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
        .zIndex(100) // Ensure popup is above all other elements
    }
}

struct SidebarButton: View {
    let icon: String
    let action: () -> Void
    let tooltip: String
    @Binding var activePopup: ActivePopup
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @Binding var folders: [Folder]
    var onAddFolder: ((Folder, UUID?) -> Void)?
    @State private var isHovering = false
    @State private var isHoveringPopup = false
    @State private var buttonFrame: CGRect = .zero
    @State private var showTemplateBrowser = false
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass // For iPadOS adaptation
    @State private var hoverDebounceTask: Task<Void, Never>?
    @State private var profileImageVersion: UUID = UUID() // Force refresh when image changes
    
    private var shouldShowPopupOnTap: Bool { // For iOS tap behavior
        #if os(iOS)
        return popupType != .none
        #else
        return false // macOS uses hover
        #endif
    }
    
    private var shouldShowPopupOnHover: Bool { // For macOS hover behavior
        #if os(macOS)
        return popupType != .none
        #else
            return false
        #endif
    }
    
    private var popupType: ActivePopup {
        switch icon {
        case "magnifyingglass": return .search
        case "square.and.pencil": return .newDocument
        case "folder": return .folders
        case "person.crop.circle.fill": return .userProfile
        default: return .none
        }
    }
    
    @ViewBuilder
    private func iconView() -> some View {
        if icon == "rectangle.3.group" {
            // Custom layout icon for dashboard - vertical layout
            #if os(macOS)
            // Smaller fixed sizes for macOS to match other icons
            VStack(spacing: 1.5) {
                // Top rectangle (small)
                Rectangle()
                    .fill(theme.primary)
                    .frame(width: 8, height: 4.5)
                    .cornerRadius(1)
                
                // Middle rectangle (largest)
                Rectangle()
                    .fill(theme.primary)
                    .frame(width: 13, height: 5.5)
                    .cornerRadius(1)
                
                // Bottom rectangle (medium)
                Rectangle()
                    .fill(theme.primary)
                    .frame(width: 10, height: 4.5)
                    .cornerRadius(1)
            }
            .frame(width: 14, height: 18)
            #else
            // Responsive sizes for iPad
            VStack(spacing: responsiveSize(base: 2.6, min: 2, max: 3)) {  // Consistent spacing
                // Top rectangle (small)
                Rectangle()
                    .fill(theme.primary)
                    .frame(
                        width: responsiveSize(base: 13, min: 10, max: 16),
                        height: responsiveSize(base: 8, min: 6, max: 10)
                    )
                    .cornerRadius(responsiveSize(base: 2, min: 1.5, max: 2.5))
                
                // Middle rectangle (largest)
                Rectangle()
                    .fill(theme.primary)
                    .frame(
                        width: responsiveSize(base: 21, min: 16, max: 26),
                        height: responsiveSize(base: 9, min: 7, max: 11)
                    )
                    .cornerRadius(responsiveSize(base: 2, min: 1.5, max: 2.5))
                
                // Bottom rectangle (medium)
                Rectangle()
                    .fill(theme.primary)
                    .frame(
                        width: responsiveSize(base: 16, min: 12, max: 20),
                        height: responsiveSize(base: 8, min: 6, max: 10)
                    )
                    .cornerRadius(responsiveSize(base: 2, min: 1.5, max: 2.5))
            }
            .frame(
                width: responsiveSize(base: 24, min: 18, max: 30),
                height: responsiveSize(base: 30, min: 23, max: 38)
            )
            #endif
        } else if icon == "person.crop.circle.fill" {
            // Check if user has a profile image (force refresh with profileImageVersion)
            if let profileImage = UserProfileManager.shared.getProfileImage() { // This now returns PlatformSpecificImage
                PlatformImageView(platformImage: profileImage) // Use PlatformImageView
                    .scaledToFill()
                    .frame(
                        width: responsiveSize(base: 25, min: 20, max: 30),  // Consistent profile image size
                        height: responsiveSize(base: 25, min: 20, max: 30)
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(theme.primary.opacity(0.2), lineWidth: 1)
                    )
                    .scaleEffect(isHovering ? 1.05 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isHovering)
                    .id(profileImageVersion) // Force refresh when profile image changes
        } else {
                // Fallback to default icon
                Image(systemName: icon)
                    .font(.system(size: responsiveSize(base: 14, min: 12, max: 18), weight: .medium))  // Consistent icon size
            }
        } else {
            Image(systemName: icon)
                .font(.system(size: responsiveSize(base: 14, min: 12, max: 18), weight: .medium))  // Consistent icon size
        }
    }
    
    @ViewBuilder
    private func popupContent() -> some View {
        switch icon {
        case "magnifyingglass":
            SearchPopupContent(
                activePopup: $activePopup,
                document: $document,
                sidebarMode: $sidebarMode,
                isRightSidebarVisible: $isRightSidebarVisible
            )
        case "square.and.pencil":
            NewDocumentPopupContent(
                showTemplateBrowser: $showTemplateBrowser,
                activePopup: $activePopup,
                document: $document,
                sidebarMode: $sidebarMode,
                isRightSidebarVisible: $isRightSidebarVisible
            )
        case "folder":
            FoldersPopupContent(
                    activePopup: $activePopup,
                    folders: $folders,
                    document: $document,
                    sidebarMode: $sidebarMode,
                    isRightSidebarVisible: $isRightSidebarVisible,
                onAddFolder: onAddFolder!
            )
        case "person.crop.circle.fill":
            // This will only be used for hovering - modal is handled separately
            EmptyView()
        default:
            EmptyView()
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Button layer
                Button(action: {
                    if shouldShowPopupOnTap { // iOS tap behavior
                        if activePopup == popupType {
                            activePopup = .none // Toggle off
                        } else {
                            activePopup = popupType // Toggle on
                        }
                    } else if !shouldShowPopupOnHover || icon == "person.crop.circle.fill" { // macOS click behavior (if not a hover popup)
                        action()
                    }
                }) {
                    ZStack {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.primary.opacity(isHovering ? 0.1 : 0))
                            .frame(width: 48, height: 48)
                        
                        // Icon
                        iconView()
                            .foregroundStyle(theme.primary)
                    }
                }
                .buttonStyle(.plain)
                .help(tooltip)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .center)  // Center the button within its container
                .onHover { hovering in
                    #if os(macOS) // Keep hover logic only for macOS
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isHovering = hovering
                    }
                    
                    if shouldShowPopupOnHover {
                        // Cancel any existing debounce task
                        hoverDebounceTask?.cancel()
                        
                        // Create new debounce task with shorter delay
                        hoverDebounceTask = Task {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds (reduced from 0.2)
                            if !Task.isCancelled {
                                await MainActor.run {
                                    if hovering {
                                        activePopup = popupType
                                    } else {
                                        // Only close if we're not hovering over the popup
                                        if !isHoveringPopup {
                                            activePopup = .none
                                        }
                                    }
                                }
                            }
                        }
                    }
                    #endif
                }
                .zIndex(1)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileImageDidChange"))) { _ in
                    // Force view to refresh when profile image changes
                    profileImageVersion = UUID()
                }
                #if os(iOS) // iOS uses .popover - attach to Button
                .popover(
                    isPresented: Binding(
                        get: { activePopup == popupType && shouldShowPopupOnTap }, 
                        set: { if !$0 { activePopup = .none } }
                    ), 
                    arrowEdge: Edge.leading
                ) {
                    // Pass the necessary bindings and data to the popup content view
                    VStack(alignment: .leading, spacing: 0) {
                        popupContent()
                            .padding()
                    }
                    .frame(idealWidth: 350, minHeight: 200, maxHeight: 600)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onHover { hovering in
                        isHoveringPopup = hovering
                        if !hovering && !isHovering {
                            // activePopup = .none // This might be too aggressive, manage dismissal carefully
                        }
                    }
                }
                #endif
                
                // Geometry reader for position
                GeometryReader { buttonGeo in
                    Color.clear
                        .onAppear {
                            buttonFrame = buttonGeo.frame(in: .global)
                        }
                        .onChange(of: buttonGeo.frame(in: .global)) { oldFrame, newFrame in
                            buttonFrame = newFrame
                        }
                }
                
                // Popup and bridge layer
                #if os(macOS) // macOS uses the existing ZStack + SidebarPopupCard for hover popups
                if activePopup == popupType && shouldShowPopupOnHover {
                    ZStack {
                        // Invisible bridge to the popup
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 300, height: 400)
                            .contentShape(Rectangle())
                            .position(x: buttonFrame.midX + 130, y: buttonFrame.midY - 100)
                            .allowsHitTesting(true)
                            .onHover { hovering in
                                hoverDebounceTask?.cancel()
                                
                                if hovering {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        isHoveringPopup = true
                                    }
                                } else {
                                    hoverDebounceTask = Task {
                                        try? await Task.sleep(nanoseconds: 25_000_000) // 0.025 seconds (reduced from 0.05)
                                        if !Task.isCancelled {
                                            await MainActor.run {
                                                withAnimation(.easeOut(duration: 0.15)) {
                                                    isHoveringPopup = false
                                                }
                                                // Only close popup if we're not hovering over the button
                                                if !isHovering {
                                                    if activePopup != .organizeDocuments || icon != "folder" {
                                                        activePopup = .none
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .zIndex(99)
                        
                        // Popup card with faster animation
                        SidebarPopupCard(
                            title: tooltip,
                            content: AnyView(popupContent()),
                            position: CGPoint(x: buttonFrame.midX, y: buttonFrame.midY),
                            onClose: { 
                                activePopup = .none
                                isHovering = false
                                isHoveringPopup = false
                            },
                            currentFolder: (popupContent() as? FoldersPopupContent)?.currentFolder
                        )
                        .allowsHitTesting(true)
                        .onHover { hovering in
                            hoverDebounceTask?.cancel()
                            
                            if hovering {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    isHoveringPopup = true
                                }
                            } else {
                                hoverDebounceTask = Task {
                                    try? await Task.sleep(nanoseconds: 25_000_000) // 0.025 seconds (reduced from 0.05)
                                    if !Task.isCancelled {
                                        await MainActor.run {
                                            withAnimation(.easeOut(duration: 0.15)) {
                                                isHoveringPopup = false
                                            }
                                            // Only close popup if we're not hovering over the button
                                            if !isHovering {
                                                if activePopup != .organizeDocuments || icon != "folder" {
                                                    activePopup = .none
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .zIndex(100)
                    }
                }
                #endif
            }
        }
        .frame(width: 48, height: 48)
    }
}

// Helper views for SearchPopupContent
struct SearchHeaderView: View {
    @Binding var activePopup: ActivePopup
    @Environment(\.themeColors) var theme
    
    var body: some View {
        HStack {
            Text("Search Documents")
                .font(.system(size: {
                    #if os(macOS)
                    return 13 // Smaller font for macOS compact design
                    #else
                    return 15 // Larger font for iPad touch-friendly design
                    #endif
                }(), weight: .medium))
                .foregroundStyle(theme.primary)
            Spacer()
        }
        .padding(.horizontal, {
            #if os(macOS)
            return 12 // Tighter padding for macOS
            #else
            return 16 // More spacious padding for iPad
            #endif
        }())
        .padding(.vertical, {
            #if os(macOS)
            return 8 // Smaller vertical padding for macOS
            #else
            return 12 // More padding for iPad
            #endif
        }())
        .background(theme.surface)
    }
}

struct SearchContentView: View {
    @Binding var searchText: String
    @Binding var searchResults: [Letterspace_CanvasDocument]
    @Binding var searchTask: Task<Void, Never>?
    let groupedResults: [(String, [Letterspace_CanvasDocument])]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    let performSearch: () async -> Void
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(spacing: 12) {
            SearchFieldView(searchText: $searchText, searchTask: $searchTask, performSearch: performSearch)
            
            if searchText.isEmpty {
                SearchEmptyStateView()
            } else {
                SearchResultsView(
                    searchText: searchText,
                    searchResults: searchResults,
                    groupedResults: groupedResults,
                    document: $document,
                    sidebarMode: $sidebarMode,
                    activePopup: $activePopup
                )
            }
        }
    }
}

struct SearchFieldView: View {
    @Binding var searchText: String
    @Binding var searchTask: Task<Void, Never>?
    let performSearch: () async -> Void
    @Environment(\.themeColors) var theme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(theme.secondary)
            TextField("Search documents...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onChange(of: searchText) { oldValue, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await performSearch()
                    }
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.background)
        )
    }
}

struct SearchEmptyStateView: View {
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack {
            Text("Type to search through your documents")
                .font(.system(size: 12))
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
            Spacer()
        }
    }
}

struct SearchResultsView: View {
    let searchText: String
    let searchResults: [Letterspace_CanvasDocument]
    let groupedResults: [(String, [Letterspace_CanvasDocument])]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    @Environment(\.themeColors) var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if searchResults.isEmpty {
                    Text("No results found")
                        .font(.custom("InterTight-Regular", size: 13))
                        .foregroundColor(theme.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(groupedResults, id: \.0) { group in
                        SearchResultGroupView(
                            group: group,
                            searchText: searchText,
                            groupedResults: groupedResults,
                            document: $document,
                            sidebarMode: $sidebarMode,
                            activePopup: $activePopup
                        )
                    }
                }
            }
        }
    }
}

struct SearchResultGroupView: View {
    let group: (String, [Letterspace_CanvasDocument])
    let searchText: String
    let groupedResults: [(String, [Letterspace_CanvasDocument])]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            Text(group.0)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 8)
            
            // Results in this category
            ForEach(group.1) { doc in
                SearchResultRowView(
                    doc: doc,
                    group: group,
                    searchText: searchText,
                    document: $document,
                    sidebarMode: $sidebarMode,
                    activePopup: $activePopup
                )
                
                if doc.id != group.1.last?.id {
                    Divider()
                }
            }
            
            if group.0 != groupedResults.last?.0 {
                Divider()
                    .padding(.vertical, 8)
            }
        }
    }
}

struct SearchResultRowView: View {
    let doc: Letterspace_CanvasDocument
    let group: (String, [Letterspace_CanvasDocument])
    let searchText: String
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var activePopup: ActivePopup
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: {
            document = doc
            sidebarMode = .details
            activePopup = .none
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // Document title
                Text(doc.title.isEmpty ? "Untitled" : doc.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.primary)
                
                // Show subtitle for non-content matches
                if !doc.subtitle.isEmpty {
                    Text(doc.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


struct SearchPopupContent: View {
    @State private var searchText = ""
    @State private var searchResults: [Letterspace_CanvasDocument] = []
    @State private var searchTask: Task<Void, Never>?
    @Binding var activePopup: ActivePopup
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @Environment(\.themeColors) var theme
    
    private func getMatchContext(content: String, searchText: String) -> (String, Range<String.Index>?) {
        guard let range = content.range(of: searchText, options: .caseInsensitive) else {
            return (content, nil)
        }
        
        let preContext = content[..<range.lowerBound].suffix(30)
        let postContext = content[range.upperBound...].prefix(30)
        let fullContext = "..." + preContext + content[range] + postContext + "..."
        
        // Calculate the range of the search term in the full context string
        let preContextCount = preContext.count + 3 // +3 for the "..." prefix
        let searchTermStart = fullContext.index(fullContext.startIndex, offsetBy: preContextCount)
        let searchTermEnd = fullContext.index(searchTermStart, offsetBy: content[range].count)
        
        return (fullContext, searchTermStart..<searchTermEnd)
    }
    
    private func performSearch() async {
        print("🔍 Starting search with text: '\(searchText)'")
        
        guard !searchText.isEmpty else {
            print("❌ Search text is empty, clearing results")
            await MainActor.run {
                searchResults = []
            }
            return
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        print("📂 Documents path: \(appDirectory)")
        
        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📄 Found \(fileURLs.count) canvas files")
            
            var results: [Letterspace_CanvasDocument] = []
            
            for url in fileURLs {
                guard !Task.isCancelled else { return }
                
                let fileName = url.lastPathComponent
                print("🔎 Processing file: \(fileName)")
                
                do {
                    let data = try Data(contentsOf: url)
                    if let document = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                        let titleMatch = document.title.localizedCaseInsensitiveContains(searchText)
                        let subtitleMatch = document.subtitle.localizedCaseInsensitiveContains(searchText)
                        let seriesMatch = document.series?.name.localizedCaseInsensitiveContains(searchText) ?? false
                        
                        // Improved content matching
                        var contentMatch = false
                        for element in document.elements {
                            if element.content.localizedCaseInsensitiveContains(searchText) {
                                contentMatch = true
                                break
                            }
                        }
                        
                        if titleMatch || subtitleMatch || seriesMatch || contentMatch {
                            results.append(document)
                        }
                    }
                } catch {
                    print("❌ Error reading document at \(fileName): \(error)")
                    continue
                }
            }
            
            print("🏁 Search complete. Found \(results.count) matches out of \(fileURLs.count) files")
            
            await MainActor.run {
                searchResults = results
            }
        } catch {
            print("❌ Error searching documents: \(error)")
            await MainActor.run {
                searchResults = []
            }
        }
    }
    
    var groupedResults: [(String, [Letterspace_CanvasDocument])] {
        var groups: [(String, [Letterspace_CanvasDocument])] = []
        
        // Group by title/subtitle matches
        let titleMatches = searchResults.filter { doc in
            doc.title.localizedCaseInsensitiveContains(searchText) ||
            doc.subtitle.localizedCaseInsensitiveContains(searchText)
        }
        if !titleMatches.isEmpty {
            groups.append(("Document Names", titleMatches))
        }
        
        // Group by series matches
        let seriesMatches = searchResults.filter { doc in
            doc.series?.name.localizedCaseInsensitiveContains(searchText) ?? false
        }
        if !seriesMatches.isEmpty {
            groups.append(("Sermon Series", seriesMatches))
        }
        
        // Group by content matches
        let contentMatches = searchResults.filter { doc in
            doc.elements.contains { element in
                element.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !contentMatches.isEmpty {
            groups.append(("Document Content", contentMatches))
        }
        
        return groups
    }
    
    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            // Only show header on iPad - macOS uses system popup title
            SearchHeaderView(activePopup: $activePopup)
            
            Divider()
                .foregroundStyle(theme.secondary.opacity(0.2))
            #endif
            
            SearchContentView(
                searchText: $searchText,
                searchResults: $searchResults,
                searchTask: $searchTask,
                groupedResults: groupedResults,
                document: $document,
                sidebarMode: $sidebarMode,
                activePopup: $activePopup,
                performSearch: performSearch
            )
            .padding({
                #if os(macOS)
                return 12 // Tighter padding for macOS compact design
                #else
                return 16 // More spacious padding for iPad
                #endif
            }())
                                    }
    }
    
    private func findFirstMatchingElement(in document: Letterspace_CanvasDocument, searchText: String) -> (content: String, element: DocumentElement)? {
        for element in document.elements {
            if element.content.localizedCaseInsensitiveContains(searchText) {
                return (element.content, element)
            }
        }
        return nil
    }
}

struct NewDocumentPopupContent: View {
    @Environment(\.themeColors) var theme
    @State private var hoveredItem: String?
    @Binding var showTemplateBrowser: Bool
    @Binding var activePopup: ActivePopup
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            // Header - Only show on iPad, macOS uses system popup title
            HStack {
                Text("Create New Document")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, -8)
            .padding(.bottom, 20)
            .background(theme.surface)
            
            Divider()
                .foregroundStyle(theme.secondary.opacity(0.2))
                .offset(y: -8)
            #endif
            
            // Content
        VStack(alignment: .leading, spacing: {
            #if os(macOS)
            return 8 // Tighter spacing for macOS
            #else
            return 12 // More spacious for iPad
            #endif
        }()) {
            Button(action: {
                print("Creating new blank document")
                // Create document with a stable ID
                let docId = UUID().uuidString
                
                // Create new blank document with completely fresh state
                var newDocument = Letterspace_CanvasDocument(
                    title: "Untitled",
                    subtitle: "",
                    // Explicitly create a new empty text element
                    elements: [
                        DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")
                    ],
                    id: docId,
                    // Reset all document properties
                    markers: [],
                    series: nil,
                    variations: [],
                    isVariation: false,
                    parentVariationId: nil,
                    createdAt: Date(),
                    modifiedAt: Date(),
                    tags: nil,
                    isHeaderExpanded: false,  // Explicitly set to false for new documents
                    isSubtitleVisible: true,
                    links: []
                )
                
                // Save the new document first
                newDocument.save()
                
                // Wait a brief moment to ensure file is written
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Open the new document
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)) {
                        document = newDocument
                        sidebarMode = .details
                        isRightSidebarVisible = true
                        activePopup = .none
                    }
                }
            }) {
                HStack {
                    Image(systemName: "doc")
                        .font(.system(size: {
                            #if os(macOS)
                            return 13 // Smaller icon for macOS
                            #else
                            return 15 // Larger icon for iPad
                            #endif
                        }()))
                    Text("Blank Document")
                        .font(.system(size: {
                            #if os(macOS)
                            return 13 // Smaller text for macOS
                            #else
                            return 15 // Larger text for iPad
                            #endif
                        }()))
                }
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, {
                    #if os(macOS)
                    return 6 // Tighter horizontal padding for macOS
                    #else
                    return 8 // More padding for iPad
                    #endif
                }())
                .padding(.vertical, {
                    #if os(macOS)
                    return 6 // Smaller vertical padding for macOS
                    #else
                    return 9 // More padding for iPad touch targets
                    #endif
                }())
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.primary.opacity(hoveredItem == "blank" ? 0.05 : 0))
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered in
                hoveredItem = isHovered ? "blank" : nil
            }
            
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: {
                        #if os(macOS)
                        return 13 // Smaller icon for macOS
                        #else
                        return 15 // Larger icon for iPad
                        #endif
                    }()))
                Text("Templates")
                    .font(.system(size: {
                        #if os(macOS)
                        return 13 // Smaller text for macOS
                        #else
                        return 15 // Larger text for iPad
                        #endif
                    }()))
                Text("(Coming Soon)")
                    .font(.system(size: {
                        #if os(macOS)
                        return 13 // Smaller text for macOS
                        #else
                        return 15 // Larger text for iPad
                        #endif
                    }()))
                    .foregroundStyle(theme.secondary)
            }
            .foregroundStyle(theme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, {
                #if os(macOS)
                return 6 // Tighter horizontal padding for macOS
                #else
                return 8 // More padding for iPad
                #endif
            }())
            .padding(.vertical, {
                #if os(macOS)
                return 4 // Smaller vertical padding for macOS
                #else
                return 6 // More padding for iPad
                #endif
            }())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.primary.opacity(0.05))
            )
        }
            .padding({
                #if os(macOS)
                return 12 // Tighter overall padding for macOS compact design
                #else
                return 16 // More spacious padding for iPad
                #endif
            }())
        }
        .offset(y: -10)
    }
}

struct FoldersPopupContent: View {
    @Environment(\.themeColors) var theme
    @State private var hoveredFolder: String?
    @State var currentFolder: Folder?
    @State private var documents: [Letterspace_CanvasDocument] = []
    @Binding var activePopup: ActivePopup
    @Binding var folders: [Folder]
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @FocusState private var focusedFolderId: UUID?
    var onAddFolder: (Folder, UUID?) -> Void
    
    private var sortedFolders: [Folder] {
        folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var isOrganizeDocumentsActive: Bool {
        activePopup == .organizeDocuments
    }
    
    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            // Header - Only show on iPad, macOS uses system popup title
            HStack {
                Text("Folders")
                    .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(theme.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 12)
            .background(theme.surface)
            
            Divider()
                .foregroundStyle(theme.secondary.opacity(0.2))
            #endif

                        // Breathing room after separator
                    Spacer()
                .frame(height: 6)
                    
            if currentFolder == nil {
                HStack(spacing: 8) {
                    // "Organize" button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            activePopup = .organizeDocuments
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 10))
                            Text("Organize")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(hoveredFolder == "organize" ? theme.accent : theme.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                        .background(theme.secondary.opacity(hoveredFolder == "organize" ? 0 : 0.1))
                        .background(theme.accent.opacity(hoveredFolder == "organize" ? 0.1 : 0))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isOrganizeDocumentsActive)
                    .onHover { isHovered in
                        if !isOrganizeDocumentsActive {
                            hoveredFolder = isHovered ? "organize" : nil
                        }
                    }
                    
                    // "New Folder" button
                        Button(action: {
                            addNewFolder()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 10))
                                Text("New Folder")
                                    .font(.system(size: 11))
                            }
                        .foregroundStyle(hoveredFolder == "newFolder" ? theme.accent : theme.secondary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity)
                            .background(theme.secondary.opacity(hoveredFolder == "newFolder" ? 0 : 0.1))
                            .background(theme.accent.opacity(hoveredFolder == "newFolder" ? 0.1 : 0))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isOrganizeDocumentsActive)
                        .onHover { isHovered in
                            if !isOrganizeDocumentsActive {
                                hoveredFolder = isHovered ? "newFolder" : nil
                            }
                        }
                }
                .padding(.horizontal, {
                    #if os(macOS)
                    return 12 // Tighter horizontal padding for macOS
                    #else
                    return 16 // More spacious padding for iPad
                    #endif
                }())
                .padding(.vertical, {
                    #if os(macOS)
                    return 6 // Smaller vertical padding for macOS
                    #else
                    return 8 // More padding for iPad
                    #endif
                }())
                
                // Breathing room after organize/new folder buttons
                Spacer()
                    .frame(height: 6)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Navigation header
                    if let currentFolder = currentFolder {
                        HStack(spacing: 8) {
                            // Back button and folder name when inside a folder
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    self.currentFolder = nil
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(theme.primary)
                                    .padding(6)
                                    .background(theme.primary.opacity(hoveredFolder == "back" ? 0.05 : 0))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .disabled(isOrganizeDocumentsActive)
                            .onHover { isHovered in
                                if !isOrganizeDocumentsActive {
                                    hoveredFolder = isHovered ? "back" : nil
                                }
                            }
                            
                            Text(currentFolder.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.primary)
                            
                            Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                activePopup = .organizeDocuments
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 10))
                                Text("Organize")
                                    .font(.system(size: 11))
                            }
                                .foregroundStyle(hoveredFolder == "organize_inner" ? theme.accent : theme.secondary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                                .frame(width: 80)
                                .background(theme.secondary.opacity(hoveredFolder == "organize_inner" ? 0 : 0.1))
                                .background(theme.accent.opacity(hoveredFolder == "organize_inner" ? 0.1 : 0))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isOrganizeDocumentsActive)
                        .onHover { isHovered in
                            if !isOrganizeDocumentsActive {
                                    hoveredFolder = isHovered ? "organize_inner" : nil
                    }
                }
            }
            .padding(.horizontal, 12)
                    }
            
            // Content area
                    LazyVStack(spacing: 4) {
                        if let currentFolder = currentFolder {
                            let folderDocs = documents.filter { currentFolder.documentIds.contains($0.id) }
                            let displayedFolders = currentFolder.subfolders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                            
                            if displayedFolders.isEmpty && folderDocs.isEmpty {
                                Text("This folder is empty")
                                    .font(.system(size: 13))
                                    .foregroundStyle(theme.secondary)
                                    .padding()
                            } else {
                                ForEach(displayedFolders) { folder in
                                    SimpleFolderRow(folder: folder, hoveredFolder: $hoveredFolder, folders: $folders, currentFolder: $currentFolder, isOrganizeDocumentsActive: isOrganizeDocumentsActive, theme: theme)
                                }
                                ForEach(folderDocs) { doc in
                                    Text(doc.title)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(theme.primary)
                                        .padding()
                                                            }
                                                        }
                                        } else {
                            // Root folder view
                            ForEach(sortedFolders) { folder in
                                SimpleFolderRow(folder: folder, hoveredFolder: $hoveredFolder, folders: $folders, currentFolder: $currentFolder, isOrganizeDocumentsActive: isOrganizeDocumentsActive, theme: theme)
                                                        }
                        }
                    }
                    .padding(.horizontal, {
                        #if os(macOS)
                        return 10 // Tighter horizontal padding for macOS
                        #else
                        return 12 // More spacious padding for iPad
                        #endif
                    }())
                }
            }
            
                        if currentFolder == nil {
                Spacer()
                    .frame(height: 8)
                                                                
                                                                Divider()
                                                                
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 3)
                    
                                                                                                                                                            HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                                                                    .foregroundStyle(theme.secondary)
                        Text("Deleting folders doesn't delete their documents")
                                            .font(.system(size: 13))
                                                                    .foregroundStyle(theme.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                                            Spacer()
                                        }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .offset(y: 12)
                                    }
                .frame(height: 50)
            }
        }
        .offset(y: -8)
        .frame(height: 380)
        .onAppear(perform: loadDocuments)
        .onChange(of: currentFolder) { _, _ in loadDocuments() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CurrentFolderDidUpdate"))) { notification in
            if let updatedFolder = notification.userInfo?["folder"] as? Folder {
                currentFolder = updatedFolder
            }
        }
    }
    
    private func addNewFolder(parentId: UUID? = nil) {
        let newFolder = Folder(
            id: UUID(),
            name: "New Folder",
            isEditing: true,
            subfolders: [],
            parentId: parentId,
            documentIds: Set<String>()
        )
        onAddFolder(newFolder, parentId)
        focusedFolderId = newFolder.id
    }
    
    private func loadDocuments() {
        print("📂 Loading documents...")
        
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("❌ Could not access documents directory")
            return
        }
        
        print("📂 Loading from directory: \(appDirectory.path)")
        
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try fileManager.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📂 Found \(fileURLs.count) canvas files")
            
            var loadedDocuments: [Letterspace_CanvasDocument] = []
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    if let document = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                        loadedDocuments.append(document)
                        print("📂 Loaded document: \(document.title) (ID: \(document.id))")
                    }
                } catch {
                    print("❌ Error loading document at \(url): \(error)")
                }
            }
            
            documents = loadedDocuments.sorted { $0.title < $1.title }
            print("📂 Loaded \(documents.count) documents total")
            
        } catch {
            print("❌ Error accessing documents directory: \(error)")
        }
    }
}

struct FolderActionButtons: View {
    @Environment(\.themeColors) var theme
    @Binding var hoveredFolder: String?
    var onOrganize: () -> Void
    var onNewFolder: () -> Void

    var body: some View {
                                                            HStack(spacing: 8) {
            Button(action: onOrganize) {
                                                                    HStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 10))
                    Text("Organize")
                                                                            .font(.system(size: 11))
                                                                    }
                .foregroundStyle(hoveredFolder == "organize" ? theme.accent : theme.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .background(theme.secondary.opacity(hoveredFolder == "organize" ? 0 : 0.1))
                .background(theme.accent.opacity(hoveredFolder == "organize" ? 0.1 : 0))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .onHover { isHovered in hoveredFolder = isHovered ? "organize" : nil }
            
            Button(action: onNewFolder) {
                                                                    HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 10))
                    Text("New Folder")
                                                                            .font(.system(size: 11))
                                                                    }
                .foregroundStyle(hoveredFolder == "newFolder" ? theme.accent : theme.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .background(theme.secondary.opacity(hoveredFolder == "newFolder" ? 0 : 0.1))
                .background(theme.accent.opacity(hoveredFolder == "newFolder" ? 0.1 : 0))
                .cornerRadius(4)
                                            }
                                            .buttonStyle(.plain)
            .onHover { isHovered in hoveredFolder = isHovered ? "newFolder" : nil }
        }
    }
}

struct FolderNavigationView: View {
    @Environment(\.themeColors) var theme
    let currentFolder: Folder
    @Binding var hoveredFolder: String?
    var onBack: () -> Void
    var onOrganize: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .onHover { isHovered in hoveredFolder = isHovered ? "back" : nil }
            
            Text(currentFolder.name)
                .font(.system(size: 13, weight: .medium))
            
                                                Spacer()
            
            Button(action: onOrganize) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc.fill").font(.system(size: 10))
                    Text("Organize").font(.system(size: 11))
            }
                                        }
                                        .buttonStyle(.plain)
            .onHover { isHovered in hoveredFolder = isHovered ? "organize" : nil }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct SimpleFolderRow: View {
    let folder: Folder
    @Binding var hoveredFolder: String?
    @Binding var folders: [Folder]
    @Binding var currentFolder: Folder?
    let isOrganizeDocumentsActive: Bool
    let theme: ThemeColors
    
    var body: some View {
                                    Button(action: {
                                        if !isOrganizeDocumentsActive {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                        currentFolder = folders[index]
                }
            }
                                        }
                                    }) {
            HStack(spacing: 8) {
                                            Image(systemName: "folder")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.primary)
                                            Text(folder.name)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(hoveredFolder == folder.id.uuidString ? theme.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { isHovered in
                                            hoveredFolder = isHovered ? folder.id.uuidString : nil
                                        }
    }
}

extension FoldersPopupContent {
    
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
}

struct FolderListView: View {
    @Binding var folders: [Folder]
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Folders header with plus button
            HStack(spacing: 4) {
                Text("Folders")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.primary)
                
                Button(action: {
                    let newFolder = Folder(id: UUID(), name: "New Folder", isEditing: true)
                    folders.append(newFolder)
                    
                    // Save folders to ensure persistence
                    if let encoded = try? JSONEncoder().encode(folders) {
                        UserDefaults.standard.set(encoded, forKey: "SavedFolders")
                        UserDefaults.standard.synchronize()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.bottom, 8)
            
            ForEach($folders) { $folder in
                FolderRowView(folder: $folder, folders: $folders)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct FolderRowView: View {
    @Binding var folder: Folder
    @Binding var folders: [Folder]
    @Environment(\.themeColors) var theme
    @FocusState private var isFocused: Bool
    
    var body: some View {
        if folder.isEditing {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(theme.secondary)
                
                TextField("Folder name", text: $folder.name)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.secondary)
                    .focused($isFocused)
                    .onAppear {
                        isFocused = true
                    }
                    .onSubmit {
                        saveFolderName()
                    }
                    #if os(macOS)
                    .onExitCommand {
                        saveFolderName()
                    }
                    #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        } else {
            ZStack {
                // Delete button that appears on swipe
                HStack {
                    Spacer()
                    Button(action: {
                        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                            folders.remove(at: index)
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 32)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                }
                .opacity(folder.swipeOffset < 0 ? 1 : 0)
                
                // Folder button with swipe gesture
                DocumentFolderButton(title: folder.name, icon: "folder", action: {})
                    .font(.system(size: 14))
                    .offset(x: folder.swipeOffset)
                    .contextMenu {
                        Button(role: .destructive, action: {
                            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                                folders.remove(at: index)
                                
                                // Save to UserDefaults after deletion
                                if let encoded = try? JSONEncoder().encode(folders) {
                                    UserDefaults.standard.set(encoded, forKey: "SavedFolders")
                                    UserDefaults.standard.synchronize()
                                }
                            }
                        }) {
                            Label("Delete Folder", systemImage: "trash")
                        }
                    }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if value.translation.width < 0 {
                            withAnimation(.interactiveSpring()) {
                                folder.swipeOffset = value.translation.width
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width < -30 {
                                // Show delete button fully
                                folder.swipeOffset = -60
                            } else {
                                // Reset position
                                folder.swipeOffset = 0
                            }
                        }
                    }
            )
        }
    }
    
    private func saveFolderName() {
        let finalName = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalName.isEmpty {
            folder.name = "Untitled"
        }
        folder.isEditing = false
        
        // Update the folder in the array
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
        }
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: "SavedFolders")
        }
    }
}

extension Folder {
    var swipeOffset: CGFloat {
        get { UserDefaults.standard.double(forKey: "folder_offset_\(id.uuidString)") }
        set { UserDefaults.standard.set(newValue, forKey: "folder_offset_\(id.uuidString)") }
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
    @State private var searchText = ""
    @State private var searchResults: [Letterspace_CanvasDocument] = []
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFieldFocused: Bool
    @State private var folders: [Folder] = []  // Updated to use Folder from Models
    @State private var activePopup: ActivePopup = .none
    @State private var showRecentlyDeletedModal = false
    @State private var showUserProfileModal = false  // New state variable for user profile modal
    @State private var showSmartStudyModal = false   // New state variable for Smart Study modal
    @State private var showScriptureSearchModal = false // New state variable for Scripture Search modal
    @State private var showBibleReaderModal = false  // New state variable for Bible Reader modal
    @State private var showLeftSidebarSheet: Bool = false // Added missing state variable for iPad sidebar sheet
    @State private var showFoldersModal = false // New state variable for Folders modal
    @State private var showTemplateBrowser = false // New state variable for template browser modal
    
    // Floating sidebar states for iPad/iPhone
    @State private var showFloatingSidebar = {
        #if os(iOS)
        // Always show floating sidebar on iPad, but respect user interaction on iPhone
        return UIDevice.current.userInterfaceIdiom == .pad ? true : false
        #else
        return false
        #endif
    }()
    @State private var sidebarDragAmount = CGSize.zero
    @State private var sidebarOffset: CGFloat = -140 // Start off-screen - updated for new width
    @State private var isManuallyShown = false  // Track when user manually shows navigation
    @State private var isDocked = {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Default to docked on iPad, but respect saved preference if it exists
            return UserDefaults.standard.object(forKey: "sidebarIsDocked") as? Bool ?? true
        } else {
            // Default to floating on iPhone
            return UserDefaults.standard.bool(forKey: "sidebarIsDocked")
        }
        #else
        return UserDefaults.standard.bool(forKey: "sidebarIsDocked")
        #endif
    }()
    @State private var isNavigationCollapsed = {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Default to not collapsed on iPad
            return UserDefaults.standard.object(forKey: "navigationIsCollapsed") as? Bool ?? false
        } else {
            return UserDefaults.standard.bool(forKey: "navigationIsCollapsed")
        }
        #else
        return UserDefaults.standard.bool(forKey: "navigationIsCollapsed")
        #endif
    }()
    
    // Floating contextual toolbar state for iPad
    @State private var isFloatingToolbarCollapsed = {
        UserDefaults.standard.object(forKey: "floatingToolbarIsCollapsed") as? Bool ?? false
    }()
    @State private var toolbarDragAmount: CGSize = .zero
    
    // Gradient wallpaper manager
    @StateObject private var gradientManager = GradientWallpaperManager.shared
    
    let rightSidebarWidth: CGFloat = 240
    let settingsWidth: CGFloat = 220
    let collapsedWidth: CGFloat = 56
    // Responsive floating sidebar width based on iPad screen size
    private var floatingSidebarWidth: CGFloat {
        #if os(iOS)
        let screenWidth = UIScreen.main.bounds.width
        return screenWidth * 0.08 // 8% of screen width for responsive sidebar
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
        .onAppear {
            loadFolders()
            
            // Debug logging for iPad navigation
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                print("🐛 iPad Navigation Debug:")
                print("🐛 isDocked: \(isDocked)")
                print("🐛 isNavigationCollapsed: \(isNavigationCollapsed)")
                print("🐛 viewMode.isDistractionFreeMode: \(viewMode.isDistractionFreeMode)")
                print("🐛 sidebarMode: \(sidebarMode)")
                
                // Force reset navigation state on iPad to ensure sidebar shows
                if isNavigationCollapsed {
                    print("🐛 Force resetting navigation collapsed state")
                    isNavigationCollapsed = false
                    UserDefaults.standard.set(isNavigationCollapsed, forKey: "navigationIsCollapsed")
                }
                
                // Force dock navigation to be visible on iPad
                if !isDocked {
                    print("🐛 Force setting isDocked to true on iPad")
                    isDocked = true
                    UserDefaults.standard.set(isDocked, forKey: "sidebarIsDocked")
                }
                
                // If this is the first time on iPad, default to docked mode
                if UserDefaults.standard.object(forKey: "sidebarIsDocked") == nil {
                    isDocked = true
                    UserDefaults.standard.set(true, forKey: "sidebarIsDocked")
                    print("🐛 Set isDocked to true for first time iPad use")
                }
                // Also ensure navigation is not collapsed by default on iPad
                if UserDefaults.standard.object(forKey: "navigationIsCollapsed") == nil {
                    isNavigationCollapsed = false
                    UserDefaults.standard.set(false, forKey: "navigationIsCollapsed")
                    print("🐛 Set isNavigationCollapsed to false for first time iPad use")
                }
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
        // Apply blur to background content when any modal is shown
        .blur(radius: showUserProfileModal || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal ? 6 : 0)
        .opacity(showUserProfileModal || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: showUserProfileModal || showRecentlyDeletedModal || showSmartStudyModal || showBibleReaderModal || showFoldersModal)
        // Modal overlays (clean, no backdrop)
        .overlay {
                if showUserProfileModal {
                    ZStack {
                        // Dismiss layer
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
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                    ))
                    }
                }
        }
        .overlay {
            if showRecentlyDeletedModal {
                ZStack {
                // Dismiss layer
                Color.clear
                    .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                            showRecentlyDeletedModal = false
                        }
                    }
                
                RecentlyDeletedView(isPresented: $showRecentlyDeletedModal)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                    ))
                }
            }
        }
        .overlay {
                if showSmartStudyModal {
                    ZStack {
                // Dismiss layer
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
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                ))
                    }
            }
        }
        .overlay {
                if showBibleReaderModal {
                    ZStack {
                // Dismiss layer
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
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                ))
                    }
            }
        }
        .overlay {
                if showFoldersModal {
                ZStack {
                // Dismiss layer
                Color.clear
                    .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                                showFoldersModal = false
                        }
                    }
                
                                FoldersView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                                    showFoldersModal = false
                    }
                })
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .center))
                ))
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
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
        floatingSidebarContent
            .frame(width: responsiveSize(base: shouldUseExpandedNavigation ? 105 : 45, min: 40, max: 120))  // Consistent width across devices
            .scaleEffect(shouldUseExpandedNavigation ? 1.1 : 0.85, anchor: .center)  // Scale from center for better collapse animation
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
                            isRightSidebarVisible: $isRightSidebarVisible
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
                            onAddFolder: addFolder
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
                .padding(.top, 16)  // Increased top padding from 8 to 16 for more space above dashboard
                
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
                            .frame(height: 12) // Adjust this value to center the arrow properly
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 0)        // Keep top padding removed to eliminate gap
                .padding(.bottom, 2)     // Further reduced bottom padding from 5 to 2
            }
        }
        // Width is now set by compact/expanded navigation wrappers
        // Dynamic height: moderate height when expanded, content-sized for compact
        .frame(maxHeight: shouldUseExpandedNavigation ? responsiveSize(base: 800, min: 600, max: 900) : .infinity)
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
                                    shouldPauseHover: isSearchActive
                                )
                                .id(document.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
                                    removal: .opacity.combined(with: .scale(scale: 1.05, anchor: .center))
                                ))
                                .animation(.spring(response: 1.8, dampingFraction: 0.85), value: sidebarMode)
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
                // iOS: Show docked sidebar if docked mode is enabled and not collapsed
                // But skip docked sidebar on iPad since we use floating navigation
                if isDocked && !viewMode.isDistractionFreeMode && !isNavigationCollapsed && UIDevice.current.userInterfaceIdiom != .pad {
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
                                // iPad uses floating navigation, so no docked sidebar
                                return isDocked && !viewMode.isDistractionFreeMode && UIDevice.current.userInterfaceIdiom != .pad
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
                     // On iPhone, show the sidebar normally. On iPad, never show it (use floating toolbar instead)
                     if !viewMode.shouldHideSidebars && isRightSidebarVisible && UIDevice.current.userInterfaceIdiom == .phone {
                         rightSidebarContent
                             .frame(width: rightSidebarWidth)
                             .transition(.move(edge: .trailing))
                     }
                     #endif
                }
                .frame(maxWidth: .infinity)
            }
            
            #if os(iOS)
            // iOS: Add floating sidebar overlay (always for iPad, floating mode for iPhone)
            if !viewMode.isDistractionFreeMode && (UIDevice.current.userInterfaceIdiom == .pad || (!isDocked && (showFloatingSidebar || isNavigationCollapsed))) {
                                VStack(alignment: .leading) {
                HStack {
                        // Unified floating navigation with responsive size transitions
                        animatedFloatingNavigation
                            .padding(.leading, {
                                // Center between screen edge and All Documents section
                                let screenWidth = UIScreen.main.bounds.width
                                let allDocumentsLeftEdge = screenWidth * 0.065 // Approximate left edge of All Documents (based on padding)
                                let centerPoint = allDocumentsLeftEdge / 2 // Center between screen edge and All Documents
                                return shouldUseExpandedNavigation ? centerPoint : 20
                            }())
                            .padding(.top, {
                                // Responsive top padding based on screen height 
                                let screenHeight = UIScreen.main.bounds.height
                                return shouldUseExpandedNavigation ? screenHeight * 0.28 : 20 // 28% of screen height when expanded
                            }())
                            .offset(x: (showFloatingSidebar && (shouldShowNavigationPanel || isManuallyShown)) ? 0 : -200) // Hide when viewing documents unless manually shown
                            .animation(.spring(response: showFloatingSidebar ? 0.6 : 2.5, dampingFraction: showFloatingSidebar ? 0.75 : 0.9), value: showFloatingSidebar)
                            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: shouldShowNavigationPanel)
                            .onChange(of: sidebarMode) { newMode in
                                // Automatically show/hide navigation based on mode
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
                
                // Swipe indicator - interactive vertical bar on left edge
                // Show on iPhone when in floating mode, or on iPad when navigation is dismissed
                if (UIDevice.current.userInterfaceIdiom != .pad) || (UIDevice.current.userInterfaceIdiom == .pad && (!showFloatingSidebar || !shouldShowNavigationPanel)) {
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
            
            // iPad swipe indicator when floating navigation is dismissed
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
            if !viewMode.isDistractionFreeMode && isDocked && isNavigationCollapsed && UIDevice.current.userInterfaceIdiom != .pad {
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
            
            // iPad floating contextual toolbar - positioned in gutter area outside document
            if UIDevice.current.userInterfaceIdiom == .pad && sidebarMode != .allDocuments {
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
            if UIDevice.current.userInterfaceIdiom == .pad && sidebarMode != .allDocuments && isFloatingToolbarCollapsed {
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
            
            // Floating Distraction-Free Mode Button - only show when in document mode
            if sidebarMode != .allDocuments {
                VStack {
                    Spacer()
                    HStack {
                                            Spacer()
                    
                    Button(action: {
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
                // On iPhone, show the sidebar normally. On iPad, never show it (use floating toolbar instead)
                if !viewMode.shouldHideSidebars && isRightSidebarVisible && UIDevice.current.userInterfaceIdiom == .phone {
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
                        isRightSidebarVisible: $isRightSidebarVisible
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
                        onAddFolder: addFolder
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

// Floating sidebar button component
struct FloatingSidebarButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isPressed = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var isDragging = false
    @Environment(\.themeColors) var theme
    
    @ViewBuilder
    private func iconView() -> some View {
        if icon == "rectangle.3.group" {
            // Custom layout icon for dashboard - vertical layout
            #if os(macOS)
            // Smaller fixed sizes for macOS to match other icons
            VStack(spacing: 1.5) {
                // Top rectangle (small)
                Rectangle()
                    .fill(theme.primary)
                    .frame(width: 8, height: 4.5)
                    .cornerRadius(1)
                
                // Middle rectangle (largest)
                Rectangle()
                    .fill(theme.primary)
                    .frame(width: 13, height: 5.5)
                    .cornerRadius(1)
                
                // Bottom rectangle (medium)
                Rectangle()
                    .fill(theme.primary)
                    .frame(width: 10, height: 4.5)
                    .cornerRadius(1)
            }
            .frame(width: 14, height: 18)
            #else
            // Responsive sizes for iPad
            VStack(spacing: responsiveSize(base: 2.6, min: 2, max: 3)) {  // Consistent spacing
                // Top rectangle (small)
                Rectangle()
                    .fill(theme.primary)
                    .frame(
                        width: responsiveSize(base: 13, min: 10, max: 16),
                        height: responsiveSize(base: 8, min: 6, max: 10)
                    )
                    .cornerRadius(responsiveSize(base: 2, min: 1.5, max: 2.5))
                
                // Middle rectangle (largest)
                Rectangle()
                    .fill(theme.primary)
                    .frame(
                        width: responsiveSize(base: 21, min: 16, max: 26),
                        height: responsiveSize(base: 9, min: 7, max: 11)
                    )
                    .cornerRadius(responsiveSize(base: 2, min: 1.5, max: 2.5))
                
                // Bottom rectangle (medium)
                Rectangle()
                    .fill(theme.primary)
                    .frame(
                        width: responsiveSize(base: 16, min: 12, max: 20),
                        height: responsiveSize(base: 8, min: 6, max: 10)
                    )
                    .cornerRadius(responsiveSize(base: 2, min: 1.5, max: 2.5))
            }
            .frame(
                width: responsiveSize(base: 24, min: 18, max: 30),
                height: responsiveSize(base: 30, min: 23, max: 38)
            )
            #endif
        } else if icon == "person.crop.circle.fill" {
            // Check if user has a profile image
            if let profileImage = UserProfileManager.shared.getProfileImage() {
                PlatformImageView(platformImage: profileImage)
                    .scaledToFill()
                    .frame(
                        width: responsiveSize(base: 25, min: 20, max: 30),  // Consistent profile image size
                        height: responsiveSize(base: 25, min: 20, max: 30)
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(theme.primary.opacity(0.2), lineWidth: 1)
                    )
            } else {
                // Fallback to default icon
                Image(systemName: icon)
                    .font(.system(size: responsiveSize(base: 26, min: 20, max: 32)))  // Consistent icon size
            }
        } else {
            Image(systemName: icon)
                .font(.system(size: responsiveSize(base: 22, min: 18, max: 28)))  // Smaller icon size
        }
    }
    
    var body: some View {
        let buttonSize: CGFloat = {
            #if os(macOS)
            return 40  // Keep macOS fixed - window-based, not screen-based
            #else
            // Responsive button size based on screen width percentage
            let screenWidth = UIScreen.main.bounds.width
            let calculatedSize = screenWidth * 0.055 // 5.5% of screen width (reduced from 6.5%)
            return max(48, min(72, calculatedSize)) // Constrain between 48-72pt for more compact design
            #endif
        }()
        
        Button(action: {
            // Only trigger action if not dragging
            guard !isDragging else { return }
            
            // Trigger ripple animation
            withAnimation(.easeOut(duration: 0.6)) {
                rippleScale = 2.0
                rippleOpacity = 0.3
            }
            
            
            // Fade out ripple
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                rippleOpacity = 0
            }
            
            // Reset ripple after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                rippleScale = 0
            }
            
            // Execute the actual action
            action()
        }) {
            ZStack {
                // Ripple effect background
                Circle()
                    .fill(theme.accent.opacity(rippleOpacity))
                    .frame(width: buttonSize, height: buttonSize)
                    .scaleEffect(rippleScale)
                    .animation(.easeOut(duration: 0.6), value: rippleScale)
                    .animation(.easeOut(duration: 0.4), value: rippleOpacity)
                
                // Button content
                iconView()
                    .foregroundStyle(theme.primary)
                    .frame(width: buttonSize, height: buttonSize)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    isDragging = true
                    // Reset any pressed state when dragging
                    isPressed = false
                }
                .onEnded { value in
                    // Reset dragging state after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isDragging = false
                    }
                }
        )
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            // Only show pressed state if not dragging
            if !isDragging {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
        }, perform: {
            // Long press action if needed
        })
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
                    // Reset scroll position when sidebar becomes visible
                    scrollOffset.wrappedValue = 0
                }
            }
            .onChange(of: selectedElement.wrappedValue) { _ in
                if selectedElement.wrappedValue != nil {
                    // Reset scroll position when an element is selected
                    scrollOffset.wrappedValue = 0
                }
            }
            .onChange(of: viewMode.wrappedValue) { _ in
                if viewMode.wrappedValue != .normal {
                    // Reset scroll position when view mode changes
                    scrollOffset.wrappedValue = 0
                }
            }
            .onChange(of: isHeaderExpanded.wrappedValue) { _ in
                if isHeaderExpanded.wrappedValue {
                    // Reset scroll position when header is expanded
                    scrollOffset.wrappedValue = 0
                }
            }
            .onChange(of: isSubtitleVisible.wrappedValue) { _ in
                if isSubtitleVisible.wrappedValue {
                    // Reset scroll position when subtitle is visible
                    scrollOffset.wrappedValue = 0
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

// Replace SettingsPopupContent with UserProfilePopupContent
struct UserProfilePopupContent: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Binding var activePopup: ActivePopup // Keep if needed for other logic
    @Binding var isPresented: Bool
    @ObservedObject var gradientManager: GradientWallpaperManager  // Changed from let to @ObservedObject
    @State private var userProfile = UserProfileManager.shared.userProfile
    @State private var isImagePickerPresented = false
    @State private var isImageCropperPresented = false
    #if os(macOS)
    @State private var selectedImageForCropper: NSImage? // Keep NSImage for macOS cropper
    #elseif os(iOS)
    @State private var selectedImageForCropper: UIImage? // Use UIImage for potential iOS cropper/display
    #endif
    @State private var isEditingProfile = false
    @State private var isHoveringClose = false // State for close button hover
    
    var body: some View {
        ZStack {
            // Main profile content
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                        Text("User Profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.primary)
                    
                    Spacer()
                    
                    Button(action: {
                            isPresented = false
                    }) {
                        // Updated close button style
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(isHoveringClose ? Color.red : Color.gray.opacity(0.5)) // Changed hover to solid red
                            )
                    }
                    .buttonStyle(.plain) // Keep plain to remove default button styling
                    .onHover { hovering in
                        isHoveringClose = hovering
                    }
                }
                .padding(.bottom, 8)
                
                // User profile content
                VStack(alignment: .center, spacing: 20) {
                    // Profile image
                    ZStack(alignment: .bottomTrailing) {
                        if let profilePImage = UserProfileManager.shared.getProfileImage() { // Returns PlatformSpecificImage
                            PlatformImageView(platformImage: profilePImage) // Use PlatformImageView
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                                )
                        } else {
                            // Initials avatar if no image
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(userProfile.initials)
                                        .font(.system(size: 36, weight: .medium))
                                        .foregroundStyle(Color.blue)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Edit button
                        Button(action: {
                            isImagePickerPresented = true
                        }) {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "camera.fill")
                    .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    
                    // Rest of the user profile content remains the same
                    // User details
                    if isEditingProfile {
                        // Edit mode
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary)
                
                                TextField("First Name", text: $userProfile.firstName)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                    )
                                    .textFieldStyle(.plain)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                    .font(.system(size: 12))
                                    .foregroundStyle(theme.secondary)
                                
                                TextField("Last Name", text: $userProfile.lastName)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                    )
                                    .textFieldStyle(.plain)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.secondary)
                                
                                TextField("Email", text: $userProfile.email)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                    )
                                    .textFieldStyle(.plain)
                            }
                            
                            HStack {
                                Button("Cancel") {
                                    // Reset to saved values
                                    userProfile = UserProfileManager.shared.userProfile
                                    isEditingProfile = false
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(theme.secondary)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(theme.secondary.opacity(0.1))
                                .cornerRadius(8)
                                
                                Spacer()
                                
                                Button("Save") {
                                    // Save profile changes
                                    UserProfileManager.shared.userProfile = userProfile
                                    isEditingProfile = false
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(theme.accent)
                                .cornerRadius(8)
                            }
                        }
                    } else {
                        // View mode
                        VStack(spacing: 10) {
                            Text(userProfile.fullName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(theme.primary)
                            
                            if !userProfile.email.isEmpty {
                                Text(userProfile.email)
                                    .font(.system(size: 14))
                                    .foregroundStyle(theme.secondary)
                            }
                            
                            Button("Edit Profile") {
                                isEditingProfile = true
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.accent)
                            .padding(.top, 8)
                        }
                    }
                    
                    // REMOVE the Divider and the iCloud Backup section
                    /*
                    Divider()
                        .padding(.vertical, 8)
                    
                    // iCloud Backup (Coming Soon)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("iCloud Backup")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(theme.primary)
                                
                                Text("Coming Soon")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.secondary)
                            }
            
                            Spacer()
                            
                            Toggle("", isOn: .constant(false))
                                .disabled(true)
                        }
                        
                        Text("Enable iCloud backup to safely store your documents and settings in the cloud.")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    */
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Gradient Wallpaper Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wallpaper")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.primary)
                        
                        // Preview Cards Section
                        HStack(spacing: 20) {
                                Spacer()
                            
                            // Light Mode Preview Card
                            VStack(spacing: 8) {
                                Text("Light Mode Preview")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondary)
                                
                                ZStack {
                                    // Full gradient background
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(gradientManager.gradientPresets[gradientManager.selectedLightGradientIndex].lightGradient.asPreviewGradient())
                                        .frame(width: 100, height: 130)
                                    
                                    // Glassmorphism card overlay
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.05)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
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
                                        .frame(width: 75, height: 50)
                                }
                                .id("light-preview-\(gradientManager.selectedLightGradientIndex)")
                                .animation(.easeInOut(duration: 0.3), value: gradientManager.selectedLightGradientIndex)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                                        .frame(width: 100, height: 130)
                                )
                            }
                            
                            // Dark Mode Preview Card
                            VStack(spacing: 8) {
                                Text("Dark Mode Preview")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondary)
                                
                                ZStack {
                                    // Full gradient background
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(gradientManager.gradientPresets[gradientManager.selectedDarkGradientIndex].darkGradient.asPreviewGradient())
                                        .frame(width: 100, height: 130)
                                    
                                    // Glassmorphism card overlay (darker for dark mode)
                            RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.black.opacity(0.2),
                                                            Color.black.opacity(0.05)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.05)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 0.5
                                                )
                                        )
                                        .frame(width: 75, height: 50)
                                }
                                .id("dark-preview-\(gradientManager.selectedDarkGradientIndex)")
                                .animation(.easeInOut(duration: 0.3), value: gradientManager.selectedDarkGradientIndex)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                                        .frame(width: 100, height: 130)
                                )
                            }
                            
                            Spacer()
                        }
                        
                        // Light Mode Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.yellow)
                                Text("Light Mode")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(theme.primary)
                                Spacer()
                                Text("\(gradientManager.selectedLightGradientIndex + 1) of \(gradientManager.gradientPresets.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondary)
                            }
                            
                            // Light mode gradient tiles
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(gradientManager.gradientPresets.enumerated()), id: \.offset) { index, preset in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                        gradientManager.setGradient(
                                            lightIndex: index,
                                            darkIndex: gradientManager.selectedDarkGradientIndex
                                        )
                                    }
                                        }) {
                                            VStack(spacing: 4) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(preset.lightGradient.asTileGradient())
                                                        .frame(width: 70, height: 45)
                                                    
                                                    if gradientManager.selectedLightGradientIndex == index {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.green, lineWidth: 3)
                                                            .frame(width: 70, height: 45)
                                                        
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundColor(.green)
                                                            .background(
                                                                Circle()
                                                                    .fill(.white)
                                                                    .frame(width: 14, height: 14)
                                                            )
                                                            .offset(x: 20, y: -10)
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                                                            .frame(width: 70, height: 45)
                                                    }
                                                }
                                                
                                                Text(preset.name)
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(theme.secondary)
                                                    .multilineTextAlignment(.center)
                                                    .frame(width: 70)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // Dark Mode Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.purple)
                                Text("Dark Mode")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(theme.primary)
                                Spacer()
                                Text("\(gradientManager.selectedDarkGradientIndex + 1) of \(gradientManager.gradientPresets.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondary)
                            }
                            
                            // Dark mode gradient tiles
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(gradientManager.gradientPresets.enumerated()), id: \.offset) { index, preset in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                        gradientManager.setGradient(
                                            lightIndex: gradientManager.selectedLightGradientIndex,
                                            darkIndex: index
                                        )
                                    }
                                        }) {
                                            VStack(spacing: 4) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(preset.darkGradient.asTileGradient())
                                                        .frame(width: 70, height: 45)
                                                    
                                                    if gradientManager.selectedDarkGradientIndex == index {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.green, lineWidth: 3)
                                                            .frame(width: 70, height: 45)
                                                        
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundColor(.green)
                                                            .background(
                                                                Circle()
                                                                    .fill(.white)
                                                                    .frame(width: 14, height: 14)
                                                            )
                                                            .offset(x: 20, y: -10)
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                                                            .frame(width: 70, height: 45)
                                                    }
                                                }
                                                
                                                Text(preset.name)
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(theme.secondary)
                                                    .multilineTextAlignment(.center)
                                                    .frame(width: 70)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // Info text
                        Text("Choose beautiful gradient backgrounds that work with the glassmorphism effects throughout the app.")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondary.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(width: {
                #if os(iOS)
                return UIDevice.current.userInterfaceIdiom == .pad ? 500 : 400
                #else
                return 400 // macOS default
                #endif
            }())  // Responsive width for iPad
            .padding(20)  // Increased padding for modal
            .background(
                Group {
                    #if os(macOS)
                    Color(NSColor.windowBackgroundColor)
                    #elseif os(iOS)
                    Color(UIColor.systemBackground)
                    #endif
                }
            )
            .cornerRadius(12)
        }
        .overlay {
            // Image cropper overlay
            if isImageCropperPresented, let imageToEdit = selectedImageForCropper {
                ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                ImageCropperView(
                    isPresented: $isImageCropperPresented,
                    image: imageToEdit,
                    onSave: { editedImage in
                        UserProfileManager.shared.saveProfileImage(editedImage)
                        userProfile = UserProfileManager.shared.userProfile
                    }
                )
                }
            }
        }
        .fileImporter(
            isPresented: $isImagePickerPresented,
            allowedContentTypes: [UTType.image],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFileURL = try result.get().first else { return }
                
                if selectedFileURL.startAccessingSecurityScopedResource() {
                    defer { selectedFileURL.stopAccessingSecurityScopedResource() }
                    
                    #if os(macOS)
                    if let image = NSImage(contentsOf: selectedFileURL) {
                        selectedImageForCropper = image
                        isImageCropperPresented = true
                    }
                    #elseif os(iOS)
                    if let image = UIImage(contentsOfFile: selectedFileURL.path) {
                        selectedImageForCropper = image
                        isImageCropperPresented = true
                    }
                    #endif
                }
            } catch {
                print("Error selecting image: \(error)")
            }
        }
    }
}

// Add ImageCropperView after the UserProfilePopupContent struct

struct ImageCropperView: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    #if os(macOS)
    let image: NSImage
    let onSave: (NSImage) -> Void
    #elseif os(iOS)
    // If we make cropper cross-platform, image would be UIImage
    // For now, this view might be macOS only due to NSImage specific logic for cropping
    let image: UIImage // Placeholder for iOS path
    let onSave: (UIImage) -> Void // Placeholder for iOS path
    #endif
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    
    // Unique ID for the image view for screenshot identification
    @State private var displayedImageId = UUID()
    
    // Constants
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0
    private let cropSize: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Adjust Profile Image")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("Drag to position and pinch to zoom your image")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
            
            // Image cropper area
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.1) : Color(.sRGB, white: 0.95))
                    .frame(width: 280, height: 280)
                
                // Actual image with gestures - this is what we'll capture
                ZStack {
                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: cropSize, height: cropSize)
                        .clipShape(Circle())
                    #elseif os(iOS)
                    // Placeholder for iOS image display if cropper is made cross-platform
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: cropSize, height: cropSize)
                        .clipShape(Circle())
                    #endif
                }
                .id(displayedImageId) // This helps us identify it for screenshot
                .overlay(
                    Circle()
                        .stroke(theme.accent, lineWidth: 2)
                        .frame(width: cropSize, height: cropSize)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, minScale), maxScale)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                initializeImagePosition(size: CGSize(width: cropSize, height: cropSize))
                            }
                        }
                )
            }
            .frame(height: 300)
            
            Text("Double-tap to reset")
                .font(.system(size: 11))
                .foregroundStyle(theme.secondary)
                .padding(.top, -10)
            
            // Action buttons
            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondary)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.secondary.opacity(0.1))
                .cornerRadius(8)
                
                Button("Save") {
                    saveEditedImage()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.accent)
                .cornerRadius(8)
            }
        }
        .padding(24)
        .frame(width: 340)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
        .onAppear {
            initializeImagePosition(size: CGSize(width: cropSize, height: cropSize))
        }
    }
    
    private func initializeImagePosition(size: CGSize) {
        // Store the frame size
        imageSize = size
        
        // For filling, we want to use the minimum scale that ensures 
        // the smallest dimension covers the circle completely
        let scaleWidth = cropSize / image.size.width
        let scaleHeight = cropSize / image.size.height
        
        // Choose the larger scale to ensure the image fills the circle
        let fillScale = max(scaleWidth, scaleHeight)
        
        // Apply the scale, ensuring it's at least our minimum scale
        // and add 10% additional zoom for better filling
        scale = max(fillScale * 1.1, minScale)
        lastScale = scale
        
        // Center the image
        offset = .zero
        lastOffset = .zero
    }
    
    private func saveEditedImage() {
        // Combining our solutions: correct zoom + fixed Y-axis direction
        #if os(macOS)
        let finalImage = NSImage(size: CGSize(width: cropSize, height: cropSize))
        
        finalImage.lockFocus()
        
        // Apply circular clipping path
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: NSSize(width: cropSize, height: cropSize))).setClip()
        
        // Calculate what portion of the original image is visible
        
        // STEP 1: Calculate initial scale that makes the image fill the circle
        // This is exactly what we do in initializeImagePosition()
        let scaleWidth = cropSize / image.size.width
        let scaleHeight = cropSize / image.size.height
        let initialFillScale = max(scaleWidth, scaleHeight)
        
        // STEP 2: Calculate the visible rectangle at the current zoom level
        // We need to account for the initial fill scale when calculating the viewport
        let effectiveScale = initialFillScale * scale
        let visibleWidth = cropSize / effectiveScale
        let visibleHeight = cropSize / effectiveScale
        
        // STEP 3: Calculate the center point and apply offset
        let centerX = image.size.width / 2
        let centerY = image.size.height / 2
        
        // Apply offsets with correct direction for each axis
        // X: Negative because moving image right means viewing more of the left side
        // Y: Positive because of flipped coordinate system between SwiftUI and NSImage
        let adjustedX = centerX - (offset.width / effectiveScale)
        let adjustedY = centerY + (offset.height / effectiveScale) // Y-FLIPPED!
        
        // STEP 4: Calculate the final source rectangle
        let sourceRect = NSRect(
            x: adjustedX - (visibleWidth / 2),
            y: adjustedY - (visibleHeight / 2),
            width: visibleWidth,
            height: visibleHeight
        )
        
        // STEP 5: Draw the image
        let destRect = NSRect(x: 0, y: 0, width: cropSize, height: cropSize)
        image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
        
        finalImage.unlockFocus()
        
        // Debug information
        print("DEBUG: COMBINED SOLUTION")
        print("DEBUG: Image size: \(image.size.width) x \(image.size.height)")
        print("DEBUG: Initial fill scale: \(initialFillScale)")
        print("DEBUG: User scale: \(scale)")
        print("DEBUG: Effective scale: \(effectiveScale)")
        print("DEBUG: Visible size: \(visibleWidth) x \(visibleHeight)")
        print("DEBUG: User offset: \(offset)")
        print("DEBUG: Adjusted center: \(adjustedX), \(adjustedY)")
        print("DEBUG: Source rect: \(sourceRect)")
        
        // Ensure we handle the cropped image properly before saving
        if let tiffData = finalImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            
            // Create a new NSImage from the JPEG data to ensure it's properly formatted
            if let processedImage = NSImage(data: jpegData) {
                // Save within a dispatched block to avoid immediate UI changes that might cause the app to dismiss
                DispatchQueue.main.async {
                    // Now save it through the manager
                    onSave(processedImage)
                    
                    // Close just the modal/sheet
                    isPresented = false
                    dismiss()
                }
            } else {
                 isPresented = false
                 dismiss()
            }
        } else {
            isPresented = false
            dismiss()
        }
        #elseif os(iOS)
        // iOS save logic for UIImage - potentially just pass back the selected image if no cropper
        // Or implement UIImage cropping here if ImageCropperView becomes cross-platform.
        print("iOS: saveEditedImage called. Cropping logic is macOS specific. Passing back original selected image for now.")
        onSave(image) // image is UIImage here
        isPresented = false
        dismiss()
        #endif
    }
}

// Add this at the end of the file, before the last closing brace

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

// Folders modal view
struct FoldersView: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    let onDismiss: () -> Void
    @State private var folders: [Folder] = []
    @State private var activePopup: ActivePopup = .folders
    @State private var document = Letterspace_CanvasDocument(title: "", subtitle: "", elements: [], id: "", markers: [], series: nil, variations: [], isVariation: false, parentVariationId: nil, createdAt: Date(), modifiedAt: Date(), tags: nil, isHeaderExpanded: false, isSubtitleVisible: true, links: [])
    @State private var sidebarMode: RightSidebar.SidebarMode = .allDocuments
    @State private var isRightSidebarVisible = false
    @State private var isHoveringClose = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Folders")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(isHoveringClose ? Color.red : Color.gray.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringClose = hovering
                }
            }
            .padding(.bottom, 8)
            
            // Folders content
            FoldersPopupContent(
                activePopup: $activePopup,
                folders: $folders,
                document: $document,
                sidebarMode: $sidebarMode,
                isRightSidebarVisible: $isRightSidebarVisible,
                onAddFolder: addFolder
            )
        }
        .frame(width: {
            #if os(iOS)
            return UIDevice.current.userInterfaceIdiom == .pad ? 500 : 400
            #else
            return 400
            #endif
        }())
        .padding(20)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
        .cornerRadius(16)
        .onAppear {
            loadFolders()
        }
    }
    
    private func loadFolders() {
        if let savedData = UserDefaults.standard.data(forKey: "SavedFolders"),
           let decodedFolders = try? JSONDecoder().decode([Folder].self, from: savedData) {
            folders = decodedFolders
        } else {
            folders = [
                Folder(id: UUID(), name: "Sermons", isEditing: false, subfolders: [], documentIds: Set<String>()),
                Folder(id: UUID(), name: "Bible Studies", isEditing: false, subfolders: [], documentIds: Set<String>()),
                Folder(id: UUID(), name: "Notes", isEditing: false, subfolders: [], documentIds: Set<String>()),
                Folder(id: UUID(), name: "Archive", isEditing: false, subfolders: [], documentIds: Set<String>())
            ]
            }
    }
    
    private func addFolder(_ folder: Folder, to parentId: UUID?) {
        folders.append(folder)
        // Save folders
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: "SavedFolders")
            UserDefaults.standard.synchronize()
            }
    }
}

// MARK: - Gradient Wallpaper System

struct GradientPreset {
    let id: String
    let name: String
    let lightGradient: GradientData
    let darkGradient: GradientData
}

// Gradient data structure to store gradient information
struct GradientData {
    let colors: [Color]
    let type: GradientType
    let startPoint: UnitPoint?
    let endPoint: UnitPoint?
    let center: UnitPoint?
    let startRadius: CGFloat?
    let endRadius: CGFloat?
    
    enum GradientType {
        case linear
        case radial
    }
    
    // Create a linear gradient
    static func linear(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> GradientData {
        return GradientData(
            colors: colors,
            type: .linear,
            startPoint: startPoint,
            endPoint: endPoint,
            center: nil,
            startRadius: nil,
            endRadius: nil
        )
    }
    
    // Create a radial gradient
    static func radial(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> GradientData {
        return GradientData(
            colors: colors,
            type: .radial,
            startPoint: nil,
            endPoint: nil,
            center: center,
            startRadius: startRadius,
            endRadius: endRadius
        )
    }
    
    // Convert to actual gradient
    func asGradient() -> AnyShapeStyle {
        switch type {
        case .linear:
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: startPoint ?? .topLeading,
                endPoint: endPoint ?? .bottomTrailing
            ))
        case .radial:
            return AnyShapeStyle(RadialGradient(
                gradient: Gradient(colors: colors),
                center: center ?? .center,
                startRadius: startRadius ?? 0,
                endRadius: endRadius ?? 800
            ))
        }
    }
    
    // Convert to tile-optimized gradient for small previews
    func asTileGradient() -> AnyShapeStyle {
        switch type {
        case .linear:
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: startPoint ?? .topLeading,
                endPoint: endPoint ?? .bottomTrailing
            ))
        case .radial:
            // Use smaller radius for tile previews but respect original startRadius
            return AnyShapeStyle(RadialGradient(
                gradient: Gradient(colors: colors),
                center: center ?? .center,
                startRadius: startRadius ?? 0,
                endRadius: 60  // Much smaller radius for tiles
            ))
        }
    }
    
    // Convert to preview-optimized gradient for preview cards
    func asPreviewGradient() -> AnyShapeStyle {
        switch type {
        case .linear:
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: startPoint ?? .topLeading,
                endPoint: endPoint ?? .bottomTrailing
            ))
        case .radial:
            // Use medium radius for preview cards but respect original startRadius
            return AnyShapeStyle(RadialGradient(
                gradient: Gradient(colors: colors),
                center: center ?? .center,
                startRadius: startRadius ?? 0,
                endRadius: 120  // Medium radius for preview cards
            ))
        }
    }
}

class GradientWallpaperManager: ObservableObject {
    @Published var selectedLightGradientIndex: Int = 0 // Default to first (current system)
    @Published var selectedDarkGradientIndex: Int = 0 // Default to first (current system)
    
    static let shared = GradientWallpaperManager()
    
    let gradientPresets: [GradientPreset] = [
        // Default - Current system colors (unchanged)
        GradientPreset(
            id: "default",
            name: "Default",
            lightGradient: .linear(
                colors: [Color.white, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            darkGradient: .linear(
                colors: [Color(red: 0.11, green: 0.11, blue: 0.12), Color(red: 0.11, green: 0.11, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        
        // Coral Sunset - Coral → dusty pink → lavender → light fade
        GradientPreset(
            id: "coral_sunset",
            name: "Coral Sunset",
            lightGradient: .radial(
                colors: [
                    Color(red: 1.0, green: 0.5, blue: 0.3),     // Coral center
                    Color(red: 0.9, green: 0.5, blue: 0.6),     // Dusty pink
                    Color(red: 0.7, green: 0.6, blue: 0.9),     // Lavender
                    Color(red: 0.9, green: 0.9, blue: 0.95),    // Light fade
                    Color(red: 0.98, green: 0.98, blue: 1.0)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.8, green: 0.3, blue: 0.2),     // Deep coral center
                    Color(red: 0.6, green: 0.3, blue: 0.4),     // Dark dusty pink
                    Color(red: 0.4, green: 0.3, blue: 0.6),     // Dark lavender
                    Color(red: 0.15, green: 0.15, blue: 0.2),   // Dark fade
                    Color(red: 0.05, green: 0.05, blue: 0.1)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Ocean Mist - Teal → ocean blue → powder blue → light fade
        GradientPreset(
            id: "ocean_mist",
            name: "Ocean Mist",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.6, blue: 0.6),     // Teal center
                    Color(red: 0.2, green: 0.5, blue: 0.8),     // Ocean blue
                    Color(red: 0.6, green: 0.8, blue: 0.9),     // Powder blue
                    Color(red: 0.9, green: 0.95, blue: 0.98),   // Light fade
                    Color(red: 0.98, green: 1.0, blue: 1.0)     // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.4, blue: 0.4),     // Deep teal center
                    Color(red: 0.1, green: 0.3, blue: 0.5),     // Dark ocean blue
                    Color(red: 0.2, green: 0.4, blue: 0.5),     // Dark powder blue
                    Color(red: 0.1, green: 0.15, blue: 0.2),    // Dark fade
                    Color(red: 0.05, green: 0.1, blue: 0.15)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Purple Dream - Purple → lavender → pale lavender → light fade
        GradientPreset(
            id: "purple_dream",
            name: "Purple Dream",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.6, green: 0.2, blue: 0.8),     // Purple center
                    Color(red: 0.7, green: 0.5, blue: 0.9),     // Lavender
                    Color(red: 0.85, green: 0.8, blue: 0.95),   // Pale lavender
                    Color(red: 0.95, green: 0.9, blue: 1.0),    // Light fade
                    Color(red: 0.98, green: 0.98, blue: 1.0)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.4, green: 0.1, blue: 0.6),     // Deep purple center
                    Color(red: 0.3, green: 0.2, blue: 0.5),     // Dark lavender
                    Color(red: 0.25, green: 0.2, blue: 0.35),   // Dark pale lavender
                    Color(red: 0.15, green: 0.1, blue: 0.2),    // Dark fade
                    Color(red: 0.1, green: 0.05, blue: 0.15)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Forest Glow - Blue-teal → aqua → yellow → light fade
        GradientPreset(
            id: "forest_glow",
            name: "Lemonade",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.66, blue: 0.77),   // Blue-teal center (#01A8C4)
                    Color(red: 0.4, green: 0.8, blue: 0.85),    // Aqua transition
                    Color(red: 0.98, green: 1.0, blue: 0.5),    // Yellow (#FBFE7F)
                    Color(red: 0.99, green: 1.0, blue: 0.85),   // Light fade
                    Color(red: 1.0, green: 1.0, blue: 0.95)     // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.5, blue: 0.6),     // Rich teal center
                    Color(red: 0.2, green: 0.6, blue: 0.7),     // Brighter aqua transition
                    Color(red: 0.8, green: 0.8, blue: 0.4),     // Softer golden yellow
                    Color(red: 0.25, green: 0.25, blue: 0.25),  // Neutral grey fade
                    Color(red: 0.12, green: 0.12, blue: 0.12)   // Dark grey edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Rose Gold - Redesigned with warm metallic rose gold aesthetic
        GradientPreset(
            id: "rose_gold",
            name: "Rose Gold",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.95, green: 0.76, blue: 0.76),  // Soft rose gold center
                    Color(red: 0.97, green: 0.85, blue: 0.73),  // Warm champagne
                    Color(red: 0.92, green: 0.88, blue: 0.82),  // Creamy pearl
                    Color(red: 0.96, green: 0.94, blue: 0.92),  // Soft ivory
                    Color(red: 0.99, green: 0.98, blue: 0.97)   // Whisper white
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.6, green: 0.35, blue: 0.4),    // Rich rose center
                    Color(red: 0.58, green: 0.45, blue: 0.38),  // Refined bronze (less burnt)
                    Color(red: 0.5, green: 0.35, blue: 0.4),    // Warm blush pink
                    Color(red: 0.3, green: 0.22, blue: 0.28),   // Deep blush mauve
                    Color(red: 0.18, green: 0.14, blue: 0.17)   // Very deep mauve
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Sky Blush - Sky blue → blush → peach → light fade
        GradientPreset(
            id: "sky_blush",
            name: "Sky Blush",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.5, green: 0.8, blue: 1.0),     // Sky blue center
                    Color(red: 0.9, green: 0.7, blue: 0.8),     // Blush
                    Color(red: 1.0, green: 0.8, blue: 0.7),     // Peach
                    Color(red: 0.98, green: 0.95, blue: 0.95),  // Light fade
                    Color(red: 1.0, green: 0.98, blue: 0.98)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.3, green: 0.5, blue: 0.7),     // Richer sky blue center
                    Color(red: 0.5, green: 0.4, blue: 0.5),     // Enhanced blush
                    Color(red: 0.6, green: 0.4, blue: 0.3),     // Warmer peach
                    Color(red: 0.2, green: 0.15, blue: 0.3),    // Deep dark purple fade
                    Color(red: 0.1, green: 0.08, blue: 0.18)    // Very deep purple edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Lavender Mist - Lavender → dusty lavender → cream → light fade
        GradientPreset(
            id: "lavender_mist",
            name: "Lavender Mist",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.7, green: 0.6, blue: 0.9),     // Lavender center
                    Color(red: 0.8, green: 0.7, blue: 0.85),    // Dusty lavender
                    Color(red: 0.95, green: 0.93, blue: 0.9),   // Cream
                    Color(red: 0.98, green: 0.97, blue: 0.95),  // Light fade
                    Color(red: 1.0, green: 0.99, blue: 0.98)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.3, green: 0.2, blue: 0.5),     // Deep lavender center
                    Color(red: 0.25, green: 0.2, blue: 0.3),    // Dark dusty lavender
                    Color(red: 0.2, green: 0.18, blue: 0.15),   // Dark cream
                    Color(red: 0.12, green: 0.11, blue: 0.1),   // Dark fade
                    Color(red: 0.08, green: 0.07, blue: 0.06)   // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Mint Frost - Mint → frost → pearl → light fade
        GradientPreset(
            id: "mint_frost",
            name: "Mint Frost",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.6, green: 0.9, blue: 0.8),     // Mint center
                    Color(red: 0.8, green: 0.9, blue: 0.95),    // Frost
                    Color(red: 0.95, green: 0.97, blue: 0.98),  // Pearl
                    Color(red: 0.98, green: 0.99, blue: 0.99),  // Light fade
                    Color(red: 1.0, green: 1.0, blue: 1.0)      // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.2, green: 0.4, blue: 0.35),    // Deep mint center
                    Color(red: 0.15, green: 0.25, blue: 0.3),   // Dark frost
                    Color(red: 0.12, green: 0.18, blue: 0.2),   // Dark pearl
                    Color(red: 0.08, green: 0.12, blue: 0.15),  // Dark fade
                    Color(red: 0.05, green: 0.08, blue: 0.1)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Soft Amber - Amber → dusty rose → powder blue → light fade (original)
        GradientPreset(
            id: "soft_amber",
            name: "Soft Amber",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.9, green: 0.7, blue: 0.4),     // Amber center
                    Color(red: 0.8, green: 0.6, blue: 0.6),     // Dusty rose
                    Color(red: 0.7, green: 0.8, blue: 0.9),     // Powder blue
                    Color(red: 0.9, green: 0.95, blue: 0.98),   // Light fade
                    Color(red: 0.98, green: 1.0, blue: 1.0)     // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.5, green: 0.3, blue: 0.1),     // Deep amber center
                    Color(red: 0.4, green: 0.25, blue: 0.25),   // Dark dusty rose
                    Color(red: 0.2, green: 0.3, blue: 0.4),     // Dark powder blue
                    Color(red: 0.1, green: 0.15, blue: 0.2),    // Dark fade
                    Color(red: 0.05, green: 0.1, blue: 0.15)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Coral Blush - Peach → bright pink → soft transitions
        GradientPreset(
            id: "coral_blush",
            name: "Coral Blush",
            lightGradient: .radial(
                colors: [
                    Color(red: 1.0, green: 0.83, blue: 0.635),   // Peach center (#FFD4A2)
                    Color(red: 0.996, green: 0.4, blue: 0.5),    // Pink transition
                    Color(red: 0.996, green: 0.2, blue: 0.349),  // Bright pink (#FE0159)
                    Color(red: 0.98, green: 0.85, blue: 0.9),    // Light pink fade
                    Color(red: 0.99, green: 0.95, blue: 0.97)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.7, green: 0.4, blue: 0.35),     // Deep coral center
                    Color(red: 0.6, green: 0.25, blue: 0.3),     // Dark pink transition
                    Color(red: 0.5, green: 0.1, blue: 0.2),      // Deep pink
                    Color(red: 0.25, green: 0.15, blue: 0.18),   // Dark fade
                    Color(red: 0.15, green: 0.1, blue: 0.12)     // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Purple Magic - Deep purple → magenta pink → soft transitions
        GradientPreset(
            id: "purple_magic",
            name: "Purple Magic",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.408, green: 0.176, blue: 0.549), // Deep purple center (#682D8C)
                    Color(red: 0.65, green: 0.3, blue: 0.6),      // Purple transition
                    Color(red: 0.922, green: 0.4, blue: 0.6),     // Magenta pink (#EB1E79)
                    Color(red: 0.95, green: 0.8, blue: 0.9),      // Light fade
                    Color(red: 0.98, green: 0.9, blue: 0.95)      // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.3, green: 0.12, blue: 0.4),      // Deeper purple center
                    Color(red: 0.4, green: 0.15, blue: 0.35),     // Dark purple transition
                    Color(red: 0.5, green: 0.2, blue: 0.3),       // Dark magenta
                    Color(red: 0.25, green: 0.15, blue: 0.2),     // Dark fade
                    Color(red: 0.15, green: 0.1, blue: 0.13)      // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Sunset Fire - Red → orange → yellow → warm transitions
        GradientPreset(
            id: "sunset_fire",
            name: "Sunset Fire",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.929, green: 0.11, blue: 0.141),  // Red center (#ED1C24)
                    Color(red: 0.95, green: 0.4, blue: 0.1),      // Orange transition
                    Color(red: 0.988, green: 0.8, blue: 0.2),     // Yellow transition
                    Color(red: 0.988, green: 0.925, blue: 0.4),   // Bright yellow (#FCEC21)
                    Color(red: 0.99, green: 0.97, blue: 0.85)     // Light yellow edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.6, green: 0.08, blue: 0.1),      // Deep red center
                    Color(red: 0.5, green: 0.2, blue: 0.05),      // Dark orange transition
                    Color(red: 0.4, green: 0.3, blue: 0.1),       // Dark yellow
                    Color(red: 0.2, green: 0.15, blue: 0.05),     // Dark fade
                    Color(red: 0.12, green: 0.1, blue: 0.05)      // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Ocean Breeze - Deep blue → cyan → aqua transitions
        GradientPreset(
            id: "ocean_breeze",
            name: "Ocean Breeze",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.18, green: 0.2, blue: 0.576),    // Deep blue center (#2E3393)
                    Color(red: 0.15, green: 0.5, blue: 0.7),      // Blue transition
                    Color(red: 0.1, green: 0.8, blue: 0.9),       // Cyan transition
                    Color(red: 0.4, green: 0.95, blue: 0.988),    // Bright cyan (#1CFAFC)
                    Color(red: 0.85, green: 0.98, blue: 1.0)      // Very light cyan edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.12, green: 0.15, blue: 0.4),     // Deep blue center
                    Color(red: 0.1, green: 0.25, blue: 0.35),     // Dark blue transition
                    Color(red: 0.08, green: 0.3, blue: 0.4),      // Dark cyan
                    Color(red: 0.1, green: 0.2, blue: 0.25),      // Dark fade
                    Color(red: 0.05, green: 0.12, blue: 0.15)     // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Deep Ocean - Very dark blue → medium blue → navy transitions
        GradientPreset(
            id: "deep_ocean",
            name: "Deep Ocean",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.016, blue: 0.157),   // Very dark blue center (#000428)
                    Color(red: 0.0, green: 0.15, blue: 0.35),     // Navy transition
                    Color(red: 0.0, green: 0.306, blue: 0.573),   // Medium blue (#004E92)
                    Color(red: 0.4, green: 0.6, blue: 0.8),       // Light blue fade
                    Color(red: 0.85, green: 0.9, blue: 0.95)      // Very light blue edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.01, blue: 0.12),     // Very deep blue center
                    Color(red: 0.0, green: 0.08, blue: 0.2),      // Deep navy transition
                    Color(red: 0.0, green: 0.15, blue: 0.3),      // Navy blue
                    Color(red: 0.05, green: 0.1, blue: 0.18),     // Dark fade
                    Color(red: 0.02, green: 0.05, blue: 0.1)      // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        )
    ]
    
    private init() {
        loadSettings()
    }
    
    func getCurrentGradient(for colorScheme: ColorScheme) -> AnyShapeStyle {
        if colorScheme == .dark {
            return gradientPresets[selectedDarkGradientIndex].darkGradient.asGradient()
        } else {
            return gradientPresets[selectedLightGradientIndex].lightGradient.asGradient()
        }
    }
    
    func setGradient(lightIndex: Int, darkIndex: Int) {
        selectedLightGradientIndex = min(max(lightIndex, 0), gradientPresets.count - 1)
        selectedDarkGradientIndex = min(max(darkIndex, 0), gradientPresets.count - 1)
        saveSettings()
    }
    
    private func loadSettings() {
        selectedLightGradientIndex = UserDefaults.standard.integer(forKey: "selectedLightGradientIndex")
        selectedDarkGradientIndex = UserDefaults.standard.integer(forKey: "selectedDarkGradientIndex")
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedLightGradientIndex, forKey: "selectedLightGradientIndex")
        UserDefaults.standard.set(selectedDarkGradientIndex, forKey: "selectedDarkGradientIndex")
        UserDefaults.standard.synchronize()
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



