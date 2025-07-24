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
            } else if showLinkPicker {
                LinkPickerPlaceholderView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showLinkPicker = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity.animation(.easeIn(duration: 0.15)))
                ))
                .onAppear {
                    // Present the link picker as a modal overlay
                    DispatchQueue.main.async {
                        // Immediately hide the placeholder to prevent re-triggering
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showLinkPicker = false
                        }
                        
                        presentLinkPickerModal(onLinkCreate: onLinkCreate) {
                            // Modal was cancelled/dismissed - already handled by hiding showLinkPicker above
                        }
                    }
                }
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
                    onShowLinkPicker: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showLinkPicker = true
                        }
                    },
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
    
    // Function to present link picker modal
    private func presentLinkPickerModal(onLinkCreate: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let linkPickerVC = LinkPickerViewController { linkURL, linkColor, shouldUnderline in
            // Link created with custom styling
            print("🔗 Link creation: URL=\(linkURL), Color=\(linkColor), Underline=\(shouldUnderline)")
            if let onLinkCreateWithStyle = onLinkCreateWithStyle {
                print("🔗 Using onLinkCreateWithStyle callback")
                onLinkCreateWithStyle(linkURL, linkURL, linkColor, shouldUnderline)
            } else {
                print("🔗 Using fallback onLinkCreate callback")
                // Fallback to basic link creation
                onLinkCreate(linkURL, linkURL)
            }
            onCancel()
        } onCancel: {
            // Cancelled
            onCancel()
        }
        
        let navController = UINavigationController(rootViewController: linkPickerVC)
        navController.modalPresentationStyle = .formSheet
        
        // Set a compact size for the modal
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.custom(resolver: { _ in
                return 280 // Increased height for color options
            })]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }
        
        window.rootViewController?.present(navController, animated: true) {
            // Modal presented successfully
        }
        
        // Handle dismissal by swipe or other means
        linkPickerVC.onDismiss = {
            DispatchQueue.main.async {
                onCancel()
            }
        }
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
    let onShowLinkPicker: () -> Void
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
                    IOSTextButton(text: "Link", isActive: hasLink, action: onShowLinkPicker)
                    IOSTextButton(text: "Bullet", isActive: hasBulletList, action: onBulletList)
                    IOSTextButton(text: "Alignment", action: onShowAlignmentPicker)
                }
                
                // Separator 3
                Rectangle()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 20)
                
                // Keyboard dismissal button
                IOSToolbarButton(icon: "keyboard.chevron.compact.down") {
                    // Dismiss the keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollDisabled(false) // Ensure scrolling is enabled
        .scrollBounceBehavior(.basedOnSize) // Add bounce for better scroll feedback
        .scrollTargetBehavior(.viewAligned) // Better scroll targeting
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
        Button(action: {
            print("📱 Button tapped: \(text)")
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
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
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
        Button(action: {
            print("📱 Toolbar button tapped: \(icon)")
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(buttonForegroundColor)
                .frame(width: 52, height: 44)
                .background(buttonBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
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
