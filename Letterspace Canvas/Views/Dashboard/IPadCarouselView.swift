#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - iPad Carousel View
struct IPadCarouselView: View {
    // Document and state data
    let documents: [Letterspace_CanvasDocument]
    @Binding var selectedCarouselIndex: Int
    @Binding var dragOffset: CGFloat
    @Binding var reorderMode: Bool
    @Binding var draggedCardIndex: Int?
    @Binding var draggedCardOffset: CGSize
    @Binding var pinnedDocuments: Set<String>
    @Binding var wipDocuments: Set<String>
    @Binding var calendarDocuments: Set<String>
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    @Binding var showPinnedModal: Bool
    @Binding var showWIPModal: Bool
    @Binding var calendarModalData: ModalDisplayData?
    
    // Layout and presentation data
    let shouldAddNavigationPadding: Bool
    let navPadding: CGFloat
    let allDocumentsPosition: AllDocumentsPosition
    let carouselSections: [(title: String, view: AnyView)]
    let shouldShowExpandButtons: Bool
    let isLoadingDocuments: Bool
    
    // Callbacks
    let onSelectDocument: (Letterspace_CanvasDocument) -> Void
    let clearAllDocumentSelections: () -> Void
    let saveCarouselPosition: () -> Void
    let moveCarouselSection: (Int, Int) -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var colorTheme: ColorThemeManager
    private let gradientManager = GradientWallpaperManager.shared
    
    // iPad detection helper
    private var isIPadDevice: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return true // macOS always supports reorder
        #endif
    }
    
    var body: some View {
        iPadSectionCarousel
    }
    
    // iPad Carousel Component
    private var iPadSectionCarousel: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let allDocumentsLeftPadding: CGFloat = shouldAddNavigationPadding ? navPadding : 20
            let allDocumentsLeftEdge = allDocumentsLeftPadding + 20

            let cardWidth: CGFloat = {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                if isPhone {
                    // iPhone: consistent card width with breathing room on both sides
                    return screenWidth * 0.93 // Full width with breathing room (increased to 93%)
                } else {
                    // iPad: original sizing
                    return shouldAddNavigationPadding ? (screenWidth - allDocumentsLeftEdge) * 0.8 : screenWidth * 0.75
                }
                #else
                // Fallback for other platforms
                return shouldAddNavigationPadding ? (screenWidth - allDocumentsLeftEdge) * 0.8 : screenWidth * 0.75
                #endif
            }()

            let cardSpacing: CGFloat = {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 40 : 60 // Tighter spacing for iPhone
                #else
                return 60
                #endif
            }()

            let totalWidth = geometry.size.width
            let shadowPadding: CGFloat = 40
            
            ZStack {
                // Background tap area to exit reorder mode or clear document selections
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                        if reorderMode && isIPadDevice {
                            print("🔄 Exiting reorder mode via background tap")
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                reorderMode = false
                                draggedCardIndex = nil
                                draggedCardOffset = .zero
                            }
                        } else {
                            // Clear any document selections in carousel cards (iPad only)
                            #if os(iOS)
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                // Clear selections in all carousel sections
                                clearAllDocumentSelections()
                            }
                            #endif
                        }
                        }
                        .zIndex(-1) // Behind the cards
                
                ForEach(0..<carouselSections.count, id: \.self) { index in
                    carouselCard(for: index, cardWidth: cardWidth, cardSpacing: cardSpacing, totalWidth: totalWidth, shadowPadding: shadowPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, shadowPadding)
            // Only apply carousel gesture when not in reorder mode
            .gesture(reorderMode ? nil : carouselDragGesture(cardWidth: cardWidth, cardSpacing: cardSpacing))
        }
        .frame(height: {
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            if isPhone || isIPad {
                // Use dynamic height based on All Documents position for both iPhone and iPad
                return allDocumentsPosition.carouselHeight
            } else {
                return 380 // Fallback for other devices
            }
            #else
            return 380
            #endif
        }())
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: shouldAddNavigationPadding)
    }
    
    // Calculate effective index during drag (where cards will end up)
    private func effectiveCardIndex(for index: Int) -> Int {
        guard let draggedIndex = draggedCardIndex else { return index }
        
        // Calculate target position based on drag
        let dragX = draggedCardOffset.width
        let reorderCardWidth: CGFloat = 300 * 0.6 // 60% of normal card width
        let reorderSpacing: CGFloat = 20
        let totalCardWidth = reorderCardWidth + reorderSpacing
        
        // Determine how many positions to move based on drag distance
        let positionChange = Int(round(dragX / totalCardWidth))
        let targetIndex = max(0, min(carouselSections.count - 1, draggedIndex + positionChange))
        
        // Return the effective position for each card
        if index == draggedIndex {
            // Dragged card goes to target position
            return targetIndex
        } else if draggedIndex < targetIndex {
            // Moving right: cards between original and target shift left
            if index > draggedIndex && index <= targetIndex {
                return index - 1
            }
        } else if draggedIndex > targetIndex {
            // Moving left: cards between target and original shift right
            if index >= targetIndex && index < draggedIndex {
                return index + 1
            }
        }
        
        // All other cards stay in their original positions
        return index
    }
    
    // Calculate real-time positions during drag
    private func cardPosition(for index: Int, cardWidth: CGFloat, cardSpacing: CGFloat, totalWidth: CGFloat, shadowPadding: CGFloat) -> CGPoint {
        if reorderMode {
            // In reorder mode, show all cards in view with smaller spacing
            let reorderCardWidth = cardWidth * 0.6 // Cards are 60% of normal size in reorder mode
            let reorderSpacing: CGFloat = 20 // Tighter spacing in reorder mode
            let totalCardsWidth = CGFloat(carouselSections.count) * reorderCardWidth + CGFloat(carouselSections.count - 1) * reorderSpacing
            let startX = (totalWidth - totalCardsWidth) / 2
            
            if index == draggedCardIndex {
                // Dragged card follows finger with constraints
                let basePosition = startX + CGFloat(index) * (reorderCardWidth + reorderSpacing)
                let constrainedX = max(startX, 
                                     min(startX + totalCardsWidth - reorderCardWidth, 
                                         basePosition + draggedCardOffset.width))
                return CGPoint(
                    x: constrainedX,
                    y: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                        if isPhone || isIPad {
                            // Use half of dynamic height for both iPhone and iPad
                            return (allDocumentsPosition.carouselHeight / 2) + draggedCardOffset.height * 0.2
                        } else {
                            return 190 + draggedCardOffset.height * 0.2 // Fallback for other devices
                        }
                        #else
                        return 190 + draggedCardOffset.height * 0.2
                        #endif
                    }()
                )
            } else {
                // Other cards slide to their effective positions smoothly
                let effectiveIndex = effectiveCardIndex(for: index)
                let xPosition = startX + CGFloat(effectiveIndex) * (reorderCardWidth + reorderSpacing)
                return CGPoint(
                    x: xPosition,
                    y: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                        if isPhone || isIPad {
                            // Use half of dynamic height for both iPhone and iPad
                            return allDocumentsPosition.carouselHeight / 2
                        } else {
                            return 190 // Fallback for other devices
                        }
                        #else
                        return 190
                        #endif
                    }()
                )
            }
        } else {
            // Normal carousel mode - different positioning based on navigation state
            let offsetFromCenter = CGFloat(index - selectedCarouselIndex)
            let xOffset = offsetFromCenter * (cardWidth + cardSpacing)
            
            let centerX: CGFloat
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            if isPhone {
                // iPhone: Center the carousel cards with proper spacing, accounting for shadowPadding
                centerX = (totalWidth / 2) + xOffset + dragOffset - shadowPadding
            } else {
                // iPad: Proper alignment with All Documents list
                if shouldAddNavigationPadding {
                    // Navigation visible: align left edge of centered card with All Documents left edge
                    let allDocumentsLeftPadding = navPadding + 10 // navPadding + horizontal padding
                    // Account for the carousel container's shadowPadding (40pt) that shifts everything right
                    let centeredCardLeftEdge = allDocumentsLeftPadding - shadowPadding + 20 // Move more to the right
                    centerX = centeredCardLeftEdge + (cardWidth / 2) + xOffset + dragOffset
                } else {
                    // Navigation hidden: center the cards in the available space, but shift left
                    centerX = (totalWidth / 2) - 30 + xOffset + dragOffset // Move more to the left
                }
            }
            #else
            // macOS and other platforms
            if shouldAddNavigationPadding {
                let allDocumentsLeftPadding = navPadding + 10
                let centeredCardLeftEdge = allDocumentsLeftPadding - shadowPadding + 20
                centerX = centeredCardLeftEdge + (cardWidth / 2) + xOffset + dragOffset
            } else {
                centerX = (totalWidth / 2) - 30 + xOffset + dragOffset
            }
            #endif
            
            return CGPoint(
                x: centerX,
                y: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                    if isPhone || isIPad {
                        // Use half of dynamic height for both iPhone and iPad
                        return allDocumentsPosition.carouselHeight / 2
                    } else {
                        return 190 // Fallback for other devices
                    }
                    #else
                    return 190
                    #endif
                }()
            )
        }
    }
    
    // Extract carousel card into separate function
    @ViewBuilder
    private func carouselCard(for index: Int, cardWidth: CGFloat, cardSpacing: CGFloat, totalWidth: CGFloat, shadowPadding: CGFloat) -> some View {
        let isCenter = index == selectedCarouselIndex
        let isDragged = index == draggedCardIndex
        let position = cardPosition(for: index, cardWidth: cardWidth, cardSpacing: cardSpacing, totalWidth: totalWidth, shadowPadding: shadowPadding)
        let scale: CGFloat = {
            if reorderMode {
                return isDragged ? 0.65 : 0.6 // Slightly larger for dragged card in reorder mode
            } else {
                return isCenter ? 1.0 : 0.85
            }
        }()
        
        carouselSections[index].view
            .frame(width: cardWidth * scale, height: {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                let isIPad = UIDevice.current.userInterfaceIdiom == .pad
                if isPhone || isIPad {
                    // Use dynamic height for both iPhone and iPad, scaled appropriately
                    return (allDocumentsPosition.carouselHeight - 80) * scale
                } else {
                    return 300 * scale // Fallback for other devices
                }
                #else
                return 300 * scale
                #endif
            }())
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: .black.opacity(isCenter && !reorderMode ? 0.15 : 0.08),
                radius: isCenter && !reorderMode ? 20 : 10,
                x: 0,
                y: isCenter && !reorderMode ? 10 : 5
            )
            .position(position)
            .opacity(reorderMode ? (isDragged ? 0.9 : 0.7) : (isCenter ? 1.0 : 0.7))
            .animation(
                reorderMode && !isDragged ? 
                    .interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0) :
                    .spring(response: 0.6, dampingFraction: 0.75),
                value: position
            )
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: scale)
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: isCenter)
            .onTapGesture {
                if reorderMode && isIPadDevice {
                    // In reorder mode, tapping a card selects it for dragging
                    if draggedCardIndex != index {
                        draggedCardIndex = index
                        draggedCardOffset = .zero
                    }
                } else if !isCenter {
                    // Normal mode: tap to center the card
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                        selectedCarouselIndex = index
                        saveCarouselPosition()
                    }
                }
            }
            .overlay(
                // Reorder handle for iPad in reorder mode
                reorderHandle(for: index, isCenter: isCenter)
            )
            .zIndex(isDragged ? 1000 : (isCenter ? 100 : Double(10 - abs(index - selectedCarouselIndex))))
    }
    
    // Extract reorder handle
    @ViewBuilder
    private func reorderHandle(for index: Int, isCenter: Bool) -> some View {
        Button(action: {
            if !reorderMode && isIPadDevice {
                print("🔄 Entering reorder mode for card \(index)")
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                    reorderMode = true
                    draggedCardIndex = index
                    draggedCardOffset = .zero
                }
            } else if reorderMode && draggedCardIndex == index {
                print("🔄 Exiting reorder mode")
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                    reorderMode = false
                    draggedCardIndex = nil
                    draggedCardOffset = .zero
                }
            }
        }) {
            VStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .frame(width: 20, height: 2)
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.6))
                }
            }
            .padding(8)
            .background(reorderHandleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(reorderMode ? 1.2 : 1.0)
            .opacity(isIPadDevice ? (reorderMode ? 1.0 : (isCenter ? 0.8 : 0.0)) : 0.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: reorderMode)
            .animation(.easeInOut(duration: 0.2), value: isCenter)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isIPadDevice)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 12)
        .padding(.trailing, 12)
        .gesture(
            reorderMode && index == draggedCardIndex ? 
            DragGesture()
                .onChanged { value in
                    draggedCardOffset = value.translation
                }
                .onEnded { value in
                    // Finalize the reorder
                    let dragX = value.translation.width
                    let reorderCardWidth: CGFloat = 300 * 0.6
                    let reorderSpacing: CGFloat = 20
                    let totalCardWidth = reorderCardWidth + reorderSpacing
                    
                    let positionChange = Int(round(dragX / totalCardWidth))
                    let targetIndex = max(0, min(carouselSections.count - 1, index + positionChange))
                    
                    if targetIndex != index {
                        print("🔄 Moving card from \(index) to \(targetIndex)")
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                            moveCarouselSection(index, targetIndex)
                            selectedCarouselIndex = targetIndex
                            draggedCardIndex = targetIndex
                        }
                    }
                    
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        draggedCardOffset = .zero
                    }
                } : nil
        )
    }
    
    private func reorderDragGesture(for index: Int) -> some Gesture {
        // This function is no longer needed since we moved the logic to the handle
        DragGesture()
            .onChanged { _ in }
            .onEnded { _ in }
    }
    
    // Extract computed properties for styling
    private var cardBackground: some View {
        // Only check gradient for current color scheme
        let useGlassmorphism = colorScheme == .dark ? 
            gradientManager.selectedDarkGradientIndex != 0 :
            gradientManager.selectedLightGradientIndex != 0
        
        return Group {
            if useGlassmorphism {
                // Glassmorphism effect for carousel cards
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    theme.background.opacity(0.2),
                                    theme.background.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
            } else {
                // Standard background with platform-specific colors
                RoundedRectangle(cornerRadius: 16)
                    .fill({
                        if colorScheme == .dark {
                            #if os(iOS)
                            return Color(.systemGray6)
                            #else
                            return Color(.controlBackgroundColor)
                            #endif
                        } else {
                            #if os(iOS)
                            return Color(.systemBackground)
                            #else
                            return Color(.windowBackgroundColor)
                            #endif
                        }
                    }())
            }
        }
    }
    
    private var reorderHandleBackground: some View {
        Circle()
            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func carouselDragGesture(cardWidth: CGFloat, cardSpacing: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold = cardWidth * 0.3
                let cardDistance = cardWidth + cardSpacing
                let newIndex: Int
                
                if value.translation.width > threshold && selectedCarouselIndex > 0 {
                    newIndex = selectedCarouselIndex - 1
                } else if value.translation.width < -threshold && selectedCarouselIndex < carouselSections.count - 1 {
                    newIndex = selectedCarouselIndex + 1
                } else {
                    newIndex = selectedCarouselIndex
                }
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    selectedCarouselIndex = newIndex
                    dragOffset = 0
                    saveCarouselPosition()
                }
            }
    }
}

// MARK: - Supporting Types
extension IPadCarouselView {
    enum AllDocumentsPosition {
        case `default`
        case minimized
        case expanded
        
        var carouselHeight: CGFloat {
            #if os(iOS)
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            if isIPad {
                // iPad heights
                switch self {
                case .default:
                    return 380  // Default height for iPad
                case .minimized:
                    return 120  // Smaller minimized height for iPad
                case .expanded:
                    return 120  // Smaller minimized height for iPad
                }
            } else {
                // iPhone heights
                switch self {
                case .default:
                    return 360  // Slightly smaller for iPhone
                case .minimized:
                    return 5    // Essentially hidden - just enough to maintain layout structure
                case .expanded:
                    return 5    // Essentially hidden - just enough to maintain layout structure
                }
            }
            #else
            // macOS and other platforms
            switch self {
            case .default:
                return 380
            case .minimized:
                return 120
            case .expanded:
                return 140
            }
            #endif
        }
    }
}

#endif
