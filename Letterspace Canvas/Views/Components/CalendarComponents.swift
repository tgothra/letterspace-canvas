import SwiftUI

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
    @State private var calendarState = CalendarState()
    
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
@Observable
class CalendarState {
    var selectedMonth: Int
    var selectedYear: Int
    var hoveredDay: Int? = nil
    
    // Cache the days for the current month/year
    var currentDays: [Day] = []
    
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
    let calendarState: CalendarState
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
