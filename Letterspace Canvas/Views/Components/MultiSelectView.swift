import SwiftUI

struct MultiSelectView: View {
    @Binding var selectedOptions: String
    @Binding var options: [String]
    @State private var showingOptions = false
    @Environment(\.themeColors) var theme
    
    private var selectedArray: [String] {
        selectedOptions.components(separatedBy: ",").filter { !$0.isEmpty }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Multiple Selection")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(theme.secondary)
            
            ForEach(selectedArray, id: \.self) { option in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.primary)
                    Text(option)
                        .font(DesignSystem.Typography.body)
                }
            }
            
            Button(action: { showingOptions = true }) {
                Label("Add Options", systemImage: "plus.circle")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(theme.primary)
            }
        }
        .sheet(isPresented: $showingOptions) {
            MultiSelectEditor(
                options: $options,
                selectedOptions: Binding(
                    get: { Set(selectedArray) },
                    set: { selectedOptions = Array($0).joined(separator: ",") }
                )
            )
        }
    }
}

struct MultiSelectEditor: View {
    @Binding var options: [String]
    @Binding var selectedOptions: Set<String>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColors) var theme
    
    var body: some View {
        NavigationView {
            List {
                ForEach(options, id: \.self) { option in
                    HStack {
                        Text(option)
                        Spacer()
                        if selectedOptions.contains(option) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.primary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedOptions.contains(option) {
                            selectedOptions.remove(option)
                        } else {
                            selectedOptions.insert(option)
                        }
                    }
                }
            }
            .navigationTitle("Select Options")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MultiSelectView(
        selectedOptions: .constant("Option 1,Option 2"),
        options: .constant(["Option 1", "Option 2", "Option 3"])
    )
    .withTheme()
} 