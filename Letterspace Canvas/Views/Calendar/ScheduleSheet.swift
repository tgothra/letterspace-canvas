import SwiftUI 
struct ScheduleSheet: View {
    let document: Letterspace_CanvasDocument
    @Binding var isPresented: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedDate = Date()
    @State private var selectedServiceType: ServiceType = .sundayMorning
    @State private var selectedRecurrenceType = "once"
    @State private var selectedDaysOfWeek: Set<Int> = []
    @State private var selectedDayOfMonth = 1
    @State private var selectedMonth = 1
    @State private var selectedDayOfYear = 1
    @State private var notes: String = ""
    
    private var recurrencePattern: RecurrencePattern {
        switch selectedRecurrenceType {
        case "once":
            return .once
        case "weekly":
            return .weekly(daysOfWeek: selectedDaysOfWeek)
        case "monthly":
            return .monthly(dayOfMonth: selectedDayOfMonth)
        case "yearly":
            return .yearly(month: selectedMonth, day: selectedDayOfYear)
        default:
            return .once
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Text("Schedule Sermon")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Document Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Document")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondary)
                
                Text(document.title.isEmpty ? "Untitled" : document.title)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97))
                    .cornerRadius(6)
            }
            
            // Date Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Date")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondary)
                
                DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
            
            // Service Type
            VStack(alignment: .leading, spacing: 8) {
                Text("Service Type")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondary)
                
                Picker("Service Type", selection: $selectedServiceType) {
                    ForEach(ServiceType.allCases, id: \.self) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Recurrence
            VStack(alignment: .leading, spacing: 8) {
                Text("Recurrence")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondary)
                
                Picker("Recurrence", selection: $selectedRecurrenceType) {
                    Text("Once").tag("once")
                    Text("Weekly").tag("weekly")
                    Text("Monthly").tag("monthly")
                    Text("Yearly").tag("yearly")
                }
                .pickerStyle(.menu)
                
                
                // Additional options based on recurrence type
                if selectedRecurrenceType == "weekly" {
                    HStack {
                        ForEach(1...7, id: \.self) { day in
                            let dayName = Calendar.current.shortWeekdaySymbols[day - 1]
                            Toggle(dayName, isOn: Binding(
                                get: { selectedDaysOfWeek.contains(day) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedDaysOfWeek.insert(day)
                                    } else {
                                        selectedDaysOfWeek.remove(day)
                                    }
                                }
                            ))
                            .toggleStyle(.button)
                            .buttonStyle(.bordered)
                        }
                    }
                } else if selectedRecurrenceType == "monthly" {
                    Picker("Day of Month", selection: $selectedDayOfMonth) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                } else if selectedRecurrenceType == "yearly" {
                    HStack {
                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Picker("Day", selection: $selectedDayOfYear) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondary)
                
                
                TextEditor(text: $notes)
                    .font(.system(size: 13))
                    .frame(height: 80)
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            // Action Buttons
            HStack {
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                
                Button(action: scheduleDocument) {
                    Text("Schedule")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12) // Match the vertical padding of the time picker
                        .background(Color.blue)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 120)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func scheduleDocument() {
        var updatedDoc = document
        let schedule = ScheduledDocument(
            documentId: document.id,
            serviceType: selectedServiceType,
            startDate: selectedDate,
            endDate: nil,
            recurrence: recurrencePattern,
            notes: notes.isEmpty ? nil : notes
        )
        updatedDoc.addSchedule(schedule)
        isPresented = false
        
        // Notify that document list should update
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
    }
}
