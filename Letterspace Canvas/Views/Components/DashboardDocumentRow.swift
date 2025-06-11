#if os(iOS)
import SwiftUI

// iOS Dashboard Document Row View for touch-friendly interactions
struct DashboardDocumentRow: View {
    let document: Letterspace_CanvasDocument
    let isPinned: Bool
    let isWIP: Bool
    let hasCalendar: Bool
    let isSelected: Bool
    let visibleColumns: Set<String>
    let dateFilterType: DateFilterType
    let isEditMode: Bool
    @Binding var selectedItems: Set<String>
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onShowDetails: () -> Void
    let onPin: () -> Void
    let onWIP: () -> Void
    let onCalendar: () -> Void
    let onCalendarAction: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var gradientManager = GradientWallpaperManager.shared
    
    // Computed properties for theme-aware status colors
    private var pinColor: Color {
        let useThemeColors = colorScheme == .dark ? 
            gradientManager.selectedDarkGradientIndex != 0 :
            gradientManager.selectedLightGradientIndex != 0
            
        return useThemeColors ? theme.accent : .orange
    }
    
    private var wipColor: Color {
        let useThemeColors = colorScheme == .dark ? 
            gradientManager.selectedDarkGradientIndex != 0 :
            gradientManager.selectedLightGradientIndex != 0
            
        return useThemeColors ? theme.primary : .blue
    }
    
    private var calendarColor: Color {
        let useThemeColors = colorScheme == .dark ? 
            gradientManager.selectedDarkGradientIndex != 0 :
            gradientManager.selectedLightGradientIndex != 0
            
        return useThemeColors ? theme.secondary : .green
    }
    
    // Computed property for theme-aware selection color
    
    // Add default parameter values for backward compatibility
    init(
        document: Letterspace_CanvasDocument,
        isPinned: Bool,
        isWIP: Bool,
        hasCalendar: Bool,
        isSelected: Bool,
        visibleColumns: Set<String>,
        dateFilterType: DateFilterType,
        isEditMode: Bool = false,
        selectedItems: Binding<Set<String>> = .constant(Set()),
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void,
        onShowDetails: @escaping () -> Void = {},
        onPin: @escaping () -> Void,
        onWIP: @escaping () -> Void,
        onCalendar: @escaping () -> Void,
        onCalendarAction: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.document = document
        self.isPinned = isPinned
        self.isWIP = isWIP
        self.hasCalendar = hasCalendar
        self.isSelected = isSelected
        self.visibleColumns = visibleColumns
        self.dateFilterType = dateFilterType
        self.isEditMode = isEditMode
        self._selectedItems = selectedItems
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onShowDetails = onShowDetails
        self.onPin = onPin
        self.onWIP = onWIP
        self.onCalendar = onCalendar
        self.onCalendarAction = onCalendarAction
        self.onDelete = onDelete
    }
    
    var body: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let isPortrait = UIScreen.main.bounds.height > UIScreen.main.bounds.width
        
        ZStack {
            // Full-width selection background for non-iPad devices
            if isSelected && !isIPad {
                let useThemeColors = colorScheme == .dark ? 
                    gradientManager.selectedDarkGradientIndex != 0 :
                    gradientManager.selectedLightGradientIndex != 0
                
                if useThemeColors {
                    // Use glassmorphism material for gradient modes
                    RoundedRectangle(cornerRadius: 13)
                        .fill(.regularMaterial)
                } else {
                    // Use theme accent color with proper opacity and rounded corners
                    RoundedRectangle(cornerRadius: 13)
                        .fill(theme.accent.opacity(0.1))
                }
            }
            
            HStack(spacing: 0) {
                // Status indicators column (aligned with header)
                HStack(spacing: isPortrait && isIPad ? 4 : 4) {
                    if !isEditMode {
                    if isPinned {
                        Image(systemName: "pin.fill")
                                .font(.system(size: isIPad ? 10 : 16))
                                .foregroundColor(pinColor)
                    } else {
                        Image(systemName: "pin.fill")
                                .font(.system(size: isIPad ? 10 : 16))
                            .foregroundColor(.clear)
                    }
                    
                    if isWIP {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: isIPad ? 10 : 16))
                                .foregroundColor(wipColor)
                    } else {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: isIPad ? 10 : 16))
                            .foregroundColor(.clear)
                    }
                    
                    if hasCalendar {
                        Image(systemName: "calendar")
                                .font(.system(size: isIPad ? 10 : 16))
                                .foregroundColor(calendarColor)
                    } else {
                        Image(systemName: "calendar")
                                .font(.system(size: isIPad ? 10 : 16))
                            .foregroundColor(.clear)
                    }
                    }
                }
                .frame(width: isIPad ? 30 : 80, alignment: isIPad ? .center : .leading)
                
                // Add breathing room between status indicators and name column on iPad
                if isIPad {
                    Spacer().frame(width: 24)
                }
                
                // Main content area with targeted selection background for iPad
                ZStack {
                    // Selection background for iPad - only covers main content columns
                    if isSelected && isIPad {
                        let useThemeColors = colorScheme == .dark ? 
                            gradientManager.selectedDarkGradientIndex != 0 :
                            gradientManager.selectedLightGradientIndex != 0
                        
                        if useThemeColors {
                            // Use glassmorphism material for gradient modes
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.regularMaterial)
                                .padding(.vertical, -8) // Extend 8pt above and below the row
                        } else {
                            // Use theme accent color with proper opacity and rounded corners
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.accent.opacity(0.1))
                                .padding(.vertical, -8) // Extend 8pt above and below the row
                        }
                    }
                    
                    HStack(spacing: 0) {
                        // Name column with document icon (aligned with header)
                        HStack(spacing: 8) {
                            // Document icon - positioned at start of name column
                            Image(systemName: "doc.text")
                                .font(.system(size: isPortrait && isIPad ? 16 : 14))
                                .foregroundColor(theme.secondary)
                                .frame(width: 24, alignment: .center)
                            
                            // Document title and subtitle
                VStack(alignment: .leading, spacing: isPortrait && isIPad ? 3 : 2) {
                    Text(document.title.isEmpty ? "Untitled" : document.title)
                                    .font(.system(size: isPortrait && isIPad ? 17 : 18, weight: .regular))
                        .foregroundColor(theme.primary)
                        .lineLimit(1)
                    
                    if !document.subtitle.isEmpty {
                        Text(document.subtitle)
                                        .font(.system(size: isPortrait && isIPad ? 16 : 16))
                            .foregroundColor(theme.secondary)
                            .lineLimit(1)
                                }
                    }
                }
                .frame(minWidth: 120, alignment: .leading)
                
                Spacer()
                
                        // Series column (if visible, aligned with header)
                        if visibleColumns.contains("series") {
                            Group {
                                if let series = document.series, !series.name.isEmpty {
                                    Text(series.name)
                                        .font(.system(size: isPortrait && isIPad ? 15 : 16))
                        .foregroundColor(theme.secondary)
                                        .padding(.horizontal, isPortrait && isIPad ? 10 : 8)
                                        .padding(.vertical, isPortrait && isIPad ? 4 : 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: isPortrait && isIPad ? 8 : 6)
                                                .fill(Color(UIColor.systemGray5))
                                        )
                                } else {
                                    Text("-")
                                        .font(.system(size: isPortrait && isIPad ? 15 : 16))
                                        .foregroundColor(theme.secondary.opacity(0.5))
                                }
                            }
                            .frame(width: 100, alignment: .leading)
                }
                
                        // Location column (if visible, aligned with header) - moved before date
                if visibleColumns.contains("location") {
                    Group {
                        if let location = document.variations.first?.location, !location.isEmpty {
                            Text(location)
                                        .font(.system(size: isPortrait && isIPad ? 15 : 16))
                                .foregroundColor(theme.secondary)
                                        .padding(.horizontal, isPortrait && isIPad ? 10 : 8)
                                        .padding(.vertical, isPortrait && isIPad ? 4 : 3)
                                .background(
                                            RoundedRectangle(cornerRadius: isPortrait && isIPad ? 8 : 6)
                                        .fill(Color(UIColor.systemGray5))
                                )
                        } else {
                            Text("-")
                                        .font(.system(size: isPortrait && isIPad ? 15 : 16))
                                .foregroundColor(theme.secondary.opacity(0.5))
                        }
                    }
                            .frame(width: 120, alignment: .leading)
                        }
                        
                        // Date column (if visible, aligned with header) - moved after location
                        if visibleColumns.contains("date") {
                            Text(formatDate(document.modifiedAt))
                                .font(.system(size: isPortrait && isIPad ? 15 : 16))
                                .foregroundColor(theme.secondary)
                                .frame(width: 90, alignment: .leading)
                }
                
                // Created date column (if visible, aligned with header)
                if visibleColumns.contains("createdDate") {
                    Text(formatDate(document.createdAt))
                                .font(.system(size: isPortrait && isIPad ? 15 : 16))
                        .foregroundColor(theme.secondary)
                                .frame(width: 80, alignment: .leading)
                        }
                    }
                }
                
                // Add spacing before Actions column
                Spacer().frame(width: 16)
                
                // Actions column (aligned with header) - Enhanced touch target for iPad
                HStack(spacing: 8) {
                    // Info button for document details (only when not in edit mode)
                    if !isEditMode {
                        Button(action: onShowDetails) {
                            Image(systemName: "info.circle")
                                .font(.system(size: isPortrait && isIPad ? 18 : 18))
                        .foregroundColor(theme.secondary)
                                .frame(width: isPortrait && isIPad ? 36 : 28, height: isPortrait && isIPad ? 36 : 28)
                        .background(
                            Circle()
                                .fill(Color(UIColor.systemGray6).opacity(0.7))
                        )
                }
                .buttonStyle(.plain)
                    }
                    
                    // Menu button (only when not in edit mode)
                    if !isEditMode {
                        Menu {
            Button(isPinned ? "Unpin" : "Pin") {
                onPin()
            }
            
            Button(isWIP ? "Remove from WIP" : "Add to WIP") {
                onWIP()
            }
            
            Button(hasCalendar ? "Remove from Calendar" : "Add to Calendar") {
                onCalendar()
            }
                            
                            Divider()
            
            Button("Schedule Presentation") {
                onCalendarAction()
            }
            
                            Divider()
                            
                            Button("Delete") {
                                onDelete()
                            }
                            .foregroundColor(.red)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: isPortrait && isIPad ? 18 : 18))
                                .foregroundColor(theme.secondary)
                                .frame(width: isPortrait && isIPad ? 36 : 28, height: isPortrait && isIPad ? 36 : 28)
                                .background(
                                    Circle()
                                        .fill(Color(UIColor.systemGray6).opacity(0.7))
                                )
            }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 80, alignment: .center)
            }
            .padding(.horizontal, isPortrait && isIPad ? 16 : 16)
            .padding(.vertical, isPortrait && isIPad ? 16 : 10) // Increased vertical padding for iPad
        }
        .overlay(
            Group {
                // Only show separator lines on non-iPad devices
                if !isIPad {
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(UIColor.separator).opacity(0.3))
            }
            },
            alignment: .bottom
        )
        .overlay(alignment: .topLeading) {
            // Selection circle for edit mode
            if isEditMode {
                let isSelected = selectedItems.contains(document.id)
                Button(action: {}) { // Empty action since tap is handled by parent
                    ZStack {
                        Circle()
                            .stroke(theme.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        
                        if isSelected {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.top, 16)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            // Use simultaneousGesture for better long press handling
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
        .onTapGesture {
            onTap()
        }
        .frame(minHeight: isPortrait && isIPad ? 72 : 56) // Increased minimum height for iPad
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
#endif 