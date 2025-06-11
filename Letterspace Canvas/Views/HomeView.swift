import SwiftUI
import PDFKit
#if os(macOS)
import AppKit // AppKit is macOS specific
#endif
import UniformTypeIdentifiers
import CoreGraphics

// UPDATED: Using SermonCalendar instead of the original CalendarSection implementation
// The SermonCalendar implementation is located at Views/Modern/SermonCalendar.swift

// Add placeholder modifier at file scope
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#if os(macOS)
// Add this extension at the bottom of the file
private extension NSView {
    var descendantViews: [NSView] {
        var views = [NSView]()
        for subview in subviews {
            views.append(subview)
            views.append(contentsOf: subview.descendantViews)
        }
        return views
    }
}

// Add this before the DocumentDetailsCard struct
struct TrackpadScrollModifier: ViewModifier {
    let onScrollLeft: () -> Void
    let onScrollRight: () -> Void
    
    // SwiftUI doesn't directly expose scroll events, so we need to use an NSViewRepresentable
    struct ScrollEventView: NSViewRepresentable {
        let onScrollLeft: () -> Void
        let onScrollRight: () -> Void
        
        func makeNSView(context: Context) -> NSView {
            let view = TrackpadScrollView()
            view.onScrollLeft = onScrollLeft
            view.onScrollRight = onScrollRight
            return view
        }
        
        func updateNSView(_ nsView: NSView, context: Context) {
            if let view = nsView as? TrackpadScrollView {
                view.onScrollLeft = onScrollLeft
                view.onScrollRight = onScrollRight
            }
        }
    }
    
    // Custom NSView that detects scroll events
    class TrackpadScrollView: NSView {
        var onScrollLeft: (() -> Void)?
        var onScrollRight: (() -> Void)?
        var lastScrollTime: Date = Date()
        let scrollThreshold: CGFloat = 15 // Lower threshold for better sensitivity
        
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.wantsLayer = true
            self.layer?.backgroundColor = NSColor.clear.cgColor
            self.allowedTouchTypes = [.direct]
            self.wantsRestingTouches = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func scrollWheel(with event: NSEvent) {
            // Don't call super to capture the event
            
            // Detect horizontal scrolling
            let deltaX = event.scrollingDeltaX
            print("Scroll wheel event: deltaX=\(deltaX)")
            
            // Protect against rapid successive events
            let now = Date()
            if now.timeIntervalSince(lastScrollTime) < 0.1 {
                return
            }
            
            // Process scroll events
            if abs(deltaX) > scrollThreshold {
                lastScrollTime = now
                
                if deltaX > 0 {
                    print("Scroll detected: LEFT")
                    if let action = onScrollLeft {
                        action()
                    }
                } else {
                    print("Scroll detected: RIGHT")
                    if let action = onScrollRight {
                        action()
                    }
                }
                
                // Provide haptic feedback if available
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            }
        }
        
        // Make sure this view can become first responder
        override var acceptsFirstResponder: Bool {
            return true
        }
        
        // Accept all mouse/touch events
        override func hitTest(_ point: NSPoint) -> NSView? {
            return self
        }
    }
    
    func body(content: Content) -> some View {
        content.background(
            ScrollEventView(
                onScrollLeft: onScrollLeft,
                onScrollRight: onScrollRight
            )
        )
    }
}

extension View {
    func onTrackpadScroll(onScrollLeft: @escaping () -> Void, onScrollRight: @escaping () -> Void) -> some View {
        self.modifier(TrackpadScrollModifier(onScrollLeft: onScrollLeft, onScrollRight: onScrollRight))
    }
}
#endif // End of os(macOS) for TrackpadScrollModifier and NSView extension

// Remove the crashing extension
// extension View {
//     func customPopoverStyle() -> some View {
//         ...
//     }
// }

// TimePickerDropdown component to break up complex UI logic

// --- PinnedSection Items --- 
// Find the PinnedDocumentRow struct or similar item view within PinnedSection

private struct PinnedDocumentRow: View {
    let doc: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @State private var isOpenButtonHovered = false
    @State private var isUnpinButtonHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Ensure doc icon is black
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(Color.black)
                .frame(width: 20)
            
            Text(doc.title.isEmpty ? "Untitled" : doc.title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(theme.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                
            Spacer()
            
            #if os(macOS)
            // macOS hover-based button visibility
            if isHovered {
                HStack(spacing: 6) {
                    // Open button
                    Button(action: { 
                        NotificationCenter.default.post(name: NSNotification.Name("OpenDocument"), object: nil, userInfo: ["documentId": doc.id]) 
                    }) {
                        ZStack {
                            Circle()
                                // Default black, hover blue
                                .fill(isOpenButtonHovered ? Color(hex: "#007AFF") : Color.black)
                                .frame(width: 15, height: 15)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Open document")
                    .scaleEffect(isHovered ? 1.0 : 0.8)
                    .scaleEffect(isOpenButtonHovered ? 1.15 : 1.0)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            isOpenButtonHovered = hovering
                        }
                    }

                    // Unpin button
                    Button(action: { unpinDocument() }) {
                        ZStack {
                            Circle()
                                // Default black, hover red
                                .fill(isUnpinButtonHovered ? Color.red : Color.black)
                                .frame(width: 15, height: 15)
                            Image(systemName: "pin.slash.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Unpin document")
                    .scaleEffect(isHovered ? 1.0 : 0.8)
                    .scaleEffect(isUnpinButtonHovered ? 1.15 : 1.0)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            isUnpinButtonHovered = hovering
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            }
            #elseif os(iOS)
            // iOS: Buttons always visible
            HStack(spacing: 6) {
                // Open button
                Button(action: { 
                    NotificationCenter.default.post(name: NSNotification.Name("OpenDocument"), object: nil, userInfo: ["documentId": doc.id]) 
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#007AFF")) // Consistently blue or theme accent
                            .frame(width: 18, height: 18) // Slightly larger for touch
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .help("Open document")

                // Unpin button
                Button(action: { unpinDocument() }) {
                    ZStack {
                        Circle()
                            .fill(Color.red) // Consistently red or theme warning
                            .frame(width: 18, height: 18) // Slightly larger for touch
                        Image(systemName: "pin.slash.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .help("Unpin document")
            }
            #endif
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 5)
                #if os(macOS)
                .fill(isHovered ? (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)) : Color.clear)
                #else
                .fill(Color.clear) // No hover effect on iOS row background
                #endif
        )
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        #endif
    }

    private func unpinDocument() {
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil, userInfo: ["unpin": doc.id])
    }
}

// --- WIPSection Items --- 
// Find the WIPDocumentRow struct or similar item view within WIPSection

private struct WIPDocumentRow: View {
    let doc: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @State private var isOpenButtonHovered = false
    @State private var isRemoveButtonHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Ensure doc icon is black
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(theme.primary)
                .frame(width: 20)

            Text(doc.title.isEmpty ? "Untitled" : doc.title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(theme.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            #if os(macOS)
            // macOS hover-based button visibility
            if isHovered {
                HStack(spacing: 6) {
                    // Open button
                    Button(action: { 
                         NotificationCenter.default.post(name: NSNotification.Name("OpenDocument"), object: nil, userInfo: ["documentId": doc.id]) 
                    }) {
                        ZStack {
                            Circle()
                                // Default black, hover blue
                                .fill(isOpenButtonHovered ? Color(hex: "#007AFF") : Color.black)
                                .frame(width: 15, height: 15)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Open document")
                    .scaleEffect(isHovered ? 1.0 : 0.8)
                    .scaleEffect(isOpenButtonHovered ? 1.15 : 1.0)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            isOpenButtonHovered = hovering
                        }
                    }

                    // Remove from WIP button
                    Button(action: { removeFromWIP() }) {
                        ZStack {
                            Circle()
                                // Default black, hover red
                                .fill(isRemoveButtonHovered ? Color.red : Color.black)
                                .frame(width: 15, height: 15)
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Remove from Work in Progress")
                    .scaleEffect(isHovered ? 1.0 : 0.8)
                    .scaleEffect(isRemoveButtonHovered ? 1.15 : 1.0)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            isRemoveButtonHovered = hovering
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            }
            #elseif os(iOS)
            // iOS: Buttons always visible
            HStack(spacing: 6) {
                // Open button
                Button(action: { 
                     NotificationCenter.default.post(name: NSNotification.Name("OpenDocument"), object: nil, userInfo: ["documentId": doc.id]) 
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#007AFF")) // Consistently blue or theme accent
                            .frame(width: 18, height: 18) // Slightly larger for touch
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .help("Open document")

                // Remove from WIP button
                Button(action: { removeFromWIP() }) {
                    ZStack {
                        Circle()
                            .fill(Color.red) // Consistently red or theme warning
                            .frame(width: 18, height: 18) // Slightly larger for touch
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .help("Remove from Work in Progress")
            }
            #endif
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 5)
                #if os(macOS)
                .fill(isHovered ? (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)) : Color.clear)
                #else
                .fill(Color.clear) // No hover effect on iOS row background
                #endif
        )
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        #endif
    }

    private func removeFromWIP() {
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil, userInfo: ["removeWIP": doc.id])
    }
}
