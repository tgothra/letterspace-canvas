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
            // DISABLED: Haptic feedback causing 7-second freeze on search
            // HapticFeedback.impact(.light)
            // Simplified animation
            withAnimation(.easeInOut(duration: 0.2)) {
                isMenuOpen.toggle()
            }
        }) {
            ZStack {
                // Solid green background circle
                Circle()
                    .fill(theme.accent)
                    .frame(width: 56, height: 56)
                .overlay(
                    Circle()
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
                        .frame(width: 56, height: 56)
                )
                .clipShape(Circle())
                
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
                    
                    // Menu items
                    VStack(spacing: 0) {
                        // Menu items container - use VStack instead of LazyVStack for faster rendering
                        VStack(spacing: 0) {
                            menuItem(icon: "rectangle.3.group", title: "Dashboard", action: onDashboard)
                            menuItem(icon: "magnifyingglass", title: "Search", action: onSearch)
                            menuItem(icon: "plus.square", title: "New Document", action: onNewDocument)
                            menuItem(icon: "folder", title: "Folders", action: onFolders)
                            menuItem(icon: "book.closed", title: "Bible Reader", action: onBibleReader)
                            menuItem(icon: "sparkles", title: "Smart Study", action: onSmartStudy)
                            menuItem(icon: "trash", title: "Recently Deleted", action: onRecentlyDeleted)
                            menuItem(icon: "person.crop.circle.fill", title: "Settings", action: onSettings, isUserProfile: true)
                        }
                        .padding(.vertical, 10) // Add breathing room above and below menu items
                        .frame(width: 250)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.thinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.4),
                                                    Color.white.opacity(0.2)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.5),
                                                    Color.white.opacity(0.2)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                    }
                    .scaleEffect(menuScale)
                    .offset(y: menuOffset)
                    .padding(.trailing, 20)
                    .padding(.bottom, 80) // Position above the circular button
                }
            }
        }
        .onChange(of: isMenuOpen) { newValue in
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
    
    private func menuItem(icon: String, title: String, action: @escaping () -> Void, isUserProfile: Bool = false) -> some View {
        Button(action: {
            // DISABLED: Haptic feedback causing 7-second freeze when opening search
            // HapticFeedback.impact(.light)
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
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(theme.primary.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        // Fallback to cached initials
                        Circle()
                            .fill(theme.accent.opacity(0.2))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(cachedUserProfile.initials)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(theme.accent)
                            )
                    }
                } else if icon == "rectangle.3.group" {
                    // Custom dashboard icon
                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(theme.primary)
                            .frame(width: 8, height: 3)
                            .cornerRadius(0.5)
                        Rectangle()
                            .fill(theme.primary)
                            .frame(width: 12, height: 4)
                            .cornerRadius(0.5)
                        Rectangle()
                            .fill(theme.primary)
                            .frame(width: 10, height: 3)
                            .cornerRadius(0.5)
                    }
                    .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primary)
                        .frame(width: 20, height: 20)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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