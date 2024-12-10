import SwiftUI

struct DocumentFolderButton: View {
    let title: String
    let icon: String
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: {}) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 20, alignment: .center)
                    Text(title)
                        .font(.custom("InterTight-Medium", size: 16))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.surface)
                        .opacity(isHovering ? 1 : 0)
                )
                .foregroundStyle(theme.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
} 