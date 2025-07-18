import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// A unified view for both scheduling future presentations and recording past ones
struct PresentationManager: View {
    let document: Letterspace_CanvasDocument
    @Binding var isPresented: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Mode selection
    @State private var isPastPresentation: Bool = false
    
    // Editing mode
    @State private var isEditingPresentation: Bool = false
    @State private var editingPresentationId: UUID? = nil
    
    // Step management
    @State private var currentStep: Int = 0
    @State private var animateTransition: Bool = false
    
    // Common fields
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var showLocationSuggestions = false
    @State private var recentLocations: [String] = []
    @State private var hoveredLocationItem: String? = nil
    
    // Todo list fields
    @State private var todoItems: [TodoItem] = []
    @State private var newTodoText: String = ""
    @State private var isEditingTodo: Bool = false
    @State private var editingTodoId: UUID? = nil
    @State private var hoveredTodoItem: UUID? = nil
    
    // Hover states for mode buttons
    @State private var isHoveringFuture = false
    @State private var isHoveringPast = false
    
    // Hover state for close button
    @State private var isHoveringClose = false
    
    // Hover states for navigation buttons
    @State private var isHoveringBack = false
    @State private var isHoveringContinue = false
    
    // Hover states for modify section buttons
    @State private var isHoveringEdit: UUID? = nil
    @State private var isHoveringDelete: UUID? = nil
    
    // Track previous step for animation
    @State private var previousStep: Int = 0
    
    // Step configuration
    private let steps = ["Mode", "Date & Time", "Location", "Notes"]
    
    // Computed property for upcoming presentations
    private var upcomingPresentations: [DocumentPresentation] {
        document.presentations
            .filter { $0.status == .scheduled && $0.datetime >= Date() }
            .sorted { $0.datetime < $1.datetime } // Soonest first
    }
    
    private var combinedDateTime: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        return calendar.date(from: combinedComponents) ?? Date()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            headerView
            
            // Progress indicators
            stepIndicatorView
                .padding(.top, 16)
                .padding(.bottom, 24)
            
            // Main content area that changes based on current step
            ZStack {
                let fadeDuration = 0.15 // Quicker fade
                let fadeInDelay = 0.12  // Shorter delay
                
                // Each step view is conditionally shown based on currentStep
                modeSelectionView
                    .opacity(currentStep == 0 ? 1 : 0)
                    .animation(
                        (previousStep == 0) ? .easeOut(duration: fadeDuration) : .easeIn(duration: fadeDuration).delay(fadeInDelay),
                        value: currentStep
                    )
                    .offset(y: currentStep == 0 ? 0 : (currentStep > 0 ? -50 : 50))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep) // Quicker spring
                    .allowsHitTesting(currentStep == 0)
                
                dateSelectionView
                    .opacity(currentStep == 1 ? 1 : 0)
                    .animation(
                        (previousStep == 1) ? .easeOut(duration: fadeDuration) : .easeIn(duration: fadeDuration).delay(fadeInDelay),
                        value: currentStep
                    )
                    .offset(y: currentStep == 1 ? 0 : (currentStep > 1 ? -50 : 50))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep) // Quicker spring
                    .allowsHitTesting(currentStep == 1)
                
                locationInputView
                    .opacity(currentStep == 2 ? 1 : 0)
                    .animation(
                        (previousStep == 2) ? .easeOut(duration: fadeDuration) : .easeIn(duration: fadeDuration).delay(fadeInDelay),
                        value: currentStep
                    )
                    .offset(y: currentStep == 2 ? 0 : (currentStep > 2 ? -50 : 50))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep) // Quicker spring
                    .allowsHitTesting(currentStep == 2)
                
                notesInputView
                    .opacity(currentStep == 3 ? 1 : 0)
                    .animation(
                        (previousStep == 3) ? .easeOut(duration: fadeDuration) : .easeIn(duration: fadeDuration).delay(fadeInDelay),
                        value: currentStep
                    )
                    .offset(y: currentStep == 3 ? 0 : (currentStep > 3 ? -50 : 50))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep) // Quicker spring
                    .allowsHitTesting(currentStep == 3)
            }
            .frame(height: 500) // Fixed height for content area to prevent resizing
            .padding(.bottom, 30)
            
            Spacer()
            
            // Navigation buttons
            navigationButtonsView
        }
        .padding(30)
        .frame(width: 500)
        // Remove minHeight to prevent expanding
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            loadRecentLocations()
            
            // Initialize time to current hour + 1 (for future presentations)
            let now = Date()
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            components.hour = (components.hour ?? 0) + 1
            components.minute = 0
            if let date = calendar.date(from: components) {
                selectedTime = date
            }
            
            // If document has a location, use it
            if let docLocation = document.variations.first?.location, !docLocation.isEmpty {
                location = docLocation
            }
            
            // Check for edit mode from UserDefaults
            if let presentationIdString = UserDefaults.standard.string(forKey: "editingPresentationId"),
               let presentationId = UUID(uuidString: presentationIdString) {
                // Set edit mode
                isEditingPresentation = true
                editingPresentationId = presentationId
                
                // Load the presentation data
                loadPresentationData(presentationId: presentationId)
                
                // Check if we should open directly to notes step
                let openToNotesStep = UserDefaults.standard.bool(forKey: "openToNotesStep")
                if openToNotesStep {
                    // Jump directly to notes step (step 3)
                    previousStep = currentStep
                    currentStep = 3 // Notes step
                } else {
                    // Otherwise go to date & time step
                    previousStep = currentStep
                    currentStep = 1 // Date & Time step
                }
                
                // Set mode (always future for editing scheduled presentations)
                isPastPresentation = false
                
                // Clear the UserDefaults keys
                UserDefaults.standard.removeObject(forKey: "editingPresentationId")
                UserDefaults.standard.removeObject(forKey: "openToNotesStep")
            }
            
            // Validate initial date/time
            validateTimeForSelectedDate()
        }
        .onChange(of: isPastPresentation) { oldValue, newValue in
            validateTimeForSelectedDate()
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            validateTimeForSelectedDate()
        }
    }
    
    // MARK: - UI Components
    
    private var headerView: some View {
            HStack {
            Text("Schedule Presentation")
                .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    // Updated close button style to match other modals
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(isHoveringClose ? Color.red : Color.gray.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in isHoveringClose = hovering }
            }
            .padding(.bottom, 16)
    }
    
    private var stepIndicatorView: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { (step: Int) in
                HStack(spacing: 0) {
                    // Add connecting line before dots (except the first one)
                    if step > 0 {
                        Rectangle()
                            .fill(step <= currentStep ? theme.accent : Color.gray.opacity(0.3))
                            .frame(width: 30, height: 2)
                    }
                    
                    // The dot indicator
                    Circle()
                        .fill(step <= currentStep ? theme.accent : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(step <= currentStep ? theme.accent : Color.gray.opacity(0.3), lineWidth: 1)
                                .frame(width: 16, height: 16)
                        )
                        .contentShape(Rectangle().size(CGSize(width: 24, height: 24)))
                        .help(steps[step]) // Tooltip
                        .onTapGesture {
                            // Allow going back to previous steps but not forward
                            if step < currentStep {
                                withAnimation {
                                    currentStep = step
                                }
                            }
                        }
                        
                    // Add connecting line after the dot (except the last one)
                    if step < steps.count - 1 {
                        ZStack(alignment: .leading) {
                            // Background line
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 30, height: 2)
                            
                            // Animated filled line
                            if step < currentStep {
                                Rectangle()
                                    .fill(theme.accent)
                                    .frame(width: 30, height: 2)
                            } else if step == currentStep {
                                Rectangle()
                                    .fill(theme.accent)
                                    .frame(width: 30, height: 2)
                                    .opacity(animateTransition ? 1 : 0)
                                    .animation(.linear(duration: 0.4).delay(0.1), value: animateTransition)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .onChange(of: currentStep) { oldValue, newValue in
            if oldValue < newValue { // Moving forward
                animateTransition = true
                // Reset for next animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    animateTransition = false
                }
            }
        }
    }
    
    // Step 1: Mode Selection
    private var modeSelectionView: some View {
        VStack(spacing: 24) {
            Spacer() // Pushes content down from progress indicator
            
            // Consistent Title Styling
            Text("How would you like to schedule this document?")
                .font(Font.system(size: 20, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.primary)
                .padding(.top, 8) // Match date/time title padding
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: 16) {
                // Schedule Future Button
                Button(action: {
                    isPastPresentation = false
                    advanceToNextStep()
                }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16))
                        Text("Schedule for a Future Date")
                            .font(.system(size: 16))
                    }
                    .contentShape(Rectangle()) // Define hit shape
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(theme.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHoveringFuture ? theme.accent.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle()) // Apply to the Button itself
                .onHover { hovering in isHoveringFuture = hovering }
                
                // Record Past Button
                Button(action: {
                    isPastPresentation = true
                    if selectedDate > Date() {
                        selectedDate = Date()
                    }
                    advanceToNextStep()
                }) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16))
                        Text("Record a Past Presentation")
                            .font(.system(size: 16))
                    }
                    .contentShape(Rectangle()) // Define hit shape
                .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(theme.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHoveringPast ? theme.accent.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle()) // Apply to the Button itself
                .onHover { hovering in isHoveringPast = hovering }
            }
            .padding(.top, 16) // Match date/time title padding
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer() // Pushes content up from the section below
            
            // --- Modify Upcoming Section ---
            if !upcomingPresentations.isEmpty {
                Divider()
                    .padding(.horizontal, -30) // Extend divider slightly
                    .padding(.vertical, 16)
                    
                VStack(alignment: .leading, spacing: 8) {
                    Text("Modify Upcoming")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .padding(.horizontal, 8)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(upcomingPresentations) { presentation in
                                modifyPresentationRow(presentation)
                            }
                        }
                    }
                    .frame(maxHeight: 150) // Limit height if many items
                }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
    // Row view for Modify Upcoming section
    @ViewBuilder
    private func modifyPresentationRow(_ presentation: DocumentPresentation) -> some View {
        HStack {
            Text("Upcoming Date: \(formatDate(presentation.datetime))")
                        .font(.system(size: 13))
                .foregroundColor(theme.primary)
                
            Spacer()
            
            // Action buttons with closer spacing
            HStack(spacing: 4) { // Reduced spacing from default to 4
                // Edit Button
                Button(action: {
                    // Set up editing mode
                    isEditingPresentation = true
                    editingPresentationId = presentation.id
                    
                    // Populate fields with the presentation's data
                    selectedDate = presentation.datetime
                    selectedTime = presentation.datetime
                    location = presentation.location ?? ""
                    notes = presentation.notes ?? ""
                    
                    // Skip to the Date & Time step
                    previousStep = currentStep
                    currentStep = 1 // Date & Time step
                    
                    // Ensure we're in the right mode (always future for editing scheduled presentations)
                    isPastPresentation = false
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(isHoveringEdit == presentation.id ? .white : theme.secondary)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(isHoveringEdit == presentation.id ? Color.blue : Color.clear)
                                .frame(width: 18, height: 18)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringEdit = hovering ? presentation.id : nil
                }
                
                // Delete Button
                                Button(action: {
                    deletePresentation(presentation)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(isHoveringDelete == presentation.id ? .white : theme.secondary)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(isHoveringDelete == presentation.id ? .red : Color.clear)
                                .frame(width: 18, height: 18)
                        )
                                }
                                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringDelete = hovering ? presentation.id : nil
                }
            }
        }
                                .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.05)) // Subtle background
        )
    }
    
    // Helper function to delete a presentation
    private func deletePresentation(_ presentation: DocumentPresentation) {
        var mutableDoc = document // Create a mutable copy
        mutableDoc.presentations.removeAll { $0.id == presentation.id }
        mutableDoc.save()
        
        // Notify that document list might need updating (optional but good practice)
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        
        // Optionally: Close the sheet if needed, or just let the list update
        // isPresented = false
    }
    
    // Step 2: Date & Time Selection
    private var dateSelectionView: some View {
        VStack(spacing: 64) { // Further increased spacing below title
            // Consistent Title Styling
            Text("Select a date and time")
                .font(Font.system(size: 20, weight: .medium))
                .multilineTextAlignment(.center)
                                            .foregroundStyle(theme.primary)
                .padding(.top, 8)
            
            // Consistent Content Block
            VStack(spacing: 24) {
                // Custom calendar view similar to quick actions
                CalendarView(
                    selectedDate: $selectedDate,
                    dateRange: isPastPresentation ? 
                        Date(timeIntervalSince1970: 0)...Date() : 
                        Date()...Date(timeIntervalSinceNow: 3650*24*3600)
                )
                .frame(height: 280)
                
                Divider()
                    .padding(.vertical, 2) // Reduced vertical padding
                
                // Time input matching the screenshot
                HStack(spacing: 4) {
                    // Hour field with bottom border only
                    TextField("", text: Binding(
                        get: {
                            let hour = Calendar.current.component(.hour, from: selectedTime) % 12
                            return String(format: "%d", hour == 0 ? 12 : hour)
                        },
                        set: { newValue in
                            if let newHour = Int(newValue), newHour >= 1, newHour <= 12 {
                                let calendar = Calendar.current
                                let isPM = calendar.component(.hour, from: selectedTime) >= 12
                                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
                                components.hour = (newHour % 12) + (isPM ? 12 : 0)
                                if let date = calendar.date(from: components) {
                                    selectedTime = date
                                }
                            }
                        }
                    ))
                    .frame(width: 50, height: 48)
                    .multilineTextAlignment(.center)
                    .font(Font.system(size: 28, weight: .medium))
                    .textFieldStyle(PlainTextFieldStyle()) // Remove default border
                    .focusable(true)
                    .overlay( // Add bottom border
                        VStack {
                                        Spacer()
                            Rectangle()
                                .frame(height: 1.5)
                                .foregroundColor(theme.secondary)
                        }
                    )
                    
                    Text(":")
                        .font(Font.system(size: 28, weight: .medium))
                        .padding(.horizontal, 1)
                    
                    // Minute field with bottom border only
                    TextField("", text: Binding(
                        get: {
                            return String(format: "%02d", Calendar.current.component(.minute, from: selectedTime))
                        },
                        set: { newValue in
                            if let newMinute = Int(newValue), newMinute >= 0, newMinute <= 59 {
                                let calendar = Calendar.current
                                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
                                components.minute = newMinute
                                if let date = calendar.date(from: components) {
                                    selectedTime = date
                                }
                            }
                        }
                    ))
                    .frame(width: 50, height: 48)
                    .multilineTextAlignment(.center)
                    .font(Font.system(size: 28, weight: .medium))
                    .textFieldStyle(PlainTextFieldStyle()) // Remove default border
                    .focusable(true)
                    .overlay( // Add bottom border
                        VStack {
                            Spacer()
                            Rectangle()
                                .frame(height: 1.5)
                                .foregroundColor(theme.secondary)
                        }
                    )
                                        
                                        Spacer()
                    
                    // AM/PM buttons
                    HStack(spacing: 0) {
                        // AM button
                                Button(action: {
                            let calendar = Calendar.current
                            let hour = calendar.component(.hour, from: selectedTime)
                            if hour >= 12 { // Only switch if currently PM
                                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
                                components.hour = hour - 12
                                if let date = calendar.date(from: components) {
                                    selectedTime = date
                                }
                            }
                        }) {
                            Text("AM")
                                .font(Font.system(size: 18, weight: .medium))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Calendar.current.component(.hour, from: selectedTime) < 12 ? Color.blue : Color.clear)
                                .foregroundColor(Calendar.current.component(.hour, from: selectedTime) < 12 ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                        
                        // PM button
                        Button(action: {
                            let calendar = Calendar.current
                            let hour = calendar.component(.hour, from: selectedTime)
                            if hour < 12 { // Only switch if currently AM
                                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
                                components.hour = hour + 12
                                if let date = calendar.date(from: components) {
                                    selectedTime = date
                                }
                            }
                        }) {
                            Text("PM")
                                .font(Font.system(size: 18, weight: .medium))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Calendar.current.component(.hour, from: selectedTime) >= 12 ? Color.blue : Color.clear)
                                .foregroundColor(Calendar.current.component(.hour, from: selectedTime) >= 12 ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(backgroundColorForLocations)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                    }
                }
                .frame(maxWidth: .infinity)
    }
    
    // Custom calendar view matching the quick actions popover style
    private struct CalendarView: View {
        @Binding var selectedDate: Date
        let dateRange: ClosedRange<Date>
        @State private var currentMonth: Date = Date()
        
        private let calendar = Calendar.current
        private let monthFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter
        }()
        
        private let dayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter
        }()
        
        private let weekdayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter
        }()
        
        @State private var hoveredDate: Date? = nil
        @State private var isHoveringLeftArrow: Bool = false
        @State private var isHoveringRightArrow: Bool = false
        
        var body: some View {
            VStack {
                // Month header with navigation
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(isHoveringLeftArrow ? 0.3 : 0.15))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringLeftArrow = hovering
                    }
                                        
                    Spacer()
                    
                    Text(monthFormatter.string(from: currentMonth))
                        .font(Font.system(size: 16, weight: .semibold))
                                        
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.primary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(isHoveringRightArrow ? 0.3 : 0.15))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isHoveringRightArrow = hovering
                    }
                }
                .padding(.horizontal)
                
                // Weekday headers
                        HStack {
                    ForEach(getDaysOfWeek(), id: \.self) { weekday in
                        Text(weekday)
                            .font(Font.system(size: 14))
                            .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 8)
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    let daysInMonth = getDaysInMonth()
                    ForEach(daysInMonth.indices, id: \.self) { index in
                        let date = daysInMonth[index]
                        if let date = date {
                            // Check if this is today's date
                            let isToday = calendar.isDateInToday(date)
                            
                            // Modify the range check to always allow today and future dates
                            let isInRange = isToday || dateRange.contains(date)
                            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                            
                            Button(action: {
                                if isInRange {
                                    selectedDate = date
                                }
                            }) {
                                Text(dayFormatter.string(from: date))
                                    .font(Font.system(size: 16))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        // Add special highlight for today
                                        isSelected ? Color.blue :
                                            (isToday ? Color.blue.opacity(0.2) :
                                             (hoveredDate == date ? Color.blue.opacity(0.1) : Color.clear))
                                    )
                                    .foregroundStyle(isSelected ? .white : (isInRange ? .primary : .secondary))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!isInRange)
                            .opacity(isInRange ? 1.0 : 0.3)
                            .onHover { hovering in
                                hoveredDate = hovering ? date : nil
                            }
                        } else {
                            Text("")
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                
                Spacer()
            }
            .onAppear {
                // Start with the month containing the selected date
                currentMonth = selectedDate
            }
        }
        
        private func previousMonth() {
            if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                currentMonth = newMonth
            }
        }
        
        private func nextMonth() {
            if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                currentMonth = newMonth
            }
        }
        
        private func getDaysOfWeek() -> [String] {
            // Return the abbreviated weekday names (Mo, Tu, We, etc.)
            return ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
        }
        
        private func getDaysInMonth() -> [Date?] {
            var days = [Date?]()
            
            // Get start of the month
            let components = calendar.dateComponents([.year, .month], from: currentMonth)
            guard let startOfMonth = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
                return days
            }
            
            // Add empty spaces for days of the previous month
            let firstWeekday = calendar.component(.weekday, from: startOfMonth)
            let offsetDays = (firstWeekday + 5) % 7 // Convert to Monday-based (1 = Monday)
            
            for _ in 0..<offsetDays {
                days.append(nil)
            }
            
            // Add days of the current month
            for day in range {
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else {
                    continue
                }
                days.append(date)
            }
            
            // Fill the remaining cells to complete the grid
            let remainingCells = 42 - days.count // 6 rows x 7 columns = 42 cells
            for _ in 0..<remainingCells {
                days.append(nil)
            }
            
            return days
        }
    }
    
    // Step 3: Location Input
    private var locationInputView: some View {
        VStack(spacing: 24) {
            // Consistent Title Styling
            Text("Where will this be presented?")
                .font(Font.system(size: 20, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.primary)
                .padding(.top, 8) // Match date/time title padding
            
            // Consistent Content Block
            VStack(spacing: 16) { // Added VStack to group content
                TextField("Enter a New Location", text: $location)
                .font(.system(size: 28, weight: .light))
                .multilineTextAlignment(.center)
                .padding()
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: location) { oldValue, newValue in
                    // Just update the filtering without showing/hiding
                    if oldValue != newValue {
                        // This is used to filter locations as user types
                    }
                }
                .onSubmit {
                    advanceToNextStep()
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Other Locations section header
                Text("Other Locations")
                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(theme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
            
                // Other Locations list
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(recentLocations.filter {
                            location.isEmpty || $0.localizedCaseInsensitiveContains(location)
                        }, id: \.self) { loc in
                            Button(action: {
                                location = loc
                                advanceToNextStep()
                            }) {
            HStack {
                                    Text(loc)
                                        .font(.system(size: 16))
                                        .foregroundStyle(theme.primary)
                Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(hoveredLocationItem == loc ? theme.accent.opacity(0.1) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                hoveredLocationItem = hovering ? loc : nil
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(recentLocations.count * 44), 200))
            }
            
            Spacer() // Add spacer to fill available space
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var backgroundColorForLocations: some View {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }
    
    // Step 4: Notes Input
    private var notesInputView: some View {
        ScrollView { // Wrap everything in ScrollView to allow scrolling when content exceeds fixed height
            VStack(spacing: 24) {
                // Consistent Title Styling
                Text("Any notes to add?")
                    .font(Font.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.primary)
                    .padding(.top, 8) // Match date/time title padding
                
                // Only include the actual TextEditor when on step 3 (Notes)
                // Use a placeholder rectangle with the same dimensions when not active
                if currentStep == 3 {
                    // Real TextEditor when active
                TextEditor(text: $notes)
                        .font(.system(size: 16))
                        .scrollContentBackground(.hidden)
                        .padding()
                        .frame(height: 150) // Reduced height to fit
                        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.96))
                        .cornerRadius(12)
                    
                    // Todo section title with matching style
                    Text("Any tasks to add?") // Updated text
                        .font(Font.system(size: 20, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.primary)
                        .padding(.top, 12)
                        .onAppear {
                            // Force reload of todos every time this view appears
                            if let editId = editingPresentationId {
                                print("🚨 FORCE RELOADING TODOS on view appear")
                                loadTodosOnlyFromDirectBackup(presentationId: editId)
                            }
                        }
                    
                    // Todo list section - the gray box contains just the list
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // Todo Items List
                            if todoItems.isEmpty {
                                Text("No tasks yet. Add one below.")
                                    .font(.system(size: 14))
                                .foregroundStyle(theme.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(todoItems) { item in
                                    HStack(spacing: 12) {
                                        // Checkbox
                                        Image(systemName: item.completed ? "checkmark.square.fill" : "square")
                                            .foregroundColor(item.completed ? Color.blue : theme.secondary)
                                            .font(.system(size: 14))
                                            .onTapGesture {
                                                toggleTodoCompletion(item.id)
                                            }
                                        
                                        // Todo Text
                                        if editingTodoId == item.id {
                                            TextField("Edit task", text: Binding(
                                                get: { self.todoItems.first(where: { $0.id == item.id })?.text ?? "" },
                                                set: { newValue in
                                                    if let index = self.todoItems.firstIndex(where: { $0.id == item.id }) {
                                                        self.todoItems[index].text = newValue
                                                    }
                                                }
                                            ))
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .font(.system(size: 14))
                                            .onSubmit {
                                                editingTodoId = nil
                                            }
                                            #if os(macOS)
                                            .onExitCommand {
                                                editingTodoId = nil
                                            }
                                            #endif
                                        } else {
                                            Text(item.text)
                                                .font(.system(size: 14))
                                                .foregroundStyle(item.completed ? theme.secondary : theme.primary)
                                                .strikethrough(item.completed)
            }
            
            Spacer()
            
                                        // Action buttons (visible on hover)
                                        if hoveredTodoItem == item.id && editingTodoId != item.id {
                                            HStack(spacing: 8) {
                                                // Edit button
                                                Button(action: {
                                                    editTodo(item.id)
                                                }) {
                                                    Image(systemName: "pencil")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.blue)
                                                }
                                                .buttonStyle(.plain)
                                                
                                                // Delete button
                                                Button(action: {
                                                    deleteTodo(item.id)
                                                }) {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(hoveredTodoItem == item.id ? 
                                                  (colorScheme == .dark ? Color(.sRGB, white: 0.25) : Color(.sRGB, white: 0.9)) : 
                                                  Color.clear)
                                    )
                                    .onHover { hovering in
                                        hoveredTodoItem = hovering ? item.id : nil
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(height: 120) // Reduced height to fit
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.96))
                    .cornerRadius(12)
                    
                    // Add new todo field - outside the gray box
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        TextField("Add a new task", text: $newTodoText)
                            .font(.system(size: 18))
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                addTodoItem()
                            }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 4)
                } else {
                    // Empty placeholder with same dimensions when not active
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.96))
                        .frame(height: 180)
                        .cornerRadius(12)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // Navigation Buttons
    private var navigationButtonsView: some View {
                        HStack {
            // Back button
            if currentStep > 0 {
                Button(action: goToPreviousStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                        .foregroundStyle(theme.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHoveringBack ? Color.gray.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in isHoveringBack = hovering }
            }
            
            Spacer()
            
            // Next/Submit button
            Button(action: {
                if currentStep == steps.count - 1 {
                    if isEditingPresentation {
                        updatePresentation()
                    } else {
                        savePresentation()
                    }
                } else if currentStep == 1 && !isValidDateTime() {
                    // If date/time is invalid, show validation message instead of advancing
                    validateTimeForSelectedDate()
                } else {
                    advanceToNextStep()
                }
            }) {
                Text(currentStep == steps.count - 1 ? 
                     (isEditingPresentation ? "Update" : (isPastPresentation ? "Record" : "Schedule")) 
                     : "Continue")
                    .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    .frame(width: 140)
                    .padding(.vertical, 14)
                    .background(isHoveringContinue ? Color.blue.opacity(0.8) : Color.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            .onHover { hovering in isHoveringContinue = hovering }
        }
    }
    
    // MARK: - Custom Components
    
    // Custom wheel picker for time selection
    private struct TimePickerWheelView<T: Hashable>: View {
        @Binding var selection: T
        let range: ClosedRange<Int>
        let formatter: (Int) -> String
        
        var body: some View {
            VStack {
                Picker("", selection: $selection) {
                    ForEach(range, id: \.self) { value in
                        Text(formatter(value))
                            .tag(value as! T)
                    }
                }
                #if os(iOS)
                .pickerStyle(WheelPickerStyle())
                #else
                .pickerStyle(MenuPickerStyle())
                #endif
                .frame(width: 60, height: 120)
                .clipped()
                .labelsHidden()
            }
        }
    }
    
    // MARK: - Navigation Logic
    
    private func advanceToNextStep() {
        previousStep = currentStep // Store previous step before changing
        
        // If we're moving to the Notes step and we're in edit mode
        if currentStep == 2 && isEditingPresentation && editingPresentationId != nil {
            // Force reload the todos before showing the Notes view
            print("🔄 Preloading todos before advancing to Notes step")
            loadTodosOnlyFromDirectBackup(presentationId: editingPresentationId!)
        }
        
        withAnimation {
            currentStep = min(currentStep + 1, steps.count - 1)
        }
    }
    
    private func goToPreviousStep() {
        previousStep = currentStep // Store previous step before changing
        
        // If we're going back to the Notes step and we're in edit mode
        if currentStep == 3 && previousStep == 2 && isEditingPresentation && editingPresentationId != nil {
            // Force reload the todos before showing the Notes view
            print("🔄 Preloading todos before going back to Notes step")
            loadTodosOnlyFromDirectBackup(presentationId: editingPresentationId!)
        }
        
        withAnimation {
            currentStep = max(currentStep - 1, 0)
        }
    }
    
    // MARK: - Data Management
    
    private func loadRecentLocations() {
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            // Get all canvas files
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            // Load all documents
            let loadedDocs = fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                do {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                } catch {
                    return nil
                }
            }
            
            // Extract locations from all document variations
            let allLocations = Set(loadedDocs.flatMap { doc in
                doc.variations.compactMap { $0.location }.filter { !$0.isEmpty }
            })
            
            recentLocations = Array(allLocations).sorted()
        } catch {
            print("❌ Error accessing documents directory: \(error)")
        }
    }
    
    private func savePresentation() {
        var updatedDoc = document
        
        // Make a copy of todoItems to ensure it's a new instance
        let todoItemsCopy = todoItems
        
        if isPastPresentation {
            // Record past presentation
            updatedDoc.recordPresentation(
                datetime: combinedDateTime,
                location: location.isEmpty ? nil : location,
                notes: notes.isEmpty ? nil : notes,
                todoItems: todoItemsCopy.isEmpty ? nil : todoItemsCopy
            )
        } else {
            // Schedule future presentation
            updatedDoc.schedulePresentation(
                datetime: combinedDateTime,
                location: location.isEmpty ? nil : location,
                serviceType: .sundayMorning, // Use default service type
                recurrence: .once, // Always set to once
                notes: notes.isEmpty ? nil : notes,
                todoItems: todoItemsCopy.isEmpty ? nil : todoItemsCopy
            )
        }
        
        // Also update the document's first variation for backward compatibility
        if var firstVariation = updatedDoc.variations.first {
            firstVariation.datePresented = combinedDateTime
            firstVariation.location = location.isEmpty ? nil : location
            updatedDoc.variations[0] = firstVariation
        } else {
            // Create a new variation if none exists
            let variation = DocumentVariation(
                id: UUID(),
                name: "Original",
                documentId: document.id,
                parentDocumentId: document.id,
                createdAt: Date(),
                datePresented: combinedDateTime,
                location: location.isEmpty ? nil : location
            )
            updatedDoc.variations = [variation]
        }
        
        // Save to disk
        updatedDoc.save()
        
        // Explicitly save to UserDefaults for presentations
        if let presentationData = try? JSONEncoder().encode(updatedDoc.presentations) {
            let presentationsKey = "letterspace_document_presentations_\(updatedDoc.id)"
            UserDefaults.standard.set(presentationData, forKey: presentationsKey)
            UserDefaults.standard.synchronize()
            print("Explicitly saved new presentation with todos to UserDefaults")
        }
        
        // Close the sheet
        isPresented = false
        
        // Notify that document list should update
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
    }
    
    // Update an existing presentation (for edit mode)
    private func updatePresentation() {
        guard let editId = editingPresentationId else {
            // If no ID to edit, just save as a new presentation
            savePresentation()
            return
        }
        
        print("🔄 UPDATING PRESENTATION")
        print("Updating presentation with \(todoItems.count) todos")
        
        var mutableDoc = document
        
        // Find the presentation by ID
        if let index = mutableDoc.presentations.firstIndex(where: { $0.id == editId }) {
            // Debug print current state before update
            print("Before update - Presentation had: \(mutableDoc.presentations[index].todoItems?.count ?? 0) todos")
            
            // Create a deep copy of todoItems to ensure it's a new instance
            var todoItemsCopy = [TodoItem]()
            for item in todoItems {
                todoItemsCopy.append(TodoItem(
                    id: item.id,
                    text: item.text,
                    completed: item.completed
                ))
            }
            
            // FORCEFULLY SET THE TODO ITEMS ARRAY
            // IMPORTANT: We manually set the todoItems array rather than using nil for empty arrays
            // This ensures the property exists even when empty
            if todoItemsCopy.isEmpty {
                print("⚠️ No todos to save, but still creating empty array rather than nil")
                todoItemsCopy = [] // Create empty array instead of nil
            }
            
            // 1. Update all fields in the document model
            mutableDoc.presentations[index].datetime = combinedDateTime
            mutableDoc.presentations[index].location = location.isEmpty ? nil : location
            mutableDoc.presentations[index].notes = notes.isEmpty ? nil : notes
            mutableDoc.presentations[index].todoItems = todoItemsCopy
            mutableDoc.save()
            
            print("✅ SAVED DOCUMENT with \(todoItemsCopy.count) todos")
            
            // 2. Also update document's first variation for backward compatibility
            if var firstVariation = mutableDoc.variations.first {
                firstVariation.datePresented = combinedDateTime
                firstVariation.location = location.isEmpty ? nil : location
                mutableDoc.variations[0] = firstVariation
                mutableDoc.save()
            }
            
            // 3. Create direct UserDefaults backup
            var presentationDict: [String: Any] = [
                "id": editId.uuidString,
                "documentId": document.id,
                "datetime": combinedDateTime.timeIntervalSince1970,
                "notes": notes
            ]
            
            if !location.isEmpty {
                presentationDict["location"] = location
            }
            
            // Always include todoItems, even if empty
            var todoItemsArray: [[String: Any]] = []
            for item in todoItemsCopy {
                todoItemsArray.append([
                    "id": item.id.uuidString,
                    "text": item.text,
                    "completed": item.completed
                ])
            }
            presentationDict["todoItems"] = todoItemsArray
            
            // Save direct backup to UserDefaults with immediate synchronization
            let directKey = "presentation_direct_\(editId.uuidString)"
            print("📌 Saving direct backup to key: \(directKey) with \(todoItemsArray.count) todos")
            UserDefaults.standard.set(presentationDict, forKey: directKey)
            // Remove synchronize() to prevent main thread hangs
            
            // 4. Save encoded collections to UserDefaults
            if let presentationData = try? JSONEncoder().encode(mutableDoc.presentations) {
                let presentationsKey = "letterspace_document_presentations_\(document.id)"
                UserDefaults.standard.set(presentationData, forKey: presentationsKey)
                
                // Old key format for backward compatibility
                let oldKey = "document_presentations_\(document.id)"
                UserDefaults.standard.set(presentationData, forKey: oldKey)
                
                // Remove synchronize() to prevent main thread hangs
                print("✅ Saved todos to encoded UserDefaults collections")
            }
            
            // 5. VERIFICATION: Read back the values we just saved
            print("🔍 VERIFICATION CHECK")
            UserDefaults.standard.synchronize()
            
            // Verify direct backup
            if let directDict = UserDefaults.standard.object(forKey: directKey) as? [String: Any],
               let savedArray = directDict["todoItems"] as? [[String: Any]] {
                print("✓ Direct backup verification: Found \(savedArray.count) todos")
            } else {
                print("❌ Direct backup verification FAILED: Could not find todoItems")
            }
            
            // Verify document model after saving
            if let savedDoc = Letterspace_CanvasDocument.load(id: document.id),
               let savedPresentation = savedDoc.presentations.first(where: { $0.id == editId }) {
                if let savedTodos = savedPresentation.todoItems {
                    print("✓ Document verification: Found \(savedTodos.count) todos")
                } else {
                    print("❌ Document verification: todoItems is nil")
                }
            }
            
            // 6. Notify that document list should update
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        } else {
            print("⚠️ Could not find presentation with ID \(editId) to update")
        }
        
        // Close the sheet
        isPresented = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Date and Time Validation
    
    // Check if the selected date and time combination is valid for the presentation mode
    private func isValidDateTime() -> Bool {
        let now = Date()
        
        if isPastPresentation {
            // Past presentations must be in the past
            return combinedDateTime <= now
        } else {
            // Future presentations must be in the future
            return combinedDateTime > now
        }
    }
    
    // Updates the time if needed when the selected date changes
    private func validateTimeForSelectedDate() {
        let now = Date()
        
        // If we've selected today and it's a future presentation
        let isToday = Calendar.current.isDateInToday(selectedDate)
        
        if !isPastPresentation && isToday {
            // Make sure the time is in the future
            if selectedTime < now {
                // Set time to current time + 1 hour, rounded to nearest hour
                var components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: now)
                components.hour = (components.hour ?? 0) + 1
                components.minute = 0
                if let futureTime = Calendar.current.date(from: components) {
                    selectedTime = futureTime
                }
            }
        } else if isPastPresentation && selectedDate > now {
            // If recording past and selected a future date, change to today
            selectedDate = now
        }
    }
    
    // MARK: - Todo Management Methods
    
    private func addTodoItem() {
        guard !newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Create a new todo item with a unique ID
        let newItemId = UUID()
        let newItem = TodoItem(
            id: newItemId,
            text: newTodoText.trimmingCharacters(in: .whitespacesAndNewlines),
            completed: false
        )
        
        // Add to our local array
        todoItems.append(newItem)
        newTodoText = ""
        
        print("🔰 ADDING TODO: \(newItem.text), Total items now: \(todoItems.count)")
        
        // Save to all storage locations if we're editing a presentation
        if let editId = editingPresentationId {
            // 1. Update the document model
            var mutableDoc = document
            if let index = mutableDoc.presentations.firstIndex(where: { $0.id == editId }) {
                // Create deep copy of todo items
                var todoItemsCopy = [TodoItem]()
                for item in todoItems {
                    todoItemsCopy.append(TodoItem(
                        id: item.id,
                        text: item.text, 
                        completed: item.completed
                    ))
                }
                
                // Update and save document
                mutableDoc.presentations[index].todoItems = todoItemsCopy
                mutableDoc.save()
                print("✅ Saved \(todoItemsCopy.count) todos to document model")
                
                // 2. Save direct backup to UserDefaults
                saveAsDirectBackup(presentationId: editId, todoItems: todoItems)
                
                // Verification: Read back the direct backup
                let directKey = "presentation_direct_\(editId.uuidString)"
                UserDefaults.standard.synchronize()
                
                if let directDict = UserDefaults.standard.object(forKey: directKey) as? [String: Any],
                   let todoItemsArray = directDict["todoItems"] as? [[String: Any]] {
                    
                    // Check if our new item is in the direct backup
                    let foundNewItem = todoItemsArray.contains { dict in
                        if let idString = dict["id"] as? String,
                           let uuid = UUID(uuidString: idString),
                           uuid == newItemId {
                            return true
                        }
                        return false
                    }
                    
                    print(foundNewItem ? "✓ Verification: New item found in direct backup" :
                                        "❌ Verification: New item NOT found in direct backup")
                }
                
                // 3. Save encoded collections to UserDefaults
                if let presentationData = try? JSONEncoder().encode(mutableDoc.presentations) {
                    let presentationsKey = "letterspace_document_presentations_\(document.id)"
                    UserDefaults.standard.set(presentationData, forKey: presentationsKey)
                    
                    // Old key format for backward compatibility
                    let oldKey = "document_presentations_\(document.id)"
                    UserDefaults.standard.set(presentationData, forKey: oldKey)
                    
                    // Remove synchronize() to prevent main thread hangs
                    print("✅ Saved todos to encoded UserDefaults collections")
                }
            }
        }
    }
    
    private func toggleTodoCompletion(_ id: UUID) {
        if let index = todoItems.firstIndex(where: { $0.id == id }) {
            // Toggle the completion state
            todoItems[index].completed.toggle()
            
            print("🔄 TOGGLING TODO: \(todoItems[index].text), Completed: \(todoItems[index].completed)")
            
            // Save to all storage locations if we're editing a presentation
            if let editId = editingPresentationId {
                // 1. Update the document model
                var mutableDoc = document
                if let presIndex = mutableDoc.presentations.firstIndex(where: { $0.id == editId }) {
                    // Create deep copy of todo items
                    var todoItemsCopy = [TodoItem]()
                    for item in todoItems {
                        todoItemsCopy.append(TodoItem(
                            id: item.id,
                            text: item.text, 
                            completed: item.completed
                        ))
                    }
                    
                    // Update and save document
                    mutableDoc.presentations[presIndex].todoItems = todoItemsCopy
                    mutableDoc.save()
                    print("✅ Saved \(todoItemsCopy.count) todos to document model")
                    
                    // 2. Save direct backup to UserDefaults
                    saveAsDirectBackup(presentationId: editId, todoItems: todoItems)
                    
                    // 3. Save encoded collections to UserDefaults
                    if let presentationData = try? JSONEncoder().encode(mutableDoc.presentations) {
                        let presentationsKey = "letterspace_document_presentations_\(document.id)"
                        UserDefaults.standard.set(presentationData, forKey: presentationsKey)
                        
                        // Old key format for backward compatibility
                        let oldKey = "document_presentations_\(document.id)"
                        UserDefaults.standard.set(presentationData, forKey: oldKey)
                        
                        // Remove synchronize() to prevent main thread hangs
                        print("✅ Saved todos to encoded UserDefaults collections")
                    }
                }
            }
        }
    }
    
    private func editTodo(_ id: UUID) {
        editingTodoId = id
    }
    
    private func deleteTodo(_ id: UUID) {
        if let index = todoItems.firstIndex(where: { $0.id == id }) {
            let itemText = todoItems[index].text
            todoItems.remove(at: index)
            
            print("❌ DELETING TODO: \(itemText), Remaining: \(todoItems.count)")
            
            // Save to all storage locations if we're editing a presentation
            if let editId = editingPresentationId {
                // 1. Update the document model
                var mutableDoc = document
                if let presIndex = mutableDoc.presentations.firstIndex(where: { $0.id == editId }) {
                    // Create deep copy of todo items
                    var todoItemsCopy = [TodoItem]()
                    for item in todoItems {
                        todoItemsCopy.append(TodoItem(
                            id: item.id,
                            text: item.text, 
                            completed: item.completed
                        ))
                    }
                    
                    // Update and save document
                    // Always create an empty array rather than nil
                    mutableDoc.presentations[presIndex].todoItems = todoItemsCopy.isEmpty ? [] : todoItemsCopy
                    mutableDoc.save()
                    print("✅ Saved \(todoItemsCopy.count) todos to document model")
                    
                    // 2. Save direct backup to UserDefaults (even if empty)
                    saveAsDirectBackup(presentationId: editId, todoItems: todoItems)
                    
                    // 3. Save encoded collections to UserDefaults
                    if let presentationData = try? JSONEncoder().encode(mutableDoc.presentations) {
                        let presentationsKey = "letterspace_document_presentations_\(document.id)"
                        UserDefaults.standard.set(presentationData, forKey: presentationsKey)
                        
                        // Old key format for backward compatibility
                        let oldKey = "document_presentations_\(document.id)"
                        UserDefaults.standard.set(presentationData, forKey: oldKey)
                        
                        // Remove synchronize() to prevent main thread hangs
                        print("✅ Saved todos to encoded UserDefaults collections")
                    }
                    
                    // 4. Verify the direct backup exists
                    let directKey = "presentation_direct_\(editId.uuidString)"
                    if let directDict = UserDefaults.standard.object(forKey: directKey) as? [String: Any] {
                        print("✓ Verification: Direct backup exists after delete")
                        if let savedArray = directDict["todoItems"] as? [[String: Any]] {
                            print("✓ Verification: Direct backup has \(savedArray.count) todos")
                        }
                    }
                }
            }
        }
    }
    
    // Parse notes to extract todo items (no longer needed as they are stored separately)
    private func parseTodoItemsFromNotes() {
        // If todoItems are already populated, don't overwrite them
        if !todoItems.isEmpty {
            print("Todo items already loaded, preserving existing \(todoItems.count) items")
            return
        }
        
        // Find the presentation's todos if this is edit mode
        if let editId = editingPresentationId, 
           let presentation = document.presentations.first(where: { $0.id == editId }) {
            // Set the todo items from the presentation
            if let presentationTodoItems = presentation.todoItems, !presentationTodoItems.isEmpty {
                print("Loading \(presentationTodoItems.count) todo items from presentation")
                todoItems = presentationTodoItems
                
                // Debug print
                for (index, item) in todoItems.enumerated() {
                    print("Loaded item \(index): \(item.text) (completed: \(item.completed))")
                }
            } else {
                print("No todo items found in presentation")
                todoItems = []
            }
            
            // Make sure we set the notes correctly
            notes = presentation.notes ?? ""
        } else {
            // No todo items
            todoItems = []
            print("No existing presentation found, starting with empty todo list")
        }
    }
    
    // Load presentation data directly from UserDefaults
    private func loadPresentationData(presentationId: UUID) {
        // Find the presentation in the document
        if let presentation = document.presentations.first(where: { $0.id == presentationId }) {
            // Populate fields with the presentation's data
            selectedDate = presentation.datetime
            selectedTime = presentation.datetime
            location = presentation.location ?? ""
            notes = presentation.notes ?? ""
            
            print("🔄 STARTUP: Loading presentation data for ID: \(presentationId)")
            
            // CRITICAL FIX: ALWAYS try direct backup first, then do everything else
            let directKey = "presentation_direct_\(presentationId.uuidString)"
            if let directDict = UserDefaults.standard.object(forKey: directKey) as? [String: Any],
               let todoItemsArray = directDict["todoItems"] as? [[String: Any]] {
                
                var directItems = [TodoItem]()
                for itemDict in todoItemsArray {
                    if let text = itemDict["text"] as? String {
                        let id = UUID(uuidString: itemDict["id"] as? String ?? "") ?? UUID()
                        let completed = itemDict["completed"] as? Bool ?? false
                        directItems.append(TodoItem(id: id, text: text, completed: completed))
                    }
                }
                
                if !directItems.isEmpty {
                    print("⭐️ STARTUP: Loading \(directItems.count) items from direct backup")
                    todoItems = directItems
                    
                    // For completeness, update document to match
                    var mutableDoc = document
                    if let index = mutableDoc.presentations.firstIndex(where: { $0.id == presentationId }) {
                        mutableDoc.presentations[index].todoItems = todoItems
                        mutableDoc.save()
                    }
                    return
                }
            }
            
            // Fall back to document model if direct backup fails
            if let docTodos = presentation.todoItems, !docTodos.isEmpty {
                print("⭐️ STARTUP: Using \(docTodos.count) items from document model")
                todoItems = docTodos
                
                // Create direct backup for next time
                saveAsDirectBackup(presentationId: presentationId, todoItems: todoItems)
                return
            }
            
            // If both failed, try the full loadPresentationFromUserDefaults
            if !loadPresentationFromUserDefaults(documentId: document.id, presentationId: presentationId) {
                print("⚠️ STARTUP: No todos found in any storage location, starting with empty list")
                todoItems = []
            }
        } else {
            print("❌ Could not find presentation with ID \(presentationId)")
            todoItems = []
        }
    }

    private func loadPresentationFromUserDefaults(documentId: String, presentationId: UUID) -> Bool {
        print("⚠️ ATTEMPTING TO LOAD FROM USERDEFAULTS")
        
        // First try the direct backup format
        let directKey = "presentation_direct_\(presentationId.uuidString)"
        print("📂 Trying direct key first: \(directKey)")
        print("📂 Presentation ID being searched: \(presentationId.uuidString)")
        
        // DEBUG: Show all UserDefaults keys to help diagnose issues
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        var directKeys = [String]()
        for key in allKeys {
            if key.starts(with: "presentation_direct_") {
                directKeys.append(key)
            }
        }
        print("📋 Found \(directKeys.count) direct presentation keys:")
        for key in directKeys {
            print("  - \(key)")
        }
        
        // Check if the direct key exists
        if UserDefaults.standard.object(forKey: directKey) != nil {
            print("📋 Direct key EXISTS in UserDefaults")
        } else {
            print("❌ Direct key NOT FOUND in UserDefaults")
        }
        
        if let directDict = UserDefaults.standard.object(forKey: directKey) as? [String: Any] {
            print("Found direct presentation data!")
            print("Contents: \(directDict.keys.joined(separator: ", "))")
            
            // Try to load todo items from the direct format
            if let todoItemsArray = directDict["todoItems"] as? [[String: Any]] {
                print("Found \(todoItemsArray.count) todo items in direct format")
                
                var loadedItems = [TodoItem]()
                
                for (i, itemDict) in todoItemsArray.enumerated() {
                    if let text = itemDict["text"] as? String {
                        let id = UUID(uuidString: itemDict["id"] as? String ?? "") ?? UUID()
                        let completed = itemDict["completed"] as? Bool ?? false
                        
                        let item = TodoItem(id: id, text: text, completed: completed)
                        loadedItems.append(item)
                        print("Direct item #\(i): '\(text)' (completed: \(completed))")
                    }
                }
                
                if !loadedItems.isEmpty {
                    print("🟢 Successfully loaded \(loadedItems.count) todos from direct storage")
                    todoItems = loadedItems
                    
                    // IMPORTANT: ALSO update the document model to ensure consistency
                    if let index = document.presentations.firstIndex(where: { $0.id == presentationId }) {
                        var mutableDoc = document
                        mutableDoc.presentations[index].todoItems = loadedItems
                        mutableDoc.save()
                        print("✅ Also updated document in memory with todos")
                        
                        // Immediately save to the encoded presentations in UserDefaults
                        if let presentationData = try? JSONEncoder().encode(mutableDoc.presentations) {
                            let presentationsKey = "letterspace_document_presentations_\(documentId)"
                            UserDefaults.standard.set(presentationData, forKey: presentationsKey)
                            UserDefaults.standard.synchronize()
                            print("✅ Also updated encoded presentations in UserDefaults")
                        }
                    }
                    return true
                }
            } else {
                print("No todoItems array found in direct format")
            }
        }
        
        // Try both the new and old key formats for backward compatibility
        let presentationsKey = "letterspace_document_presentations_\(documentId)"
        let oldKey = "document_presentations_\(documentId)"
        
        print("📂 Trying presentations collection keys: \(presentationsKey) or \(oldKey)")
        
        // Debug: Dump all keys in UserDefaults to see what's available
        let userDefaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys
        print("All UserDefaults keys (\(userDefaultsKeys.count) total):")
        var count = 0
        for key in userDefaultsKeys where key.contains("presentation") {
            print("- \(key)")
            count += 1
            if count >= 20 {
                print("... (showing only first 20 presentation keys)")
                break
            }
        }
        
        var data: Data? = nil
        
        // Try the new key format first
        if let newKeyData = UserDefaults.standard.data(forKey: presentationsKey) {
            print("Found data using NEW key format: \(presentationsKey)")
            data = newKeyData
        } 
        // Then try the old key format
        else if let oldKeyData = UserDefaults.standard.data(forKey: oldKey) {
            print("Found data using OLD key format: \(oldKey)")
            data = oldKeyData
        }
        
        if let data = data {
            do {
                let presentations = try JSONDecoder().decode([DocumentPresentation].self, from: data)
                print("Successfully decoded \(presentations.count) presentations from UserDefaults")
                
                // Print all presentation IDs for debugging
                print("Available presentation IDs:")
                for (i, pres) in presentations.enumerated() {
                    print("\(i): \(pres.id) - has todos: \(pres.todoItems != nil) - count: \(pres.todoItems?.count ?? 0)")
                }
                
                if let presentation = presentations.first(where: { $0.id == presentationId }) {
                    print("Found matching presentation with ID \(presentationId)")
                    
                    // Load todo items if they exist
                    if let presentationTodos = presentation.todoItems {
                        if presentationTodos.isEmpty {
                            print("WARNING: Presentation has empty todoItems array")
                            todoItems = []
                        } else {
                            print("🟢 Successfully loaded \(presentationTodos.count) todos from UserDefaults")
                            todoItems = presentationTodos
                            
                            for (index, item) in todoItems.enumerated() {
                                print("UserDefaults item \(index): \(item.text) (completed: \(item.completed))")
                            }
                            
                            // IMPORTANT: Also save as direct backup for next time
                            saveAsDirectBackup(presentationId: presentationId, todoItems: todoItems)
                        }
                        return true
                    } else {
                        print("⚠️ Presentation found but todoItems is nil")
                        todoItems = []
                        return true
                    }
                } else {
                    print("⚠️ Could not find presentation with ID \(presentationId) in UserDefaults data")
                    print("Looking for: \(presentationId)")
                    print("Available IDs: \(presentations.map { $0.id.uuidString }.joined(separator: ", "))")
                }
            } catch {
                print("❌ Error decoding presentations from UserDefaults: \(error)")
                print("Data size: \(data.count) bytes")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("First 200 chars of data: \(jsonString.prefix(200))")
                }
            }
        } else {
            print("❌ No presentation data found in UserDefaults for document \(documentId)")
        }
        return false
    }

    // Helper function to save todos as direct backup with guaranteed reliability
    private func saveAsDirectBackup(presentationId: UUID, todoItems: [TodoItem]) {
        print("📌 DIRECT BACKUP: Starting save for \(todoItems.count) todos")
        
        // Always continue even with empty arrays - we want to preserve the todoItems key
        
        // Find the presentation in document
        if let presentation = document.presentations.first(where: { $0.id == presentationId }) {
            // Create a simplified presentation dictionary for storage
            var presentationDict: [String: Any] = [
                "id": presentationId.uuidString,
                "documentId": document.id,
                "datetime": presentation.datetime.timeIntervalSince1970,
                "notes": presentation.notes ?? ""
            ]
            
            if let location = presentation.location {
                presentationDict["location"] = location
            }
            
            // Convert todo items to simple dictionaries
            var todoItemsArray: [[String: Any]] = []
            for item in todoItems {
                todoItemsArray.append([
                    "id": item.id.uuidString,
                    "text": item.text,
                    "completed": item.completed
                ])
            }
            
            // IMPORTANT: Always include todoItems key, even if the array is empty
            presentationDict["todoItems"] = todoItemsArray
            
            // Save this presentation directly to UserDefaults
            let directKey = "presentation_direct_\(presentationId.uuidString)"
            UserDefaults.standard.set(presentationDict, forKey: directKey)
            UserDefaults.standard.synchronize()
            
            // CRITICAL: Force write to disk
            UserDefaults.standard.synchronize()
            
            // DOUBLE-VERIFY save was successful
            if let savedDict = UserDefaults.standard.object(forKey: directKey) as? [String: Any],
               let savedArray = savedDict["todoItems"] as? [[String: Any]] {
                
                print("✅ DIRECT BACKUP: Verified save successful with \(savedArray.count) todos")
                
                // Double-verification - print the first few items to confirm
                for (i, dict) in savedArray.prefix(min(3, savedArray.count)).enumerated() {
                    if let text = dict["text"] as? String {
                        print("  - Item \(i): '\(text)'")
                    }
                }
            } else {
                print("⚠️ DIRECT BACKUP: Verification failed! Emergency re-save")
                
                // Try again with a different approach
                let jsonData = try? JSONSerialization.data(withJSONObject: presentationDict)
                if let jsonData = jsonData,
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    
                    // Save as string for extra reliability
                    let stringKey = "presentation_direct_string_\(presentationId.uuidString)"
                    UserDefaults.standard.set(jsonString, forKey: stringKey)
                    UserDefaults.standard.synchronize()
                    
                    print("🔄 Created emergency string backup")
                }
            }
        }
    }

    // New helper function to force-load todos from direct backup (highest priority storage)
    private func loadTodosOnlyFromDirectBackup(presentationId: UUID) {
        let directKey = "presentation_direct_\(presentationId.uuidString)"
        print("🔍 EMERGENCY RELOAD from direct backup key: \(directKey)")
        
        if let directDict = UserDefaults.standard.object(forKey: directKey) as? [String: Any],
           let todoItemsArray = directDict["todoItems"] as? [[String: Any]] {
            
            print("✅ FOUND \(todoItemsArray.count) todos in direct backup")
            
            var loadedItems = [TodoItem]()
            for (i, itemDict) in todoItemsArray.enumerated() {
                if let text = itemDict["text"] as? String {
                    let id = UUID(uuidString: itemDict["id"] as? String ?? "") ?? UUID()
                    let completed = itemDict["completed"] as? Bool ?? false
                    
                    let item = TodoItem(id: id, text: text, completed: completed)
                    loadedItems.append(item)
                    print("  Emergency item #\(i): '\(text)' (completed: \(completed))")
                }
            }
            
            if !loadedItems.isEmpty {
                print("🚨 FORCE SETTING \(loadedItems.count) TODOS FROM DIRECT BACKUP")
                todoItems = loadedItems
                
                // Also update document model for completeness
                var mutableDoc = document
                if let index = mutableDoc.presentations.firstIndex(where: { $0.id == presentationId }) {
                    mutableDoc.presentations[index].todoItems = todoItems
                    mutableDoc.save()
                }
            } else {
                print("⚠️ No todos found in emergency reload")
            }
        } else {
            print("⚠️ No direct backup found in emergency reload")
        }
    }
} 