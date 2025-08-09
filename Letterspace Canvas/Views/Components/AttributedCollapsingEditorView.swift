import SwiftUI
import Combine

#if os(iOS)
import UIKit
/// A pure-SwiftUI scrolling container that hosts:
/// - An expanded header at the top
/// - A growing, non-scrollable AttributedString editor
/// - A floating, collapsed header overlay that fades/slides in as you scroll
///
/// This isolates the approach so we can evaluate and revert easily.
struct AttributedCollapsingEditorView<ExpandedHeader: View, CollapsedHeader: View>: View {
    // MARK: - Public API
    @Binding var text: AttributedString
    let expandedHeader: () -> ExpandedHeader
    let collapsedHeader: () -> CollapsedHeader

    // MARK: - Appearance / Layout Controls
    var expandedHeaderHeight: CGFloat = 240
    var collapsedHeaderHeight: CGFloat = 80
    var horizontalPadding: CGFloat = 16

    // MARK: - Internal State
    @State private var headerMinY: CGFloat = 0
    @State private var editorHeight: CGFloat = 200
    @State private var collapseProgress: CGFloat = 0 // 0 = expanded, 1 = collapsed
    @State private var keyboardHeight: CGFloat = 0
    @State private var preservedScrollOffset: CGFloat? = nil
    @State private var isPreservingScroll: Bool = false
    @FocusState private var isFocused: Bool

    private var collapseThreshold: CGFloat {
        max(1, expandedHeaderHeight - collapsedHeaderHeight)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Track the header's vertical position in scroll space
                        expandedHeader()
                            .frame(height: expandedHeaderHeight)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: HeaderMinYKey.self, value: geo.frame(in: .named("scroll"))).onAppear {}
                                }
                            )

                        // Non-scrollable editor that grows with content height
                        Group {
                            if #available(iOS 26.0, *) {
                                                            NativeGrowingAttributedTextEditor(
                                text: $text,
                                calculatedHeight: $editorHeight,
                                horizontalPadding: horizontalPadding,
                                isFocused: $isFocused
                            )
                            } else {
                                GrowingAttributedTextEditor(text: $text, calculatedHeight: $editorHeight)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: editorHeight)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 40 + keyboardHeight)
                        .id("textEditor") // Re-add ID for scroll targeting
                    }
                    .background(Color.clear)
                }
                .defaultScrollAnchor(.top)
                .scrollDismissesKeyboard(.interactively)
                .coordinateSpace(name: "scroll")
                .animation(.none, value: editorHeight) // Prevent scroll animation on height changes
                .animation(.none, value: keyboardHeight) // Prevent scroll animation on keyboard changes
                .onPreferenceChange(HeaderMinYKey.self) { frame in
                    // frame.minY goes from 0 (top) to negative as we scroll up
                    let offset = -frame.minY
                    let raw = offset / collapseThreshold
                    collapseProgress = min(max(raw, 0), 1)
                    print("📏 Scroll offset=\(offset), collapseProgress=\(collapseProgress), keyboardHeight=\(keyboardHeight)")
                    
                    // Store current scroll position for future reference
                    headerMinY = frame.minY
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named("scroll")).minY) { _, _ in
                                let y = geo.frame(in: .named("scroll")).minY
                                print("🌀 Scroll content minY=\(y)")
                            }
                    }
                )
            }

            // Floating collapsed header overlay using provided view
            VStack(spacing: 0) {
                collapsedHeader()
                    .frame(height: collapsedHeaderHeight)
                    .opacity(collapseProgress)
                    .offset(y: -8 * (1 - collapseProgress))
                    .animation(.easeInOut(duration: 0.15), value: collapseProgress)
                Spacer()
            }
            .allowsHitTesting(collapseProgress > 0.95)
        }
        // Keyboard height observer – keeps bottom padding in sync so caret never needs forced scroll
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let userInfo = notification.userInfo,
                  let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.keyWindow else {
                return
            }
            let screenHeight = window.bounds.height
            let overlap = max(0, screenHeight - endFrame.origin.y)
            keyboardHeight = overlap
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
            print("🎹 Keyboard hide: keyboardHeight reset to 0")
            // End scroll preservation when keyboard fully hides
            isPreservingScroll = false
            preservedScrollOffset = nil
        }
        .onChange(of: isFocused) { focused in
            if focused {
                print("🎯 Main view: TextEditor focused")
                
                // Start preserving scroll position during focus transition
                preservedScrollOffset = -headerMinY
                isPreservingScroll = true
                print("🔒 Starting scroll preservation at offset \(preservedScrollOffset ?? 0)")
                
                // Stop preserving after keyboard transition settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isPreservingScroll = false
                    preservedScrollOffset = nil
                    print("🔓 Ended scroll preservation")
                }
            } else {
                print("👋 Main view: TextEditor lost focus")
            }
        }
    }
}

// MARK: - Preference Key to read header position
private struct HeaderMinYKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Native growing editor using SwiftUI TextEditor (iOS 26+)
@available(iOS 26.0, *)
private struct NativeGrowingAttributedTextEditor: View {
    @Binding var text: AttributedString
    @Binding var calculatedHeight: CGFloat
    var horizontalPadding: CGFloat
    @FocusState.Binding var isFocused: Bool

    @State private var selection: AttributedTextSelection = AttributedTextSelection()
    @State private var availableWidth: CGFloat = 0
    @State private var swiftUITextMeasuredHeight: CGFloat = 0
    @State private var nextAllowedHeightUpdate: Date = .distantPast

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Native TextEditor bound to AttributedString
            TextEditor(text: $text, selection: $selection)
                .textEditorStyle(.plain)
                .scrollDisabled(true)
                .frame(minHeight: calculatedHeight)
                .background(Color.clear)
                .focused($isFocused)
                .animation(.none, value: calculatedHeight) // Prevent height animation
                .animation(.none, value: text) // Prevent text change animation
                .animation(.none, value: selection) // Prevent selection animation
                .onChange(of: selection) { _, newSel in
                    logSelection(newSel, in: text)
                    // Defer height updates slightly to avoid focus-time scroll jumps
                    nextAllowedHeightUpdate = Date().addingTimeInterval(0.25)
                }
                .onAppear {
                    logSelection(selection, in: text)
                }
                .onChange(of: isFocused) { focused in
                    if focused {
                        print("🎯 TextEditor focused")
                        logSelection(selection, in: text)
                        nextAllowedHeightUpdate = Date().addingTimeInterval(0.25)
                    } else {
                        print("👋 TextEditor lost focus")
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        iOS26NativeToolbarWrapper(
                            text: $text,
                            selection: $selection
                        )
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { updateHeightIfNeeded(forWidth: geo.size.width) }
                            .onChange(of: geo.size.width) { _, newWidth in
                                updateHeightIfNeeded(forWidth: newWidth)
                            }
                    }
                )

            // Hidden measuring Text to track SwiftUI layout height precisely
            Text(text)
                .font(.body)
                .opacity(0.001) // keep it participating in layout without flashing
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { swiftUITextMeasuredHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, h in
                                swiftUITextMeasuredHeight = h
                                if availableWidth > 0 {
                                    updateHeightIfNeeded(forWidth: availableWidth)
                                }
                            }
                    }
                )
        }
        .onChange(of: text) { _, _ in
            if availableWidth > 0 {
                updateHeightIfNeeded(forWidth: availableWidth)
            }
        }
    }

    // MARK: - Debug Logging
    private func logSelection(_ selection: AttributedTextSelection, in text: AttributedString) {
        let indices = selection.indices(in: text)
        switch indices {
        case .insertionPoint(let idx):
            let pos = text.characters.distance(from: text.characters.startIndex, to: idx)
            let count = text.characters.count
            print("🧭 Selection insertionPoint at \(pos) of \(count)")
            if pos == count { print("⚠️ Selection currently at end of text") }
        case .ranges(let rangeSet):
            if let first = rangeSet.ranges.first {
                let lower = text.characters.distance(from: text.characters.startIndex, to: first.lowerBound)
                let upper = text.characters.distance(from: text.characters.startIndex, to: first.upperBound)
                let count = text.characters.count
                print("🧭 Selection range [\(lower), \(upper)) length=\(upper - lower) of \(count)")
            } else {
                print("🧭 Selection ranges present but empty")
            }
        }
    }

    private func updateHeightIfNeeded(forWidth width: CGFloat) {
        if Date() < nextAllowedHeightUpdate {
            return
        }
        availableWidth = width
        let paddingAdjustment: CGFloat = 20 // match vertical padding in editor
        // Combine TextEngine measurement with CoreText bounding rect for robustness
        let ctHeight = measuredHeight(for: text, width: width)
        let swiftUITextHeight = swiftUITextMeasuredHeight
        let targetHeight = max(ctHeight, swiftUITextHeight) + paddingAdjustment
        let clamped = max(44, ceil(targetHeight))
        if abs(calculatedHeight - clamped) > 0.5 {
            DispatchQueue.main.async {
                calculatedHeight = clamped
            }
        }
    }

    private func measuredHeight(for attributed: AttributedString, width: CGFloat) -> CGFloat {
        let ns = NSAttributedString(attributed)
        var rect = ns.boundingRect(
            with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        // Account for trailing newline or empty last line, which boundingRect does not include
        let uiFont = UIFont.preferredFont(forTextStyle: .body)
        if attributed.characters.isEmpty || attributed.characters.last?.isNewline == true {
            rect.size.height += uiFont.lineHeight
        }
        return rect.height
    }
}

private struct EditorHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 44
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - A non-scrollable, growing AttributedString editor backed by UITextView
/// Expands vertically to fit content so the outer ScrollView controls all scrolling.
struct GrowingAttributedTextEditor: UIViewRepresentable {
    @Binding var text: AttributedString
    @Binding var calculatedHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isScrollEnabled = false // critical: let the outer ScrollView handle scrolling
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.required, for: .vertical)

        // Initial content
        textView.attributedText = NSAttributedString(from: text)
        DispatchQueue.main.async {
            self.updateHeight(for: textView)
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let incoming = NSAttributedString(from: text)
        if uiView.attributedText != incoming {
            uiView.attributedText = incoming
        }
        updateHeight(for: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func updateHeight(for textView: UITextView) {
        // Use sizeThatFits for reliable intrinsic height
        let targetSize = CGSize(width: textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width - 32,
                                height: CGFloat.greatestFiniteMagnitude)
        let size = textView.sizeThatFits(targetSize)
        let newHeight = max(44, size.height)
        if abs(calculatedHeight - newHeight) > 0.5 {
            DispatchQueue.main.async {
                self.calculatedHeight = newHeight
            }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingAttributedTextEditor
        init(parent: GrowingAttributedTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            // Update binding and measured height
            parent.text = AttributedString(textView.attributedText)
            parent.updateHeight(for: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Keep height in sync when selection causes layout changes (e.g., typing attributes)
            parent.updateHeight(for: textView)
        }
    }
}

// MARK: - Convenience initializers for NSAttributedString bridging
private extension NSAttributedString {
    convenience init(from swiftAttributed: AttributedString) {
        self.init(swiftAttributed)
    }
}

// MARK: - Preview (uses simple headers to visualize behavior)
#Preview {
    AttributedCollapsingEditorView(
        text: .constant(AttributedString(String(repeating: "Sample body text. Lorem ipsum dolor sit amet.\n", count: 60))),
        expandedHeader: {
            ZStack {
                LinearGradient(colors: [.blue, .green], startPoint: .top, endPoint: .bottom)
                Text("Expanded Header")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        },
        collapsedHeader: {
            ZStack {
                HStack {
                    Text("Collapsed Header")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .background(.ultraThinMaterial)
        }
    )
}
#endif

