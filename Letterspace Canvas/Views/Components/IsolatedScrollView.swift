#if os(macOS)
import SwiftUI
import AppKit

// Custom view that completely blocks scroll events from bubbling
class ScrollBlockingView: NSView {
    private var localMonitor: Any?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if window != nil {
            // Add a local monitor to intercept scroll events
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self = self, let _ = self.window else { return event }
                
                // Get the event location in window coordinates
                let locationInWindow = event.locationInWindow
                let locationInView = self.convert(locationInWindow, from: nil)
                
                // Check if the event is within our bounds
                if self.bounds.contains(locationInView) {
                    // Event is within our view, handle it internally and don't pass it through
                    
                    // Find the scroll view within our hierarchy and send the event to it
                    if let scrollView = self.findScrollView() {
                        scrollView.scrollWheel(with: event)
                    }
                    
                    // Return nil to consume the event and prevent it from bubbling
                    return nil
                }
                
                // Event is outside our bounds, let it pass through
                return event
            }
        } else {
            // Remove the monitor when view is removed from window
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }
    }
    
    private func findScrollView() -> NSScrollView? {
        // Recursively search for NSScrollView in our subview hierarchy
        func search(in view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            for subview in view.subviews {
                if let found = search(in: subview) {
                    return found
                }
            }
            return nil
        }
        return search(in: self)
    }
    
    override func scrollWheel(with event: NSEvent) {
        // Don't call super - we handle all scrolling through the local monitor
    }
    
    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// ScrollView wrapper that completely intercepts scroll events
struct IsolatedScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeNSView(context: Context) -> NSView {
        let containerView = ScrollBlockingView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollsDynamically = true
        
        // Create hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create content container
        let contentContainer = NSView()
        contentContainer.addSubview(hostingView)
        
        // Set up constraints for hosting view
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
        // Set the content container as document view
        scrollView.documentView = contentContainer
        
        // Add scroll view to the blocking container
        containerView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up constraints for scroll view
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Find and update the hosting view
        if let blockingView = nsView as? ScrollBlockingView,
           let scrollView = blockingView.subviews.first as? NSScrollView,
           let contentContainer = scrollView.documentView,
           let hostingView = contentContainer.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

// SwiftUI wrapper for the isolated scroll view
struct IsolatedScrollViewWrapper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if os(macOS)
        IsolatedScrollView {
            content
        }
        #else
        ScrollView {
            content
        }
        #endif
    }
}
#endif 