import SwiftUI

struct ElementPalette: View {
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.themeColors) var theme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Blocks")
                    .font(DesignSystem.Typography.black(size: 28))
                    .padding(.horizontal, 24)
                
                VStack(spacing: 8) {
                    ForEach([
                        ("Image", "photo", "Logo or graphic", ElementType.image),
                        ("Text", "text.alignleft", "Single line text", ElementType.textBlock),
                        ("Multiline Text", "text.quote", "Multiple lines", ElementType.textBlock),
                        ("Table", "tablecells", "Data grid", ElementType.table),
                        ("Dropdown", "chevron.down.circle", "Options list", ElementType.dropdown),
                        ("Date", "calendar", "Date & time", ElementType.date),
                        ("Multi Selection", "checkmark.circle", "Multiple choices", ElementType.multiSelect),
                        ("Chart", "chart.bar", "Data visualization", ElementType.chart),
                        ("Signature", "signature", "Digital signature", ElementType.signature),
                        ("Display Text", "textformat", "Large text", ElementType.header)
                    ], id: \.0) { name, icon, description, type in
                        DraggableElement(name: name, icon: icon, description: description, type: type, document: $document)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(theme.background)
    }
}

struct DraggableElement: View {
    let name: String
    let icon: String
    let description: String
    let type: ElementType
    @State private var isHovering = false
    @Binding var document: Letterspace_CanvasDocument
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: {
            document.elements.append(DocumentElement(type: type))
        }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 24)
                
                Text(name)
                    .font(DesignSystem.Typography.medium(size: 13))
                
                Spacer()
                
                Text(description)
                    .font(DesignSystem.Typography.light(size: 12))
                    .foregroundStyle(theme.secondaryMuted)
                
                Image(systemName: "grip.horizontal")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondaryMuted)
            }
            .padding(DesignSystem.Spacing.sm)
            .background(theme.button)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .draggable(DocumentElement(type: type))
        .background {
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.primary, lineWidth: 1.5)
                .opacity(isHovering ? 1 : 0)
        }
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .shadow(
            color: Color.black.opacity(0.2),
            radius: isHovering ? 4 : 0
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            withAnimation {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    ElementPalette(document: .constant(Letterspace_CanvasDocument()))
        .withTheme()
} 