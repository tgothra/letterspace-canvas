#if os(macOS)
import AppKit

// Custom scroller that only appears during scrolling with no container
class SlimScroller: NSScroller {
    private var hideTimer: Timer?
    private var isScrolling = false
    private var fadeAnimator: NSViewAnimation?
    private var currentAlpha: CGFloat = 0.0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        // Start hidden
        isScrolling = false
        currentAlpha = 0.0
        alphaValue = 0.0
        
        // Register for scroll notifications from parent scroll view
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrolling),
            name: NSScrollView.willStartLiveScrollNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrollingEnded),
            name: NSScrollView.didEndLiveScrollNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        hideTimer?.invalidate()
        hideTimer = nil
        fadeAnimator?.stop()
        fadeAnimator = nil
    }
    
    override func draw(_ dirtyRect: NSRect) {
        if isScrolling || currentAlpha > 0 {
            // Draw a visible but subtle scrollbar when actively scrolling
            NSColor.clear.setFill()
            dirtyRect.fill()
            
            // Draw knob with current alpha
            let knobColor = NSColor.gray.withAlphaComponent(0.5 * currentAlpha)
            knobColor.set()
            
            // Draw a slimmer knob with more rounded corners
            let knobRect = self.rect(for: .knob)
            let slimmerKnobRect = NSRect(
                x: knobRect.origin.x + 3,
                y: knobRect.origin.y,
                width: knobRect.width - 6,  // Make it even slimmer
                height: knobRect.height
            )
            
            // Use fully rounded corners - use half the width to make pill-shaped
            let cornerRadius = slimmerKnobRect.width / 2
            let path = NSBezierPath(roundedRect: slimmerKnobRect, xRadius: cornerRadius, yRadius: cornerRadius)
            path.fill()
        } else {
            // Draw absolutely nothing when not scrolling
            NSColor.clear.setFill()
            dirtyRect.fill()
        }
    }
    
    // Don't need to override drawKnob as we handle all drawing in draw(_:)
    
    @objc private func handleScrolling(_ notification: Notification) {
        if let scrollView = notification.object as? NSScrollView,
           scrollView == self.superview {
            showScrollerTemporarily()
        }
    }
    
    @objc private func handleScrollingEnded(_ notification: Notification) {
        if let scrollView = notification.object as? NSScrollView,
           scrollView == self.superview {
            scheduleHide()
        }
    }
    
    // When scroll wheel events happen, show the scroller
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        showScrollerTemporarily()
    }
    
    // Show the scroller temporarily when scrolling happens
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        showScrollerTemporarily()
    }
    
    // Override mouse tracking to prevent unwanted behavior
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove existing tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        // Only add minimal tracking for scroll functionality
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    // Helper method to show the scroller immediately
    private func showScrollerTemporarily() {
        // Cancel any existing hide timer and fade animations
        hideTimer?.invalidate()
        fadeAnimator?.stop()
        fadeAnimator = nil
        
        // Show immediately
        isScrolling = true
        currentAlpha = 1.0
        needsDisplay = true
    }
    
    // Schedule hiding the scroller after a delay
    private func scheduleHide() {
        // Cancel any existing hide timer
        hideTimer?.invalidate()
        
        // Set a timer to hide the scroller after scrolling stops
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }
    
    // Fade out the scroller smoothly
    private func fadeOut() {
        isScrolling = false
        
        // Stop any existing animation
        fadeAnimator?.stop()
        
        // Animate the alpha from current value to 0
        let fadeSteps = 10
        let fadeDuration = 0.3
        let stepDuration = fadeDuration / Double(fadeSteps)
        
        // Create a sequential animation
        for i in 0..<fadeSteps {
            let delay = stepDuration * Double(i)
            let targetAlpha = 1.0 - (Double(i+1) / Double(fadeSteps))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.currentAlpha = CGFloat(targetAlpha)
                self.needsDisplay = true
                
                // When fully faded out, ensure we're completely hidden
                if i == fadeSteps - 1 {
                    self.currentAlpha = 0.0
                    self.needsDisplay = true
                }
            }
        }
    }
}
#endif
