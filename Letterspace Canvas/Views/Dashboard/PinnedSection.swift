import SwiftUI

struct PinnedSection: View {
    let documents: [Letterspace_CanvasDocument]
    @Binding var pinnedDocuments: Set<String>
    var onSelectDocument: (Letterspace_CanvasDocument) -> Void
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @Binding var isExpanded: Bool
    var isCarouselMode: Bool = false
    var showExpandButtons: Bool = false // New parameter to control expand button visibility
    var onShowModal: (() -> Void)? = nil  // Callback for showing modal on iPad
    var hideHeader: Bool = false // New parameter to hide header in modals
    @State private var scrollOffset: CGFloat = 0
    @State private var shouldFlashScroll = false
    @State private var isHoveringButton = false
    @State private var isSectionHovered = false
    @State private var selectedDocumentId: String? = nil // State for iPad document selection
    @State private var isEditMode = false // Edit mode state
    @State private var selectedItems = Set<String>() // Selected items for multi-select
    @State private var isHoveringEditButton = false // Hover state for edit button
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.carouselHeaderFont) var carouselHeaderFont
    @Environment(\.carouselIconSize) var carouselIconSize
    @Environment(\.carouselHeaderPadding) var carouselHeaderPadding
    
    // iPad detection
    private var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: hideHeader ? 0 : (isCarouselMode ? 6 : 12)) {  // Reduced spacing for carousel mode, no spacing if hiding header
            // Conditionally show header
            if !hideHeader {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.system(size: isCarouselMode ? carouselIconSize : 14))
                    .foregroundStyle(theme.primary)
                Text("Pinned")
                    .font(isCarouselMode ? carouselHeaderFont : .custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.primary)

                Spacer() // Push button to the right

                    // Add Expand Button (show when showExpandButtons is true)
                    if showExpandButtons {
                Button {
                        print("🔄 Pinned expand button tapped")
                        if isCarouselMode && isIPad {
                            // On iPad carousel mode, show modal instead of expanding
                            onShowModal?()
                        } else {
                            // Normal expansion for macOS and non-carousel modes
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                            }
                    }
                } label: {
                    Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(theme.accent.opacity(isHoveringButton ? 0.1 : 0))
                        )
                        .scaleEffect(isHoveringButton ? 1.15 : 1.0)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                #if os(macOS)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isHoveringButton = hovering
                    }
                }
                #endif
                        .opacity(!isCarouselMode ? (isSectionHovered ? 1 : 0) : 1)  // Always visible in carousel mode
                .animation(.easeInOut(duration: 0.15), value: isSectionHovered)
                }
            }
            .padding(.leading, isCarouselMode ? carouselHeaderPadding : 4)
            .padding(.top, isCarouselMode ? 20 : 0)  // Add consistent top padding for carousel alignment
            
            // Add divider
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
                .padding(.vertical, isCarouselMode ? 8 : 4) // Increased carousel padding from 2 to 8 for more space
            }
            
            ScrollView(.vertical, showsIndicators: true) {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("pinnedScroll")).minY
                    )
                }
                .frame(height: 0)
                
                LazyVStack(spacing: 2) {
                    let pinnedDocs = documents.filter { pinnedDocuments.contains($0.id) }
                    if pinnedDocs.isEmpty {
                        // iPad detection for placeholder text
                        let isIPadLocal: Bool = {
                            #if os(iOS)
                            return UIDevice.current.userInterfaceIdiom == .pad
                            #else
                            return false
                            #endif
                        }()
                        
                        Text("No pinned documents")
                            .font(.system(size: isIPadLocal ? 18 : 13)) // Larger for iPad
                            .foregroundColor(theme.secondary)
                            .padding(.horizontal, 4)
                    } else {
                        ForEach(pinnedDocs, id: \.id) { doc in
                            PinnedDocumentButton(
                                document: doc,
                                action: {
                                    // Using notification to open document for better performance
                                    // This will use the same optimized path as All Documents section
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("OpenDocument"),
                                        object: nil,
                                        userInfo: ["documentId": doc.id]
                                    )
                                },
                                pinnedDocuments: $pinnedDocuments,
                                selectedDocumentId: $selectedDocumentId,
                                isEditMode: isEditMode,
                                selectedItems: $selectedItems,
                                onLongPress: {
                                    // Trigger edit mode and select this item
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if !isEditMode {
                                            isEditMode = true
                                        }
                                        // Add this item to selection
                                        selectedItems.insert(doc.id)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, -2)  // Added negative top padding to raise content up
            }
            .overlay(alignment: .bottom) {
                if scrollOffset > 0 {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            colorScheme == .dark ? Color(.sRGB, white: 0.15, opacity: 0) : .white.opacity(0),
                            colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 24)
                }
            }
            .coordinateSpace(name: "pinnedScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
            }
            #if os(macOS)
            .customScroll(shouldFlash: shouldFlashScroll)
            #endif
            // Make the ScrollView expand/collapse rather than the entire section
            .frame(height: isExpanded ? 350 : {
                if isCarouselMode {
                    return 180 // iPad landscape carousel
                } else if isIPad && !isCarouselMode && !hideHeader {
                    // iPad portrait cards need more height to fill the 380pt container
                    // Container: 380pt, Header: ~50pt, Padding: ~20pt = ~310pt available for scroll content
                    return 310 // Increased height for iPad portrait cards to better fill container
                } else {
                    return 130 // Default height for other cases
                }
            }())
        }
        .padding(isCarouselMode ? EdgeInsets() : EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24))
        .background(
            Group {
                // Remove background for all iPad carousel cards (portrait and landscape)
                if isIPad || isCarouselMode || hideHeader {
                    Color.clear
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
                }
            }
        )
        .modifier(CarouselClipModifier(isCarouselMode: isCarouselMode))
        .shadow(
            color: (isCarouselMode || hideHeader) ? .clear : (colorScheme == .dark ? .black.opacity(isExpanded ? 0.25 : 0.17) : .black.opacity(isExpanded ? 0.12 : 0.07)),
            radius: (isCarouselMode || hideHeader) ? 0 : (isExpanded ? 12 : 8),
            x: 0,
            y: (isCarouselMode || hideHeader) ? 0 : (isExpanded ? 4 : 1)
        )
        // Apply scale effect when expanded (only if not in carousel mode)
        .scaleEffect(isCarouselMode ? 1.0 : (isExpanded ? 1.02 : 1.0))
        // Increase z-index when expanded (only if not in carousel mode)
        .zIndex(isCarouselMode ? 0 : (isExpanded ? 10 : 0))
        // Revert to easeInOut animation (only if not in carousel mode)
        .animation(isCarouselMode ? .none : .easeInOut(duration: 0.3), value: isExpanded)
        // Track hover state for the entire section (only if not in carousel mode)
        #if os(macOS)
        .onHover { hovering in
            if !isCarouselMode {
             isSectionHovered = hovering
            }
        }
        #endif
        // Add tap gesture to clear selection when tapping on empty space (iPad only)
        .contentShape(Rectangle())
        .onTapGesture {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad && selectedDocumentId != nil {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedDocumentId = nil
                }
            }
            #endif
        }
        // Add automatic exit from edit mode when all items are deselected
        .onChange(of: selectedItems) { newValue in
            if isEditMode && newValue.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditMode = false
                }
            }
        }
        // Listen for clear selection notifications
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearDocumentSelections"))) { _ in
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad && selectedDocumentId != nil {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedDocumentId = nil
                }
            }
            #endif
        }
        // Add selection UI as overlay so it doesn't push content up
        .overlay(alignment: .bottom) {
            if isEditMode && isCarouselMode && isIPad {
                VStack(spacing: 0) {
                    // Divider
                    Rectangle()
                        .fill(.separator)
                        .frame(height: 1)
                        .padding(.top, 4) // Reduced from 8 to 4
                    
                    HStack {
                        if selectedItems.isEmpty {
                            // Show Done button when no items selected
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditMode = false
                                }
                            } label: {
                                Text("Done")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(theme.accent)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        } else {
                            // Show selection count and remove button when items selected
                            Text("\(selectedItems.count) selected")
                                .font(.system(size: 14))
                                .foregroundStyle(theme.secondary)
                            
                            Spacer()
                            
                            Button {
                                // Remove selected items
                                for itemId in selectedItems {
                                    pinnedDocuments.remove(itemId)
                                }
                                UserDefaults.standard.set(Array(pinnedDocuments), forKey: "PinnedDocuments")
                                NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                                
                                // Clear selections and exit edit mode
                                selectedItems.removeAll()
                                isEditMode = false
                            } label: {
                                Text("Remove")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.red)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, isCarouselMode ? carouselHeaderPadding : 24)
                    .padding(.vertical, 16) // Increased from 8 to 16 to center it
                    .background(
                        Rectangle()
                            .fill(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
                    )
                }
                .offset(y: 4) // Add slight downward offset to move it closer to bottom
            }
        }
    }
}

struct CarouselClipModifier: ViewModifier {
    let isCarouselMode: Bool
    
    func body(content: Content) -> some View {
        if isCarouselMode {
            content.clipShape(Rectangle())
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
