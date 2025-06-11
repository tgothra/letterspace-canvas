import SwiftUI

// Add ActionMenuItem struct for the menu options
struct ActionMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

// Add ActionMenuView for displaying the slash command menu
struct ActionMenuView: View {
    @Binding var selectedIndex: Int
    let items: [ActionMenuItem]
    let onDismiss: () -> Void
    @State var hoveringIndices: [Bool] = [false, false] // For tracking hover state of each item
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Helper function to get highlight color
    private func highlightColor(for index: Int) -> Color {
        if index == selectedIndex {
            return Color(hex: "#22c27d").opacity(0.15) // Lighter accent green color when selected
        } else if hoveringIndices.indices.contains(index) && hoveringIndices[index] {
            return Color(hex: "#22c27d").opacity(0.07) // Even lighter accent green when hovered
        } else {
            return Color.clear // No color otherwise
        }
    }
    
    var body: some View {
        // Use a ZStack to create our own custom background without borders
        ZStack(alignment: .center) {
            // Background shape with no stroke
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(white: 0.2) : Color.white)
                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                )
            
            // Content
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    // Menu item
                    Button(action: {
                        item.action()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.secondary)
                            
                            Text(item.title)
                                .font(.system(size: 14, weight: .medium))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            Group {
                                if index == selectedIndex {
                                    Color(hex: "#22c27d").opacity(0.15) // Lighter accent green color when selected
                                } else if hoveringIndices.indices.contains(index) && hoveringIndices[index] {
                                    Color(hex: "#22c27d").opacity(0.07) // Even lighter accent green when hovered
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        if hoveringIndices.indices.contains(index) {
                            hoveringIndices[index] = hovering
                        }
                    }
                    
                    if index < items.count - 1 {
                        Divider()
                            .padding(.horizontal, 4)
                    }
                }
            }
            .padding(0)
        }
        .onAppear {
            // Initialize hovering indices array based on items count
            hoveringIndices = Array(repeating: false, count: items.count)
            
            // Print debug message to confirm menu is showing properly
            print("📋 ACTION MENU: Menu view appeared - waiting for user interaction")
        }
    }
}
