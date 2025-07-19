import SwiftUI
import Foundation

#if os(iOS)
import UIKit
#endif

struct PinnedDocumentButton: View {
    let document: Letterspace_CanvasDocument
    let action: () -> Void
    @Binding var pinnedDocuments: Set<String>
    @Binding var selectedDocumentId: String?
    var isEditMode: Bool = false // Edit mode flag
    var selectedItems: Binding<Set<String>> = .constant(Set<String>()) // Default empty binding
    var onLongPress: (() -> Void)? = nil // Long press handler
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    @State private var isHovered = false
    @State private var isOpenButtonHovered = false
    @State private var isUnpinButtonHovered = false
    @State private var justLongPressed = false // Track if we just long pressed
    @StateObject private var gradientManager = GradientWallpaperManager.shared
    
    // iPad detection
    private var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    // Check if this item is selected (iPad only)
    private var isSelected: Bool {
        isIPad && selectedDocumentId == document.id
    }
    
    // Check if this item is selected in edit mode
    private var isSelectedForRemoval: Bool {
        selectedItems.wrappedValue.contains(document.id)
    }
    
    // Determine when to show action buttons
    private var shouldShowButtons: Bool {
        if isIPad {
            return isSelected && !isEditMode // Don't show buttons in edit mode
        } else {
            return isHovered
        }
    }
    
    // Check if we should use glassmorphism
    private var shouldUseGlassmorphism: Bool {
        gradientManager.selectedLightGradientIndex != 0 || gradientManager.selectedDarkGradientIndex != 0
    }
    
    var body: some View {
        Button(action: {
            // Ignore tap if we just long pressed
            if justLongPressed {
                justLongPressed = false
                return
            }
            
            HapticFeedback.impact(.light)
            
            if isIPad && isEditMode {
                // In edit mode, toggle selection
                withAnimation(.easeInOut(duration: 0.15)) {
                    if selectedItems.wrappedValue.contains(document.id) {
                        selectedItems.wrappedValue.remove(document.id)
                    } else {
                        selectedItems.wrappedValue.insert(document.id)
                    }
                }
            } else if isIPad {
                // iPad: Toggle selection or open if already selected
                if selectedDocumentId == document.id {
                    action() // Open document if already selected
                } else {
                    selectedDocumentId = document.id // Select this document
                }
            } else {
                // Mac: Direct action
                action()
            }
        }) {
            HStack(spacing: 8) {
                // Selection circle in edit mode (iPad only)
                if isIPad && isEditMode {
                    ZStack {
                        Circle()
                            .strokeBorder(theme.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        
                        if isSelectedForRemoval {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: isSelectedForRemoval)
                }
                
                // Replace dot with black doc icon
                Image(systemName: "doc.text")
                    .font(.system(size: isIPad ? 18 : 13)) // Larger for iPad
                    .foregroundStyle(theme.primary) // Use theme color instead of hardcoded black
                    .frame(width: 20)
                
                Text(document.title.isEmpty ? "Untitled" : document.title)
                    .font(.custom("InterTight-Regular", size: isIPad ? 18 : 14)) // Larger for iPad
                    .tracking(0.3)
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                Spacer()
                
                // Action buttons that appear on hover (not in edit mode)
                if shouldShowButtons {
                    HStack(spacing: 6) {
                        // Green "open" button when hovering
                        Button(action: {
                            HapticFeedback.impact(.light)
                            action()
                        }) {
                            ZStack {
                                Circle()
                                    // iPad: Use hover color when selected, Mac: Use hover color when hovered
                                    .fill((isIPad && isSelected) || isOpenButtonHovered ? Color(hex: "#007AFF") : Color.black)
                                    .frame(width: isIPad ? 26 : 15, height: isIPad ? 26 : 15) // Increased to 26x26 for iPad
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: isIPad ? 14 : 8, weight: .semibold)) // Increased to 14pt for iPad
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Open document")
                        .scaleEffect(shouldShowButtons ? 1.0 : 0.8)
                        .scaleEffect(isOpenButtonHovered ? 1.15 : 1.0)
                        #if os(macOS)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                isOpenButtonHovered = hovering
                            }
                        }
                        #endif
                        
                        // Red unpin button
                        Button(action: {
                            HapticFeedback.impact(.light)
                            pinnedDocuments.remove(document.id)
                            UserDefaults.standard.set(Array(pinnedDocuments), forKey: "PinnedDocuments")
                            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                            // Clear selection when unpinning on iPad
                            if isIPad && selectedDocumentId == document.id {
                                selectedDocumentId = nil
                            }
                        }) {
                            ZStack {
                                Circle()
                                    // iPad: Use hover color when selected, Mac: Use hover color when hovered
                                    .fill((isIPad && isSelected) || isUnpinButtonHovered ? Color.red : Color.black)
                                    .frame(width: isIPad ? 26 : 15, height: isIPad ? 26 : 15) // Increased to 26x26 for iPad
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: isIPad ? 14 : 8, weight: .bold)) // Increased to 14pt for iPad
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Unpin document")
                        .scaleEffect(shouldShowButtons ? 1.0 : 0.8)
                        .scaleEffect(isUnpinButtonHovered ? 1.15 : 1.0)
                        #if os(macOS)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                isUnpinButtonHovered = hovering
                            }
                        }
                        #endif
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: shouldShowButtons)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isIPad ? 14 : 10) // Increased from 10 to 14 for iPad
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .simultaneousGesture(
            // Only add long press on iPad
            isIPad ? 
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    print("Long press detected on iPad") // Debug print
                    justLongPressed = true // Mark that we just long pressed
                    if let onLongPress = onLongPress {
                        onLongPress()
                    }
                }
            : nil
        )
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
                if !hovering {
                    isOpenButtonHovered = false
                    isUnpinButtonHovered = false
                }
            }
        }
        #endif
        .padding(.horizontal, 4)
    }
} 