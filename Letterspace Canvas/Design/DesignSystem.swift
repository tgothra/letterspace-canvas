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
    
    func toHex() -> String {
        #if os(macOS)
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return "#000000"
        }
        
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        
        return String(format: "#%02X%02X%02X", red, green, blue)
        #elseif os(iOS)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return "#000000"
        }
        let red = Int(round(r * 255))
        let green = Int(round(g * 255))
        let blue = Int(round(b * 255))
        
        return String(format: "#%02X%02X%02X", red, green, blue)
        #else
        return "#000000" // Placeholder for other platforms
        #endif
    }
}

// Font registration is now handled automatically via Info.plist UIAppFonts
// No manual registration needed

enum DesignSystem {
    enum Colors {
        static let accent = Color(hex: "#22c27d")
        
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
            
            // Liquid Glass tints for iOS 26
            var glassPrimary: Color { accent.opacity(0.15) }
            var glassSecondary: Color { primary.opacity(0.08) }
            var glassSubtle: Color { primary.opacity(0.05) }
            
            static let dark = ThemeColors(
                background: Color.black,
                surface: Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0),
                primary: .white,
                secondary: Color.white.opacity(0.7),
                secondaryMuted: Color.white.opacity(0.5),
                divider: Color.white.opacity(0.1),
                button: Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0),
                buttonHover: Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 1.0),
                accent: Color(hex: "#22c27d")
            )
            
            static let light = ThemeColors(
                background: .white,
                surface: Color(hex: "#f5f5f5"),
                primary: Color(hex: "#1a1a1a"),
                secondary: Color(hex: "#1a1a1a").opacity(0.7),
                secondaryMuted: Color(hex: "#1a1a1a").opacity(0.5),
                divider: Color.black.opacity(0.1),
                button: Color(hex: "#0066FF"),
                buttonHover: Color(hex: "#0052CC"),
                accent: Color(hex: "#22c27d")
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
            .custom("InterTight-Bold", size: size) // Fallback to Bold since Black was removed
        }
        
        static func bold(size: CGFloat) -> Font {
            .custom("InterTight-Bold", size: size)
        }
        
        static func semibold(size: CGFloat) -> Font {
            .custom("InterTight-SemiBold", size: size)
        }
        
        static func medium(size: CGFloat) -> Font {
            .custom("InterTight-Medium", size: size)
        }
        
        static func regular(size: CGFloat) -> Font {
            .custom("InterTight-Regular", size: size)
        }
        
        static func light(size: CGFloat) -> Font {
            .custom("InterTight-Regular", size: size) // Fallback to Regular since Light was removed
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