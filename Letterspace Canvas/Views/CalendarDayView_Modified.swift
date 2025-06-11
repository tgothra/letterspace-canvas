import SwiftUI

// Modified CalendarDayView with black border for today's date
// Replace the existing CalendarDayView in HomeView.swift with this implementation

/*
private struct CalendarDayView: View {
    let day: Int
    let isCurrentMonth: Bool
    let isSelected: Bool
    let hasScheduledItems: Bool
    let hoveredDay: Int?
    let documents: [Letterspace_CanvasDocument]
    let calendarDocuments: Set<String>
    let date: Date
    let onSelect: (CGRect) -> Void
    let onHover: (Bool) -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Add computed property to check if this is today's date
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var scheduledDocuments: [ScheduledDocument] {
        let calendar = Calendar.current
        let scheduledFromSchedules = documents.filter { calendarDocuments.contains($0.id) }
            .compactMap { doc -> [ScheduledDocument]? in
                doc.schedules.filter { schedule in
                    schedule.isScheduledFor(date: date)
                }
            }
            .flatMap { $0 }
            .sorted { $0.startDate < $1.startDate }
        
        // Also check for documents with datePresented matching this date
        // Create virtual ScheduledDocument entries for presentations
        let presentedDocuments = documents.filter { calendarDocuments.contains($0.id) }
            .flatMap { doc -> [ScheduledDocument] in
                doc.variations.compactMap { variation -> ScheduledDocument? in
                    if let presentedDate = variation.datePresented,
                       calendar.isDate(date, equalTo: presentedDate, toGranularity: .day) {
                        // Create a virtual ScheduledDocument for this presentation
                        return ScheduledDocument(
                            documentId: doc.id,
                            serviceType: .special, // Default to special service type
                            startDate: presentedDate,
                            notes: "Presentation" + (variation.location != nil ? " at \(variation.location!)" : "")
                        )
                    }
                    return nil
                }
            }
        
        // Combine and sort both types of documents
        return (scheduledFromSchedules + presentedDocuments)
            .sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        GeometryReader { geometry in
            Button(action: {
                if isCurrentMonth {
                    onSelect(geometry.frame(in: .global))
                }
            }) {
                Text("\(day)")
                    .font(.custom("InterTight-Regular", size: 10))
                    .tracking(0.5)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isCurrentMonth ? theme.primary : theme.secondary.opacity(0.3))
                    .frame(width: 18, height: 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            // Filled background for days with scheduled items
                            Circle()
                                .fill(hasScheduledItems ? theme.accent.opacity(0.2) : Color.clear)
                            
                            // Background for hovered days (not scheduled)
                            Circle()
                                .fill(!hasScheduledItems && !isSelected && hoveredDay == day && isCurrentMonth ? 
                                     theme.secondary.opacity(0.1) : Color.clear)
                            
                            // Light gray filled circle for selected date (only if no scheduled items and not today)
                            Circle()
                                .fill(isSelected && !hasScheduledItems && !isToday ? theme.secondary.opacity(0.1) : Color.clear)
                            
                            // Black border for today's date instead of gray fill
                            Circle()
                                .strokeBorder(isToday ? Color.black : Color.clear, lineWidth: 1)
                        }
                    )
            }
            .buttonStyle(.plain)
            .position(x: geometry.size.width/2, y: geometry.size.height/2)
        }
        .frame(height: 20)
        .contentShape(Rectangle())
        .onHover(perform: onHover)
        .disabled(!isCurrentMonth)
        .contextMenu {
            if scheduledDocuments.isEmpty {
                Text("No scheduled sermons")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondary)
            } else {
                // Rest of the context menu implementation...
            }
        }
    }
}
*/ 