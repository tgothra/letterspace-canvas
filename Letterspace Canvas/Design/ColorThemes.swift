import SwiftUI

// MARK: - Color Theme System
// This file provides centralized color theming for all visual elements

/// Defines colors for curated section cards
struct CuratedCardColors {
    let todaysDocs: Color
    let journal: Color
    let preachItAgain: Color
    let statistics: Color
    let recentlyOpened: Color
}

/// Defines colors for header action buttons
struct HeaderButtonColors {
    let filter: Color
    let sort: Color
    let tags: Color
}

/// Defines colors for bottom navigation badges
struct BottomNavColors {
    let starred: Color
    let wip: Color
    let schedule: Color
}

/// Main theme structure containing all customizable colors
struct AppColorTheme {
    let name: String
    let id: String
    
    // Core app colors (existing)
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    
    // New themeable colors
    let curatedCards: CuratedCardColors
    let headerButtons: HeaderButtonColors
    let bottomNav: BottomNavColors
    let floatingNav: Color // The bottom corner floating nav color
    
    /// Preview colors for swatches (key representative colors)
    var previewColors: [Color] {
        [
            curatedCards.todaysDocs,
            curatedCards.journal,
            curatedCards.statistics,
            curatedCards.recentlyOpened
        ]
    }
    

}

// MARK: - Predefined Themes

extension AppColorTheme {
    
    /// Current theme (matches existing colors)
    static let current = AppColorTheme(
        name: "Current",
        id: "current",
        primary: .primary,
        secondary: .secondary,
        accent: .blue,
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: .green.opacity(0.2),
            journal: .red.opacity(0.3),
            preachItAgain: .orange.opacity(0.3),
            statistics: .yellow.opacity(0.3),
            recentlyOpened: .blue.opacity(0.3)
        ),
        headerButtons: HeaderButtonColors(
            filter: .orange.opacity(0.3),
            sort: .green.opacity(0.2),
            tags: .blue.opacity(0.3)
        ),
        bottomNav: BottomNavColors(
            starred: .green.opacity(0.2),
            wip: .orange.opacity(0.3),
            schedule: .blue.opacity(0.3)
        ),
        floatingNav: .blue.opacity(0.3)
    )
    
    /// Warm theme
    static let warm = AppColorTheme(
        name: "Warm",
        id: "warm",
        primary: .primary,
        secondary: .secondary,
        accent: .orange,
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: .orange.opacity(0.2),
            journal: .red.opacity(0.3),
            preachItAgain: .yellow.opacity(0.3),
            statistics: .pink.opacity(0.3),
            recentlyOpened: .purple.opacity(0.3)
        ),
        headerButtons: HeaderButtonColors(
            filter: .yellow.opacity(0.3),
            sort: .orange.opacity(0.2),
            tags: .pink.opacity(0.3)
        ),
        bottomNav: BottomNavColors(
            starred: .orange.opacity(0.2),
            wip: .yellow.opacity(0.3),
            schedule: .pink.opacity(0.3)
        ),
        floatingNav: .orange.opacity(0.3)
    )
    
    /// Cool theme
    static let cool = AppColorTheme(
        name: "Cool",
        id: "cool",
        primary: .primary,
        secondary: .secondary,
        accent: .cyan,
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: .cyan.opacity(0.2),
            journal: .purple.opacity(0.3),
            preachItAgain: .blue.opacity(0.3),
            statistics: .indigo.opacity(0.3),
            recentlyOpened: .teal.opacity(0.3)
        ),
        headerButtons: HeaderButtonColors(
            filter: .blue.opacity(0.3),
            sort: .cyan.opacity(0.2),
            tags: .purple.opacity(0.3)
        ),
        bottomNav: BottomNavColors(
            starred: .cyan.opacity(0.2),
            wip: .blue.opacity(0.3),
            schedule: .purple.opacity(0.3)
        ),
        floatingNav: .cyan.opacity(0.3)
    )
    
    /// Nature theme
    static let nature = AppColorTheme(
        name: "Nature",
        id: "nature",
        primary: .primary,
        secondary: .secondary,
        accent: .green,
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: .green.opacity(0.2),
            journal: .brown.opacity(0.3),
            preachItAgain: .yellow.opacity(0.3),
            statistics: .orange.opacity(0.3),
            recentlyOpened: .teal.opacity(0.3)
        ),
        headerButtons: HeaderButtonColors(
            filter: .yellow.opacity(0.3),
            sort: .green.opacity(0.2),
            tags: .brown.opacity(0.3)
        ),
        bottomNav: BottomNavColors(
            starred: .green.opacity(0.2),
            wip: .yellow.opacity(0.3),
            schedule: .brown.opacity(0.3)
        ),
        floatingNav: .green.opacity(0.3)
    )
    
    /// Monochrome theme
    static let monochrome = AppColorTheme(
        name: "Monochrome",
        id: "monochrome",
        primary: .primary,
        secondary: .secondary,
        accent: .gray,
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: .gray.opacity(0.2),
            journal: .black.opacity(0.1),
            preachItAgain: .gray.opacity(0.3),
            statistics: .black.opacity(0.15),
            recentlyOpened: .gray.opacity(0.25)
        ),
        headerButtons: HeaderButtonColors(
            filter: .gray.opacity(0.3),
            sort: .gray.opacity(0.2),
            tags: .black.opacity(0.15)
        ),
        bottomNav: BottomNavColors(
            starred: .gray.opacity(0.2),
            wip: .gray.opacity(0.3),
            schedule: .black.opacity(0.15)
        ),
        floatingNav: .gray.opacity(0.3)
    )
}

// MARK: - Theme Manager

class ColorThemeManager: ObservableObject {
    @Published var currentTheme: AppColorTheme = .current
    
    // All available themes
    static let allThemes: [AppColorTheme] = [
        .current,
        .warm,
        .cool,
        .nature,
        .monochrome
    ]
    
    // Easy theme switching
    func setTheme(_ theme: AppColorTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
    }
    
    func setThemeById(_ id: String) {
        if let theme = Self.allThemes.first(where: { $0.id == id }) {
            setTheme(theme)
        }
    }
    
    // Convenience getters for specific color groups
    var curatedCards: CuratedCardColors { currentTheme.curatedCards }
    var headerButtons: HeaderButtonColors { currentTheme.headerButtons }
    var bottomNav: BottomNavColors { currentTheme.bottomNav }
    var floatingNav: Color { currentTheme.floatingNav }
}

// MARK: - Environment Key

struct ColorThemeKey: EnvironmentKey {
    static let defaultValue = ColorThemeManager()
}

extension EnvironmentValues {
    var colorTheme: ColorThemeManager {
        get { self[ColorThemeKey.self] }
        set { self[ColorThemeKey.self] = newValue }
    }
}

// MARK: - Convenience Extensions

extension View {
    func environmentColorTheme(_ themeManager: ColorThemeManager) -> some View {
        self.environment(\.colorTheme, themeManager)
    }
}

// MARK: - Quick Theme Creator Helper

/**
 Quick Theme Creator Guide:
 
 To create a new theme, add it to the AppColorTheme extension above following this pattern:
 
 ```swift
 static let yourThemeName = AppColorTheme(
     name: "Your Theme Name",
     id: "yourtheme",
     primary: .primary,
     secondary: .secondary,
     accent: .yourAccentColor,
     background: .clear,
     curatedCards: CuratedCardColors(
         todaysDocs: .color.opacity(0.2),
         journal: .color.opacity(0.3),
         preachItAgain: .color.opacity(0.3),
         statistics: .color.opacity(0.3),
         recentlyOpened: .color.opacity(0.3)
     ),
     headerButtons: HeaderButtonColors(
         filter: .color.opacity(0.3),
         sort: .color.opacity(0.2),
         tags: .color.opacity(0.3)
     ),
     bottomNav: BottomNavColors(
         starred: .color.opacity(0.2),
         wip: .color.opacity(0.3),
         schedule: .color.opacity(0.3)
     ),
     floatingNav: .color.opacity(0.3)
 )
 ```
 
 Then add it to the allThemes array in ColorThemeManager.
 */
