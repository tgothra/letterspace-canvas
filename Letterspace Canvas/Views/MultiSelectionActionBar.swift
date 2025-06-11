import SwiftUI

struct MultiSelectionActionBar: View {
    let selectedCount: Int
    let onPin: () -> Void
    let onWIP: () -> Void
    let onDelete: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isPinHovered = false
    @State private var isWIPHovered = false
    @State private var isDeleteHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(selectedCount) selected")
                .font(.system(size: 13))
                .foregroundStyle(theme.primary)
            
            Divider()
                .frame(height: 20)
            
            Button(action: onPin) {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                    Text("Pin")
                }
                .font(.system(size: 13))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPinHovered ? 
                            (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)) : 
                            .clear)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.primary)
            .onHover { hovering in
                isPinHovered = hovering
            }
            
            Button(action: onWIP) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                    Text("WIP")
                }
                .font(.system(size: 13))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isWIPHovered ? 
                            (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)) : 
                            .clear)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.primary)
            .onHover { hovering in
                isWIPHovered = hovering
            }
            
            Button(action: onDelete) {
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                    Text("Delete")
                        .fixedSize(horizontal: true, vertical: false) // Ensure text doesn't get truncated
                }
                .font(.system(size: 13))
                .padding(.horizontal, 8) // Increased from 6 to 8
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDeleteHovered ? 
                            (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)) : 
                            .clear)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .onHover { hovering in
                isDeleteHovered = hovering
            }
        }
        .padding(.horizontal, 28) // Increased from 24 to 28
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : .white)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15),
                    radius: 15,
                    x: 0,
                    y: 5
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.1), lineWidth: 0.5)
        )
        .frame(minWidth: 240) // Add minimum width to ensure all content fits
    }
} 