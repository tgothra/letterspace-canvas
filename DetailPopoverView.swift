import SwiftUI

struct DetailPopoverView: View {
    @State private var isEditing = false
    @Binding var item: YourItemType // Replace with your actual model type
    
    var body: some View {
        NavigationView {
            Form {
                // Example form fields - replace with your actual fields
                Section {
                    if isEditing {
                        TextField("Title", text: $item.title)
                    } else {
                        Text(item.title)
                            .foregroundColor(.primary)
                    }
                    
                    if isEditing {
                        TextField("Description", text: $item.description)
                    } else {
                        Text(item.description)
                            .foregroundColor(.primary)
                    }
                    
                    // Add more fields following the same pattern
                }
            }
            .navigationTitle("Details")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }
                }
            }
        }
    }
}

// Preview provider for SwiftUI canvas
struct DetailPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        DetailPopoverView(item: .constant(YourItemType.preview)) // Add a preview item
    }
}
