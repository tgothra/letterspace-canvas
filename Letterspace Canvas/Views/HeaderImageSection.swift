import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit // For UIImage and potentially other UIKit elements if needed later
#endif
import UniformTypeIdentifiers

// Extension for String isEmpty check
extension String {
    var isNotEmpty: Bool {
        return !self.isEmpty
    }
}

struct HeaderImageSection: View {
    @Binding var isExpanded: Bool
    #if os(macOS)
    @Binding var headerImage: NSImage?
    #elseif os(iOS)
    @Binding var headerImage: UIImage?
    #endif
    @Binding var isShowingImagePicker: Bool
    @Binding var document: Letterspace_CanvasDocument
    @State private var isHoveringSubtitle = false
    @Binding var viewMode: ViewMode
    let colorScheme: ColorScheme
    let paperWidth: CGFloat
    @Binding var isHeaderSectionActive: Bool
    @Binding var isHeaderExpanded: Bool
    @Binding var isEditorFocused: Bool
    let onClick: () -> Void  // Keep for compatibility but won't use
    @State private var isHoveringPhoto = false
    @State private var isHoveringX = false
    @State private var isHoveringHeader = false
    @Binding var isTitleVisible: Bool
    @Binding var showTooltip: Bool
    @Binding var hasShownTooltip: Bool
    @Binding var hasShownRevealTooltip: Bool
    @State private var isImageLoading = false
    @State private var placeholderOpacity: Double = 0.0
    #if os(macOS)
    @State private var lastUploadedImage: NSImage? = nil
    #elseif os(iOS)
    @State private var lastUploadedImage: UIImage? = nil
    #endif
    @FocusState private var isContentEditorFocused: Bool
    // New state to control visibility timing
    @State private var isVisible: Bool = false
    
    // Heights for the collapsed header bar
    private let collapsedBarHeight: CGFloat = 64
    
    // Access underlying NSWindow to manage first responder
    #if os(macOS)
    private var window: NSWindow? {
        return NSApp.keyWindow
    }
    #elseif os(iOS)
    private var window: UIWindow? {
        return UIApplication.shared.windows.first { $0.isKeyWindow }
    }
    #endif
    
    var body: some View {
        if !self.isHeaderExpanded { // If the header FEATURE is off
            EmptyView()
        } else { // Header FEATURE is ON
            ZStack {
                // Simply display the header image or placeholder
                if let headerImage = headerImage { // Actual image EXISTS
                    expandedHeaderView(headerImage)
                } else { // Show placeholder
                    placeholderImageView
                        .onTapGesture {
                            isShowingImagePicker = true
                        }
                }
                
                // Loading indicator
                if isImageLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                        .edgesIgnoringSafeArea(.all)
                }
            }
            .frame(width: paperWidth)
            .onAppear {
                loadHeaderImageIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isVisible = true
                    }
                }
            }
            .onChange(of: document.id) {
                headerImage = nil
                loadHeaderImageIfNeeded()
            }
            .sheet(isPresented: $isShowingImagePicker) {
                #if os(macOS)
                SimpleMacOSFilePicker(
                    isPresented: $isShowingImagePicker,
                    allowedContentTypes: [UTType.image],
                    onFilePicked: { url in
                        handleImageSelection(url: url)
                    },
                    onCancel: {
                        // Just close the picker
                    }
                )
                #elseif os(iOS)
                EmptyView() // Placeholder for iOS image picker
                #endif
            }
        }
    }

    // MARK: - Expanded Header View
    @ViewBuilder
    private func expandedHeaderView(_ image: PlatformSpecificImage) -> some View {
        let size = image.size
        let aspectRatioValue = size.height / size.width // Calculate aspect ratio once
        let headerHeight = paperWidth * aspectRatioValue

        // Apply modifiers directly inside platform blocks
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: paperWidth, height: headerHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98))),
                removal: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98)))
            ))
            .animation(.easeInOut(duration: 0.35), value: isExpanded)
            .drawingGroup()
            .overlay(alignment: .bottomTrailing) {
                if isHoveringHeader { headerMenu }
            }
        #elseif os(iOS)
        Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: paperWidth, height: headerHeight)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98))),
                                        removal: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98)))
                                    ))
                                    .animation(.easeInOut(duration: 0.35), value: isExpanded)
                                    .drawingGroup()
                                    .overlay(alignment: .bottomTrailing) {
                if isHoveringHeader { headerMenu }
            }
        #else
        // Fallback for other platforms or if specific image type isn't available
        EmptyView() // Or some placeholder text
        #endif
    }

    // MARK: - Placeholder Image View
    @ViewBuilder
    private var placeholderImageView: some View {
        // This is shown when headerImage is nil but isExpanded is true
                            Rectangle()
                                .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1.0))
                                .frame(maxWidth: paperWidth)
            // The height might need to be dynamic based on viewMode or a fixed value for placeholder
            .frame(height: viewMode == .minimal ? 160 : 300) // Adjusted height for placeholder
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98))),
                                    removal: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98)))
                                ))
            .animation(.easeInOut(duration: 0.35), value: isExpanded) // Make sure this animation is desired here
                                .drawingGroup()
                                .overlay(
                                    Button(action: {
                    // Action to show the image picker
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            isShowingImagePicker = true
                                        }
                                    }) {
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.system(size: 48))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                                                .padding(.bottom, 8)
                                            
                                            Text("Add Header Image")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                                        }
                    .contentShape(Rectangle()) // Ensure the whole area is tappable
                                    }
                                    .buttonStyle(.plain)
                                )
    }

    // MARK: - Header Menu (for expanded view)
    @ViewBuilder
    private var headerMenu: some View {
                                            Menu {
                                                Button(action: {
                #if os(macOS)
                                                    // Clear text editor focus
                                                    if let window = NSApp.keyWindow,
                                                       window.firstResponder is NSTextView {
                                                        window.makeFirstResponder(nil)
                                                    }
                #endif
                                                    isShowingImagePicker = true
                                                }) {
                                                    Label("Replace Image", systemImage: "photo")
                                                }
                                                
            #if os(macOS) // Download specific to macOS
                                                Button(action: {
                                                    if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
                                                       !headerElement.content.isEmpty,
                                                       let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                                        let documentPath = documentsPath.appendingPathComponent("\(document.id)")
                                                        let imagesPath = documentPath.appendingPathComponent("Images")
                                                        let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
                                                        
                                                        let savePanel = NSSavePanel()
                                                        savePanel.allowedContentTypes = [UTType.image]
                                                        savePanel.nameFieldStringValue = headerElement.content
                                                        
                                                        if savePanel.runModal() == .OK {
                                                            if let destinationURL = savePanel.url {
                                                                try? FileManager.default.copyItem(at: imageUrl, to: destinationURL)
                                                            }
                                                        }
                                                    }
                                                }) {
                                                    Label("Download Image", systemImage: "square.and.arrow.down")
                                                }
            #endif
                                                
                                                Divider()
                                                
                                                Button(role: .destructive, action: removeHeaderImage) {
                                                    Label("Remove Image", systemImage: "trash")
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .frame(width: 32, height: 32)
                                                    .background(
                                                        ZStack {
                                                            // Darker background with opacity for visibility
                                                            Circle()
                                                                .fill(Color.black.opacity(0.6))
                                                            
                                                            // Border to help with visibility
                                                            Circle()
                                                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                                        }
                                                    )
                                                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                                            }
                                            .buttonStyle(.plain)
                                            .onHover { hovering in
            isHoveringPhoto = hovering // This state might be for the ellipsis icon itself
                                            }
                                            .padding(.trailing, 16)
                                            .padding(.bottom, 16)
                                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                        }
    
    // MARK: - Placeholder Image View
    @ViewBuilder
    private var placeholderImageView: some View {
        // This is shown when headerImage is nil but isExpanded is true
                            Rectangle()
                                .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1.0))
                                .frame(maxWidth: paperWidth)
            // The height might need to be dynamic based on viewMode or a fixed value for placeholder
            .frame(height: viewMode == .minimal ? 160 : 300) // Adjusted height for placeholder
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98))),
                                    removal: .opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.98)))
                                ))
            .animation(.easeInOut(duration: 0.35), value: isExpanded) // Make sure this animation is desired here
                                .drawingGroup()
                                .overlay(
                                    Button(action: {
                    // Action to show the image picker
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            isShowingImagePicker = true
                                        }
                                    }) {
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.system(size: 48))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                                                .padding(.bottom, 8)
                                            
                                            Text("Add Header Image")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                                        }
                    .contentShape(Rectangle()) // Ensure the whole area is tappable
                                    }
                                    .buttonStyle(.plain)
                                )
    }

    // MARK: - Collapsed Placeholder View
    @ViewBuilder
    private var collapsedPlaceholderView: some View {
        // This is shown when headerImage is nil AND isExpanded is false
                            ZStack {
                                // Background for the header bar
                                Rectangle()
                                    .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1.0))
                                    .frame(height: collapsedBarHeight)
                // .clipShape(RoundedRectangle(cornerRadius: 12)) // Keep consistent with other collapsed view
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(document.title.isEmpty ? "Untitled" : document.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                            .lineLimit(1)
                                        
                                        if document.subtitle.isNotEmpty {
                                            Text(document.subtitle)
                            .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                                                .lineLimit(1)
                                        }
                                    }
                .padding(.leading, 20)
                                    
                                    Spacer()
                                    
                // Button to add header image (which should expand the header)
                // The main Button(action: toggleHeader) should handle this if isExpanded is false
                // So this inner button might not be needed, or toggleHeader needs to be smarter
                // For now, let's assume toggleHeader will correctly set isExpanded = true
                Image(systemName: "photo") // Visually indicates add image action, main button handles it
                                            .font(.system(size: 14))
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
                                            .padding(8)
                                            .background(Circle().fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)))
                                    }
            .padding(.horizontal, 16) // Original padding was 16
        }
        .frame(height: collapsedBarHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Apply clipping to the ZStack
        .transition(.asymmetric( // Consistent transition
            insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98))),
            removal: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98)))
        ))
        .animation(.easeInOut(duration: 0.35), value: isExpanded)
            .drawingGroup()
    }
}

#if os(macOS)
struct SimpleMacOSFilePicker: NSViewRepresentable {
    @Binding var isPresented: Bool
    let allowedContentTypes: [UTType]
    let onFilePicked: (URL) -> Void
    let onCancel: (() -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView() // Dummy view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // This needs to be triggered carefully to avoid multiple presentations
        // Typically, this logic is better outside updateNSView or controlled by a separate state.
        // For simplicity in this context, we'll attempt to show it if isPresented is true
        // and the panel isn't already up (which is hard to check from here directly).
        // A better approach for production would be a more robust coordinator pattern.

        // Guard against re-presenting if already handled by a previous update cycle
        if isPresented && context.coordinator.panelPresentedThisUpdateCycle == false {
            context.coordinator.panelPresentedThisUpdateCycle = true // Mark as presented for this cycle
            
            DispatchQueue.main.async { // Ensure panel is presented on the main thread
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = allowedContentTypes
                
                // If we present it modally, it blocks.
                // If we need it non-modal, it requires more complex handling.
                // For a sheet-like behavior, modal is usually expected.
                if panel.runModal() == .OK, let url = panel.url {
                    onFilePicked(url)
                } else {
                    onCancel?()
                }
                // Reset presentation state binding
                self.isPresented = false
                // Allow panel to be presented again in future update cycles
                context.coordinator.panelPresentedThisUpdateCycle = false
            }
        } else if !isPresented {
            // If isPresented becomes false, ensure we reset the cycle guard
             context.coordinator.panelPresentedThisUpdateCycle = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
                            }

    class Coordinator: NSObject {
        var parent: SimpleMacOSFilePicker
        var panelPresentedThisUpdateCycle: Bool = false // Guard

        init(_ parent: SimpleMacOSFilePicker) {
            self.parent = parent
            }
        }
    }
#endif

// Custom button style to prevent flash effect
struct NoFlashButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(1.0)
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.35), value: configuration.isPressed)
    }
}
