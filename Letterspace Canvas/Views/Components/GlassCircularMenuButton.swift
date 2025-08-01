import SwiftUI

struct GlassCircularMenuButton: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Binding var isMenuOpen: Bool
    
    // Menu actions
    let onDashboard: () -> Void
    let onSearch: () -> Void
    let onNewDocument: () -> Void
    let onFolders: () -> Void
    let onBibleReader: () -> Void
    let onSmartStudy: () -> Void
    let onRecentlyDeleted: () -> Void
    let onSettings: () -> Void
    
    // Finger tracking state
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var hoveredButtonIndex: Int? = nil
    
    // iOS 26 Animated SF Symbols state
    @State private var menuToggleAnimationTrigger = 0
    @State private var menuItemAnimationTriggers: [Int: Int] = [:]
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background overlay for tap-outside-to-dismiss
            if isMenuOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.bouncy(duration: 0.7, extraBounce: 0.01)) {
                            isMenuOpen = false
                        }
                    }
                    .zIndex(-1) // Behind the menu
            }
            
            GlassNavigationMenu(
                alignment: .bottomTrailing,
                progress: isMenuOpen ? 1.0 : 0.0,
                labelSize: CGSize(width: 56, height: 56),
                cornerRadius: 20
            ) {
            // Menu content - all the navigation items with finger tracking
            VStack(spacing: 2) {
                menuItem(icon: "rectangle.3.group", title: "Dashboard", action: onDashboard, index: 0)
                menuItem(icon: "magnifyingglass", title: "Search", action: onSearch, index: 1)
                menuItem(icon: "plus.square", title: "New Document", action: onNewDocument, index: 2)
                menuItem(icon: "folder", title: "Folders", action: onFolders, index: 3)
                menuItem(icon: "book.closed", title: "Bible Reader", action: onBibleReader, index: 4)
                menuItem(icon: "sparkles", title: "Smart Study", action: onSmartStudy, index: 5)
                menuItem(icon: "trash", title: "Recently Deleted", action: onRecentlyDeleted, index: 6)
                menuItem(icon: "person.crop.circle.fill", title: "Settings", action: onSettings, index: 7, isUserProfile: true)
            }
            .padding(.vertical, 8)
            .frame(width: 240)
            .simultaneousGesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .onChanged { value in
                        dragLocation = value.location
                        isDragging = true
                        
                        // Calculate which button is being hovered
                        let startY: CGFloat = 8 // top padding
                        let buttonHeight: CGFloat = 40 // button height including padding
                        let adjustedY = value.location.y - startY
                        
                        let newButtonIndex = Int(adjustedY / buttonHeight)
                        let validIndex = newButtonIndex >= 0 && newButtonIndex < 8 ? newButtonIndex : nil
                        
                        // Only update if index actually changed
                        if validIndex != hoveredButtonIndex {
                            hoveredButtonIndex = validIndex
                            if validIndex != nil {
                                HapticFeedback.selection()
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isDragging = false
                            hoveredButtonIndex = nil
                            dragLocation = .zero
                        }
                    }
            )
        } label: {
            // The green circular button that morphs into the menu (glass effect with green tint)
            VStack(spacing: 3.5) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 16, height: 2.5)
                    .rotationEffect(.degrees(isMenuOpen ? 45 : 0))
                    .offset(y: isMenuOpen ? 3 : 0)
                
                if !isMenuOpen {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: 16, height: 2.5)
                        .opacity(isMenuOpen ? 0 : 1)
                }
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 16, height: 2.5)
                    .rotationEffect(.degrees(isMenuOpen ? -45 : 0))
                    .offset(y: isMenuOpen ? -3 : 0)
            }
            .animation(.easeInOut(duration: 0.2), value: isMenuOpen)
            // ✨ iOS 26 Animated SF Symbol: Variable color pulse during menu toggle
            .symbolEffect(.variableColor.reversing, value: menuToggleAnimationTrigger)
            .frame(width: 56, height: 56)
            .glassEffect(.regular.tint(theme.accent.opacity(0.8)).interactive())
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
            .contentShape(Circle())
            .onTapGesture {
                HapticFeedback.safeTrigger(.light)
                withAnimation(.bouncy(duration: 0.7, extraBounce: 0.01)) {
                    isMenuOpen.toggle()
                }
                // ✨ Trigger iOS 26 animated SF symbol for menu toggle
                menuToggleAnimationTrigger += 1
            }
        }
        // Apply bouncy container movement effects to the entire glass navigation menu
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .offset(
            x: isDragging ? (dragLocation.x - 120) * 0.08 : 0,  // Dramatic X movement
            y: isDragging ? (dragLocation.y - 160) * 0.06 : 0   // Dramatic Y movement
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isDragging)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: dragLocation)
        }
    }
    
    private func menuItem(icon: String, title: String, action: @escaping () -> Void, index: Int, isUserProfile: Bool = false) -> some View {
        Button(action: {
            HapticFeedback.safeTrigger(.light)
            // ✨ Trigger iOS 26 animated SF symbol for this menu item
            menuItemAnimationTriggers[index] = (menuItemAnimationTriggers[index] ?? 0) + 1
            // Close menu first, then execute action
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isMenuOpen = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                if isUserProfile && icon == "person.crop.circle.fill" {
                    // User profile image
                    if let profileImage = UserProfileManager.shared.getProfileImage() {
                        PlatformImageView(platformImage: profileImage)
                            .scaledToFill()
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(theme.primary.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        // Fallback to initials
                        Circle()
                            .fill(theme.accent.opacity(0.2))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(UserProfileManager.shared.userProfile.initials)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(theme.accent)
                            )
                    }
                } else if icon == "rectangle.3.group" {
                    // Custom dashboard icon
                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(.black)
                            .frame(width: 8, height: 3)
                            .cornerRadius(0.5)
                        Rectangle()
                            .fill(.black)
                            .frame(width: 12, height: 4)
                            .cornerRadius(0.5)
                        Rectangle()
                            .fill(.black)
                            .frame(width: 10, height: 3)
                            .cornerRadius(0.5)
                    }
                    .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primary)
                        .frame(width: 20, height: 20)
                        // ✨ iOS 26 Animated SF Symbol: Bounce when menu item is tapped
                        .symbolEffect(.bounce, value: menuItemAnimationTriggers[index] ?? 0)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.accent)
                .opacity(hoveredButtonIndex == index && isDragging ? 0.3 : 0)
                .animation(.easeInOut(duration: 0.1), value: hoveredButtonIndex == index && isDragging)
        )
        .scaleEffect(hoveredButtonIndex == index && isDragging ? 1.08 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: hoveredButtonIndex == index && isDragging)
        .brightness(hoveredButtonIndex == index && isDragging ? 0.1 : 0)
        .animation(.easeInOut(duration: 0.1), value: hoveredButtonIndex == index && isDragging)
    }
}

#Preview {
    ZStack {
        Color.black
        
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                GlassCircularMenuButton(
                    isMenuOpen: .constant(false),
                    onDashboard: {},
                    onSearch: {},
                    onNewDocument: {},
                    onFolders: {},
                    onBibleReader: {},
                    onSmartStudy: {},
                    onRecentlyDeleted: {},
                    onSettings: {}
                )
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
    .frame(width: 400, height: 600)
} 