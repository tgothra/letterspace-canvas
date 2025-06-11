import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// Add at the top of the file with other imports
struct Marker: Identifiable {
    let id = UUID()
    var title: String
    var page: Int
    var type: String    // Instead of color string
    var position: Int   // Instead of x,y coordinates
}

// MARK: - Helper Extensions
extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }
}

struct HoverPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Helper Models
struct Day: Identifiable {
    let id: UUID = UUID()
    let number: Int?  // Changed to optional
    let month: Int
    let year: Int
    let isCurrentMonth: Bool
    let isSelected: Bool
}

extension Calendar {
    func daysInMonth(year: Int, month: Int) -> [Day] {
        var days = [Day]()
        
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = self.date(from: dateComponents),
              let range = self.range(of: .day, in: .month, for: date),
              let firstWeekday = self.date(from: dateComponents)?.startOfMonth().weekday else {
            return []
        }
        
        // Add empty spaces for previous month
        let previousOffset = firstWeekday - 1
        if previousOffset > 0 {
            for _ in 0..<previousOffset {
                days.append(Day(
                    number: nil,  // Use nil to indicate empty space
                    month: month,
                    year: year,
                    isCurrentMonth: false,
                    isSelected: false
                ))
            }
        }
        
        // Add days from current month
        for day in range {
            days.append(Day(
                number: day,
                month: month,
                year: year,
                isCurrentMonth: true,
                isSelected: false
            ))
        }
        
        // Add empty spaces for next month (instead of actual dates)
        let remainingDays = 42 - days.count // 6 rows * 7 days = 42
        if remainingDays > 0 {
            for _ in 0..<remainingDays {
                days.append(Day(
                    number: nil,  // Use nil to indicate empty space
                    month: month,
                    year: year,
                    isCurrentMonth: false,
                    isSelected: false
                ))
            }
        }
        
        return days
    }
}

struct DocumentTag: Identifiable, Hashable {
    let id = UUID()
    let text: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum SeriesSortOrder: String, CaseIterable {
    case name = "Name"
    case date = "Date"
    case custom = "Custom"
}

// MARK: - Helper Views
struct EditableField: View {
    let placeholder: String
    @Binding var text: String
    var isDateField: Bool = false
    var isLocationField: Bool = false
    var suggestions: [String] = []
    var onSelect: ((String) -> Void)? = nil
    var isBold: Bool = false
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Add local state to track text input
    @State private var localText: String = ""
    @State private var isShowingCalendar = false
    @State private var showSuggestions = false
    @State private var recentLocations: [String] = []
    @State private var selectedDate = Date()
    @FocusState private var isTextFieldFocused: Bool
    
    // Date formatter for displaying date with time
    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter
    }()
    
    // Date formatter for parsing date string
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
    
    // Lazy load documents only when needed for location suggestions
    private var documents: [Letterspace_CanvasDocument] {
        // Only load documents if we're in a location field
        guard isLocationField else {
            return []
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return []
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        print("📂 Loading documents from directory: \(appDirectory.path)")
        
        do {
            // Create app directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📂 Found \(fileURLs.count) canvas files")
            
            let loadedDocs = fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    print("📂 Loaded document: \(doc.title) (ID: \(doc.id))")
                    return doc
                } catch {
                    print("❌ Error loading document at \(url): \(error)")
                    return nil
                }
            }
            
            print("📂 Loaded \(loadedDocs.count) documents total")
            return loadedDocs
        } catch {
            print("❌ Error accessing documents directory: \(error)")
            return []
        }
    }
    
    private func loadRecentLocations() {
        // Get locations from all documents, with their last used date
        let locationsWithDates = documents.flatMap { doc -> [(String, Date)] in
            doc.variations.compactMap { variation -> (String, Date)? in
                guard let location = variation.location, !location.isEmpty else { return nil }
                return (location, doc.modifiedAt)
            }
        }
        
        // Group by location and take the most recent date for each
        let locationDict = Dictionary(grouping: locationsWithDates, by: { $0.0 })
            .mapValues { dates in
                dates.map { $0.1 }.max() ?? Date.distantPast
            }
        
        // Sort by date (most recent first) and take top 4
        recentLocations = locationDict
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { $0.key }
        
        // Show suggestions with animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            showSuggestions = true  // Show suggestions immediately when loading locations
        }
        
        // Print debug information
        print("📍 Found \(recentLocations.count) recent locations: \(recentLocations)")
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if isDateField {
                HStack {
                    Text(localText.isEmpty ? placeholder : localText)
                        .font(.system(size: 13, weight: isBold ? .medium : .regular))
                        .foregroundStyle(localText.isEmpty ? theme.secondary : theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary)
                }
                .padding(8)
                .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                .cornerRadius(6)
                .onTapGesture {
                    // Parse the current text to initialize the date
                    if !localText.isEmpty {
                        if let date = dateFormatter.date(from: localText) {
                            selectedDate = date
                        } else {
                            selectedDate = Date()
                        }
                    } else {
                        selectedDate = Date()
                    }
                    isShowingCalendar = true
                }
                .popover(isPresented: $isShowingCalendar) {
                    OptimizedCalendarPopover(selectedDate: Binding(
                        get: { selectedDate },
                        set: { date in
                            selectedDate = date
                            localText = dateTimeFormatter.string(from: date)
                            text = localText // Update the binding
                            isShowingCalendar = false
                        }
                    ))
                }
                .presentationCompactAdaptation(.popover) // Force popover style
                .presentationBackground(.white) // Set white background for the popover
                .presentationCornerRadius(8) // Match the corner radius
                .interactiveDismissDisabled(true) // Prevent accidental dismissal
            } else if isLocationField {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TextField(placeholder, text: $localText)
                            .font(.system(size: 13, weight: isBold ? .medium : .regular))
                            .textFieldStyle(.plain)
                            .focused($isTextFieldFocused)
                            .onTapGesture {
                                loadRecentLocations()
                            }
                            .onChange(of: isTextFieldFocused) { oldValue, newValue in
                                if newValue {
                                    loadRecentLocations()
                                } else {
                                    // Don't hide suggestions immediately when losing focus
                                    // This allows clicking on suggestions
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if !isTextFieldFocused {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                                showSuggestions = false
                                                recentLocations = []
                                            }
                                        }
                                    }
                                }
                            }
                            .onChange(of: localText) { oldValue, newValue in
                                // Sync local text with binding
                                text = newValue
                                print("📝 EditableField location: Text changed from '\(oldValue)' to '\(newValue)'")
                                
                                // Keep suggestions visible while typing
                                if isTextFieldFocused {
                                    showSuggestions = true
                                }
                            }
                            .onSubmit {
                                if !localText.isEmpty {
                                    onSelect?(localText)
                                    showSuggestions = false
                                    isTextFieldFocused = false
                                }
                            }
                            
                        // Add clear button
                        if !localText.isEmpty || showSuggestions {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                    localText = ""
                                    text = ""
                                    showSuggestions = false
                                    isTextFieldFocused = false
                                    onSelect?("")
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(theme.secondary.opacity(0.7))
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .popover(isPresented: Binding<Bool>(
                        get: { showSuggestions },
                        set: { 
                            if !$0 {
                                showSuggestions = false
                                // Clear input text if dismissed without selection
                                if isTextFieldFocused {
                                    localText = ""
                                    text = ""
                                    if let onSelectHandler = onSelect {
                                        onSelectHandler("")
                                    }
                                }
                                isTextFieldFocused = false
                            } else {
                                showSuggestions = $0
                            }
                        }
                    ), arrowEdge: .bottom) {
                        VStack(spacing: 0) {
                            LocationSuggestionsPopover(
                                recentLocations: recentLocations,
                                text: $localText,
                                showSuggestions: $showSuggestions,
                                isTextFieldFocused: Binding<Bool>(
                                    get: { isTextFieldFocused },
                                    set: { isTextFieldFocused = $0 }
                                ),
                                onSelect: onSelect
                            )
                        }
                        .frame(minWidth: 300, maxHeight: 250)
                        .padding(8)
                        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                        .cornerRadius(8)
                    }
                    .presentationCompactAdaptation(.popover)
                }
                .zIndex(2)
            } else {
                TextField(placeholder, text: $localText)
                    .font(.system(size: 13, weight: isBold ? .medium : .regular))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .focused($isTextFieldFocused)
                    .onChange(of: localText) { oldValue, newValue in
                        // Immediately update the binding when local text changes
                        if text != newValue {
                            text = newValue
                            print("📝 EditableField: Text changed from '\(oldValue)' to '\(newValue)'")
                        }
                    }
                    .onChange(of: text) { oldValue, newValue in
                        // Keep localText in sync with external changes to binding
                        if localText != newValue {
                            localText = newValue
                            print("📝 EditableField: External text changed from '\(oldValue)' to '\(newValue)'")
                        }
                    }
                    .onSubmit {
                        isTextFieldFocused = false
                    }
            }
        }
        .onTapGesture {
            if !isLocationField {
                showSuggestions = false
                isTextFieldFocused = false
            }
        }
        .onAppear {
            // Ensure localText is synchronized with text binding on appearance
            localText = text
            print("📝 EditableField onAppear: Synced localText with text = '\(text)'")
        }
    }
}

struct SuggestionButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected || isHovered ? theme.accent.opacity(0.1) : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// Add this view struct before CalendarView
private struct CalendarDayButton: View {
    let day: Day
    let selectedYear: Int
    let selectedMonth: Int
    let hoveredDay: Int?
    let dateFormatter: DateFormatter
    @Binding var selectedDate: String
    @Binding var isPresented: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            if day.isCurrentMonth, let number = day.number {
                let components = DateComponents(year: selectedYear, month: selectedMonth, day: number)
                if let date = Calendar.current.date(from: components) {
                    selectedDate = dateFormatter.string(from: date)
                    isPresented = false
                }
            }
        }) {
            if let number = day.number {
                Text("\(number)")
                    .font(.custom("InterTight-Regular", size: 13))
                    .foregroundStyle(day.isCurrentMonth ? theme.primary : theme.secondary.opacity(0.5))
                    .kerning(0.5) // Added kerning for better spacing between digits
                    .frame(width: 28, height: 28) // Reduced from 32x32 to 28x28
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        Circle()
                            .fill(hoveredDay == number && day.isCurrentMonth ? 
                                  theme.accent.opacity(0.15) :
                                  Color.white)
                            .frame(width: 24, height: 24) // Reduced from 28x28 to 24x24
                    )
            } else {
                Color.white
                    .frame(width: 32, height: 32)
            }
        }
        .buttonStyle(.plain)
        .disabled(!day.isCurrentMonth)
    }
}

struct CalendarView: View {
    @Binding var selectedDate: String
    @Binding var isPresented: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var currentDate = Date()
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var hoveredDay: Int? = nil
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE • MMMM d, yyyy"
        return formatter
    }()
    
    init(selectedDate: Binding<String>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._isPresented = isPresented
        let calendar = Calendar.current
        let date = Date()
        self._selectedYear = State(initialValue: calendar.component(.year, from: date))
        self._selectedMonth = State(initialValue: calendar.component(.month, from: date))
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Month/Year header
            HStack {
                Text("\(calendar.monthSymbols[selectedMonth - 1]), \(String(selectedYear))")
                    .font(.custom("InterTight-Medium", size: 12))
                    .tracking(0.5)
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 8) {
                    NavigationButton(icon: "chevron.left", action: previousMonth)
                    
                    NavigationButton(label: "Today", action: {
                        selectedMonth = Calendar.current.component(.month, from: Date())
                        selectedYear = Calendar.current.component(.year, from: Date())
                    })
                    
                    NavigationButton(icon: "chevron.right", action: nextMonth)
                }
            }
            .padding(.top, 4)
            
            // Day labels
            HStack(spacing: 0) {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.custom("InterTight-Regular", size: 9))
                        .foregroundStyle(theme.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            let days = calendar.daysInMonth(year: selectedYear, month: selectedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 7), spacing: 0) {
                ForEach(days) { day in
                    CalendarDayButton(
                        day: day,
                        selectedYear: selectedYear,
                        selectedMonth: selectedMonth,
                        hoveredDay: hoveredDay,
                        dateFormatter: dateFormatter,
                        selectedDate: $selectedDate,
                        isPresented: $isPresented
                    )
                    .onHover { isHovered in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            hoveredDay = isHovered ? day.number : nil
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
        )
    }
    
    private func previousMonth() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
    }
    
    private func nextMonth() {
        if selectedMonth == 12 {
            selectedMonth = 1
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
    }
}

struct CalendarPopover: View {
    @Binding var selectedDate: Date
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        CalendarView(
            selectedDate: Binding(
                get: {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEE • MMMM d, yyyy"
                    return formatter.string(from: selectedDate)
                },
                set: { dateString in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEE • MMMM d, yyyy"
                    if let date = formatter.date(from: dateString) {
                        selectedDate = date
                    }
                }
            ),
            isPresented: .constant(true)
        )
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.17) : .black.opacity(0.07),
            radius: 8,
            x: 0,
            y: 1
        )
    }
}

// Add these optimized calendar components after the existing CalendarPopover

// MARK: - Optimized Calendar Components
struct OptimizedCalendarPopover: View {
    @Binding var selectedDate: Date
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTime: Date
    
    // Cache date formatters
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE • MMMM d, yyyy"
        return formatter
    }()
    
    // Initialize with the current selected date's time
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._selectedTime = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Calendar view for date selection
            OptimizedCalendarView(
                selectedDate: Binding(
                    get: {
                        OptimizedCalendarPopover.dateFormatter.string(from: selectedDate)
                    },
                    set: { dateString in
                        if let date = OptimizedCalendarPopover.dateFormatter.date(from: dateString) {
                            // Preserve the time part when setting a new date
                            let calendar = Calendar.current
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
                            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                            var finalComponents = DateComponents()
                            finalComponents.year = dateComponents.year
                            finalComponents.month = dateComponents.month
                            finalComponents.day = dateComponents.day
                            finalComponents.hour = timeComponents.hour
                            finalComponents.minute = timeComponents.minute
                            if let combinedDate = calendar.date(from: finalComponents) {
                                selectedDate = combinedDate
                            } else {
                                selectedDate = date // Fallback
                            }
                        }
                    }
                ),
                isPresented: .constant(true)
            )
            
            Divider()
            
            // Time picker
            HStack {
                Text("Time:")
                    .font(.custom("InterTight-Medium", size: 12))
                    .foregroundStyle(theme.secondary)
                
                Spacer()
                
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedTime },
                        set: { newTime in
                            selectedTime = newTime
                            
                            // Update selectedDate with the new time
                            let calendar = Calendar.current
                            let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: newTime)
                            var finalComponents = DateComponents()
                            finalComponents.year = dateComponents.year
                            finalComponents.month = dateComponents.month
                            finalComponents.day = dateComponents.day
                            finalComponents.hour = timeComponents.hour
                            finalComponents.minute = timeComponents.minute
                            if let combinedDate = calendar.date(from: finalComponents) {
                                selectedDate = combinedDate
                            }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(width: 80)
            }
            .padding(.horizontal, 8)
        }
        .padding(8)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(
            color: .black.opacity(0.05),
            radius: 4,
            x: 0,
            y: 1
        )
    }
}

struct OptimizedCalendarView: View {
    @Binding var selectedDate: String
    @Binding var isPresented: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Use StateObject for values that should persist across renders
    @StateObject private var calendarState = CalendarState()
    
    // Cache formatters and calendar
    private static let calendar = Calendar.current
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE • MMMM d, yyyy"
        return formatter
    }()
    
    init(selectedDate: Binding<String>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._isPresented = isPresented
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Month/Year header
            HStack {
                Text("\(OptimizedCalendarView.calendar.shortMonthSymbols[calendarState.selectedMonth - 1]), \(String(calendarState.selectedYear))")
                    .font(.custom("InterTight-Medium", size: 12))
                    .tracking(0.5)
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 8) {
                    NavigationButton(icon: "chevron.left", action: calendarState.previousMonth)
                    
                    NavigationButton(icon: "calendar.badge.clock", action: calendarState.goToToday)
                    
                    NavigationButton(icon: "chevron.right", action: calendarState.nextMonth)
                }
            }
            .padding(.top, 4)
            
            // Day labels
            HStack(spacing: 0) {
                ForEach(OptimizedCalendarView.calendar.veryShortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.custom("InterTight-Regular", size: 9))
                        .foregroundStyle(theme.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4) // Reduced from 8 to 4
            .background(Color.white)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(calendarState.currentDays, id: \.number) { day in
                    if day.number != nil {
                        OptimizedCalendarDayButton(
                            day: day,
                            selectedYear: calendarState.selectedYear,
                            selectedMonth: calendarState.selectedMonth,
                            hoveredDay: calendarState.hoveredDay,
                            selectedDate: $selectedDate,
                            isPresented: $isPresented
                        )
                        .onHover { isHovered in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                calendarState.hoveredDay = isHovered ? day.number : nil
                            }
                        }
                    } else {
                        Color.white // Use white for empty cells
                            .frame(height: 28) // Match the height of day buttons
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 28 * 6) // Force a consistent 6-row height
            .background(Color.white)
        }
        .padding(6) // Reduced from 10 to 6
    }
}

// State object to manage calendar state
class CalendarState: ObservableObject {
    @Published var selectedMonth: Int
    @Published var selectedYear: Int
    @Published var hoveredDay: Int? = nil
    
    // Cache the days for the current month/year
    @Published var currentDays: [Day] = []
    
    init() {
        let calendar = Calendar.current
        let date = Date()
        self.selectedMonth = calendar.component(.month, from: date)
        self.selectedYear = calendar.component(.year, from: date)
        self.updateDays()
    }
    
    func updateDays() {
        currentDays = Calendar.current.daysInMonth(year: selectedYear, month: selectedMonth)
    }
    
    func previousMonth() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
        updateDays()
    }
    
    func nextMonth() {
        if selectedMonth == 12 {
            selectedMonth = 1
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
        updateDays()
    }
    
    func goToToday() {
        let calendar = Calendar.current
        let date = Date()
        selectedMonth = calendar.component(.month, from: date)
        selectedYear = calendar.component(.year, from: date)
        updateDays()
    }
}

struct OptimizedCalendarGrid: View {
    @ObservedObject var calendarState: CalendarState
    @Binding var selectedDate: String
    @Binding var isPresented: Bool
    @Binding var hoveredDay: Int?
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Cache formatters
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE • MMMM d, yyyy"
        return formatter
    }()
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 7), spacing: 0) {
            ForEach(calendarState.currentDays) { day in
                OptimizedCalendarDayButton(
                    day: day,
                    selectedYear: calendarState.selectedYear,
                    selectedMonth: calendarState.selectedMonth,
                    hoveredDay: hoveredDay,
                    selectedDate: $selectedDate,
                    isPresented: $isPresented
                )
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        hoveredDay = isHovered ? day.number : nil
                    }
                }
            }
        }
    }
}

struct OptimizedCalendarDayButton: View {
    let day: Day
    let selectedYear: Int
    let selectedMonth: Int
    let hoveredDay: Int?
    @Binding var selectedDate: String
    @Binding var isPresented: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Cache formatters
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE • MMMM d, yyyy"
        return formatter
    }()
    
    var body: some View {
        Button(action: {
            if day.isCurrentMonth, let number = day.number {
                let components = DateComponents(year: selectedYear, month: selectedMonth, day: number)
                if let date = Calendar.current.date(from: components) {
                    selectedDate = OptimizedCalendarDayButton.dateFormatter.string(from: date)
                    isPresented = false
                }
            }
        }) {
            if let number = day.number {
                Text("\(number)")
                    .font(.custom("InterTight-Regular", size: 13))
                    .foregroundStyle(day.isCurrentMonth ? theme.primary : theme.secondary.opacity(0.5))
                    .kerning(0.5) // Added kerning for better spacing between digits
                    .frame(width: 28, height: 28) // Reduced from 32x32 to 28x28
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        Circle()
                            .fill(hoveredDay == number && day.isCurrentMonth ? 
                                  theme.accent.opacity(0.15) :
                                  Color.white)
                            .frame(width: 24, height: 24) // Reduced from 28x28 to 24x24
                    )
            } else {
                Color.white
                    .frame(width: 32, height: 32)
            }
        }
        .buttonStyle(.plain)
        .disabled(!day.isCurrentMonth)
    }
}

// MARK: - Views
struct RightSidebar: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var isVisible: Bool
    @Binding var selectedElement: UUID?
    @Binding var scrollOffset: CGFloat
    @Binding var documentHeight: CGFloat
    @Binding var viewportHeight: CGFloat
    @Binding var viewMode: ViewMode
    @Binding var isHeaderExpanded: Bool
    @Binding var isSubtitleVisible: Bool
    @State private var sidebarMode: SidebarMode = .details
    @State private var linkURL: String = ""
    @State private var linkTitle: String = ""
    @State private var isAddingLink: Bool = false
    @State private var searchText: String = ""
    @State private var isSelectingTags: Bool = false
    @State private var currentTag: String = ""
    @State private var currentVariations: [Letterspace_CanvasDocument] = []
    @State private var showTranslationModal: Bool = false
    @State private var hoveredSeriesItem: String? = nil
    
    // Local environment values
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var colorManager = TagColorManager.shared
    
    // Add the missing series state property
    @State private var series: [DocumentSeries] = []
    
    // Add document cache
    @State private var documentCache: [String: Letterspace_CanvasDocument] = [:]
    
    // Add a flag to track if we've loaded variations for this document
    @State private var loadedForDocumentId: String = ""
    
    enum SidebarMode {
        case documents
        case details
        case settings
        case recentlyDeleted
        case series
        case tags
        case variations
        case bookmarks
        case links
        case search
        case allDocuments
    }
    
    @State private var isAnimating = false
    @State private var documentName: String = ""
    @State private var datePresented: String = ""
    @State private var location: String = ""
    @State private var tags: Set<String> = []
    
    @State private var seriesSearchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedSeries: String? = nil
    @State private var allSeries: [DocumentSeries] = []
    @State private var isDateSortAscending = true  // Add this line
    
    @State private var tagSearchText = ""
    @FocusState private var isTagSearchFocused: Bool
    @State private var showTagSuggestions = false
    @State private var documents: [Letterspace_CanvasDocument] = []
    @State private var showPresentationManager: Bool = false
    @State private var showPresentationTimeline: Bool = false
    @State private var isPresentationButtonHovered = false
    
    // Add a state variable to force refresh on notification
    @State private var refreshTrigger = UUID()
    
    // Add missing variables for links functionality
    @State private var newLinkTitle: String = ""
    @State private var newLinkURL: String = ""
    
    private var recentSeries: [String] {
        Array(Set(allSeries.map { $0.name })).sorted()
    }
    
    private func formatSeries(_ series: String) -> String {
        // Split by spaces and capitalize first letter of each word
        return series.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    private var matchingSeries: [String] {
        if seriesSearchText.isEmpty {
            return []
        }
        
        return recentSeries
            .filter { $0.localizedCaseInsensitiveContains(seriesSearchText) }
            .sorted { (series1: String, series2: String) -> Bool in
                // Exact matches first (case insensitive)
                let exactMatch1 = series1.localizedCaseInsensitiveCompare(seriesSearchText) == .orderedSame
                let exactMatch2 = series2.localizedCaseInsensitiveCompare(seriesSearchText) == .orderedSame
                if exactMatch1 != exactMatch2 {
                    return exactMatch1
                }
                
                // Starts with search text (case insensitive)
                let startsWith1 = series1.lowercased().hasPrefix(seriesSearchText.lowercased())
                let startsWith2 = series2.lowercased().hasPrefix(seriesSearchText.lowercased())
                if startsWith1 != startsWith2 {
                    return startsWith1
                }
                
                // Alphabetical order
                return series1.localizedCaseInsensitiveCompare(series2) == .orderedAscending
            }
    }
    
    private var shouldShowCreateNew: Bool {
        if seriesSearchText.isEmpty { return false }
        return !recentSeries.contains { $0.localizedCaseInsensitiveCompare(seriesSearchText) == .orderedSame }
    }
    
    private var shouldShowCreateNewTag: Bool {
        !tagSearchText.isEmpty && !(document.tags ?? []).contains(tagSearchText)
    }
    
    private var allTags: [String] {
        var tags: Set<String> = []
        for document in documents {
            if let documentTags = document.tags {
                tags.formUnion(documentTags)
            }
        }
        return Array(tags).sorted()
    }
    
    // Computed property for platform-specific background color
    private var backgroundColorForTagsSection: Color {
        #if os(macOS)
        return colorScheme == .dark ? Color(.windowBackgroundColor) : .white
        #elseif os(iOS)
        return colorScheme == .dark ? Color(.systemBackground) : .white
        #endif
    }
    
    private func formatTag(_ tag: String) -> String {
        // Split by spaces and capitalize first letter of each word
        return tag.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    private var matchingTags: [String] {
        if tagSearchText.isEmpty {
            return []
        }
        
        // Get all currently used tags
        var activeTags = Set<String>()
        for document in documents {
            if let documentTags = document.tags {
                activeTags.formUnion(documentTags)
            }
        }
        
        return Array(activeTags)
            .filter { $0.localizedCaseInsensitiveContains(tagSearchText) }
            .sorted { (tag1: String, tag2: String) -> Bool in
                // Exact matches first (case insensitive)
                let exactMatch1 = tag1.localizedCaseInsensitiveCompare(tagSearchText) == .orderedSame
                let exactMatch2 = tag2.localizedCaseInsensitiveCompare(tagSearchText) == .orderedSame
                if exactMatch1 != exactMatch2 {
                    return exactMatch1
                }
                
                // Starts with search text (case insensitive)
                let startsWith1 = tag1.lowercased().hasPrefix(tagSearchText.lowercased())
                let startsWith2 = tag2.lowercased().hasPrefix(tagSearchText.lowercased())
                if startsWith1 != startsWith2 {
                    return startsWith1
                }
                
                // Alphabetical order
                return tag1.localizedCaseInsensitiveCompare(tag2) == .orderedAscending
            }
    }
    
    private var filteredSeriesItems: [(title: String, date: String, isActive: Bool)] {
        guard let selectedSeries = selectedSeries else { return [] }
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        var items: [(title: String, date: String, isActive: Bool)] = []
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            // Add current document first if it belongs to the series
            if document.series?.name.lowercased() == selectedSeries.lowercased() {
                let dateStr: String
                if let presentedDate = document.variations.first?.datePresented {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d, yyyy"
                    dateStr = formatter.string(from: presentedDate)
                } else {
                    dateStr = "No date"
                }
                items.append((
                    title: document.title.isEmpty ? "Untitled" : document.title,
                    date: dateStr,
                    isActive: true
                ))
            }
            
            // Add other documents in the series
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if let series = doc.series,
                       series.name.lowercased() == selectedSeries.lowercased(),
                       doc.id != document.id {  // Skip current document as it's already added
                        
                        let dateStr: String
                        if let presentedDate = doc.variations.first?.datePresented {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "MMM d, yyyy"
                            dateStr = formatter.string(from: presentedDate)
                        } else {
                            dateStr = "No date"
                        }
                        
                        items.append((
                            title: doc.title.isEmpty ? "Untitled" : doc.title,
                            date: dateStr,
                            isActive: false
                        ))
                    }
                } catch {
                    print("Error reading document at \(url): \(error)")
                }
            }
            
            // Sort items
            return items.sorted { 
                // Handle "No date" cases
                if $0.date == "No date" { return !isDateSortAscending }
                if $1.date == "No date" { return isDateSortAscending }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                
                guard let date1 = formatter.date(from: $0.date),
                      let date2 = formatter.date(from: $1.date) else {
                    return false
                }
                
                return isDateSortAscending ? date1 < date2 : date1 > date2
            }
            
        } catch {
            print("Error accessing documents directory: \(error)")
            return []
        }
    }
    
    private func tagColor(for tag: String) -> Color {
        return colorManager.color(for: tag)
    }
    
    var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Details Section - Always visible
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    sidebarMode = .details
                }
            }) {
                SectionHeader(title: "Details", isExpanded: true, showChevron: false)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 16)
            
            VStack(spacing: 8) {
                EditableField(
                    placeholder: "Title",
                    text: Binding(
                        get: { document.title },
                        set: { newValue in
                            document.title = newValue
                            document.save()
                            print("✏️ Title updated to: \(newValue)")
                        }
                    ),
                    isDateField: false,
                    isLocationField: false,
                    suggestions: [],
                    isBold: true
                )
                if isSubtitleVisible {
                    EditableField(
                        placeholder: "Subtitle",
                        text: Binding(
                            get: { document.subtitle },
                            set: { newValue in
                                document.subtitle = newValue
                                document.save()
                                print("✏️ Subtitle updated to: \(newValue)")
                            }
                        ),
                        isDateField: false,
                        isLocationField: false,
                        suggestions: []
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                // Custom presentation button
                Button(action: {
                    showPresentationManager = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Document Calendar")
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondary)
                            
                            Text(getPresentationText())
                                .font(.system(size: 13))
                                .foregroundColor(theme.primary)
                        }
                        
                        Spacer()
                        
                        // Image(systemName: "calendar") // <-- Remove this and its modifiers
                        //     .font(.system(size: 12))
                        //     .foregroundColor(theme.secondary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? 
                                (isPresentationButtonHovered ? Color(.sRGB, white: 0.25) : Color(.sRGB, white: 0.2)) : 
                                (isPresentationButtonHovered ? Color(.sRGB, white: 0.92) : Color(.sRGB, white: 0.95)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isPresentationButtonHovered ? theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                    .scaleEffect(isPresentationButtonHovered ? 1.01 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPresentationButtonHovered)
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isPresentationButtonHovered = isHovered
                }
                .sheet(isPresented: $showPresentationManager) {
                    PresentationManager(document: document, isPresented: $showPresentationManager)
                }
                
                EditableField(
                    placeholder: "Location",
                    text: Binding(
                        get: { location },
                        set: { newValue in
                            location = newValue
                            // Update document's location
                            if var firstVariation = document.variations.first {
                                // Set location to nil if empty string
                                firstVariation.location = newValue.isEmpty ? nil : newValue
                                document.variations[0] = firstVariation
                                document.save()
                            } else {
                                // Create first variation if it doesn't exist
                                let variation = DocumentVariation(
                                    id: UUID(),
                                    name: "Original",
                                    documentId: document.id,
                                    parentDocumentId: document.id,
                                    createdAt: Date(),
                                    datePresented: nil,
                                    location: newValue
                                )
                                document.variations = [variation]
                                document.save()
                            }
                        }
                    ),
                    isDateField: false,
                    isLocationField: true,
                    suggestions: [],
                    onSelect: { selectedLocation in
                        location = selectedLocation
                        // Update document's location
                        if var firstVariation = document.variations.first {
                            // Set location to nil if empty string
                            firstVariation.location = selectedLocation.isEmpty ? nil : selectedLocation
                            document.variations[0] = firstVariation
                            document.save()
                        } else {
                            // Create first variation if it doesn't exist
                            let variation = DocumentVariation(
                                id: UUID(),
                                name: "Original",
                                documentId: document.id,
                                parentDocumentId: document.id,
                                createdAt: Date(),
                                datePresented: nil,
                                // Set location to nil if empty string
                                location: selectedLocation.isEmpty ? nil : selectedLocation
                            )
                            document.variations = [variation]
                            document.save()
                        }
                    }
                )
                
                Divider()
                    .padding(.vertical, 16)
                
                // Document Options
                VStack(spacing: 12) {
                    Text("Sections")
                        .font(.custom("Inter-Bold", size: 13))
                        .foregroundColor(theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isHeaderExpanded.toggle()
                                document.isHeaderExpanded = isHeaderExpanded
                                applyConsistentTextEditorStyling()
                                document.save()
                            }
                        }) {
                            Text("Header Image")
                                .font(.custom("Inter", size: 13))
                                .foregroundColor(theme.primary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isHeaderExpanded },
                            set: { newValue in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isHeaderExpanded = newValue
                                    document.isHeaderExpanded = newValue
                                    applyConsistentTextEditorStyling()
                                    document.save()
                                }
                            }
                        ))
                            .toggleStyle(GreenToggleStyle())
                            .scaleEffect(0.8)
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Button(action: {
                            isSubtitleVisible.toggle()
                            document.save()  // Save when subtitle visibility changes
                        }) {
                            Text("Subtitle")
                                .font(.custom("Inter", size: 13))
                                .foregroundColor(theme.primary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isSubtitleVisible },
                            set: { newValue in
                                isSubtitleVisible = newValue
                                document.save()  // Save when subtitle visibility changes
                            }
                        ))
                            .toggleStyle(GreenToggleStyle())
                            .scaleEffect(0.8)
                            .frame(width: 40)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSubtitleVisible)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Middle content area
            VStack(alignment: .leading, spacing: 0) {
                if sidebarMode == .details {
                    // Navigation buttons
                    VStack(spacing: 24) {
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sidebarMode = .series
                            }
                        }) {
                            SectionHeader(title: "Series", isExpanded: false, icon: "square.stack.3d.up")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sidebarMode = .tags
                            }
                        }) {
                            SectionHeader(title: "Tags", isExpanded: false, icon: "tag")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sidebarMode = .variations
                            }
                        }) {
                            SectionHeader(title: "Variations", isExpanded: false, icon: "square.on.square")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sidebarMode = .bookmarks
                            }
                        }) {
                            SectionHeader(title: "Bookmarks", isExpanded: false, icon: "bookmark")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sidebarMode = .links
                            }
                        }) {
                            SectionHeader(title: "Links", isExpanded: false, icon: "link")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 24)
                } else if sidebarMode == .series {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Series", isExpanded: true, icon: "square.stack.3d.up")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    seriesContent
                } else if sidebarMode == .tags {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Tags", isExpanded: true, icon: "tag")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    tagsContent
                } else if sidebarMode == .variations {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Variations", isExpanded: true, icon: "square.on.square")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    variationsContent
                } else if sidebarMode == .bookmarks {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Bookmarks", isExpanded: true, icon: "bookmark")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    bookmarksContent
                } else if sidebarMode == .links {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Links", isExpanded: true, icon: "link")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    linksContent
                } else if sidebarMode == .search {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "Search", isExpanded: true, icon: "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    searchContent
                } else if sidebarMode == .allDocuments {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarMode = .details
                        }
                    }) {
                        SectionHeader(title: "All Documents", isExpanded: true, icon: "folder")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 24)
                    
                    allDocumentsContent
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: sidebarMode)
            
            Spacer()
        }
    }
    
    // Extract content views for cleaner organization
    var seriesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
                // Only show search and suggestions when no series is selected
                if selectedSeries == nil {
                // Search field with suggestions
                VStack(alignment: .leading, spacing: 0) {
                    Text("Add a series")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    
                    // Keep everything in a fixed position with proper alignment
                    ZStack(alignment: .topLeading) {
                        // Very small spacer that doesn't affect layout
                        Color.clear.frame(height: 0).allowsHitTesting(false)
                        // Text field
                        TextField("Search or create new series", text: $seriesSearchText)
                            .font(.system(size: 13))
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                            .cornerRadius(6)
                            .frame(height: 35) // Fixed height to prevent shifting
                            .padding(.horizontal, 16)
                            .focused($isSearchFocused)
                            .onChange(of: seriesSearchText) { oldValue, newValue in
                                if !seriesSearchText.isEmpty {
                                    isSearchFocused = true
                                }
                            }
                            .onSubmit {
                                if !seriesSearchText.isEmpty {
                                    let formattedSeries = formatSeries(seriesSearchText)
                                    attachToSeries(named: formattedSeries)
                                    seriesSearchText = ""
                                    isSearchFocused = false
                                }
                            }
                            .zIndex(1)
                        
                        // Use a proper popover for the dropdown menu
                        Text("")
                            .frame(width: 0, height: 0)
                            .padding(0)
                            .position(x: 150, y: 35) // Position at the bottom of the search field
                            .popover(isPresented: Binding<Bool>(
                                get: { isSearchFocused && !seriesSearchText.isEmpty },
                                set: { 
                                    if !$0 { 
                                        isSearchFocused = false
                                        seriesSearchText = ""  // Clear search text when dismissed without selection
                                    } 
                                }
                            ), arrowEdge: .bottom) {
                                VStack(spacing: 0) {
                                    SeriesDropdownView(
                                        matchingSeries: matchingSeries,
                                        shouldShowCreateNew: shouldShowCreateNew,
                                        seriesSearchText: seriesSearchText,
                                        formatSeries: formatSeries,
                                        hoveredSeriesItem: $hoveredSeriesItem,
                                        onSelect: { seriesName in
                                            attachToSeries(named: seriesName)
                                            seriesSearchText = ""
                                            isSearchFocused = false
                                        }
                                    )
                                }
                                .padding(8)
                                .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                                .cornerRadius(8)
                            }
                            .presentationCompactAdaptation(.popover)
                    }
                    // Remove dynamic height/padding that was moving the text field
                    
                    // Quick access recent series when no search
                    if seriesSearchText.isEmpty && !recentSeries.isEmpty {
                        VStack(spacing: 0) {
                            RecentSeriesList(
                                recentSeries: recentSeries,
                                hoveredSeriesItem: $hoveredSeriesItem,
                                onSelect: { series in
                                    attachToSeries(named: series)
                                    seriesSearchText = ""
                                    isSearchFocused = false
                                }
                            )
                            
                            // Small spacer for visual separation
                            Spacer().frame(height: 12)
                        }
                    }
                    
                                                                // Overlay to capture clicks outside dropdown
                    if isSearchFocused && !seriesSearchText.isEmpty {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isSearchFocused = false
                            }
                            .ignoresSafeArea()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .zIndex(1)
                    }
                    
                    // Add a small spacer to ensure input and Recent Series are close together
            Spacer().frame(height: 4)
                }
            }
            
            // Show current series if selected
            if let seriesName = selectedSeries {
                SelectedSeriesView(
                    seriesName: seriesName,
                    items: filteredSeriesItems,
                    isDateSortAscending: $isDateSortAscending,
                    onRemoveSeries: {
                        self.selectedSeries = nil
                        document.series = nil
                        document.save()
                        loadAllSeries()
                    },
                    onOpenItem: { openDocument(item: $0) }
                )
            }
        }
    }
    
    private func openDocument(item: (title: String, date: String, isActive: Bool)) {
        // Don't try to open if this is the active document
        if item.isActive {
            return
        }
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            // Find and open the matching document
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if doc.title == item.title {
                        print("Found matching document, opening: \(url.lastPathComponent)")
                        
                        // Update document directly
                        document = doc
                        sidebarMode = .details
                        return
                    }
                } catch {
                    print("Error reading document at \(url): \(error)")
                }
            }
            
            print("Could not find document with title: \(item.title) in series: \(selectedSeries ?? "unknown")")
            
        } catch {
            print("Error accessing documents directory: \(error)")
        }
    }
    
    // Add this new function to handle series attachment
    private func attachToSeries(named seriesName: String) {
        print("📂 Attaching document to series: \(seriesName)")
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📂 Found \(fileURLs.count) canvas files")
            
            // First find if this series already exists
            var existingSeriesId: UUID? = nil
            var existingDocumentIds = Set<String>()
            
            // First pass: collect all existing series information
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if let series = doc.series, series.name.lowercased() == seriesName.lowercased() {
                        existingSeriesId = series.id
                        existingDocumentIds.insert(doc.id)
                        existingDocumentIds.formUnion(Set(series.documents))
                    }
                } catch {
                    print("❌ Error reading document at \(url): \(error)")
                }
            }
            
            // Create or update the series object
            let seriesId = existingSeriesId ?? UUID()
            existingDocumentIds.insert(document.id)
            
            let newSeries = DocumentSeries(
                id: seriesId,
                name: seriesName,
                documents: Array(existingDocumentIds),
                order: 0
            )
            
            // Update current document first
            document.series = newSeries
            document.save()
            print("✅ Updated current document with series: \(seriesName)")
            
            // Second pass: update all other documents that should have this series
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    var doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Skip if this is the current document (already saved)
                    if doc.id == document.id {
                        continue
                    }
                    
                    // Update document if it's in the series or has matching series name
                    if existingDocumentIds.contains(doc.id) || 
                       (doc.series?.name.lowercased() == seriesName.lowercased()) {
                        doc.series = newSeries
                        let updatedData = try JSONEncoder().encode(doc)
                        try updatedData.write(to: url)
                        print("✅ Updated document \(doc.title) with series: \(seriesName)")
                    }
                } catch {
                    print("❌ Error updating document at \(url): \(error)")
                }
            }
            
            // Update UI state
            selectedSeries = seriesName
            seriesSearchText = ""
            
            // Reload series to refresh UI
            loadAllSeries()
            
            // Post notification that document list updated
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
            print("📣 Posted DocumentListDidUpdate notification")
            
        } catch {
            print("❌ Error accessing documents directory: \(error)")
        }
    }
    
    private func loadAllSeries() {
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            var seriesMap: [String: (id: UUID, documents: Set<String>)] = [:]
            
            // First pass: collect all series information
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if let series = doc.series {
                        let normalizedName = series.name.lowercased()
                        if let existing = seriesMap[normalizedName] {
                            var updatedDocs = existing.documents
                            updatedDocs.insert(doc.id)
                            updatedDocs.formUnion(Set(series.documents))
                            seriesMap[normalizedName] = (id: existing.id, documents: updatedDocs)
                        } else {
                            var docs = Set<String>()
                            docs.insert(doc.id)
                            docs.formUnion(Set(series.documents))
                            seriesMap[normalizedName] = (id: series.id, documents: docs)
                        }
                    }
                } catch {
                    print("Error reading document at \(url): \(error)")
                }
            }
            
            // Update UI state
            allSeries = seriesMap.map { (normalizedName, seriesInfo) in
                let originalName = fileURLs.compactMap { url -> String? in
                    guard let data = try? Data(contentsOf: url),
                          let doc = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data),
                          let series = doc.series,
                          series.name.lowercased() == normalizedName
                    else { return nil }
                    return series.name
                }.first ?? normalizedName
                
                return DocumentSeries(
                    id: seriesInfo.id,
                    name: originalName,
                    documents: Array(seriesInfo.documents),
                    order: 0
                )
            }
            
            // Update selected series based on current document
            if let currentSeries = document.series {
                selectedSeries = currentSeries.name
            } else {
                selectedSeries = nil
            }
            
        } catch {
            print("Error accessing documents directory: \(error)")
        }
    }
    
    var tagsContent: some View {
        VStack(spacing: 8) {
            // Search field with suggestions
            VStack(alignment: .leading, spacing: 0) {
                TextField("Add Tag", text: $tagSearchText)
                    .font(.custom("Inter", size: 13))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .padding(.horizontal, 16)
                    .focused($isTagSearchFocused)
                    .onChange(of: tagSearchText) { oldValue, newValue in
                        // Keep suggestions visible while typing
                        if !tagSearchText.isEmpty {
                            isTagSearchFocused = true
                            loadDocuments()
                        }
                    }
                    .onSubmit {
                        if !tagSearchText.isEmpty {
                            var updatedTags = document.tags ?? []
                            let formattedTag = formatTag(tagSearchText)
                            if !updatedTags.contains(where: { $0.localizedCaseInsensitiveCompare(formattedTag) == .orderedSame }) {
                                updatedTags.append(formattedTag)
                                document.tags = updatedTags
                                document.save()
                            }
                            tagSearchText = ""
                        }
                    }
                
                // Tag suggestions popover
                if isTagSearchFocused && !tagSearchText.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        // Show matching tags
                        ForEach(matchingTags.prefix(5), id: \.self) { tag in
                            Button(action: {
                                var updatedTags = document.tags ?? []
                                if !updatedTags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
                                    updatedTags.append(tag)
                                    document.tags = updatedTags
                                    document.save()
                                }
                                tagSearchText = ""
                                isTagSearchFocused = false
                            }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .stroke(tagColor(for: tag), lineWidth: 1.5)
                                        .background(
                                            Circle()
                                                .fill(Color(colorScheme == .dark ? .black : .white).opacity(0.1))
                                        )
                                        .frame(width: 6, height: 6)
                                    Text(tag)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(theme.primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if tag != matchingTags.last {
                                Divider()
                            }
                        }
                        
                        // Show create option if no exact match exists
                        if shouldShowCreateNewTag {
                            if !matchingTags.isEmpty {
                                Divider()
                            }
                            Button(action: {
                                var updatedTags = document.tags ?? []
                                let formattedTag = formatTag(tagSearchText)
                                if !updatedTags.contains(where: { $0.localizedCaseInsensitiveCompare(formattedTag) == .orderedSame }) {
                                    updatedTags.append(formattedTag)
                                    document.tags = updatedTags
                                    document.save()
                                }
                                tagSearchText = ""
                                isTagSearchFocused = false
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#22c27d"))
                                    Text("Create \"\(formatTag(tagSearchText))\"")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color(hex: "#22c27d"))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(backgroundColorForTagsSection)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                }
            }
            
            // Show existing tags
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(document.tags ?? [], id: \.self) { tag in
                        HStack {
                            Circle()
                                .stroke(tagColor(for: tag), lineWidth: 1.5)
                                .background(
                                    Circle()
                                        .fill(Color(colorScheme == .dark ? .black : .white).opacity(0.1))
                                )
                                .frame(width: 6, height: 6)
                            Text(tag)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.primary)
                            Spacer()
                            Button(action: {
                                var updatedTags = document.tags ?? []
                                updatedTags.removeAll { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }
                                document.tags = updatedTags
                                document.save()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(.bottom, 16)
    }
    
    var variationsContent: some View {
        VStack(spacing: 8) {
            // Show Original section first
            if document.isVariation, let parentId = document.parentVariationId, let originalDoc = loadDocument(id: parentId) {
                Text("Original")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                VariationItem(
                    title: originalDoc.title.isEmpty ? "Untitled" : originalDoc.title,
                    date: formatDate(originalDoc.modifiedAt),
                    isOriginal: true,
                    action: { 
                        document = originalDoc
                        // Post notification that document has loaded
                        NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                    },
                    onDelete: { deleteVariation(originalDoc) }
                )
                
                if !currentVariations.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            } else if !document.isVariation {
                // If this is the original document, show it at the top
                Text("Original")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                VariationItem(
                    title: document.title.isEmpty ? "Untitled" : document.title,
                    date: formatDate(document.modifiedAt),
                    isOriginal: true,
                    action: {
                        // Already viewing this document, no action needed
                    },
                    onDelete: { /* Cannot delete the original */ }
                )
                
                if !currentVariations.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
            
            // Show variations section if there are any
            if !currentVariations.isEmpty {
                HStack {
                    Text("Variations")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        showTranslationModal = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text("Translate")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#7662E9"))
                        .padding(.horizontal, 10) // Changed from 12 to 10
                        .padding(.vertical, 4)
                        .background(Color(hex: "#7662E9").opacity(0.1))
                        .cornerRadius(4)
                        .frame(minWidth: 90) // Keep the minimum width
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    
                    Button(action: {
                        createNewVariation()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                            Text("New")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#22c27d"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#22c27d").opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                
                ForEach(currentVariations, id: \.id) { variation in
                    // Skip the current document if it's the original to avoid duplication
                    if variation.id != document.id {
                        VariationItem(
                            title: variation.title.isEmpty ? "Untitled" : variation.title,
                            date: formatDate(variation.modifiedAt),
                            isOriginal: false,
                            action: { 
                                document = variation
                                // Post notification that document has loaded
                                NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                            },
                            onDelete: { deleteVariation(variation) }
                        )
                    }
                }
            } else {
                // Show the New button even if there are no variations yet
                HStack {
                    Text("Variations")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        showTranslationModal = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text("Translate")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#7662E9"))
                        .padding(.horizontal, 10) // Changed from 12 to 10
                        .padding(.vertical, 4)
                        .background(Color(hex: "#7662E9").opacity(0.1))
                        .cornerRadius(4)
                        .frame(minWidth: 90) // Keep the minimum width
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    
                    Button(action: {
                        createNewVariation()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                            Text("New")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "#22c27d"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#22c27d").opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                
                Text("No variations")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
        }
        .onAppear {
            refreshVariations()
        }
        .onChange(of: document.id) { _, _ in
            refreshVariations()
        }
        .sheet(isPresented: $showTranslationModal) {
            TranslationPreviewView(document: $document, isPresented: $showTranslationModal)
        }
    }
    
    private func refreshVariations() {
        // Only reload if we haven't loaded for this document yet
        if loadedForDocumentId != document.id {
            // Use DispatchQueue.main.async to defer state updates until after the current view update cycle
            DispatchQueue.main.async {
                self.currentVariations = self.loadVariations()
                self.loadedForDocumentId = self.document.id
            }
        }
    }
    
    private func deleteVariation(_ variationDoc: Letterspace_CanvasDocument) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        let trashDirectory = appDirectory.appendingPathComponent(".trash", isDirectory: true)
        let sourceURL = appDirectory.appendingPathComponent("\(variationDoc.id).canvas")
        let destinationURL = trashDirectory.appendingPathComponent("\(variationDoc.id).canvas")
        
        do {
            // Create trash directory if it doesn't exist
            try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // If destination file exists, remove it first
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Move the file to trash
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            
            // Set the modification date to track when it was moved to trash
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: destinationURL.path)
            
            // Remove from cache
            documentCache.removeValue(forKey: variationDoc.id)
            
            // If we're deleting the current document, switch to the parent
            if variationDoc.id == document.id, let parentId = document.parentVariationId,
               let parentDoc = loadDocument(id: parentId) {
                // Schedule state update for the next run loop to avoid modifying state during view update
                DispatchQueue.main.async {
                    self.document = parentDoc
                    // Post notification that document has loaded
                    NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
                }
            }
            
            // Directly update the currentVariations array by removing the deleted variation
            withAnimation {
                // Filter out the deleted variation from the current list
                currentVariations.removeAll { $0.id == variationDoc.id }
                
                // Also remove it from the parent document's variations list if it's a variation
                if let parentId = variationDoc.parentVariationId, 
                   var parentDoc = documentCache[parentId] ?? loadDocument(id: parentId) {
                    parentDoc.variations.removeAll { $0.documentId == variationDoc.id }
                    parentDoc.save()
                    
                    // Update the parent in cache
                    if documentCache[parentId] != nil {
                        documentCache[parentId] = parentDoc
                    }
                    
                    // If we're viewing the parent, update our document reference
                    if document.id == parentId {
                        // Schedule state update for the next run loop to avoid modifying state during view update
                        DispatchQueue.main.async {
                            self.document = parentDoc
                        }
                    }
                }
            }
            
            // Notify that documents have been updated
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        } catch {
            print("Error moving variation to trash: \(error)")
        }
    }
    
    // Format helper for dates
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    // Helper to get presentation text for the button
    private func getPresentationText() -> String {
        let now = Date()
        
        // Priority 1: Find the soonest upcoming scheduled presentation
        let upcomingSchedule = document.presentations
            .filter { $0.status == .scheduled && $0.datetime >= now }
            .sorted { $0.datetime < $1.datetime }
            .first
        
        if let nextSchedule = upcomingSchedule {
            return "Upcoming Date: \(formatDate(nextSchedule.datetime))"
        }
        
        // Priority 2: Find the most recent past presentation
        let lastPresented = document.presentations
            .filter { $0.status == .presented && $0.datetime < now }
            .sorted { $0.datetime > $1.datetime } // Note: Sort descending for most recent
            .first
            
        if let last = lastPresented {
            return "Most Recent: \(formatDate(last.datetime))"
        }
        
        // Fallback: Check the legacy datePresented field (if still relevant)
        // Consider removing if `presentations` array is the sole source of truth
        if let legacyDate = document.variations.first?.datePresented {
            if legacyDate < now { // Only show if it's actually in the past
                 return "Most Recent: \(formatDate(legacyDate))"
            } else {
                 // If legacyDate is future, it should be in presentations array
                 // Treat as unscheduled if somehow only legacy date exists and is future
            }
        }
        
        // Default text if neither scheduled nor presented found
        return "Schedule or Log Presentation"
    }
    
    private func loadDocument(id: String) -> Letterspace_CanvasDocument? {
        // Check cache first
        if let cachedDoc = documentCache[id] {
            return cachedDoc
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        let fileURL = appDirectory.appendingPathComponent("\(id).canvas")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedDoc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
            
            // Cache the document - defer to main thread to avoid state updates during view cycles
            DispatchQueue.main.async {
                self.documentCache[id] = loadedDoc
            }
            
            return loadedDoc
        } catch {
            print("Error loading document \(id): \(error)")
            return nil
        }
    }
    
    private func loadVariations() -> [Letterspace_CanvasDocument] {
        // If the document has variations metadata, use that instead of scanning the directory
        if !document.variations.isEmpty {
            return document.variations.compactMap { variation -> Letterspace_CanvasDocument? in
                // Skip if this is the current document to avoid duplication
                if variation.documentId == document.id {
                    return nil
                }
                return loadDocument(id: variation.documentId)
            }
        }
        
        // Fall back to directory scanning if needed
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            return fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                // Extract document ID from filename
                let filename = url.deletingPathExtension().lastPathComponent
                
                // Skip if this is the current document to avoid duplication
                if filename == document.id {
                    return nil
                }
                
                // Check cache first
                if let cachedDoc = documentCache[filename], cachedDoc.parentVariationId == document.id {
                    return cachedDoc
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Cache the document
                    documentCache[doc.id] = doc
                    
                    // Only return documents that are variations of the current document
                    if doc.parentVariationId == document.id {
                        return doc
                    }
                    return nil
                } catch {
                    print("Error loading document at \(url): \(error)")
                    return nil
                }
            }
        } catch {
            print("Error accessing documents directory: \(error)")
            return []
        }
    }
    
    var bookmarksContent: some View {
        // Log marker counts every time this view is computed
        let _ = print("📚 RightSidebar.bookmarksContent: Total markers = \(document.markers.count)")
        let bookmarkedMarkers = document.markers.filter { $0.type == "bookmark" }
        let _ = print("📚 RightSidebar.bookmarksContent: Filtered bookmarks = \(bookmarkedMarkers.count)")

        // --- DEBUGGING: Log details of filtered markers ---
        let _ = print("📚 RightSidebar.bookmarksContent: Filtered Marker Details: [")
        for marker in bookmarkedMarkers {
            let _ = print("  - ID: \(marker.id.uuidString), Title: \"\(marker.title)\", Type: \(marker.type), Pos: \(marker.position)")
        }
        let _ = print("]")
        // --- END DEBUGGING ---

        return VStack(alignment: .leading, spacing: 16) {
            // Filter markers to only include bookmarks
            // let bookmarkedMarkers = document.markers.filter { $0.type == "bookmark" } // Filtered above for logging

            if bookmarkedMarkers.isEmpty {
                Text("No bookmarks added yet")
                    .font(.custom("Inter-Regular", size: 13))
                    .foregroundColor(theme.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                // Add bookmark timeline visualization
                // BookmarkTimelineView(bookmarks: bookmarkedMarkers) { position in
                //     scrollToBookmark(position: position)
                // }
                // .padding(.horizontal, 16)
                // .padding(.bottom, 8)
                
                // // Removed divider between timeline and list
                // Divider()
                //     .padding(.horizontal, 16)
                //     .padding(.bottom, 8)
                
                // Iterate over the filtered bookmarks using indices
                // Restore Original ForEach logic
                ForEach(Array(bookmarkedMarkers.enumerated()), id: \.element.id) { index, bookmark in
                    let bookmark = bookmarkedMarkers[index]
                    if let originalIndex = document.markers.firstIndex(where: { $0.id == bookmark.id }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(markerColor(for: bookmark.type))
                                .frame(width: 6, height: 6)
                            
                            // Make this section clickable
                            Button(action: {
                                scrollToBookmark(position: bookmark.position)
                            }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    TextField("Bookmark Title", text: Binding(
                                        get: { 
                                            // Safe access to bookmark title
                                            guard document.markers.indices.contains(originalIndex) else { return "" } 
                                            return document.markers[originalIndex].title 
                                        },
                                        set: { newValue in
                                            // Update the original marker in the document
                                            // Check index validity before accessing
                                            if document.markers.indices.contains(originalIndex) {
                                                document.markers[originalIndex].title = newValue
                                                document.save()
                                            }
                                        }
                                    ))
                                    .font(.custom("Inter-Medium", size: 12))
                                    .foregroundColor(theme.primary)
                                    .textFieldStyle(.plain)
                                    
                                    // Show bookmark line number
                                    Text("Line \(bookmark.position)") // Changed to show Line number
                                        .font(.custom("Inter-Regular", size: 10))
                                        .foregroundColor(theme.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            // Button to remove the bookmark using the original index
                            Button(action: {
                                // Check index validity before removing
                                if document.markers.indices.contains(originalIndex) {
                                    document.markers.remove(at: originalIndex)
                                    document.save()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    // Add Bookmark Timeline View
    struct BookmarkTimelineView: View {
        let bookmarks: [DocumentMarker]
        let onBookmarkTap: (Int) -> Void
        @Environment(\.themeColors) var theme
        @State private var hoveredBookmarkId: UUID? = nil
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timeline")
                    .font(.custom("Inter-Medium", size: 12))
                    .foregroundColor(theme.secondary)
                    .padding(.bottom, 4)
                
                // Calculate relative positions for visualization
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Timeline line
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 2)
                        
                        // Bookmark dots
                        ForEach(bookmarks.sorted(by: { $0.position < $1.position })) { bookmark in
                            BookmarkDot(
                                bookmark: bookmark,
                                isHovered: hoveredBookmarkId == bookmark.id,
                                onTap: { onBookmarkTap(bookmark.position) }
                            )
                            .position(
                                x: calculateXPosition(for: bookmark, in: geo.size.width),
                                y: 0
                            )
                            .onHover { isHovered in
                                if isHovered {
                                    hoveredBookmarkId = bookmark.id
                                } else if hoveredBookmarkId == bookmark.id {
                                    hoveredBookmarkId = nil
                                }
                            }
                        }
                    }
                }
                .frame(height: 24)
            }
        }
        
        private func calculateXPosition(for bookmark: DocumentMarker, in width: CGFloat) -> CGFloat {
            let sortedPositions = bookmarks.map { $0.position }.sorted()
            guard let minPosition = sortedPositions.first,
                  let maxPosition = sortedPositions.last,
                  minPosition != maxPosition else {
                return width / 2 // Center if only one bookmark or all at same position
            }
            
            // Calculate relative position on timeline
            let range = maxPosition - minPosition
            let relativePosition = CGFloat(bookmark.position - minPosition) / CGFloat(range)
            
            // Add padding on both sides (10% of width)
            let padding = width * 0.1
            let availableWidth = width - (padding * 2)
            
            return padding + (relativePosition * availableWidth)
        }
    }
    
    struct BookmarkDot: View {
        let bookmark: DocumentMarker
        let isHovered: Bool
        let onTap: () -> Void
        @Environment(\.themeColors) var theme
        
        var body: some View {
            VStack(spacing: 2) {
                // Tooltip with title if hovered
                if isHovered {
                    Text(bookmark.title.isEmpty ? "Bookmark" : bookmark.title)
                        .font(.custom("Inter-Regular", size: 10))
                        .foregroundColor(theme.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.9))
                        )
                        .offset(y: -20)
                        .transition(.opacity)
                }
                
                // Bookmark dot
                Circle()
                    .fill(markerColor(for: bookmark.type))
                    .frame(width: isHovered ? 10 : 8, height: isHovered ? 10 : 8)
                    .animation(.spring(response: 0.2), value: isHovered)
                    .contentShape(Rectangle().size(CGSize(width: 20, height: 20)))
                    .onTapGesture {
                        onTap()
                    }
            }
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        
        private func markerColor(for type: String) -> Color {
            switch type {
            case "highlight": return Color(hex: "#22c27d")
            case "comment": return Color(hex: "#FF6B6B")
            case "bookmark": return Color(hex: "#4ECDC4")
            default: return Color(hex: "#96CEB4")
            }
        }
    }
    
    private func markerColor(for type: String) -> Color {
        switch type {
        case "highlight": return Color(hex: "#22c27d")
        case "comment": return Color(hex: "#FF6B6B")
        case "bookmark": return Color(hex: "#4ECDC4")
        default: return Color(hex: "#96CEB4")
        }
    }
    
    var linksContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Link inputs
            VStack(alignment: .leading, spacing: 8) {
                TextField("Link Title", text: $newLinkTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .onSubmit {
                        // If URL is empty, move focus to URL field
                        if !newLinkTitle.isEmpty && newLinkURL.isEmpty {
                            // Focus will move to the URL field automatically
                        } 
                        // If both fields are filled, add the link
                        else if !newLinkTitle.isEmpty && !newLinkURL.isEmpty {
                            addLink()
                        }
                    }
                
                TextField("Link URL", text: $newLinkURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .onSubmit {
                        // Call the same addLink function when Enter is pressed
                        if !newLinkTitle.isEmpty && !newLinkURL.isEmpty {
                            addLink()
                        }
                    }
                
                Button(action: addLink) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Link")
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(newLinkTitle.isEmpty || newLinkURL.isEmpty)
                .opacity(newLinkTitle.isEmpty || newLinkURL.isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Links list
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    if document.links.isEmpty {
                        Text("No links attached yet")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(document.links) { link in
                            LinkItemView(link: link) {
                                removeLink(link)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func addLink() {
        guard !newLinkTitle.isEmpty, !newLinkURL.isEmpty else { return }
        
        var updatedDoc = document
        let newLink = DocumentLink(
            id: UUID().uuidString,
            title: newLinkTitle,
            url: newLinkURL,
            createdAt: Date()
        )
        updatedDoc.links.append(newLink)
        document = updatedDoc
        document.save()
        
        // Clear input fields
        newLinkTitle = ""
        newLinkURL = ""
    }
    
    private func removeLink(_ link: DocumentLink) {
        var updatedDoc = document
        updatedDoc.links.removeAll { $0.id == link.id }
        document = updatedDoc
        document.save()
    }
    
    private struct LinkItemView: View {
        let link: DocumentLink
        let onDelete: () -> Void
        @Environment(\.themeColors) var theme
        @Environment(\.colorScheme) var colorScheme
        @State private var isHovering = false
        
        var body: some View {
            Button(action: {
                if let url = URL(string: link.url) {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #elseif os(iOS)
                    UIApplication.shared.open(url)
                    #endif
                }
            }) {
                HStack(spacing: 8) {
                    // Link icon based on URL type
                    Image(systemName: getLinkIcon(for: link.url))
                        .font(.system(size: 14))
                        .foregroundStyle(theme.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.title)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.primary)
                            .lineLimit(1)
                        
                        Text(link.url)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if isHovering {
                        HStack(spacing: 8) {
                            Button(action: {
                                if let url = URL(string: link.url) {
                                    #if os(macOS)
                                    NSWorkspace.shared.open(url)
                                    #elseif os(iOS)
                                    UIApplication.shared.open(url)
                                    #endif
                                }
                            }) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Open Link")
                            
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete Link")
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? 
                            (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97)) : 
                            .clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }
        }
        
        private func getLinkIcon(for url: String) -> String {
            if url.contains("youtube.com") || url.contains("youtu.be") {
                return "play.square"
            } else if url.contains("drive.google.com") {
                return "doc.fill"
            } else if url.contains("dropbox.com") {
                return "folder.fill"
            } else {
                return "link"
            }
        }
    }
    
    var searchContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Search documents...", text: .constant(""))
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 13))
                .padding(8)
                .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                .cornerRadius(6)
            
            // Search results would go here
            Text("No results found")
                .font(.system(size: 13))
                .foregroundColor(theme.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        }
    }
    
    var allDocumentsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Document list would go here
            Text("No documents found")
                .font(.system(size: 13))
                .foregroundColor(theme.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 48)
            
            // Wrap mainContent in a ScrollView with animation
            ScrollView {
                mainContent
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: sidebarMode)
        }
        // --- Add Notification Listener ---
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentListDidUpdate"))) { _ in
            print("📬 RightSidebar received DocumentListDidUpdate notification. Triggering refresh.")
            refreshTrigger = UUID() // Change state to force view update
        }
        // --- End Notification Listener ---
        .frame(width: 260, alignment: .leading)
        .offset(x: viewMode == .minimal ? 260 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewMode)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, -20)
                .padding(.vertical, -20)
                .onTapGesture {
                    #if os(macOS)
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    #elseif os(iOS)
                    // On iOS, dismiss the keyboard by ending editing
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
        )
        .onAppear {
            // Initialize selectedSeries only if document has one
            if let documentSeries = document.series {
                selectedSeries = documentSeries.name
            } else {
                selectedSeries = nil  // Explicitly clear selected series if document has none
            }
            
            // Load all series from documents
            loadAllSeries()
            
            // Reset fields
            resetFields()
            
            loadDocuments()
        }
        .onChange(of: document.id) { oldValue, newValue in
            // Reset fields when document changes
            resetFields()
            
            // Update selected series based on new document
            if let documentSeries = document.series {
                selectedSeries = documentSeries.name
            } else {
                selectedSeries = nil  // Explicitly clear selected series if document has none
            }
            
            // Reload series when document changes
            loadAllSeries()
        }
    }
    
    private func resetFields() {
        // Initialize other fields if needed
        if let firstVariation = document.variations.first {
            if let datePresented = firstVariation.datePresented {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy h:mm a"
                self.datePresented = formatter.string(from: datePresented)
            } else {
                self.datePresented = ""
            }
            self.location = firstVariation.location ?? ""
        } else {
            self.datePresented = ""
            self.location = ""
        }
        
        // Initialize tags
        if let documentTags = document.tags {
            self.tags = Set(documentTags)
        } else {
            self.tags = []
        }
    }
    
    private func loadDocuments() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            documents = fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                do {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                } catch {
                    print("Error loading document at \(url): \(error)")
                    return nil
                }
            }
        } catch {
            print("Error accessing documents directory: \(error)")
        }
    }

    private func cleanupUnusedTags() {
        // Get all currently used tags
        var activeTags = Set<String>()
        for document in documents {
            if let documentTags = document.tags {
                activeTags.formUnion(documentTags)
            }
        }
        
        // Remove color preferences for unused tags
        let unusedTags = Set(colorManager.colorPreferences.keys).subtracting(activeTags)
        for tag in unusedTags {
            colorManager.colorPreferences.removeValue(forKey: tag)
        }
    }
    
    // Helper function to generate a unique variation title with proper numbering
    private func generateVariationTitle(baseTitle: String) -> String {
        // Get all existing variations
        let existingVariations = loadVariations()
        
        // Extract all variation titles
        let existingTitles = existingVariations.map { $0.title }
        
        // Start with (2) and increment if needed
        var counter = 2
        var newTitle = "\(baseTitle) (\(counter))"
        
        // Keep incrementing until we find an unused number
        while existingTitles.contains(newTitle) {
            counter += 1
            newTitle = "\(baseTitle) (\(counter))"
        }
        
        return newTitle
    }
    
    // Helper function to find the next available variation number
    private func getNextVariationNumber(for baseTitle: String) -> Int {
        // Get all existing variations
        let variations = loadVariations()
        
        // Extract numbers from existing variation titles with the same base name
        var usedNumbers = Set<Int>()
        let pattern = "^(.*?)\\s*\\((\\d+)\\)$"
        
        for variation in variations {
            if let range = variation.title.range(of: pattern, options: .regularExpression) {
                let titleMatch = variation.title[range]
                if let numberRange = titleMatch.range(of: "\\((\\d+)\\)", options: .regularExpression) {
                    let numberString = titleMatch[numberRange]
                    if let number = Int(numberString.dropFirst().dropLast()) {
                        usedNumbers.insert(number)
                    }
                }
            }
        }
        
        // Find the next available number starting from 2
        var nextNumber = 2
        while usedNumbers.contains(nextNumber) {
            nextNumber += 1
        }
        
        return nextNumber
    }
    
    // Helper function to create a new variation with proper title
    private func createNewVariation() {
        // Get the next available variation number
        let nextNumber = getNextVariationNumber(for: document.title)
        let newTitle = "\(document.title) (\(nextNumber))"
        
        // Create a new variation record for the parent document
        let newVariation = DocumentVariation(
            id: UUID(),
            name: "Original",
            documentId: UUID().uuidString,  // Generate the ID first so we can use it in both places
            parentDocumentId: document.id,
            createdAt: Date(),
            datePresented: document.variations.first?.datePresented,
            location: document.variations.first?.location
        )
        
        // Create a new document as a variation, copying all properties from the original
        let newDoc = Letterspace_CanvasDocument(
            title: newTitle,
            subtitle: document.subtitle,
            elements: document.elements,  // Copy all elements including content
            id: newVariation.documentId,  // Use the same ID we generated above
            markers: document.markers,
            series: document.series,
            variations: [newVariation],
            isVariation: true,
            parentVariationId: document.id,
            tags: document.tags,
            isHeaderExpanded: document.isHeaderExpanded,
            isSubtitleVisible: document.isSubtitleVisible,
            links: document.links
        )
        
        // Save the new document
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // First, update the parent document's variations list
            var updatedParentDoc = document
            updatedParentDoc.variations.append(newVariation)
            
            // Save the updated parent document
            let parentData = try JSONEncoder().encode(updatedParentDoc)
            let parentFileURL = appDirectory.appendingPathComponent("\(updatedParentDoc.id).canvas")
            try parentData.write(to: parentFileURL)
            
            // Then save the new variation document
            let newDocData = try JSONEncoder().encode(newDoc)
            let newDocFileURL = appDirectory.appendingPathComponent("\(newDoc.id).canvas")
            try newDocData.write(to: newDocFileURL)
            
            // Switch to the new document
            document = newDoc
            
            // Post notification that document has loaded
            NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
        } catch {
            print("Error creating variation: \(error)")
        }
    }
    
    // Add a function to ensure consistent text editor styling
    private func applyConsistentTextEditorStyling() {
        #if os(macOS)
        // Allow layout to update first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Find all text views in the view hierarchy and ensure they have consistent styling
            if let hostingWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "documentWindow" }) {
                // Define the recursive function properly
                func findTextViews(in views: [NSView]) -> [NSTextView] {
                    var textViews: [NSTextView] = []
                    for view in views {
                        if let textView = view as? NSTextView {
                            textViews.append(textView)
                        }
                        textViews.append(contentsOf: findTextViews(in: view.subviews))
                    }
                    return textViews
                }
                
                // Process text views
                for textView in findTextViews(in: hostingWindow.contentView?.subviews ?? []) {
                    // Apply consistent settings
                    textView.textContainerInset = NSSize(width: 17, height: textView.textContainerInset.height)
                    
                    // Clear any custom formatting
                    let style = NSMutableParagraphStyle()
                    textView.defaultParagraphStyle = style
                    
                    // Apply consistent font
                    textView.font = NSFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
                    
                    // Apply simpler layout manager settings
                    if let layoutManager = textView.layoutManager {
                        layoutManager.showsInvisibleCharacters = false
                        layoutManager.showsControlCharacters = false
                    }
                    
                    // Update text container settings
                    if let container = textView.textContainer {
                        container.widthTracksTextView = true
                    }
                }
            }
        }
        #endif
        // On iOS, this function does nothing since it's AppKit-specific
    }
    
    // Function to scroll to a bookmark position
    private func scrollToBookmark(position: Int) {
        // We need to find the text view and scroll to the position
        // First, post a notification that other views can observe
        print("📚 Attempting to scroll to bookmark at line: \(position)")
        
        // Look for the bookmark in the document markers to get additional metadata
        if let bookmark = document.markers.first(where: { $0.position == position && $0.type == "bookmark" }) {
            // Create a notification with enhanced position info
            var userInfo: [String: Any] = ["lineNumber": position]
            
            // Add character position metadata if available
            if let metadata = bookmark.metadata {
                if let charPosition = metadata["charPosition"], 
                   let charLength = metadata["charLength"] {
                    userInfo["charPosition"] = Int(charPosition)
                    userInfo["charLength"] = Int(charLength)
                    print("📚 Found character position metadata: \(charPosition), length: \(charLength)")
                }
            }
            
            // Post notification with all available data
            NotificationCenter.default.post(
                name: NSNotification.Name("ScrollToBookmark"), 
                object: nil, 
                userInfo: userInfo
            )
        } else {
            // Fallback to just using line number if metadata isn't available
            let userInfo: [String: Any] = ["lineNumber": position]
            NotificationCenter.default.post(
                name: NSNotification.Name("ScrollToBookmark"), 
                object: nil, 
                userInfo: userInfo
            )
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(x: bounds.minX + result.positions[index].x,
                              y: bounds.minY + result.positions[index].y)
            subview.place(at: point, proposal: .init(result.sizes[index]))
        }
    }
    
    private struct FlowResult {
        var positions: [CGPoint]
        var sizes: [CGSize]
        var size: CGSize
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var sizes: [CGSize] = []
            
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            var rowMaxY: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && !positions.isEmpty {
                    x = 0
                    y = rowMaxY + spacing
                }
                
                positions.append(CGPoint(x: x, y: y))
                sizes.append(size)
                
                rowHeight = max(rowHeight, size.height)
                rowMaxY = y + rowHeight
                x += size.width + spacing
            }
            
            self.positions = positions
            self.sizes = sizes
            self.size = CGSize(width: maxWidth, height: rowMaxY)
        }
    }
}

// Add this helper view for consistent section headers
struct SectionHeader: View {
    let title: String
    let isExpanded: Bool
    let showChevron: Bool
    let icon: String?
    @Environment(\.themeColors) var theme
    @State private var isHovered = false
    
    init(title: String, isExpanded: Bool, showChevron: Bool = true, icon: String? = nil) {
        self.title = title
        self.isExpanded = isExpanded
        self.showChevron = showChevron
        self.icon = icon
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.primary)
            }
            Text(title)
                .font(.custom("Inter-Bold", size: 13))
                .foregroundColor(theme.primary)
            Spacer()
            if showChevron {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.primary)
                    .padding(.trailing, 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? theme.accent.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .padding(.horizontal, 8)
    }
}

// Add before RightSidebar struct
struct TagView: View {
    let text: String
    let onRemove: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var colorManager = TagColorManager.shared
    
    private func tagColor(for tag: String) -> Color {
        return colorManager.color(for: tag)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(tagColor(for: text))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundColor(tagColor(for: text))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .stroke(tagColor(for: text), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(colorScheme == .dark ? .black : .white).opacity(0.1))
                )
        )
    }
}

struct MarkerRow: View {
    let marker: Marker
    @Environment(\.themeColors) var theme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            // Navigate to marker
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(markerColor(for: marker.type))
                        .frame(width: 8, height: 8)
                
                Text(marker.title)
                    .font(.system(size: 13))
                    .foregroundColor(theme.primary)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(theme.accent)
                    .font(.system(size: 16))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? theme.accent.opacity(0.1) : theme.background)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private func markerColor(for type: String) -> Color {
        switch type {
        case "highlight": return Color(hex: "#22c27d")
        case "comment": return Color(hex: "#FF6B6B")
        case "bookmark": return Color(hex: "#4ECDC4")
        default: return Color(hex: "#96CEB4")
        }
    }
}

// Add this struct for the block buttons
struct BlockTypeButton: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    let action: () -> Void
    
    @Environment(\.themeColors) var theme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.custom("Inter", size: 13))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .foregroundColor(isSelected ? theme.accent : (isHovered ? theme.primary : theme.secondary))
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? theme.accent : (isHovered ? theme.secondary.opacity(0.3) : Color.clear), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? theme.accent.opacity(0.1) : (isHovered ? theme.surface : Color.clear))
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// Add this struct before RightSidebar
struct GreenToggleStyle: ToggleStyle {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    private var inactiveColor: Color {
        #if os(macOS)
        return Color(NSColor.tertiaryLabelColor)
        #elseif os(iOS)
        return Color(UIColor.tertiaryLabel)
        #endif
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Rectangle()
                .foregroundColor(configuration.isOn ? Color(hex: "#22c27d") : inactiveColor)
                .frame(width: 40, height: 24)
                .overlay(
                    Circle()
                        .foregroundColor(.white)
                        .padding(2)
                        .offset(x: configuration.isOn ? 8 : -8)
                )
            .clipShape(Capsule())
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}

// Add this new button style definition near other helper types
struct SeriesItemButtonStyle: ButtonStyle {
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? 
                          Color.white.opacity(isHovering ? 0.1 : 0) : 
                          Color.black.opacity(isHovering ? 0.05 : 0))
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

// Add these new view components before the seriesContent definition
private struct SeriesListItem: View {
    let item: (title: String, date: String, isActive: Bool)
    let selectedSeries: String?
    let onOpen: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top) {
                // Document indicator - green for active, black/white for others
                Circle()
                    .fill(item.isActive ? Color(hex: "#22c27d") : theme.primary)
                    .frame(width: 6, height: 6)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Inter-Medium", size: 12))
                        .foregroundColor(theme.primary)
                        .lineLimit(1)
                    
                    if !item.date.isEmpty {
                        Text(item.date)
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(theme.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? 
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97)) : 
                        Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct SeriesSearchView: View {
    @Binding var seriesSearchText: String
    let recentSeries: [String]
    let shouldShowCreateNew: Bool
    let onAttach: (String) -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool
    @State private var isHovered: String? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Search or create new series", text: $seriesSearchText)
                .font(.custom("Inter", size: 13))
                .textFieldStyle(.plain)
                .padding(8)
                .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                .cornerRadius(6)
                .padding(.horizontal, 16)
            
            if !recentSeries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Series")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .padding(.horizontal, 16)
                    
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(recentSeries.filter { 
                                seriesSearchText.isEmpty || $0.localizedCaseInsensitiveContains(seriesSearchText)
                            }, id: \.self) { series in
                                Button(action: { onAttach(series) }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.secondary)
                                            .frame(width: 16)
                                        Text(series)
                                            .font(.system(size: 13))
                                            .foregroundColor(theme.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isHovered == series ? 
                                                (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97)) : 
                                                Color.clear)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    isHovered = hovering ? series : nil
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            if shouldShowCreateNew {
                Button(action: { onAttach(seriesSearchText) }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#22c27d"))
                        Text("Create \"\(seriesSearchText)\"")
                            .font(.custom("Inter", size: 13))
                            .foregroundStyle(Color(hex: "#22c27d"))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "#22c27d").opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
}

private struct VariationItem: View {
    let title: String
    let date: String
    let isOriginal: Bool
    let action: () -> Void
    let onDelete: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @State private var showMenu = false
    @State private var isOpenHovered = false
    @State private var isDeleteHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isOriginal ? Color(hex: "#22c27d") : theme.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primary)
                    Text(date)
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondary)
                }
                Spacer()
                
                // Context menu button that appears on hover
                if isHovered || showMenu {
                    Button(action: { showMenu = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                        VStack(spacing: 0) {
                            Button(action: {
                                action()
                                showMenu = false
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 12))
                                    Text("Open")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(theme.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93))
                                    .opacity(isOpenHovered ? 1 : 0)
                            )
                            .onHover { isOpenHovered = $0 }
                            
                            Divider()
                            
                            Button(action: {
                                onDelete()
                                showMenu = false
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                    Text("Delete")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93))
                                    .opacity(isDeleteHovered ? 1 : 0)
                            )
                            .onHover { isDeleteHovered = $0 }
                        }
                        .frame(width: 120)
                        .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : .white)
                        .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((isHovered || showMenu) ? 
                        (colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93)) : 
                        Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct NavigationButton: View {
    var icon: String? = nil
    var label: String? = nil
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.secondary)
                }
                
                if let label = label {
                    Text(label)
                        .font(.custom("Inter", size: 11))
                        .foregroundStyle(theme.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? 
                          (colorScheme == .dark ? Color(.sRGB, white: 0.25) : Color(.sRGB, white: 0.9)) : 
                          Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// Add this new component after the EditableField struct
struct LocationSuggestionButton: View {
    let location: String
    var isAdd: Bool = false
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isAdd {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#22c27d"))
                    Text("Add \"\(location)\"")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#22c27d"))
                } else {
                    Circle()
                        .fill(theme.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(location)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Rectangle()
                    .fill(isHovered ? theme.accent.opacity(0.1) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// Add this component before RightSidebar struct
struct LocationSuggestionsPopover: View {
    let recentLocations: [String]
    @Binding var text: String
    @Binding var showSuggestions: Bool
    // Change parameter to expect a regular binding that we'll create from FocusState
    @Binding var isTextFieldFocused: Bool
    var onSelect: ((String) -> Void)?
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var hoveredLocation: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Matching Locations")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)
            
            Divider()
                .padding(.horizontal, 8)
            
            // Location suggestions
            if recentLocations.isEmpty && !text.isEmpty {
                // Show "Add location" if no matches but text exists
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        showSuggestions = false
                        isTextFieldFocused = false
                        onSelect?(text)
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                        Text("Add \"\(text)\"")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(hoveredLocation == "add" ?
                        (colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.05)) :
                        Color.clear)
                }
                .buttonStyle(.plain)
                .onHover(perform: { hovering in
                    hoveredLocation = hovering ? "add" : nil
                })
            } else if recentLocations.isEmpty {
                Text("No recent locations")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentLocations.filter { text.isEmpty || $0.localizedCaseInsensitiveContains(text) }, id: \.self) { loc in
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            text = loc
                            showSuggestions = false
                            isTextFieldFocused = false
                            onSelect?(loc)
                        }
                    }) {
                        HStack {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(theme.secondary)
                            Text(loc)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(hoveredLocation == loc ?
                            (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) :
                            Color.clear)
                    }
                    .buttonStyle(.plain)
                    .onHover(perform: { hovering in
                        hoveredLocation = hovering ? loc : nil
                    })
                    
                    if loc != recentLocations.filter({ text.isEmpty || $0.localizedCaseInsensitiveContains(text) }).last {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
                
                // Option to add new location if it doesn't exist in recent locations
                if !text.isEmpty && !recentLocations.contains(where: { $0.localizedCaseInsensitiveCompare(text) == .orderedSame }) {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            showSuggestions = false
                            isTextFieldFocused = false
                            onSelect?(text)
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                            Text("Add \"\(text)\"")
                                .font(.system(size: 13))
                                .foregroundStyle(.blue)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(hoveredLocation == "add" ?
                            (colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.05)) :
                            Color.clear)
                    }
                    .buttonStyle(.plain)
                    .onHover(perform: { hovering in
                        hoveredLocation = hovering ? "add" : nil
                    })
                }
            }
        }
    }
}

// MARK: - Helper Components for Series Section

// Helper for Recent Series
// Helper for Selected Series
struct SelectedSeriesView: View {
    let seriesName: String
    let items: [(title: String, date: String, isActive: Bool)]
    @Binding var isDateSortAscending: Bool
    let onRemoveSeries: () -> Void
    let onOpenItem: ((title: String, date: String, isActive: Bool)) -> Void
    
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Series title and remove button
            HStack {
                Text(seriesName)
                    .font(.custom("Inter-Medium", size: 16))
                    .foregroundColor(theme.primary)
                Spacer()
                Button(action: onRemoveSeries) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Column headers
            HStack {
                Text("Name")
                    .font(.custom("Inter-Medium", size: 11))
                    .foregroundColor(theme.secondary)
                Spacer()
                Button(action: {
                    withAnimation {
                        isDateSortAscending.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Presented On")
                            .font(.custom("Inter-Medium", size: 11))
                            .foregroundColor(theme.secondary)
                        Image(systemName: isDateSortAscending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(theme.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Series items list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(items, id: \.title) { item in
                        SeriesListItem(
                            item: item,
                            selectedSeries: seriesName,
                            onOpen: { onOpenItem(item) }
                        )
                    }
                }
            }
        }
    }
}

struct RecentSeriesList: View {
    let recentSeries: [String]
    @Binding var hoveredSeriesItem: String?
    var onSelect: (String) -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Series")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            ForEach(recentSeries.prefix(3), id: \.self) { series in
                let isHovering = hoveredSeriesItem == series
                let backgroundColor = colorScheme == .dark ?
                    Color(.sRGB, white: 0.2, opacity: isHovering ? 1 : 0) :
                    Color(.sRGB, white: 0.95, opacity: isHovering ? 1 : 0)
                
                Button(action: { 
                    onSelect(series)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                        Text(series)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(backgroundColor)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredSeriesItem = hovering ? series : nil
                }
            }
        }
    }
}
struct SeriesDropdownView: View {
    let matchingSeries: [String]
    let shouldShowCreateNew: Bool
    let seriesSearchText: String
    let formatSeries: (String) -> String
    @Binding var hoveredSeriesItem: String?
    var onSelect: (String) -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Matching Series")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)
            
            Divider()
                .padding(.horizontal, 8)
            
            // Matching series suggestions
            ForEach(matchingSeries.prefix(5), id: \.self) { series in
                Button(action: {
                    onSelect(series)
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                        Text(series)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(hoveredSeriesItem == series ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) :
                        Color.clear)
                }
                .buttonStyle(.plain)
                .onHover(perform: { hovering in
                    hoveredSeriesItem = hovering ? series : nil
                })
                
                if series != matchingSeries.prefix(5).last {
                    Divider()
                        .padding(.leading, 12)
                }
            }
            
            // Option to create a new series if it doesn't exist
            if shouldShowCreateNew {
                Divider()
                    .padding(.horizontal, 8)
                
                Button(action: {
                    let formattedSeries = formatSeries(seriesSearchText)
                    onSelect(formattedSeries)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Create \"\(formatSeries(seriesSearchText))\"")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(hoveredSeriesItem == "create" ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) :
                        Color.clear)
                }
                .buttonStyle(.plain)
                .onHover(perform: { hovering in
                    hoveredSeriesItem = hovering ? "create" : nil
                })
            }
        }
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
        .cornerRadius(8)
        .frame(width: 250)
        .fixedSize(horizontal: false, vertical: true)
        // Add shadow to create visual separation instead of a border
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}