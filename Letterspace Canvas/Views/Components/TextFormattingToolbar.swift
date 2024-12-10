import SwiftUI

struct TextFormattingToolbar: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: (Color) -> Void
    let onLink: () -> Void
    let onHighlight: (Color) -> Void
    let onTextColor: (Color) -> Void
    let onBulletList: () -> Void
    let onNumberedList: () -> Void
    let onTextSize: () -> Void
    let onAlignment: (TextAlignment) -> Void
    
    @State private var showColorPicker = false
    @State private var showHighlightPicker = false
    @State private var showUnderlinePicker = false
    @State private var showAlignmentPicker = false
    @State private var hoveredButton: String? = nil
    @State private var hoveredColor: Color? = nil
    @State private var hoveredAlignment: TextAlignment? = nil
    
    private let textColors: [Color] = [
        .black,
        .gray,
        Color(red: 0.95, green: 0.3, blue: 0.3),   // Red
        Color(red: 1.0, green: 0.4, blue: 0.7),    // Pink
        Color(red: 1.0, green: 0.6, blue: 0.0),    // Orange
        Color(red: 1.0, green: 0.8, blue: 0.0),    // Yellow
        Color(red: 0.3, green: 0.85, blue: 0.4),   // Green
        Color(red: 0.2, green: 0.6, blue: 1.0),    // Blue
        Color(red: 0.6, green: 0.4, blue: 0.8)     // Purple
    ]
    
    var body: some View {
        HStack(spacing: 16) {
            // Basic formatting
            Group {
                Button(action: onBold) {
                    Image(systemName: "bold")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .help("Bold (⌘B)")
                
                Button(action: onItalic) {
                    Image(systemName: "italic")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .help("Italic (⌘I)")
                
                Button(action: { onUnderline(.primary) }) {
                    Image(systemName: "underline")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .help("Underline (⌘U)")
                
                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.3))
                
                Button(action: onLink) {
                    Image(systemName: "link")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .help("Add Link (⌘K)")
                
                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.3))
                
                Button(action: onBulletList) {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .help("Bullet List (⌘L)")
                
                Button(action: onNumberedList) {
                    Image(systemName: "list.number")
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .help("Numbered List (⌘⇧L)")
            }
            .buttonStyle(.plain)
            .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.2))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
 