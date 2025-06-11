import SwiftUI 
struct CalendarContextMenu: View {
    let document: Letterspace_CanvasDocument
    @Binding var showScheduleSheet: Bool
    let onCalendar: (String) -> Void
    @State private var scheduledDate: Date = Date()
    @State private var selectedTime: String = {
        // Initialize with current time
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"  // Format: "1:30 PM"
        return formatter.string(from: Date())
    }()
    @State private var currentMonth: Date = Date()
    @State private var hoveredDay: Int? = nil
    // Time options kept for API compatibility with the time picker
    @State private var timeOptions: [String] = []
    @State private var showTimeOptions: Bool = false
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Constants for calendar sizing
    private let calendarRowHeight: CGFloat = 28 // Height of each calendar row
    private let calendarRowSpacing: CGFloat = 5 // Spacing between rows
    private let fixedCalendarHeight: CGFloat = 175 // Fixed height for calendar regardless of number of weeks
    
    private let calendar = Calendar.current
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private var weeks: [[Date?]] {
        // Get start of the month
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        // Convert to 0-indexed where Monday is 0 (instead of Sunday being 1)
        let firstWeekdayMonday = (firstWeekday + 5) % 7
        
        let numDays = range.count
        var days = [Date?](repeating: nil, count: firstWeekdayMonday)
        
        for day in 1...numDays {
            if let date = calendar.date(byAdding: .day, value: day-1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // Ensure we have complete weeks
        let remainingDays = (7 - (days.count % 7)) % 7
        days.append(contentsOf: [Date?](repeating: nil, count: remainingDays))
        
        // Split days into weeks
        var weeks = [[Date?]]()
        let numberOfWeeks = days.count / 7
        
        for week in 0..<numberOfWeeks {
            let startIndex = week * 7
            let endIndex = startIndex + 7
            weeks.append(Array(days[startIndex..<endIndex]))
        }
        
        // Always ensure we have 6 weeks for consistent height (most months span 5 weeks max, some span 6)
        while weeks.count < 6 {
            weeks.append([Date?](repeating: nil, count: 7))
        }
        
        return weeks
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay to block interactions
            if showScheduleSheet {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showScheduleSheet = false
                        showTimeOptions = false
                    }
                    .ignoresSafeArea()
            }
            
            // Calendar popup content
            VStack(spacing: 0) {
                Text("Schedule Document")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.primary)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                // Calendar section with icon and separator
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(Color.blue)
                    
                    Text("Date")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                        .frame(height: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 15) // Further increased for more breathing room
                
                // Month navigation
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                                currentMonth = newMonth
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(theme.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text(monthFormatter.string(from: currentMonth))
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 120) // Fixed width to prevent text shifting
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                                currentMonth = newMonth
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(theme.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                // Weekday headers
                HStack {
                    ForEach(["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                
                // Calendar grid with fixed height
                VStack(spacing: 0) {
                    // Fixed height container that holds the calendar grid
                    ZStack(alignment: .top) {
                        // Empty spacer to maintain fixed height
                        Color.clear.frame(height: fixedCalendarHeight)
                        
                        // Actual calendar grid with weeks
                        VStack(spacing: calendarRowSpacing) {
                            ForEach(weeks.indices, id: \.self) { weekIndex in
                                HStack(spacing: 0) {
                                    ForEach(0..<7) { dayIndex in
                                        let day = weeks[weekIndex][dayIndex]
                                        if let date = day {
                                            let dayNumber = calendar.component(.day, from: date)
                                            let isSelectedDay = calendar.isDate(date, inSameDayAs: scheduledDate)
                                            let isHovered = hoveredDay == dayNumber && isInCurrentMonth(date)
                                            
                                            Button(action: {
                                                scheduledDate = date
                                            }) {
                                                ZStack {
                                                    Circle()
                                                        .fill(isSelectedDay ? Color.blue : (isHovered ? Color.blue.opacity(0.1) : Color.clear))
                                                        .frame(width: 28, height: 28)
                                                    
                                                    Text("\(dayNumber)")
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(isSelectedDay ? .white : (isInCurrentMonth(date) ? theme.primary : theme.secondary.opacity(0.5)))
                                                }
                                                .frame(maxWidth: .infinity)
                                                .frame(height: calendarRowHeight)
                                            }
                                            .buttonStyle(.plain)
                                            .onHover { hovering in
                                                if hovering && isInCurrentMonth(date) {
                                                    hoveredDay = dayNumber
                                                } else if hoveredDay == dayNumber {
                                                    hoveredDay = nil
                                                }
                                            }
                                        } else {
                                            // Empty cell with fixed height
                                            Color.clear
                                                .frame(maxWidth: .infinity)
                                                .frame(height: calendarRowHeight)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22) // Further increased for more separation
                
                // Time section with icon and separator
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(Color.blue)
                    
                    Text("Time")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondary)
                    
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                        .frame(height: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16) // Further increased for more breathing room
                
                // Time picker
                TimePickerDropdown(
                    selectedTime: $selectedTime,
                    showTimeOptions: $showTimeOptions,
                    timeOptions: timeOptions,
                    theme: theme,
                    colorScheme: colorScheme
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 30) // Significantly increased for more separation from buttons
                
                // Bottom buttons - side by side
                HStack(spacing: 10) {
                    // Remove Scheduling Button
                    Button(action: {
                        var updatedDoc = document
                        
                        // Remove date from document variation
                        if var firstVariation = updatedDoc.variations.first {
                            firstVariation.datePresented = nil
                            firstVariation.serviceTime = nil
                            updatedDoc.variations[0] = firstVariation
                        }
                        
                        // Remove all schedules for this document
                        updatedDoc.schedules = updatedDoc.schedules.filter { $0.documentId != document.id }
                        
                        updatedDoc.save()
                        
                        // Post notification to update the document list
                        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                        
                        // Post notification to clear any highlights for this document
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DocumentUnscheduled"),
                            object: nil,
                            userInfo: [
                                "documentId": document.id,
                                "forceRefresh": true as Any
                            ]
                        )
                        
                        showScheduleSheet = false
                    }) {
                        Text("Remove Scheduling")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.secondary)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 10)
                            .background(colorScheme == .dark ? Color(.sRGB, white: 0.18) : Color(.sRGB, white: 0.94))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Schedule Button
                    Button(action: {
                        var updatedDoc = document
                        let scheduleDate = scheduledDate
                        
                        // Create or update a document variation with the scheduled date
                        if var firstVariation = updatedDoc.variations.first {
                            firstVariation.datePresented = scheduleDate
                            firstVariation.serviceTime = selectedTime
                            // Set location to "Scheduled" as a default location if none exists
                            if firstVariation.location == nil || firstVariation.location!.isEmpty {
                                firstVariation.location = "Scheduled"
                            }
                            updatedDoc.variations[0] = firstVariation
                        } else {
                            let variation = DocumentVariation(
                                id: UUID(),
                                name: "Original",
                                documentId: document.id,
                                parentDocumentId: document.id,
                                createdAt: Date(),
                                datePresented: scheduleDate,
                                location: "Scheduled", // Default location
                                serviceTime: selectedTime,
                                notes: nil
                            )
                            updatedDoc.variations = [variation]
                        }
                        
                        // Add a ScheduledDocument entry for better tracking
                        let newSchedule = ScheduledDocument(
                            documentId: document.id,
                            serviceType: .special,
                            startDate: scheduleDate,
                            recurrence: .once,
                            notes: "\(selectedTime)" // Just the time without any prefix
                        )
                        updatedDoc.addSchedule(newSchedule)
                        
                        // Make sure first variation has the location
                        if let firstIndex = updatedDoc.variations.firstIndex(where: { variation in
                            if let presentedDate = variation.datePresented {
                                return Calendar.current.isDate(presentedDate, equalTo: scheduleDate, toGranularity: .day)
                            }
                            return false
                        }) {
                            // Ensure the found variation has a location
                            if updatedDoc.variations[firstIndex].location == nil || updatedDoc.variations[firstIndex].location!.isEmpty {
                                updatedDoc.variations[firstIndex].location = "Scheduled"
                            }
                        }
                        
                        // Add location to document metadata
                        updatedDoc.setMetadata(key: "location", value: "Scheduled") // Default location
                        
                        updatedDoc.save()
                        
                        onCalendar(document.id)
                        
                        // Scroll the document scheduler to the month and date we just scheduled
                        let scheduledMonth = Calendar.current.component(.month, from: scheduleDate)
                        let scheduledYear = Calendar.current.component(.year, from: scheduleDate)
                        
                        // Post notification to update calendar views
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DocumentScheduledUpdate"),
                            object: nil,
                            userInfo: [
                                "date": scheduleDate,
                                "month": scheduledMonth,
                                "year": scheduledYear,
                                "documentId": document.id
                            ]
                        )
                        
                        // Post notification to update the document list
                        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                        showScheduleSheet = false
                    }) {
                        Text("Schedule")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.blue)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .frame(width: 340)
            .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            .onAppear {
                // Initialize to current month and date
                currentMonth = Date()
                scheduledDate = Date()
            }
        }
        .allowsHitTesting(true)
    }
    
    private func isInCurrentMonth(_ date: Date) -> Bool {
        return Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
}
