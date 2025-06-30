#if os(iOS)
import SwiftUI
import UIKit

// MARK: - iOS Text Formatting Toolbar (Keyboard Accessory)
struct IOSTextFormattingToolbar: View {
    let onTextStyle: (String) -> Void
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onLink: () -> Void
    let onTextColor: (Color) -> Void
    let onHighlight: (Color) -> Void
    let onBulletList: () -> Void
    let onAlignment: (TextAlignment) -> Void
    let onBookmark: () -> Void
    
    // Active state properties
    let currentTextStyle: String?
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let hasLink: Bool
    let hasBulletList: Bool
    let hasTextColor: Bool
    let hasHighlight: Bool
    let hasBookmark: Bool
    let currentTextColor: Color?
    let currentHighlightColor: Color?
    
    @State private var showStylePicker = false
    @State private var showColorPicker = false
    @State private var showHighlightPicker = false
    @State private var showAlignmentPicker = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if showStylePicker {
                InlineStylePickerView(
                    currentStyle: currentTextStyle,
                    onStyleSelect: { style in
                        onTextStyle(style)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStylePicker = false
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStylePicker = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity.animation(.easeIn(duration: 0.15)))
                ))
            } else if showColorPicker {
                InlineColorPickerView(
                    title: "Text Color",
                    colors: [.clear, .gray, .red, .orange, .brown, .pink, .blue, .green, .purple],
                    onColorSelect: { color in
                        onTextColor(color)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showColorPicker = false
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showColorPicker = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity.animation(.easeIn(duration: 0.15)))
                ))
            } else if showHighlightPicker {
                InlineColorPickerView(
                    title: "Highlighter",
                    colors: [.clear, .yellow, .green, .blue, .pink, .purple, .orange],
                    onColorSelect: { color in
                        onHighlight(color)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showHighlightPicker = false
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showHighlightPicker = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity.animation(.easeIn(duration: 0.15)))
                ))
            } else if showAlignmentPicker {
                InlineAlignmentPickerView(
                    onAlignment: { alignment in
                        onAlignment(alignment)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAlignmentPicker = false
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAlignmentPicker = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity.animation(.easeIn(duration: 0.15)))
                ))
            } else {
                // Main toolbar
                MainToolbarView(
                    currentTextStyle: currentTextStyle,
                    isBold: isBold,
                    isItalic: isItalic,
                    isUnderlined: isUnderlined,
                    hasLink: hasLink,
                    hasBulletList: hasBulletList,
                    hasTextColor: hasTextColor,
                    hasHighlight: hasHighlight,
                    hasBookmark: hasBookmark,
                    currentTextColor: currentTextColor,
                    currentHighlightColor: currentHighlightColor,
                    onShowStylePicker: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStylePicker = true
                        }
                    },
                    onBold: onBold,
                    onItalic: onItalic,
                    onUnderline: onUnderline,
                    onLink: onLink,
                    onBulletList: onBulletList,
                    onShowColorPicker: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showColorPicker = true
                        }
                    },
                    onShowHighlightPicker: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showHighlightPicker = true
                        }
                    },
                    onShowAlignmentPicker: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAlignmentPicker = true
                        }
                    },
                    onBookmark: onBookmark
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity.animation(.easeOut(duration: 0.15)))
                ))
            }
        }
        .frame(maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Supporting Views
private struct MainToolbarView: View {
    let currentTextStyle: String?
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let hasLink: Bool
    let hasBulletList: Bool
    let hasTextColor: Bool
    let hasHighlight: Bool
    let hasBookmark: Bool
    let currentTextColor: Color?
    let currentHighlightColor: Color?
    let onShowStylePicker: () -> Void
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onLink: () -> Void
    let onBulletList: () -> Void
    let onShowColorPicker: () -> Void
    let onShowHighlightPicker: () -> Void
    let onShowAlignmentPicker: () -> Void
    let onBookmark: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Left Group: Text Style - Style, Bold, Italic, Underline
                HStack(spacing: 12) {
                    IOSTextButton(text: currentTextStyle ?? "Style", isActive: currentTextStyle != nil && currentTextStyle != "Body", action: onShowStylePicker)
                    IOSTextButton(text: "Bold", isBold: true, isActive: isBold, action: onBold)
                    IOSTextButton(text: "Italic", isItalic: true, isActive: isItalic, action: onItalic)
                    IOSTextButton(text: "Underline", isUnderlined: true, isActive: isUnderlined, action: onUnderline)
                }
                
                // Separator 1
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 20)
                
                // Center Group: Text Enhancement - Text Color, Highlighter, Bookmark
                HStack(spacing: 12) {
                    IOSTextButton(text: "Text Color", isActive: hasTextColor, action: onShowColorPicker)
                    IOSTextButton(text: "Highlighter", isActive: hasHighlight, action: onShowHighlightPicker)
                    IOSTextButton(text: "Bookmark", isActive: hasBookmark, action: onBookmark)
                }
                
                // Separator 2
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 20)
                
                // Right Group: Structure - Link, Bullet, Alignment
                HStack(spacing: 12) {
                    IOSTextButton(text: "Link", isActive: hasLink, action: onLink)
                    IOSTextButton(text: "Bullet", isActive: hasBulletList, action: onBulletList)
                    IOSTextButton(text: "Alignment", action: onShowAlignmentPicker)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground).opacity(0.95))
    }
}

private struct InlineColorPickerView: View {
    let title: String
    let colors: [Color]
    let onColorSelect: (Color) -> Void
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                )
            }
            
            // Title
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            // Color options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { color in
                        InlineColorButton(color: color, onSelect: { onColorSelect(color) })
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 8)
        .background(Color(UIColor.systemBackground))
    }
}

private struct InlineAlignmentPickerView: View {
    let onAlignment: (TextAlignment) -> Void
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                )
            }
            
            // Title
            Text("Alignment")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            // Alignment options
            HStack(spacing: 8) {
                IOSToolbarButton(icon: "text.alignleft") { onAlignment(.leading) }
                IOSToolbarButton(icon: "text.aligncenter") { onAlignment(.center) }
                IOSToolbarButton(icon: "text.alignright") { onAlignment(.trailing) }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 8)
        .background(Color(UIColor.systemBackground))
    }
}

private struct InlineStylePickerView: View {
    let currentStyle: String?
    let onStyleSelect: (String) -> Void
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private let styles = ["Title", "Heading", "Strong", "Body", "Caption"]
    
    var body: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                )
            }
            
            // Title
            Text("Style")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            // Style options
            HStack(spacing: 8) {
                ForEach(styles, id: \.self) { style in
                    IOSTextButton(
                        text: style,
                        isActive: currentStyle == style,
                        action: { onStyleSelect(style) }
                    )
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 8)
        .background(Color(UIColor.systemBackground))
    }
}

private struct InlineColorButton: View {
    let color: Color
    let onSelect: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onSelect) {
            Group {
                if color == .clear {
                    // Clear/default color button - improved design
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .frame(width: 28, height: 28)
                        
                        Circle()
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        
                        // Diagonal line through circle
                        Path { path in
                            path.move(to: CGPoint(x: 8, y: 8))
                            path.addLine(to: CGPoint(x: 20, y: 20))
                        }
                        .stroke(Color.red, lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                    }
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .frame(width: 36, height: 36) // Larger tap target
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            // Instant response - no animation delay
            isPressed = pressing
        }, perform: {})
    }
}

private struct IOSTextButton: View {
    let text: String
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let textColor: Color?
    let highlightColor: Color?
    let isActive: Bool
    let action: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    init(text: String, isBold: Bool = false, isItalic: Bool = false, isUnderlined: Bool = false, 
         textColor: Color? = nil, highlightColor: Color? = nil, isActive: Bool = false, action: @escaping () -> Void) {
        self.text = text
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.textColor = textColor
        self.highlightColor = highlightColor
        self.isActive = isActive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: isBold ? .bold : .medium))
                .italic(isItalic)
                .underline(isUnderlined)
                .foregroundColor(textColor ?? buttonForegroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(highlightColor ?? buttonBackgroundColor)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            // Instant response - no animation delay
            isPressed = pressing
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
            return .blue
        } else if isPressed {
            return colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2)
        } else {
            return Color.gray.opacity(0.1)
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
                .frame(width: 48, height: 36)
                .background(buttonBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            // Instant response - no animation delay
            isPressed = pressing
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
            return .blue
        } else if isPressed {
            return colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
}

// MARK: - UIKit Integration
class IOSFormattingToolbarHostingController: UIHostingController<IOSTextFormattingToolbar> {
    private var strokeView: UIView?
    
    init(toolbar: IOSTextFormattingToolbar) {
        super.init(rootView: toolbar)
        
        // Configure for keyboard accessory - completely flush with keyboard
        view.backgroundColor = UIColor.systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Set a preferred content size to give iOS a hint about our desired dimensions
        // This helps prevent layout conflicts while still being flexible
        preferredContentSize = CGSize(width: 0, height: 50)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        
        // Ensure no margins or safe area insets
        view.insetsLayoutMarginsFromSafeArea = false
        if #available(iOS 11.0, *) {
            additionalSafeAreaInsets = UIEdgeInsets.zero
        }
        
        // Set up flexible height constraints to avoid conflicts
        setupFlexibleConstraints()
        
        // Add stroke at the top of the toolbar
        setupStroke()
    }
    
    private func setupFlexibleConstraints() {
        // Don't add any height constraints - let the keyboard system handle sizing
        // This prevents the constraint conflicts we were seeing
        // The preferredContentSize provides a hint to the system about our desired height
    }
    
    private func setupStroke() {
        // Remove existing stroke if any
        strokeView?.removeFromSuperview()
        
        // Create stroke view
        let stroke = UIView()
        stroke.backgroundColor = UIColor.label.withAlphaComponent(0.1)
        stroke.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stroke)
        
        // Position stroke at the very top of the toolbar
        NSLayoutConstraint.activate([
            stroke.topAnchor.constraint(equalTo: view.topAnchor),
            stroke.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stroke.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stroke.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        strokeView = stroke
    }
}

#endif 