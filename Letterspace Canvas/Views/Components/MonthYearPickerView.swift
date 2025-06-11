import SwiftUI 
// Month/year picker view for calendar
struct MonthYearPickerView: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    let onDismiss: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var hoveredMonth: Int? = nil  // Add state for hovered month
    
    var body: some View {
        // Use a ZStack with a white background that extends to the edges
        ZStack {
            // Background layer
            Rectangle()
                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
                .edgesIgnoringSafeArea(.all)
            
            // Content layer
            VStack(spacing: 6) {  // Further reduced from 8 to 6
                // Year with navigation
                HStack {
                    Button(action: {
                        selectedYear -= 1
                    }) {
                        ZStack {
                            Circle()
                                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97))
                                .frame(width: 22, height: 22)  // Further reduced from 24x24 to 22x22
                            
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9))  // Further reduced from 10 to 9
                                .foregroundStyle(theme.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text(verbatim: "\(selectedYear)")
                        .font(.system(size: 15, weight: .medium))  // Further reduced from 16 to 15
                        .foregroundStyle(theme.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        selectedYear += 1
                    }) {
                        ZStack {
                            Circle()
                                .fill(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97))
                                .frame(width: 22, height: 22)  // Further reduced from 24x24 to 22x22
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))  // Further reduced from 10 to 9
                                .foregroundStyle(theme.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Month grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {  // Further reduced from 8 to 6
                    ForEach(1...12, id: \.self) { month in
                        Button(action: {
                            selectedMonth = month
                            onDismiss()
                        }) {
                            Text(Calendar.current.shortMonthSymbols[month-1])
                                .font(.system(size: 11))  // Further reduced from 12 to 11
                                .frame(height: 24)  // Further reduced from 26 to 24
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)  // Further reduced from 6 to 5
                                        .fill(
                                            selectedMonth == month ? theme.accent.opacity(0.15) :
                                            hoveredMonth == month ? theme.accent.opacity(0.05) :
                                            Color.clear
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)  // Further reduced from 6 to 5
                                                .stroke(selectedMonth == month ?
                                                       theme.accent :
                                                       Color.clear, lineWidth: 0.8)  // Further reduced from 1 to 0.8
                                        )
                                )
                                .foregroundStyle(selectedMonth == month ? theme.accent : theme.primary)
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovered in
                            hoveredMonth = isHovered ? month : nil
                        }
                    }
                }
                
                Divider()
                
                // Bottom controls
                HStack {
                    Button("Today") {
                        let today = Date()
                        selectedMonth = Calendar.current.component(.month, from: today)
                        selectedYear = Calendar.current.component(.year, from: today)
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))  // Further reduced from 12 to 11
                    .foregroundStyle(theme.accent)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))  // Further reduced from 12 to 11
                    .foregroundStyle(theme.secondary)
                }
            }
            .padding(10)  // Further reduced from 12 to 10
        }
        .frame(width: 200)  // Further reduced from 220 to 200
    }
}
