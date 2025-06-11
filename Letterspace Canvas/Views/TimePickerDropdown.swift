import SwiftUI

// Import DesignSystem for ThemeColors - update to match the structure defined in the project
typealias ThemeColors = DesignSystem.Colors.ThemeColors

// TimePickerDropdown component with styled time input and AM/PM toggle
struct TimePickerDropdown: View {
    @Binding var selectedTime: String
    @Binding var showTimeOptions: Bool  // Kept for API compatibility
    let timeOptions: [String] // Kept for API compatibility
    let theme: ThemeColors
    let colorScheme: ColorScheme
    
    // Define accent blue color
    private let accentBlue = Color.blue
    
    // State for the input field and AM/PM selection
    @State private var hourInput: String = "9"
    @State private var minuteInput: String = "00"
    @State private var amPm: String = "AM"
    
    // State to control text field focus
    @State private var isHourFocused: Bool = false
    @State private var isMinuteFocused: Bool = false
    
    // Initialize state values from selectedTime when the view appears
    func parseSelectedTime() {
        if !selectedTime.isEmpty {
            let components = selectedTime.components(separatedBy: " ")
            if components.count == 2 {
                let timeComponents = components[0].components(separatedBy: ":")
                if timeComponents.count == 2 {
                    hourInput = timeComponents[0]
                    minuteInput = timeComponents[1]
                }
                amPm = components[1]
            }
        }
    }
    
    // Format input to valid time
    func updateSelectedTime() {
        // Ensure input is valid
        let validHour = validateHourInput(hourInput)
        let validMinute = validateMinuteInput(minuteInput)
        
        // Set the validated time
        selectedTime = "\(validHour):\(validMinute) \(amPm)"
    }
    
    // Validate and correct hour input
    func validateHourInput(_ input: String) -> String {
        guard let hour = Int(input) else { return "12" }
        if hour < 1 { return "1" }
        if hour > 12 { return "12" }
        return String(hour)
    }
    
    // Validate and correct minute input
    func validateMinuteInput(_ input: String) -> String {
        guard let minute = Int(input) else { return "00" }
        if minute < 0 { return "00" }
        if minute > 59 { return "59" }
        return minute < 10 ? "0\(minute)" : "\(minute)"
    }
    
    var body: some View {
        // Clean time picker with absolutely no background fills
        HStack(spacing: 2) {
            // Hour field with only border
            ZStack {
                Color.clear // Ensure transparent background
                
                TextField("", text: $hourInput)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .background(Color.clear)
                    .textFieldStyle(PlainTextFieldStyle()) // Use plain style to avoid default styling
            }
            .frame(width: 28, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 0.5)
            )
            .onChange(of: hourInput) { _, newValue in
                hourInput = newValue.filter { "0123456789".contains($0) }
                updateSelectedTime()
            }
            .onSubmit { hourInput = validateHourInput(hourInput) }
            
            // Separator
            Text(":")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 6)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            // Minute field with only border
            ZStack {
                Color.clear // Ensure transparent background
                
                TextField("", text: $minuteInput)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .background(Color.clear)
                    .textFieldStyle(PlainTextFieldStyle()) // Use plain style to avoid default styling
            }
            .frame(width: 28, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 0.5)
            )
            .onChange(of: minuteInput) { _, newValue in
                minuteInput = newValue.filter { "0123456789".contains($0) }
                updateSelectedTime()
            }
            .onSubmit { minuteInput = validateMinuteInput(minuteInput) }
            
            // Minimal spacer
            Spacer()
                .frame(width: 5)
            
            // AM/PM toggle with no background except when selected
            HStack(spacing: 0) {
                // AM label
                Text("AM")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 29, height: 28)
                    .foregroundColor(amPm == "AM" ? .white : (colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)))
                    .background(amPm == "AM" ? accentBlue : Color.clear)
                    .cornerRadius(4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if amPm != "AM" {
                            amPm = "AM"
                            updateSelectedTime()
                        }
                    }
                
                // PM label
                Text("PM")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 29, height: 28)
                    .foregroundColor(amPm == "PM" ? .white : (colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)))
                    .background(amPm == "PM" ? accentBlue : Color.clear)
                    .cornerRadius(4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if amPm != "PM" {
                            amPm = "PM"
                            updateSelectedTime()
                        }
                    }
            }
            .background(Color.clear) // Ensure outer container has no background
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 2)
        .id("timePickerInput")
        .onAppear {
            parseSelectedTime()
        }
    }
}