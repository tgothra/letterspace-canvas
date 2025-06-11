import Foundation

// Represents a scheduled service type (e.g., Sunday morning, Wednesday night)
enum ServiceType: String, Codable, CaseIterable {
    case sundayMorning = "Sunday Morning"
    case sundayEvening = "Sunday Evening"
    case wednesdayNight = "Wednesday Night"
    case special = "Special Service"
}

// Represents how often a document repeats
enum RecurrencePattern: Codable, Hashable {
    case once
    case weekly(daysOfWeek: Set<Int>) // 1 = Sunday, 2 = Monday, etc.
    case monthly(dayOfMonth: Int)
    case yearly(month: Int, day: Int)
    
    var isRecurring: Bool {
        switch self {
        case .once:
            return false
        default:
            return true
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .once:
            hasher.combine(0)
        case .weekly(let daysOfWeek):
            hasher.combine(1)
            hasher.combine(daysOfWeek)
        case .monthly(let dayOfMonth):
            hasher.combine(2)
            hasher.combine(dayOfMonth)
        case .yearly(let month, let day):
            hasher.combine(3)
            hasher.combine(month)
            hasher.combine(day)
        }
    }
    
    static func == (lhs: RecurrencePattern, rhs: RecurrencePattern) -> Bool {
        switch (lhs, rhs) {
        case (.once, .once):
            return true
        case (.weekly(let lhsDays), .weekly(let rhsDays)):
            return lhsDays == rhsDays
        case (.monthly(let lhsDay), .monthly(let rhsDay)):
            return lhsDay == rhsDay
        case (.yearly(let lhsMonth, let lhsDay), .yearly(let rhsMonth, let rhsDay)):
            return lhsMonth == rhsMonth && lhsDay == rhsDay
        default:
            return false
        }
    }
}

// Represents a scheduled document
struct ScheduledDocument: Identifiable, Codable {
    let id: UUID
    let documentId: String
    let serviceType: ServiceType
    let startDate: Date
    let endDate: Date?
    let recurrence: RecurrencePattern
    var notes: String?
    
    init(
        documentId: String,
        serviceType: ServiceType,
        startDate: Date,
        endDate: Date? = nil,
        recurrence: RecurrencePattern = .once,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.documentId = documentId
        self.serviceType = serviceType
        self.startDate = startDate
        self.endDate = endDate
        self.recurrence = recurrence
        self.notes = notes
    }
    
    // Helper function to determine if this schedule is active for a given date
    func isScheduledFor(date: Date) -> Bool {
        let calendar = Calendar.current
        
        // Start by comparing just the date components without time
        let startOfDate = calendar.startOfDay(for: date)
        let startOfStartDate = calendar.startOfDay(for: startDate)
        
        // Check if date is within the schedule's date range
        if startOfDate < startOfStartDate || (endDate != nil && startOfDate > calendar.startOfDay(for: endDate!)) {
            return false
        }
        
        switch recurrence {
        case .once:
            // Compare only the date component, ignoring time
            return calendar.isDate(startOfDate, inSameDayAs: startOfStartDate)
            
        case .weekly(let daysOfWeek):
            let weekday = calendar.component(.weekday, from: date)
            return daysOfWeek.contains(weekday)
            
        case .monthly(let dayOfMonth):
            let day = calendar.component(.day, from: date)
            return day == dayOfMonth
            
        case .yearly(let month, let day):
            let currentMonth = calendar.component(.month, from: date)
            let currentDay = calendar.component(.day, from: date)
            return currentMonth == month && currentDay == day
        }
    }
}

// Extension to Letterspace_CanvasDocument to handle scheduling
extension Letterspace_CanvasDocument {
    // Add these properties to your document model
    var schedules: [ScheduledDocument] {
        get {
            if let data = UserDefaults.standard.data(forKey: "document_schedules_\(id)"),
               let schedules = try? JSONDecoder().decode([ScheduledDocument].self, from: data) {
                return schedules
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "document_schedules_\(id)")
            }
        }
    }
    
    // Helper function to add a schedule
    mutating func addSchedule(_ schedule: ScheduledDocument) {
        var currentSchedules = schedules
        currentSchedules.append(schedule)
        schedules = currentSchedules
    }
    
    // Helper function to remove a schedule
    mutating func removeSchedule(id: UUID) {
        var currentSchedules = schedules
        currentSchedules.removeAll { $0.id == id }
        schedules = currentSchedules
    }
    
    // Helper function to update a schedule
    mutating func updateSchedule(_ schedule: ScheduledDocument) {
        var currentSchedules = schedules
        if let index = currentSchedules.firstIndex(where: { $0.id == schedule.id }) {
            currentSchedules[index] = schedule
            schedules = currentSchedules
        }
    }
    
    // Helper function to get all schedules for a specific date
    func schedulesFor(date: Date) -> [ScheduledDocument] {
        return schedules.filter { $0.isScheduledFor(date: date) }
    }
} 