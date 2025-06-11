#if os(macOS)
import AppKit
import ObjectiveC

// Associated keys for caching
private struct AssociatedKeys {
    static var cachedDescendantViews: UnsafeRawPointer = UnsafeRawPointer(bitPattern: "cachedDescendantViews".hashValue)!
}

extension NSView {
    /// Returns all descendant views recursively with memoization for better performance
    var allDescendantViews: [NSView] {
        // Use a cache to avoid redundant calculations
        if let cachedViews = objc_getAssociatedObject(self, AssociatedKeys.cachedDescendantViews) as? [NSView] {
            return cachedViews
        }
        
        var views = [NSView]()
        
        // Add safeguard for empty subviews
        guard !subviews.isEmpty else { return views }
        
        for subview in subviews {
            views.append(subview)
            
            // Add safeguard for recursive call
            if !subview.subviews.isEmpty {
                views.append(contentsOf: subview.allDescendantViews)
            }
        }
        
        // Cache the result
        objc_setAssociatedObject(self, AssociatedKeys.cachedDescendantViews, views, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return views
    }
    
    /// Find the first descendant view of the specified type
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        // Check self first
        if let selfAsType = self as? T {
            return selfAsType
        }
        
        // Add safeguard for empty subviews
        guard !subviews.isEmpty else { return nil }
        
        // Use breadth-first search for better performance
        var queue = subviews
        var index = 0
        
        while index < queue.count {
            let subview = queue[index]
            index += 1
            
            if let viewOfType = subview as? T {
                return viewOfType
            }
            
            queue.append(contentsOf: subview.subviews)
        }
        
        return nil
    }
    
    /// Find all descendant views of the specified type
    func allDescendants<T: NSView>(ofType type: T.Type) -> [T] {
        var descendants = [T]()
        
        // Check self first
        if let selfAsType = self as? T {
            descendants.append(selfAsType)
        }
        
        // Add safeguard for empty subviews
        guard !subviews.isEmpty else { return descendants }
        
        // Use breadth-first search for better performance
        var queue = subviews
        var index = 0
        
        while index < queue.count {
            let subview = queue[index]
            index += 1
            
            if let viewOfType = subview as? T {
                descendants.append(viewOfType)
            }
            
            queue.append(contentsOf: subview.subviews)
        }
        
        return descendants
    }
    
    /// Invalidate the cached descendant views
    func invalidateDescendantViewsCache() {
        objc_setAssociatedObject(self, AssociatedKeys.cachedDescendantViews, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Recursively invalidate cache for all subviews
        for subview in subviews {
            subview.invalidateDescendantViewsCache()
        }
    }
}

// Add extension to hide window buttons
extension NSWindow {
    func hideStandardButtons() {
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }
}
#endif 