import SwiftUI

struct ElementToolbar: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach([
                    ("Image", "photo", ElementType.image),
                    ("Text", "text.alignleft", ElementType.textBlock),
                    ("Table", "tablecells", ElementType.table),
                    ("Dropdown", "chevron.down.circle", ElementType.dropdown),
                    ("Date", "calendar", ElementType.date),
                    ("Multi Selection", "checkmark.circle", ElementType.multiSelect),
                    ("Chart", "chart.bar", ElementType.chart),
                    ("Signature", "signature", ElementType.signature),
                    ("Header", "textformat", ElementType.header)
                ], id: \.0) { name, icon, type in
                    DraggableToolbarItem(name: name, type: type, icon: icon)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .frame(height: 80)
        .background(.ultraThinMaterial)
    }
}

struct DraggableToolbarItem: View {
    let name: String
    let type: ElementType
    let icon: String
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(theme.primary)
            Text(name)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(theme.secondary)
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(width: 80)
        .background(theme.button)
        .cornerRadius(12)
        .draggable(DocumentElement(type: type))
        .contentShape(Rectangle())
    }
} 