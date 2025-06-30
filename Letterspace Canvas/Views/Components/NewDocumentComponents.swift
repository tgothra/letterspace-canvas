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
        VStack(spacing: 0) {
            #if os(iOS)
            // Header - Only show on iPad, macOS uses system popup title
            HStack {
                Text("Create New Document")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, -8)
            .padding(.bottom, 20)
            .background(theme.surface)
            
            Divider()
                .foregroundStyle(theme.secondary.opacity(0.2))
                .offset(y: -8)
            #endif
            
            // Content
        VStack(alignment: .leading, spacing: {
            #if os(macOS)
            return 8 // Tighter spacing for macOS
            #else
            return 12 // More spacious for iPad
            #endif
        }()) {
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
                HStack {
                    Image(systemName: "doc")
                        .font(.system(size: {
                            #if os(macOS)
                            return 13 // Smaller icon for macOS
                            #else
                            return 15 // Larger icon for iPad
                            #endif
                        }()))
                    Text("Blank Document")
                        .font(.system(size: {
                            #if os(macOS)
                            return 13 // Smaller text for macOS
                            #else
                            return 15 // Larger text for iPad
                            #endif
                        }()))
                }
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, {
                    #if os(macOS)
                    return 6 // Tighter horizontal padding for macOS
                    #else
                    return 8 // More padding for iPad
                    #endif
                }())
                .padding(.vertical, {
                    #if os(macOS)
                    return 6 // Smaller vertical padding for macOS
                    #else
                    return 9 // More padding for iPad touch targets
                    #endif
                }())
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.primary.opacity(hoveredItem == "blank" ? 0.05 : 0))
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered in
                hoveredItem = isHovered ? "blank" : nil
            }
            
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: {
                        #if os(macOS)
                        return 13 // Smaller icon for macOS
                        #else
                        return 15 // Larger icon for iPad
                        #endif
                    }()))
                Text("Templates")
                    .font(.system(size: {
                        #if os(macOS)
                        return 13 // Smaller text for macOS
                        #else
                        return 15 // Larger text for iPad
                        #endif
                    }()))
                Text("(Coming Soon)")
                    .font(.system(size: {
                        #if os(macOS)
                        return 13 // Smaller text for macOS
                        #else
                        return 15 // Larger text for iPad
                        #endif
                    }()))
                    .foregroundStyle(theme.secondary)
            }
            .foregroundStyle(theme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, {
                #if os(macOS)
                return 6 // Tighter horizontal padding for macOS
                #else
                return 8 // More padding for iPad
                #endif
            }())
            .padding(.vertical, {
                #if os(macOS)
                return 4 // Smaller vertical padding for macOS
                #else
                return 6 // More padding for iPad
                #endif
            }())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.primary.opacity(0.05))
            )
        }
            .padding({
                #if os(macOS)
                return 12 // Tighter overall padding for macOS compact design
                #else
                return 16 // More spacious padding for iPad
                #endif
            }())
        }
        .offset(y: -10)
    }
}
