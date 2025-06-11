import SwiftUI 
struct CalendarDayView: View {
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
                    // Change from medium to bold
                    .fontWeight(isSelected ? .bold : .regular)
            .foregroundStyle(isCurrentMonth ? theme.primary : theme.secondary.opacity(0.3))
                    .frame(width: 18, height: 18)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Filled background for days with scheduled items (now includes selected dates too)
                Circle()
                        .fill(hasScheduledItems ? theme.accent.opacity(0.2) : Color.clear)
                    
                    // Background for hovered days (not scheduled) - now using gray
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
            // Remove the dot overlay
            //.overlay(
            //    Circle()
            //        .fill(hasScheduledItems ? theme.accent : Color.clear)
            //        .frame(width: 2.5, height: 2.5)
            //        .offset(y: 3),
            //    alignment: .bottom
            //)
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
                    ForEach(scheduledDocuments) { schedule in
                        if let doc = documents.first(where: { $0.id == schedule.documentId }) {
                            Button(action: {
                        // Open the document
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenDocument"),
                            object: nil,
                            userInfo: ["documentId": doc.id]
                        )
                            }) {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(doc.title.isEmpty ? "Untitled" : doc.title)
                                        
                                        // Handle presentation dates and regular schedules differently
                                        if let notes = schedule.notes, notes.starts(with: "Presentation") {
                                            let locationPart = notes.contains(" at ") ? notes.components(separatedBy: " at ")[1] : ""
                                            if !locationPart.isEmpty {
                                                Text("at \(locationPart)")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(theme.secondary)
                                            }
                                        } else {
                                        Text(schedule.serviceType.rawValue)
                                            .font(.system(size: 11))
                                            .foregroundStyle(theme.secondary)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.primary) // Changed from serviceTypeColor to primary theme color
                                }
                            }
                        }
                    }
                }
            }
    }
    
    private func serviceTypeColor(_ type: ServiceType) -> Color {
        switch type {
        case .sundayMorning:
            return .blue
        case .sundayEvening:
            return .purple
        case .wednesdayNight:
            return .green
        case .special:
            return .orange
        }
    }
}
