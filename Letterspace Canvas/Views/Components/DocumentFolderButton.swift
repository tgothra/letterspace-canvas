import SwiftUI

struct DocumentFolderButton: View {
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
                        .font(.system(size: 14))
                        .frame(width: 16, alignment: .center)
                    Text(title)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.surface)
                        .opacity(isHovering ? 1 : 0)
                )
                .foregroundStyle(theme.secondary)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
} 