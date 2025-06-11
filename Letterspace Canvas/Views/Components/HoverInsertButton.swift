#if os(macOS)
import SwiftUI
import AppKit

struct HoverInsertButton: View {
    let lineRect: CGRect
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color(.windowBackgroundColor)))
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .position(x: -12, y: lineRect.midY)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .contentShape(Circle())
        .allowsHitTesting(true)
    }
}
#endif 