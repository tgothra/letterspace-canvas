import SwiftUI

struct SidebarActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 20, alignment: .center)
                    Text(title)
                        .font(.custom("InterTight-Medium", size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.surface)
                        .opacity(isHovering ? 1 : 0)
                )
                .foregroundStyle(theme.primary)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
} 