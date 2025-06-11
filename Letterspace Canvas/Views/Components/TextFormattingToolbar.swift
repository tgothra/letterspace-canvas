import SwiftUI

private func makeToolbarBackground(colorScheme: ColorScheme) -> some View {
    RoundedRectangle(cornerRadius: 10)
        .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : .white)
}

private func makeToolbarBorder(colorScheme: ColorScheme) -> some View {
    RoundedRectangle(cornerRadius: 10)
        .strokeBorder(
            colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05),
            lineWidth: 0.5
        )
}

private func makePopoverBackground(colorScheme: ColorScheme, cornerRadius: CGFloat = 16) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius)
        .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : .white)
}

private func makePopoverBorder(colorScheme: ColorScheme, cornerRadius: CGFloat = 16) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(
            colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05),
            lineWidth: 0.5
        )
}

private struct ModernPopupEffect: ViewModifier {
    let isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPresented ? 1 : 0.95, anchor: .top)
            .offset(y: isPresented ? 0 : -10)
            .blur(radius: isPresented ? 0 : 4)
            .opacity(isPresented ? 1 : 0)
            .animation(
                .spring(
                    response: 0.3,
                    dampingFraction: 0.7,
                    blendDuration: 0.2
                ),
                value: isPresented
            )
    }
}

extension View {
    func modernPopup(isPresented: Bool) -> some View {
        modifier(ModernPopupEffect(isPresented: isPresented))
    }
}

private struct ColorButton: View {
    let icon: String?
    let color: Color
    let isDefaultColor: Bool
    let onSelect: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    init(icon: String? = nil, color: Color, isDefaultColor: Bool = false, onSelect: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.isDefaultColor = isDefaultColor
        self.onSelect = onSelect
    }
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 20, height: 20)
                    .background(isHovering ? 
                        (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)) : 
                        Color.clear)
                    .clipShape(Circle())
            } else if isDefaultColor {
                // Enhanced "clear" button for better visibility against white background
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    
                    // Diagonal line to indicate "clear"
                    Path { path in
                        path.move(to: CGPoint(x: 6, y: 6))
                        path.addLine(to: CGPoint(x: 14, y: 14))
                    }
                    .stroke(Color.red, lineWidth: 1.5)
                }
                .frame(width: 20, height: 20)
                .background(isHovering ? 
                    (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)) : 
                    Color.clear)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(isHovering ? 
                                (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)) : 
                                Color.clear, 
                                lineWidth: 2)
                    )
            }
        }
        .contentShape(Circle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
        .frame(width: 24, height: 28)
    }
}

private struct ColorPickerOverlay: View {
    let colors: [Color]
    let onColorSelect: (Color) -> Void
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            ToolbarButton(icon: "chevron.left") {
                onBack()
            }
            .frame(width: 28)
            .padding(.leading, 2)
            
            ToolbarDivider()
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
            
            Spacer(minLength: 4)
            
            HStack(spacing: 4) {
                ForEach(colors, id: \.self) { color in
                    Group {
                        if color == .clear {
                            ColorButton(
                                color: color,
                                isDefaultColor: true,
                                onSelect: { onColorSelect(color) }
                            )
                        } else {
                            ColorButton(
                                color: color,
                                onSelect: { onColorSelect(color) }
                            )
                        }
                    }
                }
            }
            
            Spacer(minLength: 4)
        }
    }
}

private struct ColorPickerSection: View {
    let colors: [Color]
    let onColorSelect: (Color) -> Void
    @Binding var isVisible: Bool
    let onToggle: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ToolbarButton(icon: "paintbrush.fill") {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onToggle()
            }
        }
        .overlay(alignment: .top) {
            if isVisible {
                ColorPickerOverlay(colors: colors, onColorSelect: { color in
                    onColorSelect(color)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isVisible = false
                    }
                }, onBack: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isVisible = false
                    }
                })
                .offset(y: 36)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
            }
        }
    }
}

private struct HighlightPickerSection: View {
    let colors: [Color]
    let onColorSelect: (Color) -> Void
    @Binding var isVisible: Bool
    let onToggle: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ToolbarButton(icon: "scribble") {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onToggle()
            }
        }
        .overlay(alignment: .top) {
            if isVisible {
                ColorPickerOverlay(
                    colors: colors + [.clear],
                    onColorSelect: { color in
                        onColorSelect(color)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isVisible = false
                        }
                    },
                    onBack: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isVisible = false
                        }
                    }
                )
                .offset(y: 36)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
            }
        }
    }
}

// --- NEW TEXT STYLE OVERLAY ---
private struct TextStyleOverlay: View {
    let styles = ["Title", "Heading", "Strong", "Body", "Caption"]
    let onStyleSelect: (String) -> Void
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ToolbarButton(icon: "chevron.left") {
                onBack()
            }
            .frame(width: 28)
            .padding(.leading, 2)

            ToolbarDivider()
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))

            Spacer(minLength: 2)

            HStack(spacing: 1) {
                ForEach(styles, id: \.self) { styleName in
                    ToolbarButton(text: styleName) {
                        onStyleSelect(styleName)
                    }
                    .help("Apply \(styleName) Style")
                }
            }

            Spacer(minLength: 2)
        }
    }
}
// --- END NEW TEXT STYLE OVERLAY ---

private struct BasicFormattingSection: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    
    var body: some View {
        Group {
            ToolbarButton(icon: "bold", isActive: isBold, action: onBold)
                .help("Bold (⌘B)")
                .onHover { hovering in print("Hovering Bold button: \(hovering)") }
            ToolbarButton(icon: "italic", isActive: isItalic, action: onItalic)
                .help("Italic (⌘I)")
            ToolbarButton(icon: "underline", isActive: isUnderlined, action: onUnderline)
                .help("Underline (⌘U)")
        }
    }
}

private struct ListSection: View {
    let onBulletList: () -> Void
    let hasBulletList: Bool
    
    var body: some View {
        Group {
            ToolbarButton(icon: "list.bullet", isActive: hasBulletList, action: onBulletList)
                .help("Bullet List")
        }
    }
}

private struct ToolbarDivider: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 2)
            .opacity(colorScheme == .dark ? 0.9 : 0.8)
    }
}

public struct TextFormattingToolbar: View {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onLink: () -> Void
    let onTextColor: (Color) -> Void
    let onHighlight: (Color) -> Void
    let onBulletList: () -> Void
    let onTextStyleSelect: (String) -> Void
    let onAlignment: (TextAlignment) -> Void
    let onBookmark: () -> Void
    
    // Add active state properties
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let hasLink: Bool
    let currentTextColor: Color?
    let currentHighlightColor: Color?
    let hasBulletList: Bool
    let isBookmarked: Bool
    let currentAlignment: TextAlignment?
    
    @State private var isTextColorMenuOpen = false
    @State private var isHighlightMenuOpen = false
    @State private var isTextStyleMenuOpen = false
    @State private var isAlignmentMenuOpen = false
    @State private var isTextColorButtonHovering = false
    @State private var isHighlightButtonHovering = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var theme
    
    public init(
        onBold: @escaping () -> Void,
        onItalic: @escaping () -> Void,
        onUnderline: @escaping () -> Void,
        onLink: @escaping () -> Void,
        onTextColor: @escaping (Color) -> Void,
        onHighlight: @escaping (Color) -> Void,
        onBulletList: @escaping () -> Void,
        onTextStyleSelect: @escaping (String) -> Void,
        onAlignment: @escaping (TextAlignment) -> Void,
        onBookmark: @escaping () -> Void,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        hasLink: Bool = false,
        currentTextColor: Color? = nil,
        currentHighlightColor: Color? = nil,
        hasBulletList: Bool = false,
        isBookmarked: Bool = false,
        currentAlignment: TextAlignment? = nil
    ) {
        self.onBold = onBold
        self.onItalic = onItalic
        self.onUnderline = onUnderline
        self.onLink = onLink
        self.onTextColor = onTextColor
        self.onHighlight = onHighlight
        self.onBulletList = onBulletList
        self.onTextStyleSelect = onTextStyleSelect
        self.onAlignment = onAlignment
        self.onBookmark = onBookmark
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.hasLink = hasLink
        self.currentTextColor = currentTextColor
        self.currentHighlightColor = currentHighlightColor
        self.hasBulletList = hasBulletList
        self.isBookmarked = isBookmarked
        self.currentAlignment = currentAlignment
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            if isTextColorMenuOpen {
                // Text Color Picker View
                ColorPickerOverlay(
                    colors: [
                        .clear,  // Default color button
                        .gray,
                        .red,
                        .orange,
                        .brown,
                        .pink,
                        .blue,
                        .green,
                        .purple
                    ],
                    onColorSelect: { color in
                        onTextColor(color)
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            isTextColorMenuOpen = false
                        }
                    },
                    onBack: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            isTextColorMenuOpen = false
                        }
                    }
                )
            } else if isHighlightMenuOpen {
                // Highlight Color Picker View
                ColorPickerOverlay(
                    colors: [
                        .clear,
                        .yellow,
                        .green,
                        .blue,
                        .pink,
                        .purple,
                        .orange
                    ],
                    onColorSelect: { color in
                        onHighlight(color)
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            isHighlightMenuOpen = false
                        }
                    },
                    onBack: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            isHighlightMenuOpen = false
                        }
                    }
                )
            } else if isTextStyleMenuOpen {
                TextStyleOverlay(
                    onStyleSelect: { styleName in
                        onTextStyleSelect(styleName)
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            isTextStyleMenuOpen = false
                        }
                    },
                    onBack: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            isTextStyleMenuOpen = false
                        }
                    }
                )
            } else {
                // Regular Toolbar View
                // Text Style Group
                BasicFormattingSection(
                    onBold: onBold,
                    onItalic: onItalic,
                    onUnderline: onUnderline,
                    isBold: isBold,
                    isItalic: isItalic,
                    isUnderlined: isUnderlined
                )
                ToolbarDivider()
                // --- INSERT MISSING TEXT COLOR BUTTON HERE ---
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isTextColorMenuOpen.toggle()
                        if isTextColorMenuOpen {
                            isHighlightMenuOpen = false
                            isAlignmentMenuOpen = false // Close other menus
                        }
                    }
                } label: {
                     // Define isColorActive here, outside the Group, so it's in scope for the modifier
                     let isColorActive = currentTextColor != nil && currentTextColor != .clear // Assuming .clear represents default

                     Group {
                         if let color = currentTextColor, isColorActive {
                             // Display selected color
                             Circle()
                                 .fill(color)
                                 .frame(width: 16, height: 16) // Slightly smaller circle
                                 .overlay(
                                     // Subtle border to distinguish white/light colors
                                     Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                                 )
                         } else {
                             // Display default icon
                             Image(systemName: "paintbrush.fill")
                         }
                     }
                     // Ensure default icon is black in light mode, white in dark mode
                     .foregroundColor(isColorActive ? .blue : (colorScheme == .light ? .black : .white))
                     .frame(width: 24, height: 28) // Match ToolbarButton size
                     .background( // Mimic ToolbarButton background states
                         RoundedRectangle(cornerRadius: 6)
                             .fill(
                                 isTextColorMenuOpen ? Color.blue.opacity(0.1) : // Use menu open state as active state
                                 isTextColorButtonHovering ? Color.blue.opacity(0.08) : // Hover effect
                                 Color.clear
                             )
                     )
                }
                .buttonStyle(.plain)
                .onHover { isTextColorButtonHovering = $0 }
                .help("Text Color") // Tooltip for Text Color
                // --- END INSERTED TEXT COLOR BUTTON ---
                
                // --- RE-INSERT HIGHLIGHT BUTTON HERE ---
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isHighlightMenuOpen.toggle()
                        if isHighlightMenuOpen {
                            isTextColorMenuOpen = false
                            isAlignmentMenuOpen = false // Close other menus
                        }
                    }
                } label: {
                    Image(systemName: "highlighter")
                        // .foregroundColor(.yellow) // Use adaptive color
                        .frame(width: 24, height: 28) // Match ToolbarButton size
                        .background( // Mimic ToolbarButton background states
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    isHighlightMenuOpen ? (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)) :
                                    isHighlightButtonHovering ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)) : // Hover effect
                                    Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHighlightButtonHovering = $0 }
                .help("Highlight") // Tooltip for Highlight
                // --- END RE-INSERTED HIGHLIGHT BUTTON ---

                ToolbarDivider()
                
                // MOVE LINK/BOOKMARK BUTTONS HERE
                ToolbarButton(icon: "link", isActive: hasLink) {
                    onLink()
                }
                .help("Insert Link (⌘K)") // Tooltip for Link

                ToolbarButton(icon: "bookmark", isActive: isBookmarked) {
                    print("🔖📢 BOOKMARK BUTTON CLICKED in TextFormattingToolbar")
                    onBookmark()
                }
                .help("Add Bookmark") // Tooltip for Bookmark
                // END MOVED LINK/BOOKMARK BUTTONS

                ToolbarDivider()

                // Text Style Button (Replaces Text Size)
                ToolbarButton(icon: "textformat") {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isTextStyleMenuOpen.toggle()
                        if isTextStyleMenuOpen {
                            isTextColorMenuOpen = false
                            isHighlightMenuOpen = false
                            isAlignmentMenuOpen = false
                        }
                    }
                }
                .help("Text Style") // Updated tooltip

                // Lists Group
                ListSection(
                    onBulletList: onBulletList,
                    hasBulletList: hasBulletList
                )
                .help("Bullet List")

                // Text Size and Alignment Group - NOW ONLY ALIGNMENT
                Group {
                    // Text Size Button - Direct Action - USE ICON INSTEAD OF TEXT -- REMOVED
                    // ToolbarButton(icon: "textformat.size") { ... }

                    // Alignment Button (Tooltip added in AlignmentSection)
                    AlignmentSection(
                        onAlignment: onAlignment,
                        isVisible: $isAlignmentMenuOpen,
                        currentAlignment: currentAlignment
                    )
                    .help("Text Alignment")
                }
            }
        }
        .scaleEffect(1.05)
        .frame(width: 300 * 1.05)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isTextColorMenuOpen)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHighlightMenuOpen)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isTextStyleMenuOpen)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAlignmentMenuOpen)
        .onAppear {
            print("Current colorScheme: \(colorScheme == .dark ? "dark" : "light")")
        }
        .onDisappear {
            // Reset all states when the toolbar disappears
            isTextColorMenuOpen = false
            isHighlightMenuOpen = false
            isTextStyleMenuOpen = false
            isAlignmentMenuOpen = false
        }
    }
}

private struct ButtonFrame: Equatable {
    let id: String
    let frame: CGRect
}

private struct ButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: [ButtonFrame] = []
    
    static func reduce(value: inout [ButtonFrame], nextValue: () -> [ButtonFrame]) {
        value.append(contentsOf: nextValue())
    }
}

// Helper types for view positioning
private struct ViewPosition: Equatable {
    let id: String
    let frame: CGRect
}

private struct ViewPositionKey: PreferenceKey {
    static var defaultValue: [ViewPosition] = []
    
    static func reduce(value: inout [ViewPosition], nextValue: () -> [ViewPosition]) {
        value.append(contentsOf: nextValue())
    }
}

private struct ToolbarButton: View {
    let icon: String?
    let text: String?
    let action: () -> Void
    let isActive: Bool
    @State private var isHovering = false
    @State private var isPressed = false
    @State private var localIsActive: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    init(icon: String? = nil, text: String? = nil, isActive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.text = text
        self.isActive = isActive
        self.action = action
        self._localIsActive = State(initialValue: isActive)
    }
    
    var body: some View {
        // Use a ZStack approach instead of Button for more control
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isPressed ? Color.blue.opacity(0.2) :
                    isHovering ? Color.blue.opacity(0.08) : // Always use blue for hover
                    localIsActive ? Color.blue.opacity(0.1) : // Use blue for active state
                    Color.clear
                )
            
            // Content
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(localIsActive ? .blue : .black)
                    .frame(width: 24, height: 28)
            } else if let text = text {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(localIsActive ? .blue : .black)
                    .frame(width: 45, height: 24)
                    .padding(.horizontal, 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Toggle local active state immediately
            localIsActive.toggle()
            // Execute action
            action()
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            localIsActive = isActive
        }
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

private func emptyAction() { }
private func colorAction(_ color: Color) { }
private func sizeAction(_ size: CGFloat) { }
private func alignmentAction(_ alignment: TextAlignment) { }

#Preview("Light Mode Example") {
    TextFormattingToolbar(
        onBold: emptyAction,
        onItalic: emptyAction,
        onUnderline: emptyAction,
        onLink: emptyAction,
        onTextColor: colorAction,
        onHighlight: colorAction,
        onBulletList: emptyAction,
        onTextStyleSelect: { style in print("Style selected: \(style)") },
        onAlignment: alignmentAction,
        onBookmark: emptyAction,
        isBold: false,
        isItalic: true,
        isUnderlined: false,
        hasLink: false,
        currentTextColor: .red,
        currentHighlightColor: nil,
        hasBulletList: true,
        isBookmarked: false,
        currentAlignment: nil
    )
    .padding()
    .environment(\.colorScheme, .light)
}

#Preview("Dark Mode Example") {
    TextFormattingToolbar(
        onBold: emptyAction,
        onItalic: emptyAction,
        onUnderline: emptyAction,
        onLink: emptyAction,
        onTextColor: colorAction,
        onHighlight: colorAction,
        onBulletList: emptyAction,
        onTextStyleSelect: { style in print("Style selected: \(style)") },
        onAlignment: alignmentAction,
        onBookmark: emptyAction,
        isBold: true,
        isItalic: false,
        isUnderlined: false,
        hasLink: true,
        currentTextColor: nil,
        currentHighlightColor: .yellow,
        hasBulletList: false,
        isBookmarked: true,
        currentAlignment: nil
    )
    .padding()
    .background(Color.black)
    .environment(\.colorScheme, .dark)
}

private struct TextSizeSection: View {
    let onTextSize: (CGFloat) -> Void
    @Binding var isVisible: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ToolbarButton(icon: "textformat") {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isVisible.toggle()
            }
        }
        .overlay(alignment: .top) {
            if isVisible {
                VStack(spacing: 4) {
                    Text("Text Size")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                        .padding(.top, 8)
                    
                    ForEach([
                        ("Small", CGFloat(12)),
                        ("Normal", CGFloat(15)),
                        ("Large", CGFloat(18)),
                        ("Extra Large", CGFloat(24))
                    ], id: \.0) { name, size in
                        Button {
                            onTextSize(size)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isVisible = false
                            }
                        } label: {
                            Text(name)
                                .font(.system(size: 13))
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
                .frame(width: 140)
                .background(makePopoverBackground(colorScheme: colorScheme))
                .overlay(makePopoverBorder(colorScheme: colorScheme))
                .offset(y: 45)
                .modernPopup(isPresented: isVisible)
            }
        }
        .help("Cycle Text Size")
    }
}

private struct AlignmentSection: View {
    let onAlignment: (TextAlignment) -> Void
    @Binding var isVisible: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // Add a property for the current alignment
    let currentAlignment: TextAlignment?
    
    @State private var internalAlignment: TextAlignment = .leading
    @State private var isHovering = false
    
    // Update internal state when initialized or when currentAlignment changes
    private func updateInternalAlignment() {
        if let alignment = currentAlignment {
            internalAlignment = alignment
        }
    }
    
    private func cycleAlignment() {
        // Cycle through alignments: left -> center -> right -> left
        switch internalAlignment {
        case .leading:
            internalAlignment = .center
        case .center:
            internalAlignment = .trailing
        case .trailing:
            internalAlignment = .leading
        }
        
        // Apply the new alignment
        onAlignment(internalAlignment)
    }
    
    private func getAlignmentIcon() -> String {
        switch internalAlignment {
        case .leading:
            return "text.alignleft"
        case .center:
            return "text.aligncenter"
        case .trailing:
            return "text.alignright"
        }
    }
    
    var body: some View {
        Button {
            // Cycle to the next alignment
            cycleAlignment()
        } label: {
            Image(systemName: getAlignmentIcon())
                .foregroundColor(colorScheme == .light ? .black : .white)
                .frame(width: 24, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            isHovering ? Color.blue.opacity(0.08) : // Changed to blue for consistent hover
                                Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Text Alignment")
        .onAppear {
            updateInternalAlignment()
        }
        .onChange(of: currentAlignment) {
            updateInternalAlignment()
        }
    }
}


