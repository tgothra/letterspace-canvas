#if os(iOS)
import SwiftUI
import UIKit

struct SimpleKeyboardToolbar: View {
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                Image(systemName: "bold")
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {}) {
                Image(systemName: "italic")
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {}) {
                Image(systemName: "textformat")
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button(action: dismissKeyboard) {
                Image(systemName: "keyboard.chevron.compact.down")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color(UIColor.systemGray6))
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
