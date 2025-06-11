import SwiftUI

struct SidebarButtonBackup: View {
    let icon: String
    let action: () -> Void
    let tooltip: String
    @Binding var activePopup: String?
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(theme.primary)
                .frame(width: 40, height: 40)  // Fixed size frame for the icon
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.surface)
                        .opacity(isHovering ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)  // Center the button in its container
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .help(tooltip)  // Native macOS tooltip
    }
} 