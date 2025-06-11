#if os(macOS)
import SwiftUI
import AppKit

// Custom toggle style that ensures consistent positioning
struct FixedPositionToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .opacity(0)
            
            // Use a ZStack to position the toggle in a fixed location
            ZStack {
                // Use the native toggle
                Toggle("", isOn: configuration.$isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .frame(width: 40, height: 22)
        }
    }
}

struct PDFExportSidebar: View {
    @Binding var showDocumentTitle: Bool
    @Binding var showHeaderImage: Bool
    @Binding var showPageNumbers: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Options with fixed layout
            VStack(alignment: .leading, spacing: 20) {
                // Document Title Toggle
                HStack {
                    Text("Hide Document Title")
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    // Use the custom toggle style
                    Toggle("Toggle", isOn: Binding(
                        get: { !showDocumentTitle },
                        set: { showDocumentTitle = !$0 }
                    ))
                    .toggleStyle(FixedPositionToggleStyle())
                }
                
                // Header Image Toggle
                HStack {
                    Text("Hide Header Image")
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    // Use the custom toggle style
                    Toggle("Toggle", isOn: Binding(
                        get: { !showHeaderImage },
                        set: { showHeaderImage = !$0 }
                    ))
                    .toggleStyle(FixedPositionToggleStyle())
                }
                
                // Page Numbers Toggle
                HStack {
                    Text("Show Page Numbers")
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    // Use the custom toggle style
                    Toggle("Toggle", isOn: $showPageNumbers)
                        .toggleStyle(FixedPositionToggleStyle())
                }
            }
            
            Spacer()
        }
        .padding(16)
    }
}

// Preview for development
struct PDFExportSidebar_Previews: PreviewProvider {
    static var previews: some View {
        PDFExportSidebar(
            showDocumentTitle: .constant(true),
            showHeaderImage: .constant(true),
            showPageNumbers: .constant(false)
        )
        .frame(width: 250)
    }
}
#endif 