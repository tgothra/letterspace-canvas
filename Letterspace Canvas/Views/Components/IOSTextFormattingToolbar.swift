#if os(iOS)
import SwiftUI
import UIKit

// MARK: - iOS 26 Enhanced Text Formatting Toolbar
struct IOSTextFormattingToolbar: View {
    let onTextStyle: (String) -> Void
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onLink: () -> Void
    let onLinkCreate: (String, String) -> Void
    let onLinkCreateWithStyle: ((String, String, UIColor, Bool) -> Void)?
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
    @State private var showLinkPicker = false
    
    // iOS 26 Enhancement: Advanced gesture state tracking
    @State private var scrollVelocity: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?
    
    @Environment(\.colorScheme) var colorScheme
    
    // Custom initializer to handle optional onLinkCreateWithStyle parameter
    init(
        onTextStyle: @escaping (String) -> Void,
        onBold: @escaping () -> Void,
        onItalic: @escaping () -> Void,
        onUnderline: @escaping () -> Void,
        onLink: @escaping () -> Void,
        onLinkCreate: @escaping (String, String) -> Void,
        onLinkCreateWithStyle: ((String, String, UIColor, Bool) -> Void)? = nil,
        onTextColor: @escaping (Color) -> Void,
        onHighlight: @escaping (Color) -> Void,
        onBulletList: @escaping () -> Void,
        onAlignment: @escaping (TextAlignment) -> Void,
        onBookmark: @escaping () -> Void,
        currentTextStyle: String?,
        isBold: Bool,
        isItalic: Bool,
        isUnderlined: Bool,
        hasLink: Bool,
        hasBulletList: Bool,
        hasTextColor: Bool,
        hasHighlight: Bool,
        hasBookmark: Bool,
        currentTextColor: Color?,
        currentHighlightColor: Color?
    ) {
        self.onTextStyle = onTextStyle
        self.onBold = onBold
        self.onItalic = onItalic
        self.onUnderline = onUnderline
        self.onLink = onLink
        self.onLinkCreate = onLinkCreate
        self.onLinkCreateWithStyle = onLinkCreateWithStyle
        self.onTextColor = onTextColor
        self.onHighlight = onHighlight
        self.onBulletList = onBulletList
        self.onAlignment = onAlignment
        self.onBookmark = onBookmark
        self.currentTextStyle = currentTextStyle
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.hasLink = hasLink
        self.hasBulletList = hasBulletList
        self.hasTextColor = hasTextColor
        self.hasHighlight = hasHighlight
        self.hasBookmark = hasBookmark
        self.currentTextColor = currentTextColor
        self.currentHighlightColor = currentHighlightColor
    }
    
    var body: some View {
        MainToolbarView()
            .overlay(
                // iOS 26 Enhancement: Better modal presentations
                ZStack {
                    if showStylePicker {
                        StylePickerView()
                    }
                    if showColorPicker {
                        ColorPickerView()
                    }
                    if showHighlightPicker {
                        HighlightPickerView()
                    }
                    if showAlignmentPicker {
                        AlignmentPickerView()
                    }
                    if showLinkPicker {
                        LinkPickerView()
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showStylePicker)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showColorPicker)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showHighlightPicker)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showAlignmentPicker)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showLinkPicker)
            )
    }
    
    // MARK: - Main Toolbar View with iOS 26 Enhancements
    @ViewBuilder
    private func MainToolbarView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Styles section
                HStack(spacing: 12) {
                    IOSTextButton(text: currentTextStyle ?? "Normal", action: onShowStylePicker)
                    IOSToolbarButton(icon: "textformat.abc", action: onShowStylePicker)
                }
                
                // Separator 1
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 20)
                
                // Basic formatting
                HStack(spacing: 12) {
                    IOSToolbarButton(icon: "bold", isActive: isBold, action: onBold)
                    IOSToolbarButton(icon: "italic", isActive: isItalic, action: onItalic)
                    IOSToolbarButton(icon: "underline", isActive: isUnderlined, action: onUnderline)
                }
                
                // Separator 2
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 20)
                
                // Colors
                HStack(spacing: 12) {
                    IOSToolbarButton(icon: "textformat", isActive: hasTextColor, action: onShowColorPicker)
                    IOSToolbarButton(icon: "highlighter", isActive: hasHighlight, action: onShowHighlightPicker)
                }
                
                // Separator 3
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 20)
                
                // Actions
                HStack(spacing: 12) {
                    IOSTextButton(text: "Link", isActive: hasLink, action: onShowLinkPicker)
                    IOSTextButton(text: "Bullet", isActive: hasBulletList, action: onBulletList)
                    IOSTextButton(text: "Alignment", action: onShowAlignmentPicker)
                }
                
                // Separator 4
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 20)
                
                // Keyboard dismissal button with iOS 26 enhanced animation
                IOSToolbarButton(icon: "keyboard.chevron.compact.down") {
                    // iOS 26 Enhancement: Improved keyboard dismissal with haptic feedback
                    HapticFeedback.impact(.medium, intensity: 0.8)
                    
                    // iOS 26 Enhancement: Smooth dismissal animation
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        // iOS 26 Enhancement: Improved scroll behavior
        .scrollDisabled(false)
        .scrollBounceBehavior(.basedOnSize)
        .scrollTargetBehavior(.viewAligned)
        .coordinateSpace(name: "toolbar")
        // iOS 26 Enhancement: Advanced gesture tracking for better responsiveness
        .gesture(
            DragGesture()
                .onChanged { value in
                    let translation = value.translation
                    let currentOffset: CGFloat = translation.width
                    scrollVelocity = currentOffset - lastScrollOffset
                    lastScrollOffset = currentOffset
                    
                    // iOS 26 Enhancement: Velocity-based scroll feedback
                    if abs(scrollVelocity) > 5 {
                        // Provide subtle haptic feedback for fast scrolling
                        HapticFeedback.selection()
                    }
                }
                .onEnded { _ in
                    // Reset velocity tracking
                    scrollVelocity = 0
                    lastScrollOffset = 0
                }
        )
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground).opacity(0.95))
    }
    
    // MARK: - Action Handlers
    private func onShowStylePicker() {
        // iOS 26 Enhancement: Contextual haptic feedback
        HapticFeedback.impact(.light, intensity: 0.6)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showStylePicker.toggle()
            showColorPicker = false
            showHighlightPicker = false
            showAlignmentPicker = false
            showLinkPicker = false
        }
    }
    
    private func onShowColorPicker() {
        HapticFeedback.impact(.light, intensity: 0.6)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showColorPicker.toggle()
            showStylePicker = false
            showHighlightPicker = false
            showAlignmentPicker = false
            showLinkPicker = false
        }
    }
    
    private func onShowHighlightPicker() {
        HapticFeedback.impact(.light, intensity: 0.6)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showHighlightPicker.toggle()
            showStylePicker = false
            showColorPicker = false
            showAlignmentPicker = false
            showLinkPicker = false
        }
    }
    
    private func onShowAlignmentPicker() {
        HapticFeedback.impact(.light, intensity: 0.6)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showAlignmentPicker.toggle()
            showStylePicker = false
            showColorPicker = false
            showHighlightPicker = false
            showLinkPicker = false
        }
    }
    
    private func onShowLinkPicker() {
        HapticFeedback.impact(.light, intensity: 0.6)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showLinkPicker.toggle()
            showStylePicker = false
            showColorPicker = false
            showHighlightPicker = false
            showAlignmentPicker = false
        }
    }
}

// MARK: - Supporting Views
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
            .scrollBounceBehavior(.basedOnSize)
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



// Placeholder view that shows while modal is being presented
private struct LinkPickerPlaceholderView: View {
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
            
            Spacer()
            
            Text("Opening Link Editor...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 8)
        .background(Color(UIColor.systemBackground))
    }
}

// UIKit-based link picker view controller
private class LinkPickerViewController: UIViewController {
    private let onLinkCreate: (String, UIColor, Bool) -> Void
    private let onCancel: () -> Void
    private var textField: UITextField!
    private var colorStackView: UIStackView!
    private var underlineSwitch: UISwitch!
    private var selectedColorIndex = 0
    var onDismiss: (() -> Void)?
    
    private let linkColors: [(String, UIColor)] = [
        ("Blue", .systemBlue),
        ("Red", .systemRed),
        ("Green", .systemGreen),
        ("Purple", .systemPurple),
        ("Orange", .systemOrange)
    ]
    
    init(onLinkCreate: @escaping (String, UIColor, Bool) -> Void, onCancel: @escaping () -> Void) {
        self.onLinkCreate = onLinkCreate
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }
    

    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // If the view controller is being dismissed (not just covered by another view)
        if isBeingDismissed || isMovingFromParent {
            onDismiss?()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Add Link"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        // Create text field
        textField = UITextField()
        textField.placeholder = "Enter URL"
        textField.text = "https://"
        textField.keyboardType = .URL
        textField.autocapitalizationType = .none
        textField.borderStyle = .roundedRect
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        
        // Create color label
        let colorLabel = UILabel()
        colorLabel.text = "Link Color"
        colorLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        colorLabel.textColor = .label
        
        // Create color selection using buttons instead of segmented control
        colorStackView = UIStackView()
        colorStackView.axis = .horizontal
        colorStackView.distribution = .fillEqually
        colorStackView.spacing = 8
        colorStackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (index, (name, color)) in linkColors.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.backgroundColor = color
            button.layer.cornerRadius = 20
            button.layer.borderWidth = 2
            button.layer.borderColor = index == 0 ? UIColor.label.cgColor : UIColor.clear.cgColor
            button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
            
            // Add color name as accessibility label
            button.accessibilityLabel = name
            
            colorStackView.addArrangedSubview(button)
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 40),
                button.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
        
        // Create underline label
        let underlineLabel = UILabel()
        underlineLabel.text = "Underline"
        underlineLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        underlineLabel.textColor = .label
        
        // Create underline switch
        underlineSwitch = UISwitch()
        underlineSwitch.isOn = true // Default to underlined
        
        // Layout
        textField.translatesAutoresizingMaskIntoConstraints = false
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        underlineLabel.translatesAutoresizingMaskIntoConstraints = false
        underlineSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(textField)
        view.addSubview(colorLabel)
        view.addSubview(colorStackView)
        view.addSubview(underlineLabel)
        view.addSubview(underlineSwitch)
        
        NSLayoutConstraint.activate([
            // URL field
            textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textField.heightAnchor.constraint(equalToConstant: 44),
            
            // Color label
            colorLabel.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 24),
            colorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Color stack view
            colorStackView.topAnchor.constraint(equalTo: colorLabel.bottomAnchor, constant: 8),
            colorStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            colorStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            colorStackView.heightAnchor.constraint(equalToConstant: 40),
            
            // Underline label and switch
            underlineLabel.topAnchor.constraint(equalTo: colorStackView.bottomAnchor, constant: 24),
            underlineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            underlineSwitch.centerYAnchor.constraint(equalTo: underlineLabel.centerYAnchor),
            underlineSwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        updateDoneButton()
    }
    
    @objc private func textFieldChanged() {
        updateDoneButton()
    }
    
    private func updateDoneButton() {
        let text = textField.text ?? ""
        navigationItem.rightBarButtonItem?.isEnabled = !text.isEmpty && text != "https://"
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true) {
            self.onCancel()
        }
    }
    
    @objc private func colorButtonTapped(_ sender: UIButton) {
        // Update selection visual state
        for subview in sender.superview?.subviews ?? [] {
            if let button = subview as? UIButton {
                button.layer.borderColor = UIColor.clear.cgColor
            }
        }
        sender.layer.borderColor = UIColor.label.cgColor
        selectedColorIndex = sender.tag
    }
    
    @objc private func doneTapped() {
        let urlString = textField.text ?? ""
        let selectedColor = linkColors[selectedColorIndex].1
        let shouldUnderline = underlineSwitch.isOn
        
        dismiss(animated: true) {
            self.onLinkCreate(urlString, selectedColor, shouldUnderline)
        }
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
            .frame(width: 44, height: 44) // Larger tap target
        }
        .buttonStyle(PlainButtonStyle())
        .onTapGesture {
            // Provide haptic feedback
            HapticFeedback.impact(.light)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50) {
            // This handles the press effect without interfering with scroll
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - iOS 26 Enhanced Text Button
private struct IOSTextButton: View {
    let text: String
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let textColor: Color?
    let highlightColor: Color?
    let isActive: Bool
    let action: () -> Void
    
    // iOS 26 Enhancement: Advanced state tracking
    @State private var isPressed = false
    @State private var isHovering = false
    @State private var pressIntensity: Double = 0.0
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
        Button(action: {
            print("📱 iOS 26 Enhanced Button tapped: \(text)")
            // iOS 26 Enhancement: Contextual haptic feedback based on button state
            let hapticIntensity = isActive ? 0.9 : 0.7
            HapticFeedback.impact(.light, intensity: hapticIntensity)
            action()
        }) {
            Text(text)
                .font(.system(size: 14, weight: isBold ? .bold : .medium))
                .italic(isItalic)
                .underline(isUnderlined)
                .foregroundColor(textColor ?? buttonForegroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(minWidth: 44, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(highlightColor ?? buttonBackgroundColor)
                        // iOS 26 Enhancement: Subtle shadow for depth
                        .shadow(color: isPressed ? .black.opacity(0.1) : .clear, radius: 2, x: 0, y: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        // iOS 26 Enhancement: More fluid press animation with spring
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .brightness(isHovering ? 0.05 : 0.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50) {
            // iOS 26 Enhancement: No-op for gesture completion
        } onPressingChanged: { pressing in
            // iOS 26 Enhancement: Improved animation with spring response
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
                pressIntensity = pressing ? 1.0 : 0.0
            }
            
            // iOS 26 Enhancement: Progressive haptic feedback
            if pressing {
                HapticFeedback.selection()
            }
        }
        // iOS 26 Enhancement: Enhanced accessibility
        .accessibilityLabel("\(text) button")
        .accessibilityHint(isActive ? "Currently active. Double tap to deactivate." : "Double tap to activate \(text) formatting.")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
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

// MARK: - iOS 26 Enhanced Toolbar Button
private struct IOSToolbarButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    // iOS 26 Enhancement: Advanced state tracking
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    @State private var pressScale: Double = 1.0
    @Environment(\.colorScheme) var colorScheme
    
    init(icon: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.isActive = isActive
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            print("📱 iOS 26 Enhanced Toolbar button tapped: \(icon)")
            
            // iOS 26 Enhancement: Dynamic haptic feedback based on action
            let hapticIntensity = isActive ? 0.8 : 0.6
            HapticFeedback.impact(.light, intensity: hapticIntensity)
            
            // iOS 26 Enhancement: Micro-interaction animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                rotationAngle += 360
                pressScale = 1.1
            }
            
            // Reset animation
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                pressScale = 1.0
            }
            
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(buttonForegroundColor)
                .frame(width: 52, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(buttonBackgroundColor)
                        // iOS 26 Enhancement: Dynamic shadow
                        .shadow(color: isPressed ? .black.opacity(0.15) : .black.opacity(0.05), 
                               radius: isPressed ? 4 : 2, x: 0, y: isPressed ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                // iOS 26 Enhancement: Micro-interaction scaling
                .scaleEffect(pressScale)
                .rotationEffect(.degrees(rotationAngle))
        }
        .buttonStyle(PlainButtonStyle())
        // iOS 26 Enhancement: Improved press animation
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .brightness(isPressed ? -0.05 : 0.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50) {
            // iOS 26 Enhancement: No-op for gesture completion
        } onPressingChanged: { pressing in
            // iOS 26 Enhancement: Smoother spring animation
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isPressed = pressing
            }
            
            // iOS 26 Enhancement: Subtle selection feedback on press
            if pressing {
                HapticFeedback.selection()
            }
        }
        // iOS 26 Enhancement: Rich accessibility support
        .accessibilityLabel(accessibilityLabelForIcon(icon))
        .accessibilityHint(isActive ? "Currently active. Double tap to deactivate." : "Double tap to activate.")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityValue(isActive ? "Active" : "Inactive")
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
    
    // iOS 26 Enhancement: Accessibility helper function
    private func accessibilityLabelForIcon(_ icon: String) -> String {
        switch icon {
        case "bold": return "Bold formatting"
        case "italic": return "Italic formatting"
        case "underline": return "Underline formatting"
        case "textformat": return "Text color"
        case "highlighter": return "Text highlighter"
        case "textformat.abc": return "Text style picker"
        case "keyboard.chevron.compact.down": return "Dismiss keyboard"
        default: return icon.replacingOccurrences(of: ".", with: " ")
        }
    }
}

// MARK: - iOS 26 Enhanced Picker Views
private struct StylePickerView: View {
    var body: some View {
        VStack {
            Text("Style Picker - iOS 26 Enhanced")
                .font(.headline)
                .padding()
            // TODO: Implement enhanced style picker with iOS 26 features
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
}

private struct ColorPickerView: View {
    var body: some View {
        VStack {
            Text("Color Picker - iOS 26 Enhanced")
                .font(.headline)
                .padding()
            // TODO: Implement enhanced color picker with iOS 26 features
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
}

private struct HighlightPickerView: View {
    var body: some View {
        VStack {
            Text("Highlight Picker - iOS 26 Enhanced")
                .font(.headline)
                .padding()
            // TODO: Implement enhanced highlight picker with iOS 26 features
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
}

private struct AlignmentPickerView: View {
    var body: some View {
        VStack {
            Text("Alignment Picker - iOS 26 Enhanced")
                .font(.headline)
                .padding()
            // TODO: Implement enhanced alignment picker with iOS 26 features
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
}

private struct LinkPickerView: View {
    var body: some View {
        VStack {
            Text("Link Picker - iOS 26 Enhanced")
                .font(.headline)
                .padding()
            // TODO: Implement enhanced link picker with iOS 26 features
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
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
        
        // Ensure proper touch handling
        view.isUserInteractionEnabled = true
        
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
