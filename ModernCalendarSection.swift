import SwiftUI

// The main calendar section with horizontal month slider and list view
struct CalendarSection: View {
    let documents: [Letterspace_CanvasDocument]
    let calendarDocuments: Set<String>
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedDate = Date()
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    @State private var availableYears: [Int] = (Calendar.current.component(.year, from: Date())-5...Calendar.current.component(.year, from: Date())+5).map { $0 }
    
    init(documents: [Letterspace_CanvasDocument], calendarDocuments: Set<String>) {
        self.documents = documents
        self.calendarDocuments = calendarDocuments
        let calendar = Calendar.current
        let date = Date()
        _selectedYear = State(initialValue: calendar.component(.year, from: date))
        _selectedMonth = State(initialValue: calendar.component(.month, from: date))
    }
    
    private var scheduledDocuments: [ScheduledDocument] {
        let calendar = Calendar.current
        
        let scheduledFromSchedules = documents.filter { calendarDocuments.contains($0.id) }
            .compactMap { doc -> [ScheduledDocument]? in
                doc.schedules.filter { schedule in
                    schedule.isScheduledFor(date: selectedDate)
                }
            }
            .flatMap { $0 }
            .sorted { $0.startDate < $1.startDate }
        
        // Also check for documents with datePresented matching this date
        let presentedDocuments = documents
            .flatMap { doc -> [ScheduledDocument] in
                doc.variations.compactMap { variation -> ScheduledDocument? in
                    if let presentedDate = variation.datePresented,
                       calendar.isDate(selectedDate, equalTo: presentedDate, toGranularity: .day) {
                        return ScheduledDocument(
                            documentId: doc.id,
                            serviceType: .special,
                            startDate: presentedDate,
                            notes: "Presentation" + (variation.location != nil ? " at \(variation.location!)" : "")
                        )
                    }
                    return nil
                }
            }
        
        return (scheduledFromSchedules + presentedDocuments)
            .sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with title and year picker
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.primary)
                Text("Sermon Schedule")
                    .font(.custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                // Year picker button
                Menu {
                    ForEach(availableYears, id: \.self) { year in
                        Button(action: {
                            selectedYear = year
                        }) {
                            Text("\(year)")
                                .foregroundStyle(year == selectedYear ? theme.accent : theme.primary)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(selectedYear)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.primary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 12)
            
            // Month slider
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...12, id: \.self) { month in
                        MonthButton(
                            month: month,
                            isSelected: month == selectedMonth,
                            action: { selectedMonth = month }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            
            Divider()
                .padding(.horizontal, 12)
            
            // Active date/documents list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(daysWithSchedules, id: \.date) { dayInfo in
                        DateSection(
                            dayInfo: dayInfo,
                            documents: documents,
                            isSelected: Calendar.current.isDate(dayInfo.date, equalTo: selectedDate, toGranularity: .day),
                            onSelect: { date in
                                selectedDate = date
                            }
                        )
                    }
                    
                    if daysWithSchedules.isEmpty {
                        Text("No scheduled sermons this month")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.17) : .black.opacity(0.07),
            radius: 8,
            x: 0,
            y: 1
        )
    }
    
    // Get all days with schedules in the current month and year
    private var daysWithSchedules: [DayInfo] {
        // Get all days in month
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: makeDate(day: 1))?.count ?? 30
        
        let days = (1...daysInMonth).compactMap { day -> DayInfo? in
            let date = makeDate(day: day)
            let schedules = getSchedulesForDate(date)
            if !schedules.isEmpty {
                return DayInfo(date: date, schedules: schedules)
            }
            return nil
        }
        return days.sorted(by: { $0.date < $1.date })
    }
    
    // Generate date from day, month, and year
    private func makeDate(day: Int) -> Date {
        return Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: day)) ?? Date()
    }
    
    // Get schedules for a specific date
    private func getSchedulesForDate(_ date: Date) -> [ScheduledDocument] {
        let calendar = Calendar.current
        
        let scheduledFromSchedules = documents.filter { calendarDocuments.contains($0.id) }
            .compactMap { doc -> [ScheduledDocument]? in
                doc.schedules.filter { schedule in
                    schedule.isScheduledFor(date: date)
                }
            }
            .flatMap { $0 }
        
        let presentedDocuments = documents
            .flatMap { doc -> [ScheduledDocument] in
                doc.variations.compactMap { variation -> ScheduledDocument? in
                    if let presentedDate = variation.datePresented,
                       calendar.isDate(date, equalTo: presentedDate, toGranularity: .day) {
                        return ScheduledDocument(
                            documentId: doc.id,
                            serviceType: .special,
                            startDate: presentedDate,
                            notes: "Presentation" + (variation.location != nil ? " at \(variation.location!)" : "")
                        )
                    }
                    return nil
                }
            }
        
        return (scheduledFromSchedules + presentedDocuments)
            .sorted { $0.startDate < $1.startDate }
    }
}

// Modern Month Button for the horizontal slider
private struct MonthButton: View {
    let month: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(Calendar.current.shortMonthSymbols[month - 1])
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? theme.accent : (isHovered ? theme.primary : theme.secondary))
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSelected ? 
                              (colorScheme == .dark ? theme.accent.opacity(0.2) : theme.accent.opacity(0.1)) : 
                              (isHovered ? (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(isSelected ? theme.accent : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// Date section for the list of scheduled dates
private struct DateSection: View {
    let dayInfo: DayInfo
    let documents: [Letterspace_CanvasDocument]
    let isSelected: Bool
    let onSelect: (Date) -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header with day and weekday
            Button(action: { onSelect(dayInfo.date) }) {
                HStack {
                    HStack(spacing: 4) {
                        Text("\(Calendar.current.component(.day, from: dayInfo.date))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.primary)
                        
                        Text(formatMonth(dayInfo.date))
                            .font(.system(size: 13))
                            .foregroundStyle(theme.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatWeekday(dayInfo.date))
                        .font(.system(size: 13))
                        .foregroundStyle(theme.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? 
                    (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) : 
                    Color.clear
                )
            }
            .buttonStyle(.plain)
            
            // Document items
            VStack(alignment: .leading, spacing: 2) {
                ForEach(dayInfo.schedules) { schedule in
                    if let doc = documents.first(where: { $0.id == schedule.documentId }) {
                        DocumentItem(document: doc, schedule: schedule)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(colorScheme == .dark ? Color(.sRGB, white: 0.25) : Color(.sRGB, white: 0.9), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// Document item in the list
private struct DocumentItem: View {
    let document: Letterspace_CanvasDocument
    let schedule: ScheduledDocument
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            // Open the document
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenDocument"),
                object: nil,
                userInfo: ["documentId": document.id]
            )
        }) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accent)
                
                Text(document.title.isEmpty ? "Untitled" : document.title)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(isHovered ? theme.primary : theme.secondary)
                    .opacity(isHovered ? 1 : 0.7)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? 
                          (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97)) : 
                          Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
} 