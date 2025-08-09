import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Utility for converting SF Symbol icons to images that can be used as header images
struct IconToImageConverter {
    
    /// Converts an SF Symbol to a high-quality image suitable for header use
    /// - Parameters:
    ///   - systemName: The SF Symbol system name
    ///   - size: The desired size for the image (default: 400x225 for 16:9 aspect ratio)
    ///   - backgroundColor: Background color for the icon (default: theme accent color)
    ///   - iconColor: Color of the icon itself (default: white)
    ///   - isCircular: Whether to create a circular icon (default: false for regular header images)
    /// - Returns: Platform-specific image (UIImage on iOS, NSImage on macOS)
    static func createHeaderImage(
        from systemName: String,
        size: CGSize = CGSize(width: 400, height: 225),
        backgroundColor: Color = .blue,
        iconColor: Color = .white,
        isCircular: Bool = false
    ) -> PlatformSpecificImage? {
        
        #if os(iOS)
        return createUIImage(from: systemName, size: size, backgroundColor: backgroundColor, iconColor: iconColor, isCircular: isCircular)
        #else
        return createNSImage(from: systemName, size: size, backgroundColor: backgroundColor, iconColor: iconColor, isCircular: isCircular)
        #endif
    }
    
    #if os(iOS)
    private static func createUIImage(
        from systemName: String,
        size: CGSize,
        backgroundColor: Color,
        iconColor: Color,
        isCircular: Bool
    ) -> UIImage? {
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            if isCircular {
                // Create circular clipping path
                let radius = min(size.width, size.height) / 2
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let circlePath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                circlePath.addClip()
            }
            
            // Fill background
            UIColor(backgroundColor).setFill()
            context.fill(rect)
            
            // Create and draw the SF Symbol
            let iconSize = min(size.width, size.height) * (isCircular ? 0.5 : 0.4) // Larger icon for circular
            let configuration = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
            
            guard let symbolImage = UIImage(systemName: systemName, withConfiguration: configuration) else {
                return
            }
            
            // Tint the icon
            let tintedImage = symbolImage.withTintColor(UIColor(iconColor), renderingMode: .alwaysOriginal)
            
            // Center the icon
            let iconRect = CGRect(
                x: (size.width - tintedImage.size.width) / 2,
                y: (size.height - tintedImage.size.height) / 2,
                width: tintedImage.size.width,
                height: tintedImage.size.height
            )
            
            tintedImage.draw(in: iconRect)
        }
    }
    #else
    private static func createNSImage(
        from systemName: String,
        size: CGSize,
        backgroundColor: Color,
        iconColor: Color,
        isCircular: Bool
    ) -> NSImage? {
        
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        
        if isCircular {
            // Create circular clipping path
            let radius = min(size.width, size.height) / 2
            let center = NSPoint(x: size.width / 2, y: size.height / 2)
            let circlePath = NSBezierPath()
            circlePath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            circlePath.addClip()
        }
        
        // Fill background
        NSColor(backgroundColor).setFill()
        rect.fill()
        
        // Create and draw the SF Symbol
        let iconSize = min(size.width, size.height) * (isCircular ? 0.5 : 0.4) // Larger icon for circular
        let configuration = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
        
        guard let symbolImage = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(configuration) else {
            image.unlockFocus()
            return nil
        }
        
        // Tint the icon
        symbolImage.lockFocus()
        NSColor(iconColor).set()
        NSRect(origin: .zero, size: symbolImage.size).fill(using: .sourceAtop)
        symbolImage.unlockFocus()
        
        // Center the icon
        let iconRect = NSRect(
            x: (size.width - symbolImage.size.width) / 2,
            y: (size.height - symbolImage.size.height) / 2,
            width: symbolImage.size.width,
            height: symbolImage.size.height
        )
        
        symbolImage.draw(in: iconRect)
        
        image.unlockFocus()
        
        return image
    }
    #endif
    
    /// Creates a circular icon image suitable for header display
    /// - Parameters:
    ///   - systemName: The SF Symbol system name
    ///   - size: The desired size for the circular icon (default: 80x80)
    ///   - backgroundColor: Background color for the icon
    ///   - iconColor: Color of the icon itself
    /// - Returns: Platform-specific circular image
    static func createCircularIcon(
        from systemName: String,
        size: CGSize = CGSize(width: 80, height: 80),
        backgroundColor: Color = .blue,
        iconColor: Color = .white
    ) -> PlatformSpecificImage? {
        return createHeaderImage(
            from: systemName,
            size: size,
            backgroundColor: backgroundColor,
            iconColor: iconColor,
            isCircular: true
        )
    }
    
    /// Creates image data from an SF Symbol suitable for saving
    /// - Parameters:
    ///   - systemName: The SF Symbol system name
    ///   - backgroundColor: Background color for the icon
    ///   - iconColor: Color of the icon itself
    ///   - isCircular: Whether to create a circular icon
    /// - Returns: Image data (JPEG format)
    static func createImageData(
        from systemName: String,
        backgroundColor: Color = .blue,
        iconColor: Color = .white,
        isCircular: Bool = false
    ) -> Data? {
        
        guard let image = createHeaderImage(
            from: systemName,
            backgroundColor: backgroundColor,
            iconColor: iconColor,
            isCircular: isCircular
        ) else {
            return nil
        }
        
        #if os(iOS)
        return image.jpegData(compressionQuality: 0.9)
        #else
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        #endif
    }
}


