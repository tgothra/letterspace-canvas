import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

struct CircularMenuButton: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Binding var isMenuOpen: Bool
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Use safer haptic feedback with timeout protection
            HapticFeedback.safeTrigger(.light)
            // Simplified animation
            withAnimation(.easeInOut(duration: 0.2)) {
                isMenuOpen.toggle()
            }
        }) {
            ZStack {
                // Liquid Glass background circle
                Circle()
                    .fill(theme.accent)
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.tint(theme.accent.opacity(0.3)).interactive())
                
                // Menu icon (hamburger or close) - white on green background
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
            }
        }
        .frame(width: 64, height: 64) // Slightly smaller frame
        .contentShape(Circle()) // Use Circle shape for better touch detection
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
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
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}

struct CircularMenuOverlay: View {
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
    
    @State private var menuScale: CGFloat = 0.85
    @State private var menuOffset: CGFloat = 15
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var hoveredButtonIndex: Int? = nil
    
    // Pre-cache user profile components to avoid first-load delays
    @State private var cachedUserProfile = UserProfileManager.shared.userProfile
    @State private var cachedProfileImage: PlatformImage? = UserProfileManager.shared.getProfileImage()
    
    var body: some View {
        ZStack {
            // Background overlay - clear like modals
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    closeMenu()
                }
            
            // Menu content
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Menu items - Wrapped in GlassEffectContainer for Liquid Glass
                    GlassEffectContainer {
                        VStack(spacing: 0) {
                            // Menu items container - use VStack instead of LazyVStack for faster rendering
                            VStack(spacing: 4) {
                                menuItem(icon: "rectangle.3.group", title: "Dashboard", action: onDashboard, index: 0)
                                menuItem(icon: "magnifyingglass", title: "Search", action: onSearch, index: 1)
                                menuItem(icon: "plus.square", title: "New Document", action: onNewDocument, index: 2)
                                menuItem(icon: "folder", title: "Folders", action: onFolders, index: 3)
                                menuItem(icon: "book.closed", title: "Bible Reader", action: onBibleReader, index: 4)
                                menuItem(icon: "sparkles", title: "Smart Study", action: onSmartStudy, index: 5)
                                menuItem(icon: "trash", title: "Recently Deleted", action: onRecentlyDeleted, index: 6)
                                menuItem(icon: "person.crop.circle.fill", title: "Settings", action: onSettings, index: 7, isUserProfile: true)
                            }
                            .padding(.vertical, 10) // Add breathing room above and below menu items
                            .frame(width: 280)
                            .glassEffect(
                                .regular,
                                in: RoundedRectangle(cornerRadius: isDragging ? 20 : 16)
                            )
                            .scaleEffect(isDragging ? 1.02 : 1.0)
                            .offset(
                                x: isDragging ? (dragLocation.x - 140) * 0.05 : 0,
                                y: isDragging ? (dragLocation.y - 160) * 0.03 : 0
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragLocation)
                            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                                                        .simultaneousGesture(
                                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                                    .onChanged { value in
                                        dragLocation = value.location
                                        isDragging = true
                                        
                                        // Calculate which button is being hovered
                                        let startY: CGFloat = 10 // top padding
                                        let buttonHeight: CGFloat = 48 // button height including padding
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
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            isDragging = false
                                            hoveredButtonIndex = nil
                                            dragLocation = .zero
                                        }
                                    }
                            )
                        }
                    }
                    .scaleEffect(menuScale)
                    .offset(y: menuOffset)
                    .padding(.trailing, 20)
                    .padding(.bottom, 80) // Position above the circular button
                }
            }
        }
        .onChange(of: isMenuOpen) { oldValue, newValue in
            // Simplified animation for better performance
            withAnimation(.easeInOut(duration: 0.25)) {
                if newValue {
                    menuScale = 1
                    menuOffset = 0
                } else {
                    menuScale = 0.85
                    menuOffset = 15
                }
            }
        }
        .opacity(isMenuOpen ? 1 : 0)
        .allowsHitTesting(isMenuOpen)
        .zIndex(isMenuOpen ? 1000 : -1)
    }
    
    private func menuItem(icon: String, title: String, action: @escaping () -> Void, index: Int, isUserProfile: Bool = false) -> some View {
        Button(action: {
            HapticFeedback.safeTrigger(.light)
            // Close menu first, then execute action to prevent gesture conflicts
            closeMenu()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // Reduced delay
                action()
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                if isUserProfile && icon == "person.crop.circle.fill" {
                    // Use cached user profile data to avoid loading delays
                    if let profileImage = cachedProfileImage {
                        PlatformImageView(platformImage: profileImage)
                            .scaledToFill()
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(theme.primary.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        // Fallback to cached initials
                        Circle()
                            .fill(theme.accent.opacity(0.2))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text(cachedUserProfile.initials)
                                    .font(.system(size: 12, weight: .medium))
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
                    .frame(width: 22, height: 22)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(theme.primary)
                        .frame(width: 22, height: 22)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(theme.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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
    
    private func closeMenu() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isMenuOpen = false
        }
    }
}

#Preview {
    ZStack {
        Color.black
        
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                CircularMenuButton(isMenuOpen: .constant(false))
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
        }
        
        CircularMenuOverlay(
            isMenuOpen: .constant(true),
            onDashboard: {},
            onSearch: {},
            onNewDocument: {},
            onFolders: {},
            onBibleReader: {},
            onSmartStudy: {},
            onRecentlyDeleted: {},
            onSettings: {}
        )
    }
    .frame(width: 400, height: 600)
} 