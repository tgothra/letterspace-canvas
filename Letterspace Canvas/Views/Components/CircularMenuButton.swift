import SwiftUI

#if os(iOS)
import UIKit
#endif

struct CircularMenuButton: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Binding var isMenuOpen: Bool
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Button(action: {
            HapticFeedback.impact(.medium)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isMenuOpen.toggle()
                rotationAngle = isMenuOpen ? 45 : 0
            }
        }) {
            ZStack {
                // Solid green background circle
                Circle()
                    .fill(theme.accent)
                    .frame(width: 48, height: 48)
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
                        .frame(width: 48, height: 48)
                )
                .clipShape(Circle())
                
                // Menu icon (hamburger or close) - white on green background
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: 14, height: 2)
                        .rotationEffect(.degrees(isMenuOpen ? 45 : 0))
                        .offset(y: isMenuOpen ? 2.5 : 0)
                    
                    if !isMenuOpen {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white)
                            .frame(width: 14, height: 2)
                            .opacity(isMenuOpen ? 0 : 1)
                    }
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: 14, height: 2)
                        .rotationEffect(.degrees(isMenuOpen ? -45 : 0))
                        .offset(y: isMenuOpen ? -2.5 : 0)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isMenuOpen)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
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
    
    @State private var menuScale: CGFloat = 0.8
    @State private var menuOffset: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Background overlay - transparent but still allows tap to close
            Rectangle()
                .fill(Color.clear)
                .ignoresSafeArea()
                .contentShape(Rectangle())
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
                        // Menu items container
                        LazyVStack(spacing: 0) {
                            menuItem(icon: "rectangle.3.group", title: "Dashboard", action: onDashboard)
                            menuItem(icon: "magnifyingglass", title: "Search", action: onSearch)
                            menuItem(icon: "plus.square", title: "New Document", action: onNewDocument)
                            menuItem(icon: "folder", title: "Folders", action: onFolders)
                            menuItem(icon: "book.closed", title: "Bible Reader", action: onBibleReader)
                            menuItem(icon: "sparkles", title: "Smart Study", action: onSmartStudy)
                            menuItem(icon: "trash", title: "Recently Deleted", action: onRecentlyDeleted)
                            menuItem(icon: "person.crop.circle.fill", title: "Settings", action: onSettings, isUserProfile: true)
                        }
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                if newValue {
                    menuScale = 1
                    menuOffset = 0
                } else {
                    menuScale = 0.8
                    menuOffset = 20
                }
            }
        }
        .opacity(isMenuOpen ? 1 : 0)
        .allowsHitTesting(isMenuOpen)
        .zIndex(isMenuOpen ? 1000 : -1)
    }
    
    private func menuItem(icon: String, title: String, action: @escaping () -> Void, isUserProfile: Bool = false) -> some View {
        Button(action: {
            HapticFeedback.impact(.light)
            action()
            closeMenu()
        }) {
            HStack(spacing: 12) {
                // Icon
                if icon == "rectangle.3.group" {
                    // Custom dashboard icon
                    VStack(spacing: 1.5) {
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
                } else if isUserProfile && icon == "person.crop.circle.fill" {
                    // User profile image or initials
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
        .background(
            Rectangle()
                .fill(Color.clear)
                .onTapGesture {
                    action()
                    closeMenu()
                }
        )
    }
    
    private func closeMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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