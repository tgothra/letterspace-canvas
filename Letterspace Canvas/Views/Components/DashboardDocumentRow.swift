#if os(iOS)
import SwiftUI
import UIKit

// iOS Dashboard Document Row View for touch-friendly interactions
// Note: Usage of `screen` environment variable for screen bounds is compliant with 
// new iOS 26.0 recommendations. The environment must provide the correct UIScreen instance.
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
    let columnWidths: (statusWidth: CGFloat, nameWidth: CGFloat, seriesWidth: CGFloat, locationWidth: CGFloat, dateWidth: CGFloat, createdDateWidth: CGFloat)?
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onShowDetails: () -> Void
    let onPin: () -> Void
    let onWIP: () -> Void
    let onCalendar: () -> Void
    let onCalendarAction: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.themeColors) var theme: ThemeColors
    @Environment(\.colorScheme) var colorScheme
    private let gradientManager = GradientWallpaperManager.shared
    
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
    
    // Helper function to calculate flexible column widths for iPhone
    private func calculateFlexibleColumnWidths() -> (statusWidth: CGFloat, nameWidth: CGFloat, seriesWidth: CGFloat, locationWidth: CGFloat, dateWidth: CGFloat, createdDateWidth: CGFloat) {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isPhone {
            // Get available width (93% of screen width minus padding)
            let screenWidth = UIScreen.main.bounds.width
            let availableWidth = screenWidth * 0.93 - 32 // Account for container padding
            
            // Fixed width for status column
            let statusWidth: CGFloat = 55
            
            // Calculate remaining width for other columns
            let remainingWidth = availableWidth - statusWidth
            
            // Get visible columns (excluding status)
            let visibleNonStatusColumns = visibleColumns.filter { $0 != "status" }
            
            // If only name column is visible, it takes all remaining space
            if visibleNonStatusColumns.count == 1 && visibleNonStatusColumns.contains("name") {
                return (statusWidth: statusWidth, nameWidth: remainingWidth, seriesWidth: 0, locationWidth: 0, dateWidth: 0, createdDateWidth: 0)
            }
            
            // Define flex ratios for each column type
            let flexRatios: [String: CGFloat] = [
                "name": 2.0,        // Name gets double space
                "series": 1.2,      // Series gets slightly more
                "location": 1.4,    // Location gets more space
                "date": 0.8,        // Date columns get less space
                "createdDate": 0.8
            ]
            
            // Calculate total flex ratio for visible columns
            let totalFlexRatio = visibleNonStatusColumns.reduce(0) { sum, columnId in
                sum + (flexRatios[columnId] ?? 1.0)
            }
            
            // Calculate individual widths
            let nameWidth = visibleNonStatusColumns.contains("name") ? 
                max(120, remainingWidth * (flexRatios["name"] ?? 1.0) / totalFlexRatio) : 0
            let seriesWidth = visibleNonStatusColumns.contains("series") ? 
                max(80, remainingWidth * (flexRatios["series"] ?? 1.0) / totalFlexRatio) : 0
            let locationWidth = visibleNonStatusColumns.contains("location") ? 
                max(90, remainingWidth * (flexRatios["location"] ?? 1.0) / totalFlexRatio) : 0
            let dateWidth = visibleNonStatusColumns.contains("date") ? 
                max(70, remainingWidth * (flexRatios["date"] ?? 1.0) / totalFlexRatio) : 0
            let createdDateWidth = visibleNonStatusColumns.contains("createdDate") ? 
                max(70, remainingWidth * (flexRatios["createdDate"] ?? 1.0) / totalFlexRatio) : 0
            
            return (statusWidth: statusWidth, nameWidth: nameWidth, seriesWidth: seriesWidth, locationWidth: locationWidth, dateWidth: dateWidth, createdDateWidth: createdDateWidth)
        } else if isIPad {
            // Fixed widths for iPad to ensure proper alignment
            return (statusWidth: 80, nameWidth: 200, seriesWidth: 120, locationWidth: 140, dateWidth: 100, createdDateWidth: 100)
        }
        
        // Default values for other devices
        return (statusWidth: 55, nameWidth: 120, seriesWidth: 100, locationWidth: 120, dateWidth: 90, createdDateWidth: 80)
    }
    
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
        columnWidths: (statusWidth: CGFloat, nameWidth: CGFloat, seriesWidth: CGFloat, locationWidth: CGFloat, dateWidth: CGFloat, createdDateWidth: CGFloat)? = nil,
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
        self.columnWidths = columnWidths
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
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        let isPortrait = screenHeight > screenWidth
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        
        mainContent
            .overlay(alignment: .bottom) {
                // Remove separator lines for cleaner iPhone appearance
                // iPad and other devices don't show separators
                EmptyView()
            }
            .overlay(alignment: .trailing) {
                // Floating action button for iPhone (only when not in edit mode)
                if isPhone && !isEditMode {
                    phoneActionMenu
                }
            }
            .background {
                // Full-width selection background for non-iPad devices
                if isSelected && !isIPad {
                    selectionBackground
                }
            }
            .overlay(alignment: .topLeading) {
                // Selection circle for edit mode
                if isEditMode {
                    editModeOverlay
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
            .frame(minHeight: isPhone ? 44 : (isPortrait && isIPad ? 72 : 56))
    }
    
    private var mainContent: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        let isPortrait = screenHeight > screenWidth
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let widths = columnWidths ?? calculateFlexibleColumnWidths()
        
        return HStack(spacing: 0) {
            // Status indicators column (aligned with header)
            HStack(spacing: isPortrait && isIPad ? 4 : 4) {
                if !isEditMode {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: isPhone ? 9 : (isIPad ? 10 : 16)))
                            .foregroundColor(pinColor)
                    } else {
                        Image(systemName: "pin.fill")
                            .font(.system(size: isPhone ? 9 : (isIPad ? 10 : 16)))
                            .foregroundColor(.clear)
                    }
                    
                    if isWIP {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: isPhone ? 9 : (isIPad ? 10 : 16)))
                            .foregroundColor(wipColor)
                    } else {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: isPhone ? 9 : (isIPad ? 10 : 16)))
                            .foregroundColor(.clear)
                    }
                    
                    if hasCalendar {
                        Image(systemName: "calendar")
                            .font(.system(size: isPhone ? 9 : (isIPad ? 10 : 16)))
                            .foregroundColor(calendarColor)
                    } else {
                        Image(systemName: "calendar")
                            .font(.system(size: isPhone ? 9 : (isIPad ? 10 : 16)))
                            .foregroundColor(.clear)
                    }
                }
            }
            .frame(width: isIPad ? widths.statusWidth : (isPhone ? widths.statusWidth : 80), alignment: isIPad ? .center : .leading)
            .padding(.leading, isPhone ? 10 : 0) // Add breathing room from left edge on iPhone
            
            // Add breathing room between status indicators and name column on iPad
            if isIPad {
                Spacer().frame(width: 24)
            } else if isPhone {
                // iPhone: Reduce spacing between status icons and name column
                Spacer().frame(width: 2)
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
                            .font(.system(size: isPhone ? 12 : (isPortrait && isIPad ? 16 : 14)))
                            .foregroundColor(theme.secondary)
                            .frame(width: isPhone ? 20 : 24, alignment: .center)
                        
                        // Document title and subtitle
                        VStack(alignment: .leading, spacing: isPortrait && isIPad ? 3 : 2) {
                            Text(document.title.isEmpty ? "Untitled" : document.title)
                                .font(.system(size: isPhone ? 14 : (isPortrait && isIPad ? 17 : 18), weight: .regular))
                                .foregroundColor(theme.primary)
                                .lineLimit(1)
                            
                            if !document.subtitle.isEmpty {
                                Text(document.subtitle)
                                    .font(.system(size: isPhone ? 13 : (isPortrait && isIPad ? 16 : 16)))
                                    .foregroundColor(theme.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        // Add spacer to fill available width when only name column is visible
                        if visibleColumns.count <= 1 {
                            Spacer()
                        }
                    }
                    .frame(width: isPhone ? widths.nameWidth : (isIPad ? widths.nameWidth : (visibleColumns.count > 1 ? nil : .infinity)), alignment: .leading)
                    
                    // Series column (if visible, aligned with header)
                    if visibleColumns.contains("series") {
                        Group {
                            if let series = document.series, !series.name.isEmpty {
                                Text(series.name)
                                    .font(.system(size: isPhone ? 12 : (isPortrait && isIPad ? 15 : 16)))
                                    .foregroundColor(theme.secondary)
                                    .padding(.horizontal, isPhone ? 6 : (isPortrait && isIPad ? 10 : 8))
                                    .padding(.vertical, isPhone ? 2 : (isPortrait && isIPad ? 4 : 3))
                                    .background(
                                        RoundedRectangle(cornerRadius: isPhone ? 4 : (isPortrait && isIPad ? 8 : 6))
                                            .fill(Color(UIColor.systemGray5))
                                    )
                            } else {
                                Text("-")
                                    .font(.system(size: isPhone ? 12 : (isPortrait && isIPad ? 15 : 16)))
                                    .foregroundColor(theme.secondary.opacity(0.5))
                            }
                        }
                        .frame(width: isPhone ? widths.seriesWidth : (isIPad ? widths.seriesWidth : 100), alignment: .leading)
                    }
                    
                    // Location column (if visible, aligned with header) - moved before date
                    if visibleColumns.contains("location") {
                        Group {
                            if let location = document.variations.first?.location, !location.isEmpty {
                                Text(location)
                                    .font(.system(size: isPhone ? 12 : (isPortrait && isIPad ? 15 : 16)))
                                    .foregroundColor(theme.secondary)
                                    .padding(.horizontal, isPhone ? 6 : (isPortrait && isIPad ? 10 : 8))
                                    .padding(.vertical, isPhone ? 2 : (isPortrait && isIPad ? 4 : 3))
                                    .background(
                                        RoundedRectangle(cornerRadius: isPhone ? 4 : (isPortrait && isIPad ? 8 : 6))
                                            .fill(Color(UIColor.systemGray5))
                                    )
                            } else {
                                Text("-")
                                    .font(.system(size: isPhone ? 12 : (isPortrait && isIPad ? 15 : 16)))
                                    .foregroundColor(theme.secondary.opacity(0.5))
                            }
                        }
                        .frame(width: isPhone ? widths.locationWidth : (isIPad ? widths.locationWidth : 120), alignment: .leading)
                    }
                    
                    // Date column (if visible, aligned with header) - moved after location
                    if visibleColumns.contains("date") {
                        Text(formatDate(document.modifiedAt))
                            .font(.system(size: isPhone ? 12 : (isPortrait && isIPad ? 15 : 16)))
                            .foregroundColor(theme.secondary)
                            .frame(width: isPhone ? widths.dateWidth : (isIPad ? widths.dateWidth : 90), alignment: .leading)
                    }
                    
                    // Created date column (if visible, aligned with header)
                    if visibleColumns.contains("createdDate") {
                        Text(formatDate(document.createdAt))
                            .font(.system(size: isPhone ? 12 : (isPortrait && isIPad ? 15 : 16)))
                            .foregroundColor(theme.secondary)
                            .frame(width: isPhone ? widths.createdDateWidth : (isIPad ? widths.createdDateWidth : 80), alignment: .leading)
                    }
                }
            }
            
            // Add spacing before Actions column (iPad only)
            if !isPhone {
                Spacer().frame(width: 16)
                
                // Actions column (aligned with header) - Enhanced touch target for iPad
                HStack(spacing: 8) {
                    // Info button for document details (iPad only)
                    if !isEditMode {
                        Button(action: {
                            HapticFeedback.impact(.light)
                            onShowDetails()
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: isPortrait && isIPad ? 18 : 18))
                                .foregroundColor(theme.secondary)
                                .frame(width: isPortrait && isIPad ? 36 : 28, 
                                       height: isPortrait && isIPad ? 36 : 28)
                                .background(
                                    Circle()
                                        .fill(Color(UIColor.systemGray6).opacity(0.7))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Menu button (iPad only, no iPhone-specific content)
                    if !isEditMode {
                        iPadActionMenu
                    }
                }
                .frame(width: isIPad ? 100 : 80, alignment: .center)
            }
        }
        .padding(.horizontal, isPhone ? 0 : (isPortrait && isIPad ? 16 : 16)) // iPhone: Remove padding to fill full width
        .padding(.vertical, isPhone ? 8 : (isPortrait && isIPad ? 16 : 10))
    }
    
    private var iPadActionMenu: some View {
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        let isPortrait = screenHeight > screenWidth
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        return Menu {
            Button(isPinned ? "Unpin" : "Pin") {
                HapticFeedback.impact(.light)
                onPin()
            }
            
            Button(isWIP ? "Remove from WIP" : "Add to WIP") {
                HapticFeedback.impact(.light)
                onWIP()
            }
            
            Button(hasCalendar ? "Remove from Calendar" : "Add to Calendar") {
                HapticFeedback.impact(.light)
                onCalendar()
            }
            
            Divider()
            
            Button("Schedule Presentation") {
                HapticFeedback.impact(.light)
                onCalendarAction()
            }
            
            Divider()
            
            Button("Delete") {
                HapticFeedback.impact(.medium)
                onDelete()
            }
            .foregroundColor(.red)
        } label: {
            Button(action: {
                HapticFeedback.impact(.medium)
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: isPortrait && isIPad ? 18 : 18))
                    .foregroundColor(theme.secondary)
                    .frame(width: isPortrait && isIPad ? 36 : 28, 
                           height: isPortrait && isIPad ? 36 : 28)
                    .background(
                        Circle()
                            .fill(Color(UIColor.systemGray6).opacity(0.7))
                    )
            }
            .buttonStyle(.plain)
        }
        .buttonStyle(.plain)
    }
    
    private var phoneActionMenu: some View {
        Menu {
            Button("Document Details") {
                HapticFeedback.impact(.light)
                onShowDetails()
            }
            
            Divider()
            
            Button(isPinned ? "Unpin" : "Pin") {
                HapticFeedback.impact(.light)
                onPin()
            }
            
            Button(isWIP ? "Remove from WIP" : "Add to WIP") {
                HapticFeedback.impact(.light)
                onWIP()
            }
            
            Button(hasCalendar ? "Remove from Calendar" : "Add to Calendar") {
                HapticFeedback.impact(.light)
                onCalendar()
            }
            
            Divider()
            
            Button("Schedule Presentation") {
                HapticFeedback.impact(.light)
                onCalendarAction()
            }
            
            Divider()
            
            Button("Delete") {
                HapticFeedback.impact(.medium)
                onDelete()
            }
            .foregroundColor(.red)
        } label: {
            Button(action: {
                HapticFeedback.impact(.medium)
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6))
                    )
            }
            .buttonStyle(.plain)
        }
        .buttonStyle(.plain)
        .padding(.trailing, -15)
    }
    
    private var selectionBackground: some View {
        let useThemeColors = colorScheme == .dark ? 
            gradientManager.selectedDarkGradientIndex != 0 :
            gradientManager.selectedLightGradientIndex != 0
        
        return Group {
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
    }
    
    private var editModeOverlay: some View {
        let isSelected = selectedItems.contains(document.id)
        
        return Button(action: {}) { // Empty action since tap is handled by parent
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
#endif 



