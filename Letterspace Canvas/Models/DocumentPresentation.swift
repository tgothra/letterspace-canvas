import Foundation

// Todo Item Model
struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var completed: Bool = false
    
    // Support equatable
    static func == (lhs: TodoItem, rhs: TodoItem) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.completed == rhs.completed
    }
    
    // Custom coding keys for potential backwards compatibility
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case completed
    }
}

// Status of a document presentation
enum PresentationStatus: String, Codable, CaseIterable {
    case presented = "Presented"     // Past event, already happened
    case scheduled = "Scheduled"     // Future event, planned
    case canceled = "Canceled"       // Canceled event
    case rescheduled = "Rescheduled" // Rescheduled event
    
    var isPast: Bool {
        return self == .presented || self == .canceled
    }
    
    var isFuture: Bool {
        return self == .scheduled
    }
    
    var color: String {
        switch self {
        case .presented: return "#22c27d" // Green
        case .scheduled: return "#007AFF" // Blue
        case .canceled: return "#FF3B30"  // Red
        case .rescheduled: return "#FF9500" // Orange
        }
    }
}

// Unified model for document presentations (past or scheduled)
struct DocumentPresentation: Identifiable, Codable {
    let id: UUID
    let documentId: String
    var status: PresentationStatus
    var datetime: Date
    var location: String?
    var notes: String?
    var todoItems: [TodoItem]?
    
    // For recurring events
    var recurrence: RecurrencePattern?
    var serviceType: ServiceType?
    
    // For rescheduled events
    var rescheduledTo: UUID?
    var rescheduledFrom: UUID?
    
    // Initialize for recording past presentation
    init(documentId: String, 
         datetime: Date, 
         location: String? = nil, 
         notes: String? = nil,
         todoItems: [TodoItem]? = nil) {
        self.id = UUID()
        self.documentId = documentId
        self.status = .presented
        self.datetime = datetime
        self.location = location
        self.notes = notes
        self.todoItems = todoItems
        self.recurrence = nil
        self.serviceType = nil
    }
    
    // Initialize for scheduling future presentation
    init(documentId: String, 
         datetime: Date, 
         location: String? = nil, 
         serviceType: ServiceType? = nil,
         recurrence: RecurrencePattern? = nil,
         notes: String? = nil,
         todoItems: [TodoItem]? = nil) {
        self.id = UUID()
        self.documentId = documentId
        self.status = .scheduled
        self.datetime = datetime
        self.location = location
        self.serviceType = serviceType
        self.recurrence = recurrence
        self.notes = notes
        self.todoItems = todoItems
    }
    
    // Generate future occurrences based on recurrence pattern
    func generateOccurrences(until endDate: Date) -> [Date] {
        guard let recurrence = self.recurrence, recurrence.isRecurring else {
            return [self.datetime]
        }
        
        var occurrences: [Date] = []
        let calendar = Calendar.current
        var currentDate = self.datetime
        
        while currentDate <= endDate {
            occurrences.append(currentDate)
            
            switch recurrence {
            case .once:
                // Should not happen, but break to avoid infinite loop
                return occurrences
                
            case .weekly(let daysOfWeek):
                // Find the next day that matches any of the selected days of week
                var nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                while !daysOfWeek.contains(calendar.component(.weekday, from: nextDate)) {
                    nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
                }
                currentDate = nextDate
                
            case .monthly(let dayOfMonth):
                // Go to the next month, same day
                var nextDateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                nextDateComponents.month! += 1
                nextDateComponents.day = min(dayOfMonth, calendar.range(of: .day, in: .month, for: calendar.date(from: nextDateComponents)!)!.count)
                currentDate = calendar.date(from: nextDateComponents)!
                
            case .yearly(let month, let day):
                // Go to the next year, same month and day
                var nextDateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                nextDateComponents.year! += 1
                nextDateComponents.month = month
                nextDateComponents.day = day
                currentDate = calendar.date(from: nextDateComponents)!
            }
        }
        
        return occurrences
    }
}

// Extension to the document model to handle presentations
extension Letterspace_CanvasDocument {
    // Get all presentations (past and scheduled) for this document
    var presentations: [DocumentPresentation] {
        get {
            let presentationsKey = "letterspace_document_presentations_\(id)"
            if let data = UserDefaults.standard.data(forKey: presentationsKey) {
                do {
                    let decoder = JSONDecoder()
                    let presentations = try decoder.decode([DocumentPresentation].self, from: data)
                    return presentations
                } catch {
                    print("❌ Error decoding presentations: \(error)")
                    
                    // Try to debug the data
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Debug JSON: \(jsonString.prefix(200))...")
                    }
                }
            }
            
            // Migration: Convert old datePresented to presentations
            if let firstVariation = self.variations.first,
               let datePresented = firstVariation.datePresented {
                let location = firstVariation.location
                let presentation = DocumentPresentation(
                    documentId: id,
                    datetime: datePresented,
                    location: location
                )
                return [presentation]
            }
            // Migration: Convert old schedules to presentations
            let existingSchedules = self.schedules
            if !existingSchedules.isEmpty {
                let convertedPresentations = existingSchedules.map { schedule in
                    DocumentPresentation(
                        documentId: id,
                        datetime: schedule.startDate,
                        location: nil,
                        serviceType: schedule.serviceType,
                        recurrence: schedule.recurrence,
                        notes: schedule.notes
                    )
                }
                return convertedPresentations
            }
            return []
        }
        set {
            let presentationsKey = "letterspace_document_presentations_\(id)"
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(newValue)
                
                // Debug encode
                if !newValue.isEmpty {
                    print("Encoded \(newValue.count) presentations, data size: \(data.count) bytes")
                    
                    // Debug any presentations with todos
                    for (index, pres) in newValue.enumerated() {
                        if let todos = pres.todoItems, !todos.isEmpty {
                            print("Presentation \(index) has \(todos.count) todos")
                        }
                    }
                }
                
                UserDefaults.standard.set(data, forKey: presentationsKey)
                UserDefaults.standard.synchronize() // Force save immediately
                
                // For backwards compatibility, set old key too
                UserDefaults.standard.set(data, forKey: "document_presentations_\(id)")
            } catch {
                print("❌ Error encoding presentations: \(error)")
            }
        }
    }
    
    // Helper function to add a presentation
    mutating func addPresentation(_ presentation: DocumentPresentation) {
        var currentPresentations = presentations
        currentPresentations.append(presentation)
        
        // Debug
        if let todos = presentation.todoItems, !todos.isEmpty {
            print("Adding presentation with \(todos.count) todos")
        }
        
        presentations = currentPresentations
    }
    
    // Helper function to remove a presentation
    mutating func removePresentation(id: UUID) {
        var currentPresentations = presentations
        currentPresentations.removeAll { $0.id == id }
        presentations = currentPresentations
    }
    
    // Helper function to update a presentation
    mutating func updatePresentation(_ presentation: DocumentPresentation) {
        var currentPresentations = presentations
        if let index = currentPresentations.firstIndex(where: { $0.id == presentation.id }) {
            // Debug
            if let oldTodos = currentPresentations[index].todoItems,
               let newTodos = presentation.todoItems {
                print("Updating presentation: changing from \(oldTodos.count) to \(newTodos.count) todos")
            }
            
            currentPresentations[index] = presentation
            presentations = currentPresentations
        }
    }
    
    // Helper function to record a past presentation
    mutating func recordPresentation(datetime: Date, location: String? = nil, notes: String? = nil, todoItems: [TodoItem]? = nil) {
        let presentation = DocumentPresentation(
            documentId: id,
            datetime: datetime,
            location: location,
            notes: notes,
            todoItems: todoItems
        )
        addPresentation(presentation)
    }
    
    // Helper function to schedule a future presentation
    mutating func schedulePresentation(datetime: Date, location: String? = nil, 
                                      serviceType: ServiceType? = nil,
                                      recurrence: RecurrencePattern? = nil, 
                                      notes: String? = nil,
                                      todoItems: [TodoItem]? = nil) {
        let presentation = DocumentPresentation(
            documentId: id,
            datetime: datetime,
            location: location,
            serviceType: serviceType,
            recurrence: recurrence,
            notes: notes,
            todoItems: todoItems
        )
        addPresentation(presentation)
    }
    
    // Helper function to cancel a scheduled presentation
    mutating func cancelPresentation(id: UUID) {
        var currentPresentations = presentations
        if let index = currentPresentations.firstIndex(where: { $0.id == id }) {
            var presentation = currentPresentations[index]
            presentation.status = .canceled
            currentPresentations[index] = presentation
            presentations = currentPresentations
        }
    }
    
    // Helper function to reschedule a presentation
    mutating func reschedulePresentation(id: UUID, to newDate: Date) {
        var currentPresentations = presentations
        if let index = currentPresentations.firstIndex(where: { $0.id == id }) {
            let oldPresentation = currentPresentations[index]
            
            // Create new presentation with new date
            var newPresentation = DocumentPresentation(
                documentId: oldPresentation.documentId,
                datetime: newDate,
                location: oldPresentation.location,
                serviceType: oldPresentation.serviceType,
                recurrence: oldPresentation.recurrence,
                notes: oldPresentation.notes,
                todoItems: oldPresentation.todoItems
            )
            let newId = newPresentation.id
            
            // Update old presentation
            var updatedOldPresentation = oldPresentation
            updatedOldPresentation.status = .rescheduled
            updatedOldPresentation.rescheduledTo = newId
            
            // Update new presentation
            newPresentation.rescheduledFrom = oldPresentation.id
            
            // Save both
            currentPresentations[index] = updatedOldPresentation
            currentPresentations.append(newPresentation)
            presentations = currentPresentations
        }
    }
    
    // Helper function to get all presentations for a specific date
    func presentationsFor(date: Date) -> [DocumentPresentation] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        
        return presentations.filter { presentation in
            let presentationDate = presentation.datetime
            return presentationDate >= startOfDay && presentationDate <= endOfDay
        }
    }
    
    // Helper function to get past presentations
    var pastPresentations: [DocumentPresentation] {
        return presentations.filter { $0.status.isPast }
    }
    
    // Helper function to get future presentations
    var futurePresentations: [DocumentPresentation] {
        return presentations.filter { $0.status.isFuture }
    }
} 