#if os(iOS)
import SwiftUI
import UIKit

// MARK: - iOS Text Formatting Toolbar (Keyboard Accessory)
struct IOSTextFormattingToolbar: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onLink: () -> Void
    let onDismiss: () -> Void
    
    // Callbacks to toggle picker views in the parent
    let onToggleTextColor: () -> Void
    let onToggleHighlight: () -> Void
    let onToggleAlignment: () -> Void
    
    // Active state properties
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let hasLink: Bool
    let hasBulletList: Bool
    
    // Bindings to show active state on picker buttons
    @Binding var isTextColorPickerVisible: Bool
    @Binding var isHighlightPickerVisible: Bool
    @Binding var isAlignmentPickerVisible: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Basic formatting
            FormattingGroup {
                IOSToolbarButton(icon: "bold", isActive: isBold, action: onBold)
                IOSToolbarButton(icon: "italic", isActive: isItalic, action: onItalic)
                IOSToolbarButton(icon: "underline", isActive: isUnderlined, action: onUnderline)
            }
            
            Divider().frame(height: 24).padding(.horizontal, 8)
            
            // Text styling
            FormattingGroup {
                IOSToolbarButton(icon: "textformat", isActive: isTextColorPickerVisible, action: onToggleTextColor)
                IOSToolbarButton(icon: "highlighter", isActive: isHighlightPickerVisible, action: onToggleHighlight)
                IOSToolbarButton(icon: "link", isActive: hasLink, action: onLink)
            }
            
            Divider().frame(height: 24).padding(.horizontal, 8)
            
            // Lists and alignment
            FormattingGroup {
                // Placeholder for bullet list button
                // IOSToolbarButton(icon: "list.bullet", isActive: hasBulletList, action: onBulletList)
                IOSToolbarButton(icon: "text.alignleft", isActive: isAlignmentPickerVisible, action: onToggleAlignment)
            }
            
            Spacer()
            
            // Dismiss button
            IOSToolbarButton(icon: "keyboard.chevron.compact.down", action: onDismiss)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color(UIColor.separator))
                        .frame(height: 0.5)
                        .frame(maxHeight: .infinity, alignment: .top)
                )
        )
        .frame(height: 50)
    }
}

// MARK: - Supporting Views
private struct FormattingGroup<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 4) {
            content
        }
    }
}

private struct IOSToolbarButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    init(icon: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.isActive = isActive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(buttonForegroundColor)
                .frame(width: 44, height: 32)
                .background(buttonBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private var buttonForegroundColor: Color {
        if isActive {
            return .white
        } else {
            return colorScheme == .dark ? .white : .black
        }
    }
    
    private var buttonBackgroundColor: Color {
        if isActive {
            return .accentColor
        } else if isPressed {
            return colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Picker Views (to be shown as overlays by parent)

struct IOSColorPicker: View {
    let title: String
    let colors: [Color]
    let onColorSelect: (Color) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        ColorButton(color: color, onSelect: { onColorSelect(color) })
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
        )
        .frame(height: 75)
    }
}

struct IOSAlignmentPicker: View {
    let onAlignment: (TextAlignment) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            IOSToolbarButton(icon: "text.alignleft") { onAlignment(.leading) }
            IOSToolbarButton(icon: "text.aligncenter") { onAlignment(.center) }
            IOSToolbarButton(icon: "text.alignright") { onAlignment(.trailing) }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
        )
        .frame(height: 50)
    }
}

// Re-add the missing ColorButton helper view
private struct ColorButton: View {
    let color: Color
    let onSelect: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onSelect) {
            Group {
                if color == .clear {
                    ZStack {
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                            .frame(width: 32, height: 32)
                        
                        Path { path in
                            path.move(to: CGPoint(x: 8, y: 8))
                            path.addLine(to: CGPoint(x: 24, y: 24))
                        }
                        .stroke(Color.red, lineWidth: 2)
                    }
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - UIKit Integration
class IOSFormattingToolbarHostingController: UIHostingController<IOSTextFormattingToolbar> {
    init(toolbar: IOSTextFormattingToolbar) {
        super.init(rootView: toolbar)
        
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        // Use preferredContentSize, not intrinsicContentSize
        self.preferredContentSize = CGSize(width: UIScreen.main.bounds.width, height: 50)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif 