import SwiftUI

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
