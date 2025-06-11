#if os(macOS)
import AppKit
import ObjectiveC

// Define keys as string constants instead of variables
private struct BookmarkNavigationKeys {
    static let isNavigatingToBookmarkKey = "isNavigatingToBookmarkKey"
    static let internalScrollInProgressKey = "internalScrollInProgressKey"
    static let lastBookmarkRangeKey = "lastBookmarkRangeKey"
    static let lastTopMarginPercentageKey = "lastTopMarginPercentageKey"
    static let bookmarkMaintenanceTimerKey = "bookmarkMaintenanceTimerKey"
    static let bookmarkScrollObserverKey = "bookmarkScrollObserverKey"
    static let maintenanceChecksCountKey = "maintenanceChecksCountKey"
}

extension DocumentTextView {
    // MARK: - Bookmark Navigation Properties (Associated Objects)

    var isNavigatingToBookmark: Bool {
        get {
            return objc_getAssociatedObject(self, BookmarkNavigationKeys.isNavigatingToBookmarkKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, BookmarkNavigationKeys.isNavigatingToBookmarkKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var internalScrollInProgress: Bool {
        get {
            return objc_getAssociatedObject(self, BookmarkNavigationKeys.internalScrollInProgressKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, BookmarkNavigationKeys.internalScrollInProgressKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var lastBookmarkRange: NSRange? {
        get {
            return objc_getAssociatedObject(self, BookmarkNavigationKeys.lastBookmarkRangeKey) as? NSRange
        }
        set {
            objc_setAssociatedObject(self, BookmarkNavigationKeys.lastBookmarkRangeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var lastTopMarginPercentage: CGFloat? {
        get {
            return objc_getAssociatedObject(self, BookmarkNavigationKeys.lastTopMarginPercentageKey) as? CGFloat
        }
        set {
            objc_setAssociatedObject(self, BookmarkNavigationKeys.lastTopMarginPercentageKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var bookmarkMaintenanceTimer: Timer? {
        get {
            return objc_getAssociatedObject(self, BookmarkNavigationKeys.bookmarkMaintenanceTimerKey) as? Timer
        }
        set {
            objc_setAssociatedObject(self, BookmarkNavigationKeys.bookmarkMaintenanceTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var bookmarkScrollObserver: NSObjectProtocol? {
        get {
            return objc_getAssociatedObject(self, BookmarkNavigationKeys.bookmarkScrollObserverKey) as? NSObjectProtocol
        }
        set {
            objc_setAssociatedObject(self, BookmarkNavigationKeys.bookmarkScrollObserverKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var maintenanceChecksCount: Int {
        get {
            return objc_getAssociatedObject(self, BookmarkNavigationKeys.maintenanceChecksCountKey) as? Int ?? 0
        }
        set {
            objc_setAssociatedObject(self, BookmarkNavigationKeys.maintenanceChecksCountKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Bookmark Navigation Methods

    internal func scrollToCharacterPosition(_ position: Int, length: Int) {
        // --- Start of method --- 
        print("📚 DocumentTextView: Scrolling to character position \(position), length: \(length)")
        
        // Cancel any existing maintenance timer
        bookmarkMaintenanceTimer?.invalidate()
        bookmarkMaintenanceTimer = nil
        
        // Safety check - ensure the position is valid
        let text = self.string
        guard position >= 0 && position < text.count else {
            print("⚠️ Invalid character position: \(position), document has \(text.count) characters")
            self.isNavigatingToBookmark = false
            return
        }
        
        // Create range for the exact bookmark and store it for potential repositioning
        let bookmarkRange = NSRange(location: position, length: min(length, text.count - position))
        self.lastBookmarkRange = bookmarkRange
        self.lastTopMarginPercentage = 0.15 // Store the desired top margin (15%)
        
        // Force layout calculation before scrolling
        self.layoutManager?.ensureLayout(forCharacterRange: NSRange(location: 0, length: text.count))
                
        // First position the bookmark near the top of the visible area
        if let layoutManager = self.layoutManager,
           let textContainer = self.textContainer,
           let enclosingScrollView = self.enclosingScrollView,
           let documentView = enclosingScrollView.documentView {

            // Get the rect for the target text
            let glyphRange = layoutManager.glyphRange(forCharacterRange: bookmarkRange, actualCharacterRange: nil)
            var targetRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            targetRect = targetRect.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)
            
            print("📐 Target rect before scroll: \(targetRect)")
            
            // Get the current visible rect
            let visibleRect = enclosingScrollView.contentView.bounds
            
            // Define the optimal area (top 30% of the viewport)
            let optimalAreaHeight = visibleRect.height * 0.3
            let optimalArea = NSRect(
                x: visibleRect.origin.x,
                y: visibleRect.origin.y,
                width: visibleRect.width,
                height: optimalAreaHeight
            )
            
            // Check if the bookmark is already in an optimal position
            let isBookmarkInOptimalPosition = optimalArea.contains(targetRect) || 
                                             (optimalArea.intersects(targetRect) && 
                                              targetRect.minY >= optimalArea.minY)
            
            if !isBookmarkInOptimalPosition {
                print("📜 Bookmark not in optimal position - repositioning")
                // Calculate scroll position to position text about 15% from the top
                let topMargin = visibleRect.height * 0.15 // 15% from the top
                var scrollPointY = targetRect.minY - topMargin
                
                // Ensure we don't scroll beyond document bounds
                let maxY = max(0, documentView.frame.height - visibleRect.height)
                scrollPointY = max(0, min(scrollPointY, maxY))
                
                print("📏 Calculated scroll point: \(scrollPointY)")
                
                // --- Use internalScrollInProgress flag ---
                self.internalScrollInProgress = true // Signal that this scroll is intentional
                print("🚩 Setting internalScrollInProgress = true")
                // Use immediate scroll first to ensure proper positioning
                let scrollPoint = NSPoint(x: visibleRect.origin.x, y: scrollPointY)
                enclosingScrollView.contentView.scroll(to: scrollPoint)
                enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
                self.internalScrollInProgress = false // Reset flag immediately after
                print("🚩 Resetting internalScrollInProgress = false")
                // --- End flag usage ---
                
                // Then animate slightly to provide visual feedback (also needs flag)
                DispatchQueue.main.async {
                    self.internalScrollInProgress = true // Signal that this scroll is intentional
                    print("🚩 Setting internalScrollInProgress = true (animation)")
                NSAnimationContext.runAnimationGroup({
                    context in
                        context.duration = 0.1
                    enclosingScrollView.contentView.animator().setBoundsOrigin(scrollPoint)
                    enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
                    }, completionHandler: {
                        // Reset flag after animation completes
                        self.internalScrollInProgress = false 
                        print("🚩 Resetting internalScrollInProgress = false (animation complete)")
                    })
                }
            } else {
                print("📜 Bookmark already in optimal position - not scrolling, just highlighting")
            }
        }
        
        // Ensure the view has focus
        if let window = self.window {
            window.makeFirstResponder(self)
        }
        
        // Apply a temporary highlight to the bookmarked text
        if let textStorage = self.textStorage {
            // Store original attributes for later restoration
            let originalAttributes = textStorage.attributes(at: bookmarkRange.location, effectiveRange: nil)
            
            // Start editing
            textStorage.beginEditing()
            
            // Apply highlight color
            let highlightColor = NSColor.systemBlue.withAlphaComponent(0.2)
            textStorage.addAttribute(.backgroundColor, value: highlightColor, range: bookmarkRange)
            
            // End editing to update the view
            textStorage.endEditing()
            
            // Schedule removal of highlight after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self, let _ = self.textStorage else { return }
                
                // Start the fade-out effect
                self.animateHighlightRemoval(range: bookmarkRange, originalAttributes: originalAttributes)
            }
        }
        
        // Set cursor position at the start of the bookmarked text
        self.setSelectedRange(NSRange(location: bookmarkRange.location, length: 0))
        
        // Set up a maintenance timer to keep the bookmark position correct
        // during layout changes (like header collapse)
        self.setupBookmarkMaintenanceTimer()
        
        // --- End of method ---
    }

    internal func setupBookmarkMaintenanceTimer() {
        // Cancel any existing timer
        bookmarkMaintenanceTimer?.invalidate()
        
        // Store current window size to detect major layout changes
        var initialWindowSize: CGSize = .zero
        if let window = self.window {
            initialWindowSize = window.frame.size
        }
        
        // Store initial scroll view size to detect container changes
        var initialScrollViewSize: CGSize = .zero
        if let scrollView = self.enclosingScrollView {
            initialScrollViewSize = scrollView.frame.size
        }
        
        print("📏 Starting bookmark position maintenance timer - will run for up to 2.5 seconds")
        
        // Set up a new timer that repeatedly checks and re-positions if needed
        // This covers us if the header collapses during navigation
        bookmarkMaintenanceTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self,
                  self.isNavigatingToBookmark, // Only if we're still in navigation mode
                  let bookmarkRange = self.lastBookmarkRange,
                  let topMarginPercentage = self.lastTopMarginPercentage,
                  let layoutManager = self.layoutManager,
                  let textContainer = self.textContainer,
                  let enclosingScrollView = self.enclosingScrollView,
                  let documentView = enclosingScrollView.documentView else {
                // If any requirements aren't met, stop the timer
                timer.invalidate()
                // Ensure scrollbar is restored if timer stops prematurely
                self?.enclosingScrollView?.hasVerticalScroller = true
                return
            }
            
            // Check if document size changed significantly (suggests layout is still changing)
            let currentScrollViewSize = enclosingScrollView.frame.size
            let scrollViewSizeChanged = abs(currentScrollViewSize.height - initialScrollViewSize.height) > 10
            
            // Check if window size changed significantly
            var windowSizeChanged = false
            if let window = self.window {
                let currentWindowSize = window.frame.size
                windowSizeChanged = abs(currentWindowSize.height - initialWindowSize.height) > 10
            }
            
            // Get the rect for the target text
            let glyphRange = layoutManager.glyphRange(forCharacterRange: bookmarkRange, actualCharacterRange: nil)
            var targetRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            targetRect = targetRect.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)
            
            // Get the current visible rect
            let visibleRect = enclosingScrollView.contentView.bounds
            
            // Define the optimal area (top 30% of the viewport)
            let optimalAreaHeight = visibleRect.height * 0.3
            let optimalArea = NSRect(
                x: visibleRect.origin.x,
                y: visibleRect.origin.y,
                width: visibleRect.width,
                height: optimalAreaHeight
            )
            
            // Check if the bookmark is in an optimal position
            let isBookmarkInOptimalPosition = optimalArea.contains(targetRect) || 
                                             (optimalArea.intersects(targetRect) && 
                                              targetRect.minY >= optimalArea.minY)
            
            // Force repositioning if layout has changed significantly
            let shouldForceRepositioning = scrollViewSizeChanged || windowSizeChanged
            
            if !isBookmarkInOptimalPosition || shouldForceRepositioning {
                if shouldForceRepositioning {
                    print("📐 MAINTENANCE: Major layout change detected - forcing repositioning")
            } else {
                    print("📐 MAINTENANCE: Bookmark position lost - repositioning")
                }
                
                // Calculate scroll position to position text with the desired top margin
                let topMargin = visibleRect.height * topMarginPercentage
                var scrollPointY = targetRect.minY - topMargin
                
                // Ensure we don't scroll beyond document bounds
                let maxY = max(0, documentView.frame.height - visibleRect.height)
                scrollPointY = max(0, min(scrollPointY, maxY))
                
                print("📏 Recalculated scroll point: \(scrollPointY)")
                
                // Use internalScrollInProgress flag to allow this scroll
                self.internalScrollInProgress = true
                
                // Scroll immediately to the correct position
                let scrollPoint = NSPoint(x: visibleRect.origin.x, y: scrollPointY)
                enclosingScrollView.contentView.scroll(to: scrollPoint)
                enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
                
                self.internalScrollInProgress = false
                
                // Update our record of the initial sizes after a major change
                if shouldForceRepositioning {
                    initialScrollViewSize = currentScrollViewSize
                    if let window = self.window {
                        initialWindowSize = window.frame.size
                    }
                }
            }
            
            // Count how many maintenance checks we've done
            self.maintenanceChecksCount += 1
            
            // Ramp up check frequency if we're approaching the end
            if self.maintenanceChecksCount > 40 && timer.timeInterval > 0.02 {
                print("🚩 Increasing bookmark maintenance check frequency")
                timer.invalidate()
                // Create a new timer with shorter interval for the final checks
                self.bookmarkMaintenanceTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] newTimer in
                    guard let self = self,
                          self.isNavigatingToBookmark, // Only if we're still in navigation mode
                          let bookmarkRange = self.lastBookmarkRange,
                          let topMarginPercentage = self.lastTopMarginPercentage,
                          let layoutManager = self.layoutManager,
                          let textContainer = self.textContainer,
                          let enclosingScrollView = self.enclosingScrollView,
                          let documentView = enclosingScrollView.documentView else {
                        // If any requirements aren't met, stop the timer
                        newTimer.invalidate()
                        // Ensure scrollbar is restored if timer stops prematurely
                        self?.enclosingScrollView?.hasVerticalScroller = true
                        return
                    }
                    
                    // Rest of the logic is the same as the original timer
                    // Get the rect for the target text
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: bookmarkRange, actualCharacterRange: nil)
                    var targetRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                    targetRect = targetRect.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)
                    
                    // Get the current visible rect
                    let visibleRect = enclosingScrollView.contentView.bounds
                    
                    // Define the optimal area (top 30% of the viewport)
                    let optimalAreaHeight = visibleRect.height * 0.3
                    let optimalArea = NSRect(
                        x: visibleRect.origin.x,
                        y: visibleRect.origin.y,
                        width: visibleRect.width,
                        height: optimalAreaHeight
                    )
                    
                    // Check if the bookmark is in an optimal position
                    let isBookmarkInOptimalPosition = optimalArea.contains(targetRect) || 
                                                     (optimalArea.intersects(targetRect) && 
                                                      targetRect.minY >= optimalArea.minY)
                    
                    // Force repositioning
                    if !isBookmarkInOptimalPosition {
                        print("📐 MAINTENANCE: Bookmark position lost in final checks - repositioning")
                        
                        // Calculate scroll position to position text with the desired top margin
                        let topMargin = visibleRect.height * topMarginPercentage
                        var scrollPointY = targetRect.minY - topMargin
                        
                        // Ensure we don't scroll beyond document bounds
                        let maxY = max(0, documentView.frame.height - visibleRect.height)
                        scrollPointY = max(0, min(scrollPointY, maxY))
                        
                        // Use internalScrollInProgress flag to allow this scroll
                        self.internalScrollInProgress = true
                        
                        // Scroll immediately to the correct position
                        let scrollPoint = NSPoint(x: visibleRect.origin.x, y: scrollPointY)
                        enclosingScrollView.contentView.scroll(to: scrollPoint)
                        enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
                        
                        self.internalScrollInProgress = false
                    }
                    
                    // Count how many maintenance checks we've done
                    self.maintenanceChecksCount += 1
                    
                    // After a reasonable number of checks, we can stop monitoring and reset navigation state
                    if self.maintenanceChecksCount >= 50 {
                        print("🚩 Maintenance complete after \(self.maintenanceChecksCount) checks, ending bookmark navigation")
                        self.isNavigatingToBookmark = false
                        newTimer.invalidate()
                        self.bookmarkMaintenanceTimer = nil
                        self.lastBookmarkRange = nil
                        self.lastTopMarginPercentage = nil
                        self.maintenanceChecksCount = 0
                        // Restore scrollbar visibility
                        print("🔙 Restoring scrollbar visibility")
                        enclosingScrollView.hasVerticalScroller = true
                    }
                }
            }
        }
        
        // Reset the check counter
        maintenanceChecksCount = 0
    }

    internal func registerForBookmarkNavigation() {
        // Remove any existing observer
        if let observer = bookmarkScrollObserver {
            NotificationCenter.default.removeObserver(observer)
            bookmarkScrollObserver = nil
        }
        
        // Create new observer
        bookmarkScrollObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ScrollToBookmark"),
            object: nil,
            queue: .main) { [weak self] notification in
                guard let self = self else { return }
                
                // Hide scrollbar BEFORE navigating
                print("🚫 Hiding scrollbar for bookmark navigation")
                self.enclosingScrollView?.hasVerticalScroller = false
                
                // Set flag before navigating
                self.isNavigatingToBookmark = true
                print("🚩 Setting isNavigatingToBookmark = true")
                
                // Cancel any existing maintenance timer
                self.bookmarkMaintenanceTimer?.invalidate()
                self.bookmarkMaintenanceTimer = nil
                
                // Check if header is expanded - this is where we actually need the delay
                // Access through document object
                let headerIsExpanded = self.document?.isHeaderExpanded ?? false
                // Check if we're at the top where header expansion would matter
                let isAtTop = self.enclosingScrollView?.contentView.bounds.origin.y ?? 0 <= 0
                
                // Only use a delay if the header is expanded and we're at the top
                if headerIsExpanded && isAtTop {
                    print("📝 Header is expanded and visible - using delay for navigation")
                    // Allow time for header animation to complete before scrolling to bookmark
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else { return }
                        self.processBookmarkNavigation(notification: notification)
            }
        } else {
                    print("📝 Header is not expanded or not visible - navigating immediately")
                    // Navigate immediately if header doesn't need to collapse
                    self.processBookmarkNavigation(notification: notification)
                }
            }
    }

    internal func processBookmarkNavigation(notification: Notification) {
        if let userInfo = notification.userInfo {
            // Check if we have character position metadata
            if let charPosition = userInfo["charPosition"] as? Int,
               let charLength = userInfo["charLength"] as? Int {
                // If we have character position, use it for more precise highlighting
                self.scrollToCharacterPosition(charPosition, length: charLength)
            } else if let lineNumber = userInfo["lineNumber"] as? Int {
                // Fall back to line-based navigation if no character data
                self.scrollToLine(lineNumber)
            }
        } else {
            // Reset flag if navigation fails
            self.isNavigatingToBookmark = false
            print("🚩 Resetting isNavigatingToBookmark = false (failed navigation)")
            // Ensure scrollbar is restored on failure
            print("🔙 Restoring scrollbar visibility on navigation failure")
            self.enclosingScrollView?.hasVerticalScroller = true
        }
    }

    internal func scrollToLine(_ lineNumber: Int) {
        // --- Start of method --- 
        print("📚 DocumentTextView: Scrolling to line \(lineNumber)")
        
        // Cancel any existing maintenance timer
        bookmarkMaintenanceTimer?.invalidate()
        bookmarkMaintenanceTimer = nil

        let text = self.string
        let lines = text.components(separatedBy: .newlines)
        
        // Safety check
        guard lineNumber > 0 && lineNumber <= lines.count else {
            print("⚠️ Invalid line number: \(lineNumber), document has \(lines.count) lines")
            self.isNavigatingToBookmark = false
            return
        }
        
        // Calculate character position of the line start
        var characterPosition = 0
        for i in 0..<(lineNumber - 1) {
            characterPosition += lines[i].count + 1 // +1 for the newline character
        }
        
        // Get the length of the target line
        let lineLength = lines[lineNumber - 1].count
        
        // Create ranges
        let lineRange = NSRange(location: characterPosition, length: lineLength)
        
        // Force layout calculation before scrolling
        self.layoutManager?.ensureLayout(forCharacterRange: NSRange(location: 0, length: text.count))
                
        // Look for actual bookmark attributes in this line
        var bookmarkRange = lineRange
        if let textStorage = self.textStorage {
            // Check if there's a bookmark attribute in this line
            textStorage.enumerateAttribute(.isBookmark, in: lineRange, options: []) { (value, range, stop) in
                if value != nil {
                    // Found bookmark attribute within this line
                    bookmarkRange = range
                    stop.pointee = true
                }
            }
        }
        
        // Store this range for potential repositioning
        self.lastBookmarkRange = bookmarkRange
        self.lastTopMarginPercentage = 0.15 // Store the desired top margin (15%)
        
        // First position the line near the top of the visible area
        if let layoutManager = self.layoutManager,
           let textContainer = self.textContainer,
           let enclosingScrollView = self.enclosingScrollView,
           let documentView = enclosingScrollView.documentView {
            
            // Get the rect for the target text
            let glyphRange = layoutManager.glyphRange(forCharacterRange: bookmarkRange, actualCharacterRange: nil)
            var targetRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            targetRect = targetRect.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)
            
            print("📐 Target rect before scroll: \(targetRect)")
            
            // Get the current visible rect
            let visibleRect = enclosingScrollView.contentView.bounds
            
            // Define the optimal area (top 30% of the viewport)
            let optimalAreaHeight = visibleRect.height * 0.3
            let optimalArea = NSRect(
                x: visibleRect.origin.x,
                y: visibleRect.origin.y,
                width: visibleRect.width,
                height: optimalAreaHeight
            )
            
            // Check if the bookmark is already in an optimal position
            let isBookmarkInOptimalPosition = optimalArea.contains(targetRect) || 
                                             (optimalArea.intersects(targetRect) && 
                                              targetRect.minY >= optimalArea.minY)
            
            if !isBookmarkInOptimalPosition {
                print("📜 Bookmark not in optimal position - repositioning")
                // Calculate scroll position to position text about 15% from the top
                let topMargin = visibleRect.height * 0.15 // 15% from the top
                var scrollPointY = targetRect.minY - topMargin
                
                // Ensure we don't scroll beyond document bounds
                let maxY = max(0, documentView.frame.height - visibleRect.height)
                scrollPointY = max(0, min(scrollPointY, maxY))
                
                print("📏 Calculated scroll point: \(scrollPointY)")
                
                
                // --- Use internalScrollInProgress flag ---
                self.internalScrollInProgress = true // Signal that this scroll is intentional
                print("🚩 Setting internalScrollInProgress = true")
                // Use immediate scroll first to ensure proper positioning
                let scrollPoint = NSPoint(x: visibleRect.origin.x, y: scrollPointY)
                enclosingScrollView.contentView.scroll(to: scrollPoint)
                enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
                self.internalScrollInProgress = false // Reset flag immediately after
                print("🚩 Resetting internalScrollInProgress = false")
                // --- End flag usage ---
                
                // Then animate slightly to provide visual feedback (also needs flag)
                DispatchQueue.main.async {
                    self.internalScrollInProgress = true // Signal that this scroll is intentional
                    print("🚩 Setting internalScrollInProgress = true (animation)")
                    NSAnimationContext.runAnimationGroup({
                        context in
                        context.duration = 0.1
                        enclosingScrollView.contentView.animator().setBoundsOrigin(scrollPoint)
                        enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
                    }, completionHandler: {
                         // Reset flag after animation completes
                        self.internalScrollInProgress = false 
                        print("🚩 Resetting internalScrollInProgress = false (animation complete)")
                    })
                }
            } else {
                print("📜 Bookmark already in optimal position - not scrolling, just highlighting")
            }
        }
        
        // Ensure the view has focus
        if let window = self.window {
            window.makeFirstResponder(self)
        }
        
        // Apply a temporary highlight to the bookmarked text
        if let textStorage = self.textStorage {
            // Store original attributes for later restoration
            let originalAttributes = textStorage.attributes(at: bookmarkRange.location, effectiveRange: nil)
            
            // Start editing
            textStorage.beginEditing()
            
            // Apply highlight color
            let highlightColor = NSColor.systemBlue.withAlphaComponent(0.2)
            textStorage.addAttribute(.backgroundColor, value: highlightColor, range: bookmarkRange)
            
            // End editing to update the view
            textStorage.endEditing()
            
            // Schedule removal of highlight after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self, let _ = self.textStorage else { return }
                
                // Start the fade-out effect
                self.animateHighlightRemoval(range: bookmarkRange, originalAttributes: originalAttributes)
            }
        }
        
        // Set cursor position at the start of the bookmarked text
        self.setSelectedRange(NSRange(location: bookmarkRange.location, length: 0))
        
        // Set up a maintenance timer to keep the bookmark position correct
        // during layout changes (like header collapse)
        self.setupBookmarkMaintenanceTimer()
        
        // --- End of method ---
    }

    // MARK: - Deinitialization Helper for Timers
    internal func cleanupBookmarkNavigation() {
        bookmarkMaintenanceTimer?.invalidate()
        bookmarkMaintenanceTimer = nil
        if let observer = bookmarkScrollObserver {
            NotificationCenter.default.removeObserver(observer)
            bookmarkScrollObserver = nil
        }
    }

    // Helper method to animate the highlight removal
    internal func animateHighlightRemoval(range: NSRange, originalAttributes: [NSAttributedString.Key: Any]) {
        guard self.textStorage != nil else { return }

        // We'll create a sequence of fading colors to simulate an animation
        let steps = 5
        let duration = 0.4 // total animation duration
        let stepDuration = duration / Double(steps)

        for i in 0..<steps {
            let delay = stepDuration * Double(i)
            let alpha = 0.2 * (1.0 - (Double(i) / Double(steps)))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, let textStorage = self.textStorage else { return }
                
                // Start editing
                textStorage.beginEditing()
                
                // Either fade out the background color or restore original attributes
                if i < steps - 1 {
                    // Use a fading blue
                    let fadeColor = NSColor.systemBlue.withAlphaComponent(CGFloat(alpha))
                    textStorage.addAttribute(.backgroundColor, value: fadeColor, range: range)
                } else {
                    // For the last step, restore all original attributes
                    // First remove all attributes to avoid any conflicts
                    textStorage.setAttributes([:], range: range)
                    
                    // Then apply the original attributes
                    for (key, value) in originalAttributes {
                        textStorage.addAttribute(key, value: value, range: range)
                    }
                }
                
                // End editing to update the view
                textStorage.endEditing()
            }
        }
    }
}
#endif 