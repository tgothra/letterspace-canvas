import SwiftUI 
struct WIPSection: View {
    let documents: [Letterspace_CanvasDocument]
    @Binding var wipDocuments: Set<String>
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @Binding var isExpanded: Bool
    var isCarouselMode: Bool = false // New parameter for carousel mode
    var showExpandButtons: Bool = false // New parameter to control expand button visibility
    var onShowModal: (() -> Void)? = nil  // Callback for showing modal on iPad
    var hideHeader: Bool = false // New parameter to hide header in modals
    var allDocumentsPosition: DashboardView.AllDocumentsPosition = .default // For iPhone dynamic heights
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.carouselHeaderFont) var carouselHeaderFont
    @Environment(\.carouselIconSize) var carouselIconSize
    @Environment(\.carouselHeaderPadding) var carouselHeaderPadding
    @State private var isHoveringButton = false // State for button hover effect
    @State private var isSectionHovered = false // State for section hover effect
    @State private var selectedDocumentId: String? = nil // State for iPad document selection
    @State private var isEditMode = false // Edit mode state
    @State private var selectedItems = Set<String>() // Selected items for multi-select
    @State private var isHoveringEditButton = false // Hover state for edit button
    
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
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: isCarouselMode ? carouselIconSize : 14))
                    .foregroundStyle(theme.primary)
                Text("Work in Progress")
                    .font(isCarouselMode ? carouselHeaderFont : .custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.primary)

                Spacer() // Push buttons to the right

                    // Expand button (show when showExpandButtons is true)
                    if showExpandButtons {
                Button {
                        print("🔄 WIP expand button tapped")
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
                        .font(.system(size: 12, weight: .medium)) // Make icon smaller
                        .foregroundStyle(theme.secondary)
                        .padding(4) // Add padding around the icon
                        .background( // Add circle background on hover
                            Circle()
                                .fill(theme.accent.opacity(isHoveringButton ? 0.1 : 0))
                        )
                        .scaleEffect(isHoveringButton ? 1.15 : 1.0) // Bounce effect on hover
                }
                .buttonStyle(.plain)
                #if os(macOS)
                .onHover { hovering in // Track hover state
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { // Apply spring animation
                        isHoveringButton = hovering
                    }
                }
                #endif
                // Make button visible only when section is hovered
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
                // Add a zero-height GeometryReader to match PinnedSection structure
                GeometryReader { _ in
                    Color.clear
                }
                .frame(height: 0)
                
                LazyVStack(spacing: 2) {  // Decreased spacing
                    let wipDocs = documents.filter { wipDocuments.contains($0.id) }
                    if wipDocs.isEmpty {
                        // iPad detection for placeholder text
                        let isIPadLocal: Bool = {
                            #if os(iOS)
                            return UIDevice.current.userInterfaceIdiom == .pad
                            #else
                            return false
                            #endif
                        }()
                        
                        Text("No WIP documents")
                            .font(.system(size: isIPadLocal ? 18 : 13)) // Larger for iPad
                            .foregroundStyle(theme.secondary)
                            .padding(.horizontal, 4)
                    } else {
                        ForEach(wipDocs, id: \.id) { doc in
                            WIPDocumentButton(
                                document: doc,
                                action: {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("OpenDocument"),
                                        object: nil,
                                        userInfo: ["documentId": doc.id]
                                    )
                                },
                                wipDocuments: $wipDocuments,
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
                .padding(.top, -2)  // Negative padding to exactly match PinnedSection
                // Blue background removed after debugging
            }
            #if os(macOS)
            .customScroll(shouldFlash: false)  // Added customScroll to match PinnedSection
            #endif
            // Make the ScrollView expand/collapse rather than the entire section
            .frame(height: isExpanded ? 350 : {
                if isCarouselMode {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if isPhone {
                        // iPhone: Use dynamic height based on All Documents position
                        // Subtract minimal header space (~55pt) to maximize ScrollView height
                        return max(220, allDocumentsPosition.carouselHeight - 55)
                    } else {
                        return 180 // iPad landscape carousel
                    }
                    #else
                    return 180 // Other platforms
                    #endif
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
                                    wipDocuments.remove(itemId)
                                }
                                UserDefaults.standard.set(Array(wipDocuments), forKey: "WIPDocuments")
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
