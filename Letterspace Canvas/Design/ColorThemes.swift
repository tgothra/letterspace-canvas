import SwiftUI

// MARK: - Color Theme System
// This file provides centralized color theming for all visual elements

/// Defines gradient styles for theme elements. Uses AnyShapeStyle to support LinearGradient, MeshGradient, etc.
struct GradientStyles {
    let todaysDocsGradient: AnyShapeStyle
    let journalGradient: AnyShapeStyle
    let preachItAgainGradient: AnyShapeStyle
    let statisticsGradient: AnyShapeStyle
    let recentlyOpenedGradient: AnyShapeStyle
    let meetingsGradient: AnyShapeStyle
    let filterGradient: AnyShapeStyle
    let sortGradient: AnyShapeStyle
    let tagsGradient: AnyShapeStyle
}

/// Defines colors for curated section cards
struct CuratedCardColors: Equatable {
    let todaysDocs: Color
    let journal: Color
    let preachItAgain: Color
    let statistics: Color
    let recentlyOpened: Color
    let meetings: Color
}

/// Defines colors for header action buttons
struct HeaderButtonColors: Equatable {
    let filter: Color
    let sort: Color
    let tags: Color
}

/// Defines colors for bottom navigation badges
struct BottomNavColors: Equatable {
    let starred: Color
    let wip: Color
    let schedule: Color
}

/// Defines colors for journal entry cards
struct JournalCardColors: Equatable {
    let background: Color
    let accent: Color
    let highlightText: Color
    let metadata: Color
}

/// Defines colors for document status icons
struct StatusIconColors: Equatable {
    let pinned: Color
    let wip: Color
    let calendar: Color
}

/// Defines colors for document tools sheet buttons
struct DocumentToolColors: Equatable {
    let details: Color
    let series: Color
    let tags: Color
    let variations: Color
    let bookmarks: Color
    let links: Color
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
    
    // Optional: Additional themed sections (can be added incrementally)
    let journalCards: JournalCardColors?
    let statusIcons: StatusIconColors?
    let documentTools: DocumentToolColors?
    
    // Optional: Gradient styles for gradient-based themes
    let gradients: GradientStyles?
    
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

// MARK: - Equatable conformance (compare by stable id only)
extension AppColorTheme: Equatable {
    static func == (lhs: AppColorTheme, rhs: AppColorTheme) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Predefined Themes

extension AppColorTheme {
    
    /// Pastel theme (soft, gentle colors)
    static let pastel = AppColorTheme(
        name: "Pastel",
        id: "pastel",
        primary: .primary,
        secondary: .secondary,
        accent: .blue,
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: .green.opacity(0.2),
            journal: .red.opacity(0.3),
            preachItAgain: .orange.opacity(0.3),
            statistics: .yellow.opacity(0.3),
            recentlyOpened: .blue.opacity(0.3),
            meetings: .yellow.opacity(0.25)
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
        floatingNav: .blue.opacity(0.3),
        
        // Optional themed sections
        journalCards: JournalCardColors(
            background: .purple.opacity(0.1),
            accent: .purple.opacity(0.6),
            highlightText: .purple,
            metadata: .purple.opacity(0.4)
        ),
        statusIcons: StatusIconColors(
            pinned: .green.opacity(0.7),
            wip: .orange.opacity(0.7),
            calendar: .blue.opacity(0.7)
        ),
        documentTools: DocumentToolColors(
            details: .blue.opacity(0.2),
            series: .purple.opacity(0.2),
            tags: .green.opacity(0.2),
            variations: .orange.opacity(0.2),
            bookmarks: .pink.opacity(0.2),
            links: .cyan.opacity(0.2)
        ),
        gradients: nil
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
            recentlyOpened: .purple.opacity(0.3),
            meetings: .orange.opacity(0.25)
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
        floatingNav: .orange.opacity(0.3),
        
        // Optional sections - can be added later
        journalCards: nil,
        statusIcons: StatusIconColors(
            pinned: .orange.opacity(0.8),
            wip: .yellow.opacity(0.8),
            calendar: .pink.opacity(0.8)
        ),
        documentTools: nil,
        gradients: nil
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
            recentlyOpened: .teal.opacity(0.3),
            meetings: .cyan.opacity(0.25)
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
        floatingNav: .cyan.opacity(0.3),
        
        // Optional sections - can be added later
        journalCards: nil,
        statusIcons: StatusIconColors(
            pinned: .cyan.opacity(0.8),
            wip: .blue.opacity(0.8),
            calendar: .purple.opacity(0.8)
        ),
        documentTools: nil,
        gradients: nil
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
            recentlyOpened: .teal.opacity(0.3),
            meetings: .green.opacity(0.25)
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
        floatingNav: .green.opacity(0.3),
        
        // Optional sections - can be added later
        journalCards: nil,
        statusIcons: StatusIconColors(
            pinned: .green.opacity(0.8),
            wip: .yellow.opacity(0.8),
            calendar: .brown.opacity(0.8)
        ),
        documentTools: nil,
        gradients: nil
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
            recentlyOpened: .gray.opacity(0.25),
            meetings: .gray.opacity(0.2)
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
        floatingNav: .gray.opacity(0.3),
        
        // Optional sections - can be added later
        journalCards: nil,
        statusIcons: StatusIconColors(
            pinned: .gray.opacity(0.8),
            wip: .gray.opacity(0.6),
            calendar: .black.opacity(0.7)
        ),
        documentTools: nil,
        gradients: nil
    )
    
    /// Vibrant Gradients theme - beautiful gradient-inspired colors with white text
    static let gradients = AppColorTheme(
        name: "Gradients",
        id: "gradients",
        primary: .white,
        secondary: .white.opacity(0.8),
        accent: .white,
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: Color(hex: "FFD92B"), // Yellow like the tag button
            journal: Color(hex: "6E5AEE"),   // Burple (blue/purple) blend
            preachItAgain: Color(hex: "19E4A4"), // Green gradient blend
            statistics: Color(hex: "336AF6"),    // Blue gradient blend
            recentlyOpened: Color(hex: "FF9B2A"),  // Swapped: use Today's Docs orange blend
            meetings: Color(hex: "FFD92B")
        ),
        headerButtons: HeaderButtonColors(
            filter: Color(hex: "02F6CE"),    // Cyan gradient blend
            sort: Color(hex: "66B7EC"),      // Cyan-purple gradient blend
            tags: Color(hex: "FFD92B")       // Yellow gradient blend
        ),
        bottomNav: BottomNavColors(
            starred: Color(hex: "FF9B2A"),   // Orange gradient blend
            wip: Color(hex: "FFD92B"),       // Yellow gradient blend  
            schedule: Color(hex: "336AF6")   // Blue gradient blend
        ),
        floatingNav: Color(hex: "19E4A4"), // Green gradient blend
        
        // Optional sections with vibrant colors
        journalCards: JournalCardColors(
            background: Color(hex: "6E5AEE").opacity(0.1),  // Burple with transparency
            accent: Color(hex: "6E5AEE"),                    // Burple blend
            highlightText: .white,
            metadata: .white.opacity(0.8)
        ),
        statusIcons: StatusIconColors(
            pinned: .white,
            wip: .white,
            calendar: .white
        ),
        documentTools: DocumentToolColors(
            details: Color(hex: "336AF6"),    // Blue gradient blend
            series: Color(hex: "6E5AEE"),     // Burple blend
            tags: Color(hex: "19E4A4"),       // Green gradient blend
            variations: Color(hex: "FF9B2A"), // Orange gradient blend
            bookmarks: Color(hex: "FB9A8D"),  // Pink gradient blend
            links: Color(hex: "66B7EC")       // Cyan-purple gradient blend
        ),
        
        // Actual gradients for gradient-aware components
        gradients: GradientStyles(
            // Yellow like the tag button gradient
            todaysDocsGradient: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "FFE324"), Color(hex: "FFB533")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            journalGradient: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "336AF6"), Color(hex: "7C4DFF")], // Blue → Purple (burple)
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            preachItAgainGradient: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "2AFEB7"), Color(hex: "08C792")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            statisticsGradient: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "5581F1"), Color(hex: "1153FC")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            recentlyOpenedGradient: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "FFCB52"), Color(hex: "FF7B02")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            meetingsGradient: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "FFE324"), Color(hex: "FFD92B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            filterGradient: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "00F7A7"), Color(hex: "04F5ED")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            sortGradient: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "1DE5E2"), Color(hex: "B588F7")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            tagsGradient: AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "FFE324"), Color(hex: "FFB533")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        )
    )

    /// Mesh Gradients theme - multi-color mesh backgrounds using SwiftUI MeshGradient
    static let mesh = AppColorTheme(
        name: "Mesh",
        id: "mesh",
        primary: .white,
        secondary: .white.opacity(0.85),
        accent: .white,
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: Color(hex: "FFD92B"),
            journal: Color(hex: "6E5AEE"),
            preachItAgain: Color(hex: "19E4A4"),
            statistics: Color(hex: "336AF6"),
            recentlyOpened: Color(hex: "FB9A8D"),
            meetings: Color(hex: "FFD92B")
        ),
        headerButtons: HeaderButtonColors(
            filter: Color(hex: "02F6CE"),
            sort: Color(hex: "66B7EC"),
            tags: Color(hex: "FFD92B")
        ),
        bottomNav: BottomNavColors(
            starred: Color(hex: "FF9B2A"),
            wip: Color(hex: "FFD92B"),
            schedule: Color(hex: "336AF6")
        ),
        floatingNav: Color(hex: "19E4A4"),
        journalCards: JournalCardColors(
            background: Color(hex: "6E5AEE").opacity(0.1),
            accent: Color(hex: "6E5AEE"),
            highlightText: .white,
            metadata: .white.opacity(0.85)
        ),
        statusIcons: StatusIconColors(
            pinned: .white,
            wip: .white,
            calendar: .white
        ),
        documentTools: DocumentToolColors(
            details: Color(hex: "336AF6").opacity(0.22),
            series: Color(hex: "6E5AEE").opacity(0.22),
            tags: Color(hex: "19E4A4").opacity(0.22),
            variations: Color(hex: "FF9B2A").opacity(0.22),
            bookmarks: Color(hex: "FB9A8D").opacity(0.22),
            links: Color(hex: "66B7EC").opacity(0.22)
        ),
        gradients: GradientStyles(
            // Inspired by Apple-style mesh gradients (see Natalia Panferova, 2025)
            todaysDocsGradient: AnyShapeStyle(MeshGradient(
                width: 2,
                height: 2,
                points: [[-0.2, -0.2], [1.0, 0.0], [0.0, 1.0], [1.2, 1.1]],
                colors: [
                    Color(hex: "FFF37D"), // warm yellow highlight
                    Color(hex: "FFAF45"), // orange
                    Color(hex: "FF6B6B"), // coral
                    Color(hex: "FFB533")  // tag yellow
                ]
            )),
            journalGradient: AnyShapeStyle(MeshGradient(
                width: 2,
                height: 2,
                points: [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]],
                colors: [
                    Color(hex: "5B8CFF"), // blue
                    Color(hex: "7C4DFF"), // purple
                    Color(hex: "6E5AEE"), // burple
                    Color(hex: "9D7CFF")  // light purple
                ]
            )),
            preachItAgainGradient: AnyShapeStyle(MeshGradient(
                width: 2,
                height: 2,
                points: [[-0.1, 0.0], [1.0, 0.0], [0.0, 1.0], [1.2, 1.0]],
                colors: [
                    Color(hex: "2AFEB7"),
                    Color(hex: "08C792"),
                    Color(hex: "66FFCC"),
                    Color(hex: "00E5A8")
                ]
            )),
            statisticsGradient: AnyShapeStyle(MeshGradient(
                width: 2,
                height: 2,
                points: [[0.0, 0.0], [1.0, -0.2], [0.0, 1.0], [1.0, 1.0]],
                colors: [
                    Color(hex: "66B7EC"),
                    Color(hex: "336AF6"),
                    Color(hex: "1153FC"),
                    Color(hex: "88C0FF")
                ]
            )),
            recentlyOpenedGradient: AnyShapeStyle(MeshGradient(
                width: 2,
                height: 2,
                points: [[-0.2, 0.0], [1.0, 0.0], [0.0, 1.0], [1.1, 1.0]],
                colors: [
                    Color(hex: "FF9BB6"), // light pink
                    Color(hex: "FF6FA3"), // pink
                    Color(hex: "FFC6A5"), // peach
                    Color(hex: "FFA38F")  // warm pink
                ]
            )),
            meetingsGradient: AnyShapeStyle(MeshGradient(
                width: 2,
                height: 2,
                points: [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]],
                colors: [
                    Color(hex: "FFE324"), // tag yellow
                    Color(hex: "FFD92B"), // warm yellow
                    Color(hex: "FFF37D"), // light yellow
                    Color(hex: "FFB533")  // deeper yellow
                ]
            )),
            filterGradient: AnyShapeStyle(MeshGradient(
                width: 2,
                height: 2,
                points: [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]],
                colors: [
                    Color(hex: "00F7A7"),
                    Color(hex: "04F5ED"),
                    Color(hex: "66FFE6"),
                    Color(hex: "02F6CE")
                ]
            )),
            sortGradient: AnyShapeStyle(MeshGradient(
                width: 2,
                height: 2,
                points: [[-0.1, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]],
                colors: [
                    Color(hex: "1DE5E2"),
                    Color(hex: "B588F7"),
                    Color(hex: "66B7EC"),
                    Color(hex: "7C4DFF")
                ]
            )),
            tagsGradient: AnyShapeStyle(MeshGradient(
                width: 2,
                height: 2,
                points: [[0.0, 0.0], [1.0, -0.1], [0.0, 1.0], [1.0, 1.0]],
                colors: [
                    Color(hex: "FFE324"),
                    Color(hex: "FFB533"),
                    Color(hex: "FFF37D"),
                    Color(hex: "FFD92B")
                ]
            ))
        )
    )

    /// Punchy, modern high-contrast theme with white text and pills
    static let punchy = AppColorTheme(
        name: "Punchy",
        id: "punchy",
        primary: .white,
        secondary: .white.opacity(0.85),
        accent: .white,
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: .orange,                     // Match pastel's Preach It Again orange (punchier here)
            journal: Color(hex: "#6E2DFF"),         // Deep vibrant purple
            preachItAgain: Color(hex: "#FF5E57"),   // Punchy red/coral
            statistics: Color(hex: "#0A84FF"),      // iOS blue
            recentlyOpened: Color(hex: "#00C853"),   // Deep modern green
            meetings: Color(hex: "#FFEA00")         // Vivid yellow for meetings
        ),
        headerButtons: HeaderButtonColors(
            filter: Color(hex: "#00E5FF"),          // Cyan
            sort: Color(hex: "#7C4DFF"),            // Deep purple
            tags: Color(hex: "#FFEA00")             // Punchy yellow
        ),
        bottomNav: BottomNavColors(
            starred: Color(hex: "#FF5E57"),
            wip: Color(hex: "#FFB300"),
            schedule: Color(hex: "#0A84FF")
        ),
        floatingNav: Color(hex: "#00E5A8"),
        journalCards: JournalCardColors(
            background: Color(hex: "#6E2DFF").opacity(0.14),
            accent: Color(hex: "#6E2DFF"),
            highlightText: .white,
            metadata: .white.opacity(0.85)
        ),
        statusIcons: StatusIconColors(
            pinned: .white,
            wip: .white,
            calendar: .white
        ),
        documentTools: DocumentToolColors(
            details: Color(hex: "#0A84FF").opacity(0.22),
            series: Color(hex: "#7E57FF").opacity(0.22),
            tags: Color(hex: "#00E5A8").opacity(0.22),
            variations: Color(hex: "#FF5E57").opacity(0.22),
            bookmarks: Color(hex: "#FFB300").opacity(0.22),
            links: Color(hex: "#00E5FF").opacity(0.22)
        ),
        gradients: nil
    )

    /// Noir + Gold theme: black/white base with gold accents, plus blue and purple touches
    static let noirGold = AppColorTheme(
        name: "Noir Gold",
        id: "noirGold",
        primary: .primary,
        secondary: .secondary,
        accent: Color(hex: "#F1C40F"),              // Rich gold
        background: .clear,
        curatedCards: CuratedCardColors(
            todaysDocs: Color(hex: "#F5D061"),      // Soft gold
            journal: Color(hex: "#2C2C2E"),         // Near-black
            preachItAgain: Color(hex: "#FFF3D1"),   // Warm parchment
            statistics: Color(hex: "#0A84FF"),      // Blue
            recentlyOpened: Color(hex: "#6E5AEE"),   // Purple
            meetings: Color(hex: "#F1C40F")        // Gold accent for meetings
        ),
        headerButtons: HeaderButtonColors(
            filter: Color(hex: "#F1C40F"),
            sort: Color(hex: "#0A84FF"),
            tags: Color(hex: "#6E5AEE")
        ),
        bottomNav: BottomNavColors(
            starred: Color(hex: "#F1C40F").opacity(0.35),
            wip: Color(hex: "#2C2C2E").opacity(0.25),
            schedule: Color(hex: "#6E5AEE").opacity(0.3)
        ),
        floatingNav: Color(hex: "#2C2C2E").opacity(0.25),
        journalCards: JournalCardColors(
            background: Color(hex: "#FFF3D1"),
            accent: Color(hex: "#F1C40F"),
            highlightText: .black,
            metadata: Color.black.opacity(0.6)
        ),
        statusIcons: StatusIconColors(
            pinned: Color(hex: "#F1C40F"),
            wip: Color(hex: "#6E5AEE"),
            calendar: Color(hex: "#0A84FF")
        ),
        documentTools: DocumentToolColors(
            details: Color(hex: "#0A84FF").opacity(0.18),
            series: Color(hex: "#6E5AEE").opacity(0.18),
            tags: Color(hex: "#F1C40F").opacity(0.18),
            variations: Color(hex: "#2C2C2E").opacity(0.15),
            bookmarks: Color(hex: "#FFF3D1").opacity(0.18),
            links: Color(hex: "#0A84FF").opacity(0.18)
        ),
        gradients: nil
    )
}

// MARK: - Theme Manager

class ColorThemeManager: ObservableObject {
    @Published var currentTheme: AppColorTheme = .mesh
    
    // All available themes
    static let allThemes: [AppColorTheme] = [
        .pastel,
        .warm,
        .cool,
        .nature,
        .gradients,
        .mesh,
        .punchy,
        .noirGold
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
    
    // Gradient support
    var hasGradients: Bool { currentTheme.gradients != nil }
    var gradients: GradientStyles? { currentTheme.gradients }
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
    
    /// Apply gradient background if gradients are available, otherwise use solid color
    func themedBackground(
        gradientStyle: KeyPath<GradientStyles, AnyShapeStyle>,
        colorStyle: Color,
        in shape: some InsettableShape,
        colorTheme: ColorThemeManager
    ) -> some View {
        self.background(
            Group {
                if let gradients = colorTheme.gradients {
                    shape.fill(gradients[keyPath: gradientStyle])
                } else {
                    shape.fill(colorStyle)
                }
            }
        )
    }
    
    /// Apply gradient background for rectangles
    func themedBackground(
        gradientStyle: KeyPath<GradientStyles, AnyShapeStyle>,
        colorStyle: Color,
        cornerRadius: CGFloat,
        colorTheme: ColorThemeManager
    ) -> some View {
        self.themedBackground(
            gradientStyle: gradientStyle,
            colorStyle: colorStyle,
            in: RoundedRectangle(cornerRadius: cornerRadius),
            colorTheme: colorTheme
        )
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
