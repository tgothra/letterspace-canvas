#if os(iOS)
import SwiftUI
import UIKit
import PhotosUI

@available(iOS 26.0, *)
struct FloatingHeaderWithMorph: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var headerCollapseProgress: CGFloat
    @Binding var headerImage: UIImage?
    @Binding var isHeaderExpanded: Bool
    @Binding var isImageExpanded: Bool
    @Binding var isTitleVisible: Bool
    @Binding var isEditorFocused: Bool
    @Binding var viewMode: ViewMode
    
    // Floating header state
    @State private var isEditingFloatingTitle: Bool = false
    @State private var isEditingFloatingSubtitle: Bool = false
    @State private var floatingTitleText: String = ""
    @State private var floatingSubtitleText: String = ""
    @State private var showFloatingImageActionSheet: Bool = false
    
    // Focus states for floating header
    @FocusState private var isFloatingTitleFocused: Bool
    @FocusState private var isFloatingSubtitleFocused: Bool
    
    // Photo picker coordinators for floating header
    @State private var floatingPhotoPickerCoordinator: Any?
    @State private var floatingDocumentPickerCoordinator: Any?
    
    let colorScheme: ColorScheme
    let paperWidth: CGFloat
    
    // Animation constants
    private let maxScrollForCollapse: CGFloat = 150
    private let expandedHeaderHeight: CGFloat = 200
    private let collapsedHeaderHeight: CGFloat = 64
    
    var body: some View {
        ZStack {
            // Full header when expanded (headerCollapseProgress < 0.3)
            if headerCollapseProgress < 0.3 {
                fullHeaderView
                    .opacity(1 - (headerCollapseProgress / 0.3))
                    .scaleEffect(1.0 - (headerCollapseProgress * 0.1))
            }
            
            // Morphing header (headerCollapseProgress 0.3 to 0.7)
            if headerCollapseProgress >= 0.3 && headerCollapseProgress < 0.7 {
                morphingHeaderView
                    .opacity(1.0)
            }
            
            // Floating header when collapsed (headerCollapseProgress >= 0.7)
            if headerCollapseProgress >= 0.7 {
                floatingCollapsedHeader
                    .opacity((headerCollapseProgress - 0.7) / 0.3)
                    .scaleEffect(0.9 + ((headerCollapseProgress - 0.7) * 0.1))
            }
        }
        .animation(.interactiveSpring(response: 0.8, dampingFraction: 0.85, blendDuration: 0.3), value: headerCollapseProgress)
    }
    
    // MARK: - Full Header View
    private var fullHeaderView: some View {
        VStack(spacing: 0) {
            // Header image section
            if let headerImage = headerImage {
                ZStack {
                    // Background image
                    Image(uiImage: headerImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: expandedHeaderHeight)
                        .clipped()
                    
                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.1),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: expandedHeaderHeight)
                    
                    // Title and subtitle overlay
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer()
                        
                        if isTitleVisible {
                            Text(document.title.isEmpty ? "Untitled" : document.title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            if !document.subtitle.isEmpty {
                                Text(document.subtitle)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            } else {
                // No image - simple header
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
                    
                    if isTitleVisible {
                        Text(document.title.isEmpty ? "Untitled" : document.title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        if !document.subtitle.isEmpty {
                            Text(document.subtitle)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .frame(height: expandedHeaderHeight)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .background(Color(UIColor.systemBackground))
            }
        }
    }
    
    // MARK: - Morphing Header View
    private var morphingHeaderView: some View {
        VStack(spacing: 0) {
            // Morphing header with glass effect
            ZStack {
                // Glass background
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.clear)
                        .frame(width: paperWidth - 16, height: 120)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 0.25) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 0.25))
                        .frame(width: paperWidth - 16, height: 120)
                        .shadow(color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
                }
                
                // Content
                HStack(spacing: 12) {
                    // Image thumbnail
                    if let headerImage = headerImage {
                        Button(action: {
                            showFloatingImageActionSheet = true
                        }) {
                            Image(uiImage: headerImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Title and subtitle
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title.isEmpty ? "Untitled" : document.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .lineLimit(1)
                        
                        if !document.subtitle.isEmpty {
                            Text(document.subtitle)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Scroll to top button
                    Button(action: {
                        withAnimation(.interactiveSpring(response: 0.8, dampingFraction: 0.85, blendDuration: 0.3)) {
                            headerCollapseProgress = 0
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15))
                                    .overlay(
                                        Circle()
                                            .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - Floating Collapsed Header
    private var floatingCollapsedHeader: some View {
        ZStack {
            // Glass background
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .frame(width: paperWidth - 16, height: 80)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 0.25) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 0.25))
                    .frame(width: paperWidth - 16, height: 80)
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
            }
            
            // Content
            HStack(spacing: 12) {
                // Image thumbnail
                if let headerImage = headerImage {
                    Button(action: {
                        showFloatingImageActionSheet = true
                    }) {
                        Image(uiImage: headerImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                // Title and subtitle - tappable for editing
                VStack(alignment: .leading, spacing: 2) {
                    // Title section
                    if isEditingFloatingTitle {
                        TextField("Enter title", text: $floatingTitleText)
                            .font(.system(size: 18, weight: .semibold))
                            .textFieldStyle(.plain)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .focused($isFloatingTitleFocused)
                            .onSubmit {
                                document.title = floatingTitleText
                                document.save()
                                isEditingFloatingTitle = false
                            }
                            .onAppear {
                                floatingTitleText = document.title
                                isFloatingTitleFocused = true
                            }
                    } else {
                        Button(action: {
                            floatingTitleText = document.title
                            isEditingFloatingTitle = true
                        }) {
                            Text(document.title.isEmpty ? "Untitled" : document.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Subtitle section
                    if isEditingFloatingSubtitle {
                        TextField("Enter subtitle", text: $floatingSubtitleText)
                            .font(.system(size: 14, weight: .regular))
                            .textFieldStyle(.plain)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                            .focused($isFloatingSubtitleFocused)
                            .onSubmit {
                                document.subtitle = floatingSubtitleText
                                document.save()
                                isEditingFloatingSubtitle = false
                            }
                            .onAppear {
                                floatingSubtitleText = document.subtitle
                                isFloatingSubtitleFocused = true
                            }
                    } else if !document.subtitle.isEmpty || isEditingFloatingTitle {
                        Button(action: {
                            floatingSubtitleText = document.subtitle
                            isEditingFloatingSubtitle = true
                        }) {
                            Text(document.subtitle.isEmpty ? "Add subtitle" : document.subtitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(document.subtitle.isEmpty ? 
                                    (colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)) :
                                    (colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7)))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Scroll to top button
                Button(action: {
                    withAnimation(.interactiveSpring(response: 0.8, dampingFraction: 0.85, blendDuration: 0.3)) {
                        headerCollapseProgress = 0
                    }
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15))
                                .overlay(
                                    Circle()
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .confirmationDialog("Header Image Options", isPresented: $showFloatingImageActionSheet) {
            Button("Photo Library") {
                presentFloatingPhotoLibraryPicker()
            }
            Button("Browse Files") {
                presentFloatingDocumentPicker()
            }
            if headerImage != nil {
                Button("Remove Image", role: .destructive) {
                    removeHeaderImage()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how to change your header image")
        }
    }
    
    // MARK: - Helper Methods
    private func presentFloatingPhotoLibraryPicker() {
        // Use existing photo picker implementation from DocumentArea
        // For now, just show a placeholder action
        print("Photo library picker would be presented here")
    }
    
    private func presentFloatingDocumentPicker() {
        // Use existing document picker implementation from DocumentArea
        // For now, just show a placeholder action
        print("Document picker would be presented here")
    }
    
    private func handleFloatingImageImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                do {
                    let imageData = try Data(contentsOf: url)
                    guard let image = UIImage(data: imageData) else { return }
                    
                    let fileName = UUID().uuidString + ".png"
                    if let documentsPath = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                        let documentPath = documentsPath.appendingPathComponent("\(document.id)")
                        let imagesPath = documentPath.appendingPathComponent("Images")
                        
                        try FileManager.default.createDirectory(at: documentPath, withIntermediateDirectories: true, attributes: nil)
                        try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
                        let fileURL = imagesPath.appendingPathComponent(fileName)
                        
                        if let pngData = image.pngData() {
                            try pngData.write(to: fileURL)
                            
                            if var headerElement = document.elements.first(where: { $0.type == .headerImage }) {
                                headerElement.content = fileName
                                if let index = document.elements.firstIndex(where: { $0.type == .headerImage }) {
                                    document.elements[index] = headerElement
                                }
                            } else {
                                let headerElement = DocumentElement(type: .headerImage, content: fileName)
                                document.elements.insert(headerElement, at: 0)
                            }
                            
                            document.save()
                            
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                headerImage = image
                                isImageExpanded = true
                                viewMode = .normal
                                isHeaderExpanded = true
                                isEditorFocused = true
                                isTitleVisible = true
                            }
                        }
                    }
                } catch {
                    print("Error importing image: \(error)")
                }
            }
        case .failure(let error):
            print("Image import failed: \(error)")
        }
    }
    
    private func removeHeaderImage() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            headerImage = nil
            isImageExpanded = false
        }
        
        // Remove header image element from document
        if let index = document.elements.firstIndex(where: { $0.type == .headerImage }) {
            document.elements.remove(at: index)
            document.save()
        }
    }
}

#endif 