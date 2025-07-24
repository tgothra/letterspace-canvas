import SwiftUI

@Observable
class GradientWallpaperManager {
    var selectedLightGradientIndex: Int = 0 // Default to first (current system)
    var selectedDarkGradientIndex: Int = 0 // Default to first (current system)
    
    static let shared = GradientWallpaperManager()
    
    let gradientPresets: [GradientPreset] = [
        // Default - Current system colors (unchanged)
        GradientPreset(
            id: "default",
            name: "Default",
            lightGradient: .linear(
                colors: [Color.white, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            darkGradient: .linear(
                colors: [Color(red: 0.11, green: 0.11, blue: 0.12), Color(red: 0.11, green: 0.11, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        
        // Coral Sunset - Coral → dusty pink → lavender → light fade
        GradientPreset(
            id: "coral_sunset",
            name: "Coral Sunset",
            lightGradient: .radial(
                colors: [
                    Color(red: 1.0, green: 0.5, blue: 0.3),     // Coral center
                    Color(red: 0.9, green: 0.5, blue: 0.6),     // Dusty pink
                    Color(red: 0.7, green: 0.6, blue: 0.9),     // Lavender
                    Color(red: 0.9, green: 0.9, blue: 0.95),    // Light fade
                    Color(red: 0.98, green: 0.98, blue: 1.0)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.8, green: 0.3, blue: 0.2),     // Deep coral center
                    Color(red: 0.6, green: 0.3, blue: 0.4),     // Dark dusty pink
                    Color(red: 0.4, green: 0.3, blue: 0.6),     // Dark lavender
                    Color(red: 0.15, green: 0.15, blue: 0.2),   // Dark fade
                    Color(red: 0.05, green: 0.05, blue: 0.1)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Ocean Mist - Teal → ocean blue → powder blue → light fade
        GradientPreset(
            id: "ocean_mist",
            name: "Ocean Mist",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.6, blue: 0.6),     // Teal center
                    Color(red: 0.2, green: 0.5, blue: 0.8),     // Ocean blue
                    Color(red: 0.6, green: 0.8, blue: 0.9),     // Powder blue
                    Color(red: 0.9, green: 0.95, blue: 0.98),   // Light fade
                    Color(red: 0.98, green: 1.0, blue: 1.0)     // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.4, blue: 0.4),     // Deep teal center
                    Color(red: 0.1, green: 0.3, blue: 0.5),     // Dark ocean blue
                    Color(red: 0.2, green: 0.4, blue: 0.5),     // Dark powder blue
                    Color(red: 0.1, green: 0.15, blue: 0.2),    // Dark fade
                    Color(red: 0.05, green: 0.1, blue: 0.15)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Purple Dream - Purple → lavender → pale lavender → light fade
        GradientPreset(
            id: "purple_dream",
            name: "Purple Dream",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.6, green: 0.2, blue: 0.8),     // Purple center
                    Color(red: 0.7, green: 0.5, blue: 0.9),     // Lavender
                    Color(red: 0.85, green: 0.8, blue: 0.95),   // Pale lavender
                    Color(red: 0.95, green: 0.9, blue: 1.0),    // Light fade
                    Color(red: 0.98, green: 0.98, blue: 1.0)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.4, green: 0.1, blue: 0.6),     // Deep purple center
                    Color(red: 0.3, green: 0.2, blue: 0.5),     // Dark lavender
                    Color(red: 0.25, green: 0.2, blue: 0.35),   // Dark pale lavender
                    Color(red: 0.15, green: 0.1, blue: 0.2),    // Dark fade
                    Color(red: 0.1, green: 0.05, blue: 0.15)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Forest Glow - Blue-teal → aqua → yellow → light fade
        GradientPreset(
            id: "forest_glow",
            name: "Lemonade",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.66, blue: 0.77),   // Blue-teal center (#01A8C4)
                    Color(red: 0.4, green: 0.8, blue: 0.85),    // Aqua transition
                    Color(red: 0.98, green: 1.0, blue: 0.5),    // Yellow (#FBFE7F)
                    Color(red: 0.99, green: 1.0, blue: 0.85),   // Light fade
                    Color(red: 1.0, green: 1.0, blue: 0.95)     // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.5, blue: 0.6),     // Rich teal center
                    Color(red: 0.2, green: 0.6, blue: 0.7),     // Brighter aqua transition
                    Color(red: 0.8, green: 0.8, blue: 0.4),     // Softer golden yellow
                    Color(red: 0.25, green: 0.25, blue: 0.25),  // Neutral grey fade
                    Color(red: 0.12, green: 0.12, blue: 0.12)   // Dark grey edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Rose Gold - Redesigned with warm metallic rose gold aesthetic
        GradientPreset(
            id: "rose_gold",
            name: "Rose Gold",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.95, green: 0.76, blue: 0.76),  // Soft rose gold center
                    Color(red: 0.97, green: 0.85, blue: 0.73),  // Warm champagne
                    Color(red: 0.92, green: 0.88, blue: 0.82),  // Creamy pearl
                    Color(red: 0.96, green: 0.94, blue: 0.92),  // Soft ivory
                    Color(red: 0.99, green: 0.98, blue: 0.97)   // Whisper white
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.6, green: 0.35, blue: 0.4),    // Rich rose center
                    Color(red: 0.58, green: 0.45, blue: 0.38),  // Refined bronze (less burnt)
                    Color(red: 0.5, green: 0.35, blue: 0.4),    // Warm blush pink
                    Color(red: 0.3, green: 0.22, blue: 0.28),   // Deep blush mauve
                    Color(red: 0.18, green: 0.14, blue: 0.17)   // Very deep mauve
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Sky Blush - Sky blue → blush → peach → light fade
        GradientPreset(
            id: "sky_blush",
            name: "Sky Blush",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.5, green: 0.8, blue: 1.0),     // Sky blue center
                    Color(red: 0.9, green: 0.7, blue: 0.8),     // Blush
                    Color(red: 1.0, green: 0.8, blue: 0.7),     // Peach
                    Color(red: 0.98, green: 0.95, blue: 0.95),  // Light fade
                    Color(red: 1.0, green: 0.98, blue: 0.98)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.3, green: 0.5, blue: 0.7),     // Richer sky blue center
                    Color(red: 0.5, green: 0.4, blue: 0.5),     // Enhanced blush
                    Color(red: 0.6, green: 0.4, blue: 0.3),     // Warmer peach
                    Color(red: 0.2, green: 0.15, blue: 0.3),    // Deep dark purple fade
                    Color(red: 0.1, green: 0.08, blue: 0.18)    // Very deep purple edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Lavender Mist - Lavender → dusty lavender → cream → light fade
        GradientPreset(
            id: "lavender_mist",
            name: "Lavender Mist",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.7, green: 0.6, blue: 0.9),     // Lavender center
                    Color(red: 0.8, green: 0.7, blue: 0.85),    // Dusty lavender
                    Color(red: 0.95, green: 0.93, blue: 0.9),   // Cream
                    Color(red: 0.98, green: 0.97, blue: 0.95),  // Light fade
                    Color(red: 1.0, green: 0.99, blue: 0.98)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.3, green: 0.2, blue: 0.5),     // Deep lavender center
                    Color(red: 0.25, green: 0.2, blue: 0.3),    // Dark dusty lavender
                    Color(red: 0.2, green: 0.18, blue: 0.15),   // Dark cream
                    Color(red: 0.12, green: 0.11, blue: 0.1),   // Dark fade
                    Color(red: 0.08, green: 0.07, blue: 0.06)   // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Mint Frost - Mint → frost → pearl → light fade
        GradientPreset(
            id: "mint_frost",
            name: "Mint Frost",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.6, green: 0.9, blue: 0.8),     // Mint center
                    Color(red: 0.8, green: 0.9, blue: 0.95),    // Frost
                    Color(red: 0.95, green: 0.97, blue: 0.98),  // Pearl
                    Color(red: 0.98, green: 0.99, blue: 0.99),  // Light fade
                    Color(red: 1.0, green: 1.0, blue: 1.0)      // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.2, green: 0.4, blue: 0.35),    // Deep mint center
                    Color(red: 0.15, green: 0.25, blue: 0.3),   // Dark frost
                    Color(red: 0.12, green: 0.18, blue: 0.2),   // Dark pearl
                    Color(red: 0.08, green: 0.12, blue: 0.15),  // Dark fade
                    Color(red: 0.05, green: 0.08, blue: 0.1)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Soft Amber - Amber → dusty rose → powder blue → light fade (original)
        GradientPreset(
            id: "soft_amber",
            name: "Soft Amber",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.9, green: 0.7, blue: 0.4),     // Amber center
                    Color(red: 0.8, green: 0.6, blue: 0.6),     // Dusty rose
                    Color(red: 0.7, green: 0.8, blue: 0.9),     // Powder blue
                    Color(red: 0.9, green: 0.95, blue: 0.98),   // Light fade
                    Color(red: 0.98, green: 1.0, blue: 1.0)     // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.5, green: 0.3, blue: 0.1),     // Deep amber center
                    Color(red: 0.4, green: 0.25, blue: 0.25),   // Dark dusty rose
                    Color(red: 0.2, green: 0.3, blue: 0.4),     // Dark powder blue
                    Color(red: 0.1, green: 0.15, blue: 0.2),    // Dark fade
                    Color(red: 0.05, green: 0.1, blue: 0.15)    // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Coral Blush - Peach → bright pink → soft transitions
        GradientPreset(
            id: "coral_blush",
            name: "Coral Blush",
            lightGradient: .radial(
                colors: [
                    Color(red: 1.0, green: 0.83, blue: 0.635),   // Peach center (#FFD4A2)
                    Color(red: 0.996, green: 0.4, blue: 0.5),    // Pink transition
                    Color(red: 0.996, green: 0.2, blue: 0.349),  // Bright pink (#FE0159)
                    Color(red: 0.98, green: 0.85, blue: 0.9),    // Light pink fade
                    Color(red: 0.99, green: 0.95, blue: 0.97)    // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.7, green: 0.4, blue: 0.35),     // Deep coral center
                    Color(red: 0.6, green: 0.25, blue: 0.3),     // Dark pink transition
                    Color(red: 0.5, green: 0.1, blue: 0.2),      // Deep pink
                    Color(red: 0.25, green: 0.15, blue: 0.18),   // Dark fade
                    Color(red: 0.15, green: 0.1, blue: 0.12)     // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Purple Magic - Deep purple → magenta pink → soft transitions
        GradientPreset(
            id: "purple_magic",
            name: "Purple Magic",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.408, green: 0.176, blue: 0.549), // Deep purple center (#682D8C)
                    Color(red: 0.65, green: 0.3, blue: 0.6),      // Purple transition
                    Color(red: 0.922, green: 0.4, blue: 0.6),     // Magenta pink (#EB1E79)
                    Color(red: 0.95, green: 0.8, blue: 0.9),      // Light fade
                    Color(red: 0.98, green: 0.9, blue: 0.95)      // Very light edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.3, green: 0.12, blue: 0.4),      // Deeper purple center
                    Color(red: 0.4, green: 0.15, blue: 0.35),     // Dark purple transition
                    Color(red: 0.5, green: 0.2, blue: 0.3),       // Dark magenta
                    Color(red: 0.25, green: 0.15, blue: 0.2),     // Dark fade
                    Color(red: 0.15, green: 0.1, blue: 0.13)      // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Sunset Fire - Red → orange → yellow → warm transitions
        GradientPreset(
            id: "sunset_fire",
            name: "Sunset Fire",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.929, green: 0.11, blue: 0.141),  // Red center (#ED1C24)
                    Color(red: 0.95, green: 0.4, blue: 0.1),      // Orange transition
                    Color(red: 0.988, green: 0.8, blue: 0.2),     // Yellow transition
                    Color(red: 0.988, green: 0.925, blue: 0.4),   // Bright yellow (#FCEC21)
                    Color(red: 0.99, green: 0.97, blue: 0.85)     // Light yellow edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.6, green: 0.08, blue: 0.1),      // Deep red center
                    Color(red: 0.5, green: 0.2, blue: 0.05),      // Dark orange transition
                    Color(red: 0.4, green: 0.3, blue: 0.1),       // Dark yellow
                    Color(red: 0.2, green: 0.15, blue: 0.05),     // Dark fade
                    Color(red: 0.12, green: 0.1, blue: 0.05)      // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Ocean Breeze - Deep blue → cyan → aqua transitions
        GradientPreset(
            id: "ocean_breeze",
            name: "Ocean Breeze",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.18, green: 0.2, blue: 0.576),    // Deep blue center (#2E3393)
                    Color(red: 0.15, green: 0.5, blue: 0.7),      // Blue transition
                    Color(red: 0.1, green: 0.8, blue: 0.9),       // Cyan transition
                    Color(red: 0.4, green: 0.95, blue: 0.988),    // Bright cyan (#1CFAFC)
                    Color(red: 0.85, green: 0.98, blue: 1.0)      // Very light cyan edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.12, green: 0.15, blue: 0.4),     // Deep blue center
                    Color(red: 0.1, green: 0.25, blue: 0.35),     // Dark blue transition
                    Color(red: 0.08, green: 0.3, blue: 0.4),      // Dark cyan
                    Color(red: 0.1, green: 0.2, blue: 0.25),      // Dark fade
                    Color(red: 0.05, green: 0.12, blue: 0.15)     // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        ),
        
        // Deep Ocean - Very dark blue → medium blue → navy transitions
        GradientPreset(
            id: "deep_ocean",
            name: "Deep Ocean",
            lightGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.016, blue: 0.157),   // Very dark blue center (#000428)
                    Color(red: 0.0, green: 0.15, blue: 0.35),     // Navy transition
                    Color(red: 0.0, green: 0.306, blue: 0.573),   // Medium blue (#004E92)
                    Color(red: 0.4, green: 0.6, blue: 0.8),       // Light blue fade
                    Color(red: 0.85, green: 0.9, blue: 0.95)      // Very light blue edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            ),
            darkGradient: .radial(
                colors: [
                    Color(red: 0.0, green: 0.01, blue: 0.12),     // Very deep blue center
                    Color(red: 0.0, green: 0.08, blue: 0.2),      // Deep navy transition
                    Color(red: 0.0, green: 0.15, blue: 0.3),      // Navy blue
                    Color(red: 0.05, green: 0.1, blue: 0.18),     // Dark fade
                    Color(red: 0.02, green: 0.05, blue: 0.1)      // Very dark edge
                ],
                center: .init(x: 0.2, y: 0.7),
                startRadius: 0,
                endRadius: 800
            )
        )
    ]
    
    private init() {
        loadSettings()
    }
    
    func getCurrentGradient(for colorScheme: ColorScheme) -> AnyShapeStyle {
        if colorScheme == .dark {
            return gradientPresets[selectedDarkGradientIndex].darkGradient.asGradient()
        } else {
            return gradientPresets[selectedLightGradientIndex].lightGradient.asGradient()
        }
    }
    
    func setGradient(lightIndex: Int, darkIndex: Int) {
        selectedLightGradientIndex = min(max(lightIndex, 0), gradientPresets.count - 1)
        selectedDarkGradientIndex = min(max(darkIndex, 0), gradientPresets.count - 1)
        saveSettings()
    }
    
    private func loadSettings() {
        selectedLightGradientIndex = UserDefaults.standard.integer(forKey: "selectedLightGradientIndex")
        selectedDarkGradientIndex = UserDefaults.standard.integer(forKey: "selectedDarkGradientIndex")
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedLightGradientIndex, forKey: "selectedLightGradientIndex")
        UserDefaults.standard.set(selectedDarkGradientIndex, forKey: "selectedDarkGradientIndex")
        UserDefaults.standard.synchronize()
    }
}

// MARK: - Gradient Wallpaper System

struct GradientPreset {
    let id: String
    let name: String
    let lightGradient: GradientData
    let darkGradient: GradientData
}

// Gradient data structure to store gradient information
struct GradientData {
    let colors: [Color]
    let type: GradientType
    let startPoint: UnitPoint?
    let endPoint: UnitPoint?
    let center: UnitPoint?
    let startRadius: CGFloat?
    let endRadius: CGFloat?
    
    enum GradientType {
        case linear
        case radial
    }
    
    // Create a linear gradient
    static func linear(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> GradientData {
        return GradientData(
            colors: colors,
            type: .linear,
            startPoint: startPoint,
            endPoint: endPoint,
            center: nil,
            startRadius: nil,
            endRadius: nil
        )
    }
    
    // Create a radial gradient
    static func radial(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> GradientData {
        return GradientData(
            colors: colors,
            type: .radial,
            startPoint: nil,
            endPoint: nil,
            center: center,
            startRadius: startRadius,
            endRadius: endRadius
        )
    }
    
    // Convert to actual gradient
    func asGradient() -> AnyShapeStyle {
        switch type {
        case .linear:
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: startPoint ?? .topLeading,
                endPoint: endPoint ?? .bottomTrailing
            ))
        case .radial:
            return AnyShapeStyle(RadialGradient(
                gradient: Gradient(colors: colors),
                center: center ?? .center,
                startRadius: startRadius ?? 0,
                endRadius: endRadius ?? 800
            ))
        }
    }
    
    // Convert to tile-optimized gradient for small previews
    func asTileGradient() -> AnyShapeStyle {
        switch type {
        case .linear:
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: startPoint ?? .topLeading,
                endPoint: endPoint ?? .bottomTrailing
            ))
        case .radial:
            // Use smaller radius for tile previews but respect original startRadius
            return AnyShapeStyle(RadialGradient(
                gradient: Gradient(colors: colors),
                center: center ?? .center,
                startRadius: startRadius ?? 0,
                endRadius: 60  // Much smaller radius for tiles
            ))
        }
    }
    
    // Convert to preview-optimized gradient for preview cards
    func asPreviewGradient() -> AnyShapeStyle {
        switch type {
        case .linear:
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: startPoint ?? .topLeading,
                endPoint: endPoint ?? .bottomTrailing
            ))
        case .radial:
            // Use medium radius for preview cards but respect original startRadius
            return AnyShapeStyle(RadialGradient(
                gradient: Gradient(colors: colors),
                center: center ?? .center,
                startRadius: startRadius ?? 0,
                endRadius: 120  // Medium radius for preview cards
            ))
        }
    }
}
