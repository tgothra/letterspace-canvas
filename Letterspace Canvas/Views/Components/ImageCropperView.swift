import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ImageCropperView: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    #if os(macOS)
    let image: NSImage
    let onSave: (NSImage) -> Void
    #elseif os(iOS)
    // If we make cropper cross-platform, image would be UIImage
    // For now, this view might be macOS only due to NSImage specific logic for cropping
    let image: UIImage // Placeholder for iOS path
    let onSave: (UIImage) -> Void // Placeholder for iOS path
    #endif
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    
    // Unique ID for the image view for screenshot identification
    @State private var displayedImageId = UUID()
    
    // Constants
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0
    private let cropSize: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Adjust Profile Image")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("Drag to position and pinch to zoom your image")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
            
            // Image cropper area
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.1) : Color(.sRGB, white: 0.95))
                    .frame(width: 280, height: 280)
                
                // Actual image with gestures - this is what we'll capture
                ZStack {
                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: cropSize, height: cropSize)
                        .clipShape(Circle())
                    #elseif os(iOS)
                    // Placeholder for iOS image display if cropper is made cross-platform
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: cropSize, height: cropSize)
                        .clipShape(Circle())
                    #endif
                }
                .id(displayedImageId) // This helps us identify it for screenshot
                .overlay(
                    Circle()
                        .stroke(theme.accent, lineWidth: 2)
                        .frame(width: cropSize, height: cropSize)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, minScale), maxScale)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                initializeImagePosition(size: CGSize(width: cropSize, height: cropSize))
                            }
                        }
                )
            }
            .frame(height: 300)
            
            Text("Double-tap to reset")
                .font(.system(size: 11))
                .foregroundStyle(theme.secondary)
                .padding(.top, -10)
            
            // Action buttons
            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondary)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.secondary.opacity(0.1))
                .cornerRadius(8)
                
                Button("Save") {
                    saveEditedImage()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.accent)
                .cornerRadius(8)
            }
        }
        .padding(24)
        .frame(width: 340)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
        .onAppear {
            initializeImagePosition(size: CGSize(width: cropSize, height: cropSize))
        }
    }
    
    private func initializeImagePosition(size: CGSize) {
        // Store the frame size
        imageSize = size
        
        // For filling, we want to use the minimum scale that ensures
        // the smallest dimension covers the circle completely
        let scaleWidth = cropSize / image.size.width
        let scaleHeight = cropSize / image.size.height
        
        // Choose the larger scale to ensure the image fills the circle
        let fillScale = max(scaleWidth, scaleHeight)
        
        // Apply the scale, ensuring it's at least our minimum scale
        // and add 10% additional zoom for better filling
        scale = max(fillScale * 1.1, minScale)
        lastScale = scale
        
        // Center the image
        offset = .zero
        lastOffset = .zero
    }
    
    private func saveEditedImage() {
        // Combining our solutions: correct zoom + fixed Y-axis direction
        #if os(macOS)
        let finalImage = NSImage(size: CGSize(width: cropSize, height: cropSize))
        
        finalImage.lockFocus()
        
        // Apply circular clipping path
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: NSSize(width: cropSize, height: cropSize))).setClip()
        
        // Calculate what portion of the original image is visible
        
        // STEP 1: Calculate initial scale that makes the image fill the circle
        // This is exactly what we do in initializeImagePosition()
        let scaleWidth = cropSize / image.size.width
        let scaleHeight = cropSize / image.size.height
        let initialFillScale = max(scaleWidth, scaleHeight)
        
        // STEP 2: Calculate the visible rectangle at the current zoom level
        // We need to account for the initial fill scale when calculating the viewport
        let effectiveScale = initialFillScale * scale
        let visibleWidth = cropSize / effectiveScale
        let visibleHeight = cropSize / effectiveScale
        
        // STEP 3: Calculate the center point and apply offset
        let centerX = image.size.width / 2
        let centerY = image.size.height / 2
        
        // Apply offsets with correct direction for each axis
        // X: Negative because moving image right means viewing more of the left side
        // Y: Positive because of flipped coordinate system between SwiftUI and NSImage
        let adjustedX = centerX - (offset.width / effectiveScale)
        let adjustedY = centerY + (offset.height / effectiveScale) // Y-FLIPPED!
        
        // STEP 4: Calculate the final source rectangle
        let sourceRect = NSRect(
            x: adjustedX - (visibleWidth / 2),
            y: adjustedY - (visibleHeight / 2),
            width: visibleWidth,
            height: visibleHeight
        )
        
        // STEP 5: Draw the image
        let destRect = NSRect(x: 0, y: 0, width: cropSize, height: cropSize)
        image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
        
        finalImage.unlockFocus()
        
        // Debug information
        print("DEBUG: COMBINED SOLUTION")
        print("DEBUG: Image size: \(image.size.width) x \(image.size.height)")
        print("DEBUG: Initial fill scale: \(initialFillScale)")
        print("DEBUG: User scale: \(scale)")
        print("DEBUG: Effective scale: \(effectiveScale)")
        print("DEBUG: Visible size: \(visibleWidth) x \(visibleHeight)")
        print("DEBUG: User offset: \(offset)")
        print("DEBUG: Adjusted center: \(adjustedX), \(adjustedY)")
        print("DEBUG: Source rect: \(sourceRect)")
        
        // Ensure we handle the cropped image properly before saving
        if let tiffData = finalImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            
            // Create a new NSImage from the JPEG data to ensure it's properly formatted
            if let processedImage = NSImage(data: jpegData) {
                // Save within a dispatched block to avoid immediate UI changes that might cause the app to dismiss
                DispatchQueue.main.async {
                    // Now save it through the manager
                    onSave(processedImage)
                    
                    // Close just the modal/sheet
                    isPresented = false
                    dismiss()
                }
            } else {
                 isPresented = false
                 dismiss()
            }
        } else {
            isPresented = false
            dismiss()
        }
        #elseif os(iOS)
        // iOS save logic for UIImage - potentially just pass back the selected image if no cropper
        // Or implement UIImage cropping here if ImageCropperView becomes cross-platform.
        print("iOS: saveEditedImage called. Cropping logic is macOS specific. Passing back original selected image for now.")
        onSave(image) // image is UIImage here
        isPresented = false
        dismiss()
        #endif
    }
}
