import SwiftUI

struct SignaturePad: View {
    @Binding var signature: String
    @Environment(\.themeColors) var theme
    
    var body: some View {
        // Placeholder for now
        VStack {
            Text("Signature Pad Coming Soon")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(theme.secondary)
            Rectangle()
                .stroke(theme.divider, lineWidth: 1)
                .frame(height: 100)
        }
    }
} 