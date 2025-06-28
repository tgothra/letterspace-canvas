#if os(iOS)
import SwiftUI
import UIKit

// MARK: - iOS Text Formatting Toolbar (Keyboard Accessory)
struct IOSTextFormattingToolbar: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onLink: () -> Void
    let onTextColor: (Color) -> Void
    let onHighlight: (Color) -> Void
    let onBulletList: () -> Void
    let onAlignment: (TextAlignment) -> Void
    let onDismiss: () -> Void
    
    // Active state properties
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let hasLink: Bool
    let hasBulletList: Bool
    
    @State private var showColorPicker = false
    @State private var showHighlightPicker = false
    @State private var showAlignmentPicker = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // Basic formatting
            FormattingGroup {
                IOSToolbarButton(icon: "bold", isActive: isBold, action: onBold)
                IOSToolbarButton(icon: "italic", isActive: isItalic, action: onItalic)
                IOSToolbarButton(icon: "underline", isActive: isUnderlined, action: onUnderline)
            }
            
            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)
            
            // Text styling
            FormattingGroup {
                IOSToolbarButton(icon: "textformat", isActive: showColorPicker) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        showColorPicker.toggle()
                        showHighlightPicker = false
                        showAlignmentPicker = false
                    }
                }
                IOSToolbarButton(icon: "highlighter", isActive: showHighlightPicker) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        showHighlightPicker.toggle()
                        showColorPicker = false
                        showAlignmentPicker = false
                    }
                }
                IOSToolbarButton(icon: "link", isActive: hasLink, action: onLink)
            }
            
            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)
            
            // Lists and alignment
            FormattingGroup {
                IOSToolbarButton(icon: "list.bullet", isActive: hasBulletList, action: onBulletList)
                IOSToolbarButton(icon: "text.alignleft", isActive: showAlignmentPicker) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        showAlignmentPicker.toggle()
                        showColorPicker = false
                        showHighlightPicker = false
                    }
                }
            }
            
            Spacer()
            
            // Dismiss button
            IOSToolbarButton(icon: "keyboard.chevron.compact.down", action: onDismiss)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .frame(height: 0.5)
                        .frame(maxHeight: .infinity, alignment: .top)
                )
        )
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if showColorPicker {
                    ColorPickerSection(
                        title: "Text Color",
                        colors: [.black, .gray, .red, .orange, .brown, .pink, .blue, .green, .purple],
                        onColorSelect: { color in
                            onTextColor(color)
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                showColorPicker = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                if showHighlightPicker {
                    ColorPickerSection(
                        title: "Highlight",
                        colors: [.clear, .yellow, .green, .blue, .pink, .purple, .orange],
                        onColorSelect: { color in
                            onHighlight(color)
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                showHighlightPicker = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                if showAlignmentPicker {
                    AlignmentPickerSection(onAlignment: { alignment in
                        onAlignment(alignment)
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            showAlignmentPicker = false
                        }
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .offset(y: -50) // Position above the toolbar
        }
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
        .contentShape(Rectangle())
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

private struct ColorPickerSection: View {
    let title: String
    let colors: [Color]
    let onColorSelect: (Color) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        ColorButton(color: color, onSelect: { onColorSelect(color) })
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            Rectangle()
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.95))
                .overlay(
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .frame(height: 0.5)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: -2)
        .contentShape(Rectangle())
    }
}

private struct ColorButton: View {
    let color: Color
    let onSelect: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onSelect) {
            Group {
                if color == .clear {
                    // Clear/default color button
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
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

private struct AlignmentPickerSection: View {
    let onAlignment: (TextAlignment) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Text("Alignment")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))

            HStack(spacing: 16) {
                IOSToolbarButton(icon: "text.alignleft") { onAlignment(.leading) }
                IOSToolbarButton(icon: "text.aligncenter") { onAlignment(.center) }
                IOSToolbarButton(icon: "text.alignright") { onAlignment(.trailing) }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            Rectangle()
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.95))
                .overlay(
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .frame(height: 0.5)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: -2)
        .contentShape(Rectangle())
    }
}

// MARK: - UIKit Integration
class IOSFormattingToolbarHostingController: UIHostingController<IOSTextFormattingToolbar> {
    init(toolbar: IOSTextFormattingToolbar) {
        super.init(rootView: toolbar)
        
        // Configure for keyboard accessory
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Set intrinsic content size (will be updated dynamically)
        preferredContentSize = CGSize(width: UIScreen.main.bounds.width, height: 50)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear
    }
    
    func updateHeight(to height: CGFloat) {
        preferredContentSize = CGSize(width: UIScreen.main.bounds.width, height: height)
    }
}

#endif 