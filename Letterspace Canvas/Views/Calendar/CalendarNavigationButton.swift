import SwiftUI 
struct CalendarNavigationButton: View {
    let icon: String?
    let label: String?
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    
    init(icon: String? = nil, label: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))  // Reduced from 12 to 10
                } else if let label = label {
                    Text(label)
                        .font(.custom("InterTight-Medium", size: 11))  // Changed from Regular to Medium
                        .kerning(label == "Today" ? 0.3 : 0.0)  // Reduced kerning from 0.4 to 0.3
                }
            }
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 5)  // Reduced from 6 to 5
            .padding(.vertical, 3)  // Reduced from 4 to 3
            .background(
                RoundedRectangle(cornerRadius: 3)  // Reduced from 4 to 3
                    .fill(theme.primary.opacity(isHovering ? 0.1 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
