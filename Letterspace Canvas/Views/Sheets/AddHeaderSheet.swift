#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - Add Header Sheet
struct AddHeaderSheet: View {
    let onAdd: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.themeColors) private var theme
    @State private var headerTitle: String = ""
    @FocusState private var isTitleFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Add Section Header")
                .font(.custom("InterTight-Bold", size: 20))
                .foregroundStyle(theme.primary)
            
            // Description
            Text("Create a section to organize your documents for today")
                .font(.custom("InterTight-Regular", size: 14))
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
            
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Section Title")
                    .font(.custom("InterTight-Medium", size: 14))
                    .foregroundStyle(theme.primary)
                
                TextField("e.g., Morning Prep, Afternoon Meetings", text: $headerTitle)
                    .font(.custom("InterTight-Regular", size: 16))
                    .textFieldStyle(.roundedBorder)
                    .focused($isTitleFieldFocused)
                    .onSubmit {
                        if !headerTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onAdd(headerTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .font(.custom("InterTight-Medium", size: 14))
                    .foregroundStyle(theme.secondary)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(theme.secondary.opacity(0.1))
                    .cornerRadius(8)
                
                Button("Add Header") {
                    if !headerTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onAdd(headerTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .font(.custom("InterTight-Medium", size: 14))
                .foregroundStyle(.white)
                .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(headerTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.secondary : theme.accent)
                    .cornerRadius(8)
                    .disabled(headerTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .onAppear {
            isTitleFieldFocused = true
        }
    }
}
#endif
