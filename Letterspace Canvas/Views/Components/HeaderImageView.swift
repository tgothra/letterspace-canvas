import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct HeaderImageView: View {
    @Binding var element: DocumentElement
    @Binding var document: Letterspace_CanvasDocument
    @State private var headerImageHeight: CGFloat = 300
    @State private var isHovering = false
    #if os(macOS)
    @State private var nsImage: NSImage?
    #elseif os(iOS)
    @State private var uiImage: UIImage?
    #endif
    @State private var isImageLoading = true
    @State private var isAppeared = false  // New state to track if view has appeared
    @Environment(\.documentSave) var parentDocumentSave
    @Environment(\.themeColors) var theme
    
    var body: some View {
        let isIcon = element.content.contains("header_icon_")
        
        Group {
            #if os(macOS)
            if let image = nsImage {
                GeometryReader { geo in
                    ZStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: isIcon ? .fit : .fit)
                            .frame(width: isIcon ? min(geo.size.width, 300) : geo.size.width + 96, 
                                   height: isIcon ? min(geo.size.width, 300) : nil,
                                   alignment: .center)
                            .clipShape(isIcon ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 12)))
                            .position(x: geo.size.width / 2, y: headerImageHeight / 2)
                            .padding(.horizontal, isIcon ? 0 : -48)
                            .background(Color.clear)
                            .opacity(isAppeared ? 1 : 0)  // Simple fade in
                            .onAppear {
                                headerImageHeight = isIcon ? min(geo.size.width, 300) : calculateHeaderImageHeight(platformImage: image, containerWidth: geo.size.width + 96)
                                // Allow layout to settle first, then animate in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        isAppeared = true
                                        isImageLoading = false
                                    }
                                }
                            }
                            .onChange(of: geo.size.width) { oldValue, newValue in
                                headerImageHeight = isIcon ? min(newValue, 300) : calculateHeaderImageHeight(platformImage: image, containerWidth: newValue + 96)
                            }
                    }
                    .overlay(alignment: .topLeading) {
                        optionsMenu
                            .offset(x: -48, y: 16)
                            .opacity(isHovering ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHovering = hovering
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: headerImageHeight)
            } else {
                ImagePickerButton(element: $element, document: $document)
                    .padding(.horizontal, -DesignSystem.Spacing.xl)
                    .environment(\.documentSave, parentDocumentSave)
                    .opacity(isAppeared ? 1 : 0)  // Fade in button too
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isAppeared = true
                        }
                    }
            }
            #elseif os(iOS)
            if let image = uiImage {
                GeometryReader { geo in
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: isIcon ? .fit : .fit)
                            .frame(width: isIcon ? min(geo.size.width, 300) : geo.size.width + 96,
                                   height: isIcon ? min(geo.size.width, 300) : nil,
                                   alignment: .center)
                            .clipShape(isIcon ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 12)))
                            .position(x: geo.size.width / 2, y: headerImageHeight / 2)
                            .padding(.horizontal, isIcon ? 0 : -48)
                            .background(Color.clear)
                            .opacity(isAppeared ? 1 : 0)  // Simple fade in
                            .onAppear {
                                headerImageHeight = isIcon ? min(geo.size.width, 300) : calculateHeaderImageHeight(platformImage: image, containerWidth: geo.size.width + 96)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        isAppeared = true
                                        isImageLoading = false
                                    }
                                }
                            }
                            .onChange(of: geo.size.width) { oldValue, newValue in
                                headerImageHeight = isIcon ? min(newValue, 300) : calculateHeaderImageHeight(platformImage: image, containerWidth: newValue + 96)
                            }
                    }
                    // Options menu might need different presentation on iOS (e.g., long press or tap)
                    // .overlay(alignment: .topLeading) {
                    //     optionsMenu
                    //         .offset(x: -48, y: 16) // Adjust offset as needed for iOS
                    // }
                }
                .frame(maxWidth: .infinity)
                .frame(height: headerImageHeight)
            } else {
                // Consider an iOS-specific ImagePickerButton or a more generic one
                ImagePickerButton(element: $element, document: $document)
                    .padding(.horizontal, -DesignSystem.Spacing.xl) // Adjust padding for iOS
                    .environment(\.documentSave, parentDocumentSave)
                    .opacity(isAppeared ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isAppeared = true
                        }
                    }
            }
            #endif
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: element.content) { oldValue, newValue in
            isAppeared = false  // Reset appearance state
            isImageLoading = true
            loadImage()
        }
        .onChange(of: document.isHeaderExpanded) { oldValue, newValue in
            if !newValue {
                withAnimation(.easeInOut(duration: 0.45)) {
                    isAppeared = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        #if os(macOS)
                        nsImage = nil
                        #elseif os(iOS)
                        uiImage = nil
                        #endif
                    }
                }
            } else {
                isAppeared = false
                loadImage()
            }
        }
    }
    
    private var optionsMenu: some View {
        Menu {
            Button(role: .destructive, action: {
                withAnimation {
                    // Remove the image file if it exists
                    if !element.content.isEmpty,
                       let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let documentPath = documentsPath.appendingPathComponent("\(document.id)")
                        let imagesPath = documentPath.appendingPathComponent("Images")
                        let imageUrl = imagesPath.appendingPathComponent(element.content)
                        try? FileManager.default.removeItem(at: imageUrl)
                    }
                    
                    // Update the element content
                    element.content = ""
                    
                    // Update the document's elements array
                    if let index = document.elements.firstIndex(where: { $0.id == element.id }) {
                        document.elements[index] = element
                    }
                    
                    // Save the document
                    document.save()
                    
                    // Update local UI state
                    #if os(macOS)
                    nsImage = nil
                    #elseif os(iOS)
                    uiImage = nil
                    #endif
                }
            }) {
                Label("Remove", systemImage: "trash")
            }
        } label: {
            Circle()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private func loadImage() {
        // Only load image if header is expanded AND content is not empty
        if !document.isHeaderExpanded || element.content.isEmpty {
            // Use a spring animation to clear the image
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAppeared = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    #if os(macOS)
                    nsImage = nil
                    #elseif os(iOS)
                    uiImage = nil
                    #endif
                }
            }
            return
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let documentPath = documentsPath.appendingPathComponent("\(document.id)")
        let imagesPath = documentPath.appendingPathComponent("Images")
        let imageUrl = imagesPath.appendingPathComponent(element.content)
            
        // First check if the file exists
        if !FileManager.default.fileExists(atPath: imageUrl.path) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAppeared = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    #if os(macOS)
                    nsImage = nil
                    #elseif os(iOS)
                    uiImage = nil
                    #endif
                }
            }
            return
        }
            
        // First try to get the image from cache
        if let cachedImage = ImageCache.shared.image(for: element.content) {
            isAppeared = false // Reset appearance before showing
            #if os(macOS)
            nsImage = cachedImage
            #elseif os(iOS)
            uiImage = cachedImage
            #endif
            // Animation will happen in onAppear
            return
        }
            
        // If not in cache, load asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            #if os(macOS)
            if let image = NSImage(contentsOf: imageUrl) {
                // Cache the image
                ImageCache.shared.setImage(image, for: element.content)
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Double check header is still expanded before setting image
                    if document.isHeaderExpanded {
                        isAppeared = false  // Reset appearance state
                        nsImage = image
                        // Animation will happen in onAppear
                    }
                }
            } else {
                // If image can't be loaded, update UI on main thread
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isAppeared = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            nsImage = nil
                        }
                    }
                }
            }
            #elseif os(iOS)
            // Use .path for UIImage initializer
            if let image = UIImage(contentsOfFile: imageUrl.path) {
                // Cache the image
                ImageCache.shared.setImage(image, for: element.content)
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Double check header is still expanded before setting image
                    if document.isHeaderExpanded {
                        isAppeared = false  // Reset appearance state
                        uiImage = image
                        // Animation will happen in onAppear
                    }
                }
            } else {
                // If image can't be loaded, update UI on main thread
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isAppeared = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            uiImage = nil
                        }
                    }
                }
            }
            #endif
        }
    }
    
    #if os(macOS)
    private func calculateHeaderImageHeight(platformImage image: NSImage, containerWidth: CGFloat) -> CGFloat {
        guard image.size.height > 0 else { return 300 } // Avoid division by zero
        let aspectRatio = image.size.width / image.size.height
        guard aspectRatio > 0 else { return 300 } // Avoid division by zero or negative aspect ratio
        return containerWidth / aspectRatio
    }
    #elseif os(iOS)
    private func calculateHeaderImageHeight(platformImage image: UIImage, containerWidth: CGFloat) -> CGFloat {
        guard image.size.height > 0 else { return 300 } // Avoid division by zero
        let aspectRatio = image.size.width / image.size.height
        guard aspectRatio > 0 else { return 300 } // Avoid division by zero or negative aspect ratio
        return containerWidth / aspectRatio
    }
    #endif
} 