import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Font {
    static func registerInterTightFonts() {
        // Register each weight of Inter Tight that we need
        let fontNames = [
            "InterTight-Thin",
            "InterTight-ThinItalic",
            "InterTight-Light",
            "InterTight-LightItalic",
            "InterTight-Regular",
            "InterTight-Italic",
            "InterTight-Medium",
            "InterTight-MediumItalic",
            "InterTight-SemiBold",
            "InterTight-SemiBoldItalic",
            "InterTight-Bold",
            "InterTight-BoldItalic",
            "InterTight-ExtraBold",
            "InterTight-ExtraBoldItalic",
            "InterTight-Black",
            "InterTight-BlackItalic"
        ]
        
        for fontName in fontNames {
            guard let url = Bundle.main.url(forResource: fontName, withExtension: "ttf"),
                  let dataProvider = CGDataProvider(url: url as CFURL),
                  let font = CGFont(dataProvider) else {
                print("Failed to load font: \(fontName)")
                continue
            }
            
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(font, &error) {
                print("Failed to register font: \(fontName)")
            }
        }
    }
}

enum DesignSystem {
    enum Colors {
        static let accent = Color(hex: "#3ee5a1")
        
        struct ThemeColors {
            let background: Color
            let surface: Color
            let primary: Color
            let secondary: Color
            let secondaryMuted: Color
            let divider: Color
            let button: Color
            let buttonHover: Color
            let accent: Color
            
            static let dark = ThemeColors(
                background: Color(.sRGB, red: 0.1, green: 0.1, blue: 0.1, opacity: 1.0),
                surface: Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0),
                primary: .white,
                secondary: Color.white.opacity(0.7),
                secondaryMuted: Color.white.opacity(0.5),
                divider: Color.white.opacity(0.1),
                button: Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0),
                buttonHover: Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 1.0),
                accent: Color(hex: "#3ee5a1")
            )
            
            static let light = ThemeColors(
                background: Color(.sRGB, red: 0.98, green: 0.98, blue: 0.98, opacity: 1.0),
                surface: Color(hex: "#f5f5f5"),
                primary: Color(hex: "#1a1a1a"),
                secondary: Color(hex: "#1a1a1a").opacity(0.7),
                secondaryMuted: Color(hex: "#1a1a1a").opacity(0.5),
                divider: Color.black.opacity(0.1),
                button: Color(hex: "#0066FF"),
                buttonHover: Color(hex: "#0052CC"),
                accent: Color(hex: "#3ee5a1")
            )
        }
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    enum Typography {
        static func black(size: CGFloat) -> Font {
            .custom("InterTight-Black", size: size)
        }
        
        static func bold(size: CGFloat) -> Font {
            .custom("InterTight-Bold", size: size)
        }
        
        static func medium(size: CGFloat) -> Font {
            .custom("InterTight-Medium", size: size)
        }
        
        static func regular(size: CGFloat) -> Font {
            .custom("InterTight-Regular", size: size)
        }
        
        static func light(size: CGFloat) -> Font {
            .custom("InterTight-Light", size: size)
        }
        
        static let title = bold(size: 24)
        static let heading = bold(size: 20)
        static let subheading = medium(size: 16)
        static let body = regular(size: 14)
        static let caption = regular(size: 12)
    }
}

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = DesignSystem.Colors.ThemeColors.dark
}

extension EnvironmentValues {
    var themeColors: DesignSystem.Colors.ThemeColors {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

struct ThemeModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content.environment(\.themeColors, colorScheme == .dark ? DesignSystem.Colors.ThemeColors.dark : DesignSystem.Colors.ThemeColors.light)
    }
}

extension View {
    func withTheme() -> some View {
        modifier(ThemeModifier())
    }
}

struct ThemeReader<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: (DesignSystem.Colors.ThemeColors) -> Content
    
    var body: some View {
        content(colorScheme == .dark ? DesignSystem.Colors.ThemeColors.dark : DesignSystem.Colors.ThemeColors.light)
    }
} 