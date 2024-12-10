import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CustomScrollBar: View {
    @Binding var scrollOffset: CGFloat
    @Binding var documentHeight: CGFloat
    let viewportHeight: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @State private var isVisible = false
    @State private var hideTimer: Timer?
    
    var body: some View {
        GeometryReader { geo in
            let scrollBarHeight = (viewportHeight / documentHeight) * geo.size.height
            let maxOffset = geo.size.height - scrollBarHeight
            let scrollBarOffset = (scrollOffset / (documentHeight - viewportHeight)) * maxOffset
            
            // Track
            RoundedRectangle(cornerRadius: 3)
                .fill(colorScheme == .dark ? Color(.sRGB, white: 1, opacity: 0.08) : Color(.sRGB, white: 0, opacity: 0.08))
                .frame(width: 6)
                .opacity(isVisible ? 1 : 0)
            
            // Thumb
            RoundedRectangle(cornerRadius: 3)
                .fill(colorScheme == .dark ? Color(.sRGB, white: 1, opacity: 0.4) : Color(.sRGB, white: 0, opacity: 0.25))
                .frame(width: 6, height: max(scrollBarHeight, 40))
                .offset(y: scrollBarOffset)
                .opacity(isVisible ? 1 : 0)
        }
        .frame(width: 6)
        .padding(.vertical, 2)
        .onChange(of: scrollOffset) { _, _ in
            showScrollBar()
        }
    }
    
    private func showScrollBar() {
        isVisible = true
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = false
            }
        }
    }
}

struct DocumentArea: View {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var text = NSAttributedString(string: "")
    @State private var isFocused: Bool = true
    @State private var isHeaderExpanded: Bool = true
    @State private var headerImage: NSImage?
    @State private var isShowingImagePicker = false
    @State private var scrollOffset: CGFloat = 0
    @State private var documentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var documentTitle: String = "Untitled"
    @FocusState private var isTitleFocused: Bool
    @Binding var isScrolling: Bool
    @Binding var scrollTimer: Timer?
    let isSidebarCollapsed: Bool
    let isDistractionFreeMode: Bool
    let viewMode: ViewMode
    let onHeaderClick: () -> Void
    
    private let paperWidth: CGFloat = 800
    private let sidebarWidth: CGFloat = 220
    private let collapsedSidebarWidth: CGFloat = 48
    private let headerHeight: CGFloat = 200
    private let collapsedHeaderHeight: CGFloat = 48
    
    private var currentOverlap: CGFloat {
        if viewMode == .minimal {
            return headerHeight - collapsedHeaderHeight + 460  // Show just the lip in minimal mode
        }
        if viewMode == .normal {
            return 16  // Fully expanded in normal mode
        }
        if !isHeaderExpanded {
            if headerImage != nil {
                return headerHeight - collapsedHeaderHeight + 520
            }
            return headerHeight - collapsedHeaderHeight + 360
        }
        return 16
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                theme.background
                    .ignoresSafeArea()
                
                HStack(spacing: 0) {
                    VStack(spacing: -currentOverlap) {
                        if viewMode != .focus {
                            headerView
                                .onChange(of: viewMode) { oldValue, newValue in
                                    if newValue == .normal {
                                        withAnimation(.spring(response: 0.3)) {
                                            isHeaderExpanded = true
                                        }
                                    } else if newValue == .minimal {
                                        withAnimation(.spring(response: 0.3)) {
                                            isHeaderExpanded = false
                                        }
                                    }
                                }
                        }
                        documentContentView
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                    .offset(x: isSidebarCollapsed ? 0 : -(sidebarWidth - collapsedSidebarWidth)/2)
                    
                    CustomScrollBar(
                        scrollOffset: $scrollOffset,
                        documentHeight: $documentHeight,
                        viewportHeight: viewportHeight
                    )
                    .padding(.trailing, 4)
                }
            }
            .onAppear {
                viewportHeight = geo.size.height
            }
        }
        .fileImporter(
            isPresented: $isShowingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    do {
                        guard url.startAccessingSecurityScopedResource() else {
                            print("Failed to access the selected file")
                            return
                        }
                        defer { url.stopAccessingSecurityScopedResource() }
                        
                        if let image = NSImage(contentsOf: url) {
                            DispatchQueue.main.async {
                                self.headerImage = image
                                print("Successfully loaded image")
                            }
                        } else {
                            print("Failed to create NSImage from URL: \(url)")
                        }
                    } catch {
                        print("Error handling image: \(error.localizedDescription)")
                    }
                }
            case .failure(let error):
                print("Error selecting image: \(error.localizedDescription)")
            }
        }
    }
    
    private var headerView: some View {
        HeaderImageSection(
            isExpanded: $isHeaderExpanded,
            headerImage: $headerImage,
            isShowingImagePicker: $isShowingImagePicker,
            viewMode: viewMode,
            colorScheme: colorScheme,
            paperWidth: paperWidth,
            onClick: onHeaderClick
        )
    }
    
    private var documentContentView: some View {
        VStack(spacing: 0) {
            if isHeaderExpanded {
                documentTitleView
            }
            documentEditorView
        }
        .frame(width: paperWidth)
        .clipShape(TopRoundedRectangle(radius: 12))
        .background(
            TopRoundedRectangle(radius: 12)
                .fill(colorScheme == .dark ? Color(.sRGB, red: 0.1, green: 0.1, blue: 0.1, opacity: 1.0) : .white)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.08),
                    radius: 12,
                    x: 0,
                    y: 2
                )
        )
        .frame(maxHeight: .infinity)
    }
    
    private var documentTitleView: some View {
        TextField("", text: $document.title)
            .font(.system(size: 48, weight: .bold))
            .textFieldStyle(.plain)
            .foregroundColor(document.title.isEmpty ? 
                (colorScheme == .dark ? Color(.sRGB, white: 1, opacity: 0.3) : Color(.sRGB, white: 0, opacity: 0.3)) :
                (colorScheme == .dark ? .white : .black))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .focused($isTitleFocused)
            .overlay(
                Text("Untitled")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color(.sRGB, white: 1, opacity: 0.3) : Color(.sRGB, white: 0, opacity: 0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .opacity(document.title.isEmpty ? 1 : 0)
                    .allowsHitTesting(false)
            )
    }
    
    private var documentEditorView: some View {
        CustomTextEditor(
            text: $text,
            isFocused: isFocused,
            onSelectionChange: { _ in },
            showToolbar: .constant(false),
            onAtCommand: nil,
            onScroll: { offset, docHeight, viewHeight in
                scrollOffset = offset
                documentHeight = docHeight
                isScrolling = true
                scrollTimer?.invalidate()
                scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    withAnimation {
                        isScrolling = false
                    }
                }
            },
            onShiftTab: {
                isTitleFocused = true
            }
        )
        .font(.custom("InterTight-Regular", size: 16))
    }
}

struct HeaderImageSection: View {
    @Binding var isExpanded: Bool
    @Binding var headerImage: NSImage?
    @Binding var isShowingImagePicker: Bool
    let viewMode: ViewMode
    let colorScheme: ColorScheme
    let paperWidth: CGFloat
    let onClick: () -> Void
    
    var body: some View {
        ZStack {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
                onClick()
            }) {
                if let headerImage = headerImage {
                    Image(nsImage: headerImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: paperWidth)
                        .clipped()
                        .blur(radius: isExpanded ? 0 : 10)
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                } else {
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1.0) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1.0))
                        .frame(width: paperWidth)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            VStack {
                                if viewMode == .normal && isExpanded {
                                    Image(systemName: "photo")
                                        .font(.system(size: 48))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3))
                                        .padding(.bottom, 8)
                                    
                                    Text("Add Header Image")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3))
                                }
                            }
                        )
                }
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottomTrailing) {
                if viewMode == .normal && isExpanded {
                    HStack(spacing: 8) {
                        Button(action: {
                            isShowingImagePicker = true
                        }) {
                            Image(systemName: "photo")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.black.opacity(0.4)))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.black.opacity(0.4)))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .padding(.bottom, viewMode == .normal && isExpanded ? 32 : 0)
    }
}

// Helper shape for top-only rounded corners
struct TopRoundedRectangle: Shape {
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Top left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                         control: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        
        // Top right corner
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                         control: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge (straight)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        
        path.closeSubpath()
        return path
    }
}

