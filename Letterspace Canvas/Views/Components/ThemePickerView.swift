import SwiftUI

/// Quick and easy theme picker component
struct ThemePickerView: View {
    @Environment(\.colorTheme) var themeManager
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color Themes")
                .font(.custom("InterTight-Bold", size: 18))
                .foregroundStyle(theme.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(ColorThemeManager.allThemes, id: \.id) { colorTheme in
                    ThemePreviewCard(
                        colorTheme: colorTheme,
                        isSelected: themeManager.currentTheme.id == colorTheme.id
                    ) {
                        themeManager.setTheme(colorTheme)
                    }
                }
            }
        }
        .padding(20)
    }
}

/// Individual theme preview card
struct ThemePreviewCard: View {
    let colorTheme: AppColorTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Theme preview with sample colors
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorTheme.curatedCards.todaysDocs)
                        .frame(height: 20)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorTheme.curatedCards.journal)
                        .frame(height: 20)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorTheme.curatedCards.preachItAgain)
                        .frame(height: 20)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorTheme.curatedCards.statistics)
                        .frame(height: 20)
                }
                
                Text(colorTheme.name)
                    .font(.custom("InterTight-Medium", size: 14))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? colorTheme.accent : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? colorTheme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Settings integration - can be added to your settings view
struct ThemeSettingsSection: View {
    @Environment(\.colorTheme) var themeManager
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.custom("InterTight-Bold", size: 16))
                .foregroundStyle(theme.primary)
            
            // Quick theme selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ColorThemeManager.allThemes, id: \.id) { colorTheme in
                        Button(action: {
                            themeManager.setTheme(colorTheme)
                        }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colorTheme.accent)
                                    .frame(width: 12, height: 12)
                                
                                Text(colorTheme.name)
                                    .font(.custom("InterTight-Medium", size: 12))
                                    .foregroundStyle(themeManager.currentTheme.id == colorTheme.id ? .white : theme.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeManager.currentTheme.id == colorTheme.id ? colorTheme.accent : Color.gray.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

#Preview {
    ThemePickerView()
        .environmentColorTheme(ColorThemeManager())
}
