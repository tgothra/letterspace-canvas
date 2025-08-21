import SwiftUI

#if os(iOS)
import UIKit
#endif

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
        case "Search Documents": return 100 // Adjusted to +100 for better vertical positioning
        case "Create New Document": return -130
        case "Folders": return -35 // Positioned higher above the button
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
        .frame(width: {
            // Match search and folders popup sizes
            if title == "Search Documents" || title == "Folders" {
                return 400 // Both search and folders use 400px width
            } else if title == "Create New Document" {
                return 300 // Balanced width for New Document
            } else {
                return 240
            }
        }(), height: {
            // Match search and folders popup heights
            if title == "Search Documents" || title == "Folders" {
                return 500 // Both search and folders use 500px height
            } else if title == "Create New Document" {
                return 190 // Increased height to accommodate header + content
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
        .position(x: {
            // Adjust horizontal positioning based on popup type
            if title == "Search Documents" || title == "Folders" {
                // Consistent horizontal positioning for search and folders popups
                return position.x + 215 // Both use 215px offset for optimal positioning
            } else if title == "Create New Document" {
                return position.x + 165 // Custom positioning for new document popup
            } else {
                return position.x + 140 // Keep original positioning for other popups
            }
        }(), y: position.y + (title == "Folders" && currentFolder != nil ? 40 : verticalOffset))
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
        #if os(macOS)
        .background(
            // Invisible background that captures scroll events
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Capture taps to prevent them from going through
                }
                .gesture(
                    DragGesture()
                        .onChanged { _ in
                            // Capture scroll gestures to prevent them from going through
                        }
                )
        )
        #endif
 
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
    @State private var isDocumentSelectionActive = false // Track if document selection sheet is open
    
    // Added state to observe screen width dynamically (for iOS 16+ compliance)
    #if os(iOS)
    @State private var observedScreenWidth: CGFloat = 0
    #endif
    
    // Computed property for screen width
    private var screenWidth: CGFloat {
        #if os(iOS)
        return observedScreenWidth > 0 ? observedScreenWidth : UIScreen.main.bounds.width
        #else
        return 1194 // Default width for macOS
        #endif
    }
    
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
                    .fill(.primary)
                    .frame(width: 8, height: 4.5)
                    .cornerRadius(1)
                
                // Middle rectangle (largest)
                Rectangle()
                    .fill(.primary)
                    .frame(width: 13, height: 5.5)
                    .cornerRadius(1)
                
                // Bottom rectangle (medium)
                Rectangle()
                    .fill(.primary)
                    .frame(width: 10, height: 4.5)
                    .cornerRadius(1)
            }
            .frame(width: 14, height: 18)
            #else
            // Responsive sizes for iPad
            VStack(spacing: responsiveSize(base: 2.6, width: screenWidth, min: 2, max: 3)) {  // Consistent spacing
                // Top rectangle (small)
                Rectangle()
                    .fill(.primary)
                    .frame(
                        width: responsiveSize(base: 13, width: screenWidth, min: 10, max: 16),
                        height: responsiveSize(base: 8, width: screenWidth, min: 6, max: 10)
                    )
                    .cornerRadius(responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5))
                
                // Middle rectangle (largest)
                Rectangle()
                    .fill(.primary)
                    .frame(
                        width: responsiveSize(base: 21, width: screenWidth, min: 16, max: 26),
                        height: responsiveSize(base: 9, width: screenWidth, min: 7, max: 11)
                    )
                    .cornerRadius(responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5))
                
                // Bottom rectangle (medium)
                Rectangle()
                    .fill(.primary)
                    .frame(
                        width: responsiveSize(base: 16, width: screenWidth, min: 12, max: 20),
                        height: responsiveSize(base: 8, width: screenWidth, min: 6, max: 10)
                    )
                    .cornerRadius(responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5))
            }
            .frame(
                width: responsiveSize(base: 24, width: screenWidth, min: 18, max: 30),
                height: responsiveSize(base: 30, width: screenWidth, min: 23, max: 38)
            )
            #endif
        } else if icon == "person.crop.circle.fill" {
            // Check if user has a profile image (force refresh with profileImageVersion)
            if let profileImage = UserProfileManager.shared.getProfileImage() { // This now returns PlatformSpecificImage
                PlatformImageView(platformImage: profileImage) // Use PlatformImageView
                    .scaledToFill()
                    .frame(
                        width: responsiveSize(base: 25, width: screenWidth, min: 20, max: 30),  // Consistent profile image size
                        height: responsiveSize(base: 25, width: screenWidth, min: 20, max: 30)
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
                    .font(.system(size: responsiveSize(base: 14, width: screenWidth, min: 12, max: 18), weight: .medium))  // Consistent icon size
            }
        } else {
            Image(systemName: icon)
                .font(.system(size: responsiveSize(base: 14, width: screenWidth, min: 12, max: 18), weight: .medium))  // Consistent icon size
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
            .onAppear {
                // Disable document scroll monitoring when search popup appears
                NotificationCenter.default.post(name: NSNotification.Name("DisableDocumentScrollMonitor"), object: nil)
            }
            .onDisappear {
                // Re-enable document scroll monitoring when search popup disappears
                NotificationCenter.default.post(name: NSNotification.Name("EnableDocumentScrollMonitor"), object: nil)
            }
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
                onAddFolder: onAddFolder!,
                showHeader: true // Show header for popover
            )
            .onAppear {
                // Disable document scroll monitoring when folders popup appears
                NotificationCenter.default.post(name: NSNotification.Name("DisableDocumentScrollMonitor"), object: nil)
            }
            .onDisappear {
                // Re-enable document scroll monitoring when folders popup disappears
                NotificationCenter.default.post(name: NSNotification.Name("EnableDocumentScrollMonitor"), object: nil)
            }
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
                                        // Only close if we're not hovering over the popup AND document selection is not active
                                        if !isHoveringPopup && !isDocumentSelectionActive {
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
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentSelectionSheetOpened"))) { _ in
                    isDocumentSelectionActive = true
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentSelectionSheetClosed"))) { _ in
                    isDocumentSelectionActive = false
                }
                #if os(iOS)
                .background(ScreenWidthReader(screenWidth: $observedScreenWidth))
                #endif
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
                    .frame(idealWidth: 400, minHeight: 200, maxHeight: 700)
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
                                                // Only close popup if we're not hovering over the button AND document selection is not active
                                                if !isHovering && !isDocumentSelectionActive {
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
                                                                        // Only close popup if we're not hovering over the button AND document selection is not active
                            if !isHovering && !isDocumentSelectionActive {
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
    
    // Added state to observe screen width dynamically (for iOS 16+ compliance)
    #if os(iOS)
    @State private var observedScreenWidth: CGFloat = 0
    #endif
    
    // Computed property for screen width
    private var screenWidth: CGFloat {
        #if os(iOS)
        return observedScreenWidth > 0 ? observedScreenWidth : UIScreen.main.bounds.width
        #else
        return 1194 // Default width for macOS
        #endif
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
                    .fill(.primary)
                    .frame(width: 8, height: 4.5)
                    .cornerRadius(1)
                
                // Middle rectangle (largest)
                Rectangle()
                    .fill(.primary)
                    .frame(width: 13, height: 5.5)
                    .cornerRadius(1)
                
                // Bottom rectangle (medium)
                Rectangle()
                    .fill(.primary)
                    .frame(width: 10, height: 4.5)
                    .cornerRadius(1)
            }
            .frame(width: 14, height: 18)
            #else
            // Responsive sizes for iPad and iPhone
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            if isPhone {
                // Smaller dashboard icon for iPhone
                VStack(spacing: responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5)) {  // Tighter spacing
                    // Top rectangle (small)
                    Rectangle()
                        .fill(.primary)
                        .frame(
                            width: responsiveSize(base: 10, width: screenWidth, min: 8, max: 12),
                            height: responsiveSize(base: 6, width: screenWidth, min: 5, max: 7)
                        )
                        .cornerRadius(responsiveSize(base: 1.5, width: screenWidth, min: 1, max: 2))
                    
                    // Middle rectangle (largest)
                    Rectangle()
                        .fill(.primary)
                        .frame(
                            width: responsiveSize(base: 16, width: screenWidth, min: 12, max: 20),
                            height: responsiveSize(base: 7, width: screenWidth, min: 6, max: 8)
                        )
                        .cornerRadius(responsiveSize(base: 1.5, width: screenWidth, min: 1, max: 2))
                    
                    // Bottom rectangle (medium)
                    Rectangle()
                        .fill(.primary)
                        .frame(
                            width: responsiveSize(base: 12, width: screenWidth, min: 10, max: 14),
                            height: responsiveSize(base: 6, width: screenWidth, min: 5, max: 7)
                        )
                        .cornerRadius(responsiveSize(base: 1.5, width: screenWidth, min: 1, max: 2))
                }
                .frame(
                    width: responsiveSize(base: 18, width: screenWidth, min: 14, max: 22),
                    height: responsiveSize(base: 24, width: screenWidth, min: 18, max: 30)
                )
            } else {
                // Existing iPad sizes
                VStack(spacing: responsiveSize(base: 2.6, width: screenWidth, min: 2, max: 3)) {  // Consistent spacing
                    // Top rectangle (small)
                    Rectangle()
                        .fill(.primary)
                        .frame(
                            width: responsiveSize(base: 13, width: screenWidth, min: 10, max: 16),
                            height: responsiveSize(base: 8, width: screenWidth, min: 6, max: 10)
                        )
                        .cornerRadius(responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5))
                    
                    // Middle rectangle (largest)
                    Rectangle()
                        .fill(.primary)
                        .frame(
                            width: responsiveSize(base: 21, width: screenWidth, min: 16, max: 26),
                            height: responsiveSize(base: 9, width: screenWidth, min: 7, max: 11)
                        )
                        .cornerRadius(responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5))
                    
                    // Bottom rectangle (medium)
                    Rectangle()
                        .fill(.primary)
                        .frame(
                            width: responsiveSize(base: 16, width: screenWidth, min: 12, max: 20),
                            height: responsiveSize(base: 8, width: screenWidth, min: 6, max: 10)
                        )
                        .cornerRadius(responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5))
                }
                .frame(
                    width: responsiveSize(base: 24, width: screenWidth, min: 18, max: 30),
                    height: responsiveSize(base: 30, width: screenWidth, min: 23, max: 38)
                )
            }
            #else
            // Existing iPad sizes for macOS
            VStack(spacing: responsiveSize(base: 2.6, width: screenWidth, min: 2, max: 3)) {  // Consistent spacing
                // Top rectangle (small)
                Rectangle()
                    .fill(theme.primary)
                    .frame(
                        width: responsiveSize(base: 13, width: screenWidth, min: 10, max: 16),
                        height: responsiveSize(base: 8, width: screenWidth, min: 6, max: 10)
                    )
                    .cornerRadius(responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5))
                
                // Middle rectangle (largest)
                Rectangle()
                    .fill(theme.primary)
                    .frame(
                        width: responsiveSize(base: 21, width: screenWidth, min: 16, max: 26),
                        height: responsiveSize(base: 9, width: screenWidth, min: 7, max: 11)
                    )
                    .cornerRadius(responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5))
                
                // Bottom rectangle (medium)
                Rectangle()
                    .fill(theme.primary)
                    .frame(
                        width: responsiveSize(base: 16, width: screenWidth, min: 12, max: 20),
                        height: responsiveSize(base: 8, width: screenWidth, min: 6, max: 10)
                    )
                    .cornerRadius(responsiveSize(base: 2, width: screenWidth, min: 1.5, max: 2.5))
            }
            .frame(
                width: responsiveSize(base: 24, width: screenWidth, min: 18, max: 30),
                height: responsiveSize(base: 30, width: screenWidth, min: 23, max: 38)
            )
            #endif
            #endif
        } else if icon == "person.crop.circle.fill" {
            // Check if user has a profile image
            if let profileImage = UserProfileManager.shared.getProfileImage() {
                PlatformImageView(platformImage: profileImage)
                    .scaledToFill()
                    .frame(
                        width: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            if isPhone {
                                return responsiveSize(base: 20, width: screenWidth, min: 18, max: 24)  // Smaller profile image for iPhone
                            } else {
                                return responsiveSize(base: 25, width: screenWidth, min: 20, max: 30)  // Existing size for iPad
                            }
                            #else
                            return responsiveSize(base: 25, width: screenWidth, min: 20, max: 30)  // Existing size for macOS
                            #endif
                        }(),
                        height: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            if isPhone {
                                return responsiveSize(base: 20, width: screenWidth, min: 18, max: 24)  // Smaller profile image for iPhone
                            } else {
                                return responsiveSize(base: 25, width: screenWidth, min: 20, max: 30)  // Existing size for iPad
                            }
                            #else
                            return responsiveSize(base: 25, width: screenWidth, min: 20, max: 30)  // Existing size for macOS
                            #endif
                        }()
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(theme.primary.opacity(0.2), lineWidth: 1)
                    )
            } else {
                // Fallback to default icon
                Image(systemName: icon)
                    .font(.system(size: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        if isPhone {
                            return responsiveSize(base: 20, width: screenWidth, min: 18, max: 24)  // Smaller fallback icon for iPhone
                        } else {
                            return responsiveSize(base: 26, width: screenWidth, min: 20, max: 32)  // Existing size for iPad
                        }
                        #else
                        return responsiveSize(base: 26, width: screenWidth, min: 20, max: 32)  // Existing size for macOS
                        #endif
                    }()))
            }
        } else {
            Image(systemName: icon)
                .font(.system(size: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if isPhone {
                        return responsiveSize(base: 18, width: screenWidth, min: 16, max: 22)  // Smaller icons for iPhone
                    } else {
                        return responsiveSize(base: 22, width: screenWidth, min: 18, max: 28)  // Existing size for iPad
                    }
                    #else
                    return responsiveSize(base: 22, width: screenWidth, min: 18, max: 28)  // Existing size for macOS
                    #endif
                }()))
        }
    }
    
    var body: some View {
        // Calculate button size dynamically based on observed screen width on iOS
        let buttonSize: CGFloat = {
            #if os(macOS)
            return 40  // Keep macOS fixed - window-based, not screen-based
            #else
            // Use observedScreenWidth instead of UIScreen.main.bounds.width for iOS 16+ compliance
            let screenWidth = observedScreenWidth > 0 ? observedScreenWidth : UIScreen.main.bounds.width
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            if isPhone {
                let calculatedSize = screenWidth * 0.045 // 4.5% of screen width for iPhone (more compact)
                return max(40, min(56, calculatedSize)) // Smaller range for iPhone: 40-56pt
            } else {
                let calculatedSize = screenWidth * 0.055 // 5.5% of screen width for iPad (existing)
                return max(48, min(72, calculatedSize)) // iPad range: 48-72pt
            }
            #endif
        }()
        
        Button(action: {
            // Only trigger action if not dragging
            guard !isDragging else { return }
            
            #if os(iOS)
                                    HapticFeedback.impact(.light)
            #endif
            
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
        #if os(iOS)
        // Attach ScreenWidthReader to observe screen width dynamically and update observedScreenWidth state
        .background(ScreenWidthReader(screenWidth: $observedScreenWidth))
        #endif
    }
}

#if os(iOS)
// UIViewRepresentable to read screen width dynamically from the view's window scene
struct ScreenWidthReader: UIViewRepresentable {
    @Binding var screenWidth: CGFloat
    
    class Coordinator {
        var screenWidth: Binding<CGFloat>
        var observation: NSKeyValueObservation?
        
        init(screenWidth: Binding<CGFloat>) {
            self.screenWidth = screenWidth
        }
        
        deinit {
            observation?.invalidate()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(screenWidth: $screenWidth)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        // Observe when the view's window property is set
        DispatchQueue.main.async {
            updateScreenWidth(from: view, context: context)
        }
        
        // Observe window property changes to update screen width on window changes
        context.coordinator.observation = view.observe(\.window, options: [.new, .initial]) { observedView, change in
            updateScreenWidth(from: observedView, context: context)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        updateScreenWidth(from: uiView, context: context)
    }
    
    private func updateScreenWidth(from view: UIView, context: Context) {
        guard let window = view.window else { return }
        if let screenWidthValue = window.windowScene?.screen.bounds.width {
            if context.coordinator.screenWidth.wrappedValue != screenWidthValue {
                DispatchQueue.main.async {
                    context.coordinator.screenWidth.wrappedValue = screenWidthValue
                }
            }
        }
    }
}
#endif

// MARK: - Geometry Change Modifier
struct GeometryChangeModifier<T: Equatable>: ViewModifier {
    let value: T
    let action: (T) -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: value) { _, newValue in
                action(newValue)
            }
    }
}

extension View {
    func onGeometryChange<T: Equatable>(for value: T, action: @escaping (T) -> Void) -> some View {
        modifier(GeometryChangeModifier(value: value, action: action))
    }
}

// MARK: - Glass Effect Container
struct GlassEffectContainer<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        content
    }
}

// MARK: - Glass Menu Effect Navigation
struct GlassNavigationMenu<Content: View, Label: View>: View, Animatable {
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat = 30
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    
    /// View Properties
    @State private var contentSize: CGSize = .zero
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        GlassEffectContainer {
            let widthDiff = contentSize.width - labelSize.width
            let heightDiff = contentSize.height - labelSize.height
            
            let rWidth = widthDiff * contentOpacity
            let rHeight = heightDiff * contentOpacity
            
            ZStack(alignment: alignment) {
                content
                    .compositingGroup()
                    .scaleEffect(contentScale)
                    .blur(radius: 14 * blurProgress)
                    .opacity(contentOpacity)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    contentSize = geometry.size
                                }
                                .onChange(of: geometry.size) { _, newSize in
                                    contentSize = newSize
                                }
                        }
                    )
                    .fixedSize()
                    .frame(
                        width: labelSize.width + rWidth,
                        height: labelSize.height + rHeight
                    )
                
                label
                    .compositingGroup()
                    .blur(radius: 14 * blurProgress)
                    .opacity(1 - labelOpacity)
                    .frame(width: labelSize.width, height: labelSize.height)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: progress < 0.5 ? min(labelSize.width, labelSize.height) / 2 : cornerRadius))
            .background(
                // Glass background without material
                RoundedRectangle(cornerRadius: progress < 0.5 ? min(labelSize.width, labelSize.height) / 2 : cornerRadius)
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: progress < 0.5 ? min(labelSize.width, labelSize.height) / 2 : cornerRadius))
            )
        }
        .scaleEffect(
            x: 1 - (blurProgress * 0.35),
            y: 1 + (blurProgress * 0.45),
            anchor: scaleAnchor
        )
        .offset(y: offset * blurProgress)
    }
    
    var labelOpacity: CGFloat {
        min(progress / 0.35, 1)
    }
    
    var contentOpacity: CGFloat {
        max(progress - 0.35, 0) / 0.65
    }
    
    var contentScale: CGFloat {
        let minAspectScale = min(labelSize.width / contentSize.width, labelSize.height / contentSize.height)
        return minAspectScale + (1 - minAspectScale) * progress
    }
    
    var blurProgress: CGFloat {
        return progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }
    
    var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing: return -80
        case .top, .topLeading, .topTrailing: return 80
        default: return 0
        }
    }
    
    var scaleAnchor: UnitPoint {
        switch alignment {
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}

