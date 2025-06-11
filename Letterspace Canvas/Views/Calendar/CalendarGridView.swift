import SwiftUI 
struct CalendarGridView: View {
    let days: [Day]
    let selectedDate: Date
    let hoveredDay: Int?
    let documents: [Letterspace_CanvasDocument]
    let calendarDocuments: Set<String>
    let onDaySelect: (Day, CGRect) -> Void
    let onDayHover: (Int?) -> Void
    let hasScheduledItems: (Date) -> Bool
    @Environment(\.themeColors) var theme
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(days, id: \.number) { day in
                if let number = day.number {
                    let date = makeDate(from: day)
                    CalendarDayView(
                        day: number,
                        isCurrentMonth: day.isCurrentMonth,
                        isSelected: Calendar.current.isDate(selectedDate, equalTo: date, toGranularity: .day),
                        hasScheduledItems: hasScheduledItems(date),
                        hoveredDay: hoveredDay,
                        documents: documents,
                        calendarDocuments: calendarDocuments,
                        date: date,
                        onSelect: { frame in
                            onDaySelect(day, frame)
                        },
                        onHover: { isHovering in
                            onDayHover(isHovering ? number : nil)
                        }
                    )
                } else {
                    Color.clear
                        .frame(height: 20)  // Updated from 24 to 20 to match CalendarDayView height
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func makeDate(from day: Day) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = day.year
        dateComponents.month = day.month
        dateComponents.day = day.number
        return Calendar.current.date(from: dateComponents) ?? Date()
    }
}
