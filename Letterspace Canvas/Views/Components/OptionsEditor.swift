import SwiftUI

struct OptionsEditor: View {
    @Binding var options: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var newOption = ""
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(options, id: \.self) { option in
                        Text(option)
                    }
                    .onDelete { options.remove(atOffsets: $0) }
                    
                    HStack {
                        TextField("New option", text: $newOption)
                        Button("Add") {
                            if !newOption.isEmpty {
                                options.append(newOption)
                                newOption = ""
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Options")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    OptionsEditor(options: .constant(["Option 1", "Option 2"]))
} 