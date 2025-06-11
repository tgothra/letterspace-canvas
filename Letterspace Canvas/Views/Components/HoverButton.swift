import SwiftUI 
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
// HoverButton for variation items
struct HoverButton: View {
    let title: String
    let label: String
    let subtitle: String?
    let date: Date?
    let onHover: (Bool) -> Void
    @State private var isHovering = false
    
    init(title: String, label: String, subtitle: String? = nil, date: Date? = nil, onHover: @escaping (Bool) -> Void) {
        self.title = title
        self.label = label
        self.subtitle = subtitle
        self.date = date
        self.onHover = onHover
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.medium(size: 12))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                
                Spacer()
                
                Text(label)
                    .font(DesignSystem.Typography.regular(size: 10))
                    #if os(macOS)
                    .foregroundStyle(Color(.secondaryLabelColor))
                    #elseif os(iOS)
                    .foregroundStyle(Color(.secondaryLabel))
                    #endif
            }
            
            if subtitle != nil || date != nil {
                HStack {
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(DesignSystem.Typography.regular(size: 10))
                            #if os(macOS)
                            .foregroundStyle(Color(.secondaryLabelColor))
                            #elseif os(iOS)
                            .foregroundStyle(Color(.secondaryLabel))
                            #endif
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if let date = date {
                        Text(formatDate(date))
                            .font(DesignSystem.Typography.regular(size: 10))
                            #if os(macOS)
                            .foregroundStyle(Color(.secondaryLabelColor))
                            #elseif os(iOS)
                            .foregroundStyle(Color(.secondaryLabel))
                            #endif
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "#22c27d").opacity(0.1))
                    .opacity(isHovering ? 1 : 0)
                
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black, lineWidth: 1)
            }
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
                onHover(hovering)
            }
        }
    }
}
