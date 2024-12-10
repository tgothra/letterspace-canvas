import SwiftUI
import AppKit

struct DocumentEditor: View {
    @State private var documentText: String = ""
    @State private var isEditing: Bool = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        ScrollView {
            TextEditor(text: $documentText)
                // Use system font for better legibility
                .font(.custom("InterTight-Regular", size: 16))
                // Remove padding to maximize editing space
                .padding(.horizontal, 0)
                // Use theme colors for consistency
                .foregroundColor(theme.primary)
                .background(theme.background)
                // Remove visual decorations for cleaner look
                .cornerRadius(0)
                // Support full-screen editing
                .frame(maxWidth: .infinity, minHeight: 800)
                // Add focus state handling
                .focused($isEditing)
                // Support for system features
                .textSelection(.enabled)
        }
        .background(theme.background)
        // Remove extra padding to maximize space
        .padding(0)
    }
}

struct DocumentEditor_Previews: PreviewProvider {
    static var previews: some View {
        DocumentEditor()
    }
} 