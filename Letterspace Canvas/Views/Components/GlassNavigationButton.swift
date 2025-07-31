import SwiftUI

struct GlassNavigationButton: View {
    @Binding var isExpanded: Bool
    let onToggle: () -> Void
    @Environment(\.themeColors) var theme
    
    var body: some View {
        GlassNavigationMenu(
            alignment: .leading,
            progress: isExpanded ? 1.0 : 0.0,
            labelSize: CGSize(width: 55, height: 55)
        ) {
            // Navigation content - all our floating sidebar buttons
            VStack(spacing: 12) {
                // Dashboard button
                FloatingSidebarButton(
                    icon: "rectangle.3.group",
                    title: "Dashboard",
                    action: {
                        // Dashboard action
                    }
                )
                
                // Smart Study button
                FloatingSidebarButton(
                    icon: "sparkles",
                    title: "Smart Study",
                    action: {
                        // Smart Study action
                    }
                )
                
                // Bible Reader button
                FloatingSidebarButton(
                    icon: "book.closed",
                    title: "Bible Reader",
                    action: {
                        // Bible Reader action
                    }
                )
                
                // Folders button
                FloatingSidebarButton(
                    icon: "folder",
                    title: "Folders",
                    action: {
                        // Folders action
                    }
                )
                
                // Settings button
                FloatingSidebarButton(
                    icon: "gearshape",
                    title: "Settings",
                    action: {
                        // Settings action
                    }
                )
                
                // User Profile button
                FloatingSidebarButton(
                    icon: "person.crop.circle.fill",
                    title: "User Profile",
                    action: {
                        // User Profile action
                    }
                )
                
                // Collapse button
                FloatingSidebarButton(
                    icon: "arrow.left",
                    title: "Hide Navigation",
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded = false
                        }
                    }
                )
            }
            .padding(16)
        } label: {
            // The green navigation button that morphs into the menu
            Button(action: {
                print("🎯 Glass navigation button tapped!")
                HapticFeedback.impact(.medium)
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                onToggle()
            }) {
                // Custom dashboard icon (same as our current implementation)
                VStack(spacing: 2.6) {
                    // Top rectangle (small)
                    Rectangle()
                        .fill(.black)
                        .frame(width: 13, height: 8)
                        .cornerRadius(2)
                    
                    // Middle rectangle (largest)
                    Rectangle()
                        .fill(.black)
                        .frame(width: 21, height: 9)
                        .cornerRadius(2)
                    
                    // Bottom rectangle (medium)
                    Rectangle()
                        .fill(.black)
                        .frame(width: 16, height: 8)
                        .cornerRadius(2)
                }
                .frame(width: 24, height: 30)
            }
            .frame(width: 55, height: 55)
            .background(
                Circle()
                    .fill(theme.accent)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    GlassNavigationButton(
        isExpanded: .constant(false),
        onToggle: {}
    )
} 