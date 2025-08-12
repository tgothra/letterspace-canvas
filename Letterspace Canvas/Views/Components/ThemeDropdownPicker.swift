import SwiftUI

// Helper function to get the actual theme colors as they appear in the UI
private func actualColorsForTheme(_ theme: AppColorTheme) -> [Color] {
    return [
        theme.curatedCards.todaysDocs,
        theme.curatedCards.journal,
        theme.curatedCards.statistics,
        theme.curatedCards.recentlyOpened
    ]
}

struct ThemeDropdownPicker: View {
    @EnvironmentObject var colorTheme: ColorThemeManager
    @Environment(\.themeColors) var theme
    @State private var isExpanded = false
    @State private var hoveredTheme: AppColorTheme?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Current theme indicator button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    // Current theme color swatches
                    HStack(spacing: 4) {
                        ForEach(Array(actualColorsForTheme(colorTheme.currentTheme).prefix(3)), id: \.self) { color in
                            ZStack {
                                Color.white
                                color
                            }
                            .frame(width: 12, height: 12)
                            .clipShape(Circle())
                        }
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.primary.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Floating dropdown content
            if isExpanded {
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(ColorThemeManager.allThemes, id: \.id) { themeOption in
                        ThemeOptionRow(
                            theme: themeOption,
                            isSelected: themeOption.id == colorTheme.currentTheme.id,
                            isHovered: hoveredTheme?.id == themeOption.id
                        ) {
                            // Don't close dropdown, let user keep exploring
                            print("🎨 Theme changing to: \(themeOption.name)")
                            colorTheme.setTheme(themeOption)
                            
                            #if os(iOS)
                            HapticFeedback.impact(.light)
                            #endif
                        }
                        .onHover { hovering in
                            hoveredTheme = hovering ? themeOption : nil
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .offset(y: 45) // Position below the button
                .zIndex(1000) // Ensure it's on top
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .topTrailing).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .topTrailing).combined(with: .opacity)
                ))
            }
        }
        // Add a background overlay to close dropdown when tapping outside
        .background(
            Group {
                if isExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }
                }
            }
        )
    }
}

struct ThemeOptionRow: View {
    let theme: AppColorTheme
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    @Environment(\.themeColors) var currentTheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Theme name
                Text(theme.name)
                    .font(.custom("InterTight-Medium", size: 14))
                    .foregroundStyle(currentTheme.primary)
                
                Spacer()
                
                // Color swatches - show actual theme colors as they appear in UI
                HStack(spacing: 4) {
                    ForEach(actualColorsForTheme(theme), id: \.self) { color in
                        ZStack {
                            Color.white
                            color
                        }
                        .frame(width: 14, height: 14)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                }
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? currentTheme.background.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

#Preview {
    VStack {
        Spacer()
        
        HStack {
            Spacer()
            ThemeDropdownPicker()
                .environmentObject(ColorThemeManager())
        }
        .padding()
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
    .withTheme()
}
