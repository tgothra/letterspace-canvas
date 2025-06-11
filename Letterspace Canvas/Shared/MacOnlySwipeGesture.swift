#if os(macOS)
import SwiftUI
import AppKit

// NOTE: This entire file is macOS-specific due to NSView, NSEvent, etc.

struct SwipeGestureViewModifier: ViewModifier {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    func body(content: Content) -> some View {
        content
            .background(
                SwipeGestureRecognizerView(
                    onSwipeLeft: onSwipeLeft,
                    onSwipeRight: onSwipeRight
                )
            )
    }
}

struct SwipeGestureRecognizerView: NSViewRepresentable {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = SwipeCaptureView()
        view.onSwipeLeft = onSwipeLeft
        view.onSwipeRight = onSwipeRight
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? SwipeCaptureView {
            view.onSwipeLeft = onSwipeLeft
            view.onSwipeRight = onSwipeRight
        }
    }

    class SwipeCaptureView: NSView {
        var onSwipeLeft: (() -> Void)?
        var onSwipeRight: (() -> Void)?
        var startLocation: CGPoint?
        var lastProcessTime = Date()
        let minSwipeDistance: CGFloat = 50

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.wantsLayer = true
            self.layer?.backgroundColor = NSColor.clear.cgColor
            self.allowedTouchTypes = [.direct] // For direct touch events on trackpad
            self.wantsRestingTouches = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func touchesBegan(with event: NSEvent) {
            super.touchesBegan(with: event)
            if let touch = event.allTouches().first {
                startLocation = touch.location(in: self)
            }
        }

        override func touchesMoved(with event: NSEvent) {
            super.touchesMoved(with: event)
            let now = Date()
            if now.timeIntervalSince(lastProcessTime) < 0.1 { return }
            guard let start = startLocation, let touch = event.allTouches().first else { return }

            let currentLocation = touch.location(in: self)
            let deltaX = currentLocation.x - start.x

            if abs(deltaX) > minSwipeDistance {
                lastProcessTime = now
                if deltaX < 0 { onSwipeLeft?() } else { onSwipeRight?() }
                startLocation = nil // Reset to prevent multiple triggers for one swipe
            }
        }

        override func touchesEnded(with event: NSEvent) {
            super.touchesEnded(with: event)
            startLocation = nil
        }

        override func touchesCancelled(with event: NSEvent) {
            super.touchesCancelled(with: event)
            startLocation = nil
        }

        override var acceptsFirstResponder: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { self }

        // Also handle scroll wheel events as an alternative for non-direct touch trackpads
        override func scrollWheel(with event: NSEvent) {
            if event.phase == .changed || event.phase == .began { // Only consider active scrolling
                let deltaX = event.scrollingDeltaX
                let now = Date()
                if now.timeIntervalSince(lastProcessTime) < 0.2 { return } // Slightly longer debounce for scroll

                if abs(deltaX) > 20 { // Threshold for scroll swipe
                    lastProcessTime = now
                    if deltaX > 0 { onSwipeLeft?() } else { onSwipeRight?() }
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                }
            }
        }
    }
}

extension View {
    func onMacSwipeGesture(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) -> some View {
        self.modifier(SwipeGestureViewModifier(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight))
    }
}

#endif // os(macOS) 