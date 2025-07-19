import SwiftUI

struct NewDocumentPopupContent: View {
    @Environment(\.themeColors) var theme
    @State private var hoveredItem: String?
    @Binding var showTemplateBrowser: Bool
    @Binding var activePopup: ActivePopup
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    
    var body: some View {
        // Content (no header since it's added by the popover)
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                print("Creating new blank document")
                // Create document with a stable ID
                let docId = UUID().uuidString
                
                // Create new blank document with completely fresh state
                var newDocument = Letterspace_CanvasDocument(
                    title: "Untitled",
                    subtitle: "",
                    // Explicitly create a new empty text element
                    elements: [
                        DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")
                    ],
                    id: docId,
                    // Reset all document properties
                    markers: [],
                    series: nil,
                    variations: [],
                    isVariation: false,
                    parentVariationId: nil,
                    createdAt: Date(),
                    modifiedAt: Date(),
                    tags: nil,
                    isHeaderExpanded: false,  // Explicitly set to false for new documents
                    isSubtitleVisible: true,
                    links: []
                )
                
                // Save the new document first
                newDocument.save()
                
                // Wait a brief moment to ensure file is written
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Open the new document
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)) {
                        document = newDocument
                        sidebarMode = .details
                        isRightSidebarVisible = true
                        activePopup = .none
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.primary)
                    Text("Blank Document")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.primary.opacity(hoveredItem == "blank" ? 0.08 : 0))
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered in
                hoveredItem = isHovered ? "blank" : nil
            }
            
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.secondary)
                Text("Templates")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.secondary)
                Text("(Coming Soon)")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondary.opacity(0.7))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.secondary.opacity(0.05))
            )
        }
        .padding(16) // Reduced padding to fit better with header
    }
}
