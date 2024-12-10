import SwiftUI

struct ChartView: View {
    @Binding var content: String
    @Environment(\.themeColors) var theme
    
    var body: some View {
        // Placeholder for now
        Text("Chart Editor Coming Soon")
            .font(DesignSystem.Typography.body)
            .foregroundStyle(theme.secondary)
    }
} 