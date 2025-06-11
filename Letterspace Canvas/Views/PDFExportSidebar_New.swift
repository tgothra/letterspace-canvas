import SwiftUI
#if os(macOS)
import AppKit
#endif

// This is a completely new implementation that can be used instead of PDFExportSidebar
struct PDFExportSidebar_New: View {
    @Binding var showDocumentTitle: Bool
    @Binding var showHeaderImage: Bool
    @Binding var showPageNumbers: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed layout for toggles
            VStack(alignment: .leading, spacing: 0) {
                // Document Title Toggle
                makeToggleRow(
                    title: "Hide Document Title",
                    isOn: Binding(
                        get: { !showDocumentTitle },
                        set: { showDocumentTitle = !$0 }
                    )
                )
                
                // Header Image Toggle
                makeToggleRow(
                    title: "Hide Header Image",
                    isOn: Binding(
                        get: { !showHeaderImage },
                        set: { showHeaderImage = !$0 }
                    )
                )
                
                // Page Numbers Toggle
                makeToggleRow(
                    title: "Show Page Numbers",
                    isOn: $showPageNumbers
                )
            }
            
            Spacer()
        }
        .padding(16)
    }
    
    // Helper function to create consistent toggle rows
    private func makeToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            
            Spacer()
            
            // Use a fixed-width container for the toggle
            ZStack(alignment: .trailing) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 50, height: 30)
                
                Toggle("", isOn: isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 8)
    }
}

// Preview for development
struct PDFExportSidebar_New_Previews: PreviewProvider {
    static var previews: some View {
        PDFExportSidebar_New(
            showDocumentTitle: .constant(true),
            showHeaderImage: .constant(true),
            showPageNumbers: .constant(false)
        )
        .frame(width: 250)
    }
} 