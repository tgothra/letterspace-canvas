#if os(iOS)
import SwiftUI
import UIKit

// MARK: - iOS 26 Sophisticated Toolbar (Extracted from iOS26NativeTextEditorWithToolbar)
@available(iOS 26.0, *)
struct iOS26SophisticatedToolbar: View {
    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    
    // State management from iOS26NativeTextEditorWithToolbar
    @State private var activeInlinePicker: InlinePicker = .none
    @State private var currentTextColor: Color = .primary
    @State private var currentHighlightColor: Color = .clear
    @State private var currentUnderlineColor: Color = .clear
    @State private var currentIsBold: Bool = false
    @State private var currentIsItalic: Bool = false
    
    // Exclusive picker state management
    enum InlinePicker {
        case none, textColor, highlightColor, underlineColor
    }
    
    // Color arrays for compact picker
    private var textColors: [Color] {
        [.clear, .gray, .blue, .green, .yellow, .red, .orange, .purple, .pink, .brown, .primary]
    }
    
    private var highlightColors: [Color] {
        [.clear, .yellow, .green, .blue, .pink, .purple, .orange]
    }
    
    private var underlineColors: [Color] {
        [.clear, .blue, .green, .yellow, .red, .orange, .purple, .pink, .brown, .primary, .black]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.systemGray4))
            
            if activeInlinePicker != .none {
                // Inline picker view
                inlinePickerView
            } else {
                // Main toolbar
                mainToolbarView
            }
        }
        .frame(height: activeInlinePicker != .none ? 44 : 44)
        .background(Color(UIColor.systemGray6))
    }
    
    // MARK: - Main Toolbar
    private var mainToolbarView: some View {
        HStack(spacing: 12) {
            // Bold
            Button(action: { applyBold() }) {
                ZStack {
                    Image(systemName: "bold")
                        .foregroundColor(.primary)
                    
                    // Blue indicator for active bold
                    if currentIsBold {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(UIColor.systemBackground), lineWidth: 1)
                                    .frame(width: 8, height: 8)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Italic
            Button(action: { applyItalic() }) {
                ZStack {
                    Image(systemName: "italic")
                        .foregroundColor(.primary)
                    
                    // Blue indicator for active italic
                    if currentIsItalic {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 1)
                                    .frame(width: 8, height: 8)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Underline
            Button(action: {
                withAnimation {
                    activeInlinePicker = activeInlinePicker == .underlineColor ? .none : .underlineColor
                }
            }) {
                ZStack {
                    Image(systemName: "underline")
                        .foregroundColor(.primary)
                    
                    // Color indicator circle
                    if currentUnderlineColor != .clear {
                        Circle()
                            .fill(currentUnderlineColor)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 1)
                                    .frame(width: 8, height: 8)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Text Color
            Button(action: {
                withAnimation {
                    activeInlinePicker = activeInlinePicker == .textColor ? .none : .textColor
                }
            }) {
                ZStack {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.primary)
                    
                    // Color indicator circle
                    if currentTextColor != .primary {
                        Circle()
                            .fill(currentTextColor)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 1)
                                    .frame(width: 8, height: 8)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Highlight
            Button(action: {
                withAnimation {
                    activeInlinePicker = activeInlinePicker == .highlightColor ? .none : .highlightColor
                }
            }) {
                ZStack {
                    Image(systemName: "highlighter")
                        .foregroundColor(.primary)
                    
                    // Color indicator circle
                    if currentHighlightColor != .clear {
                        Circle()
                            .fill(currentHighlightColor)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 1)
                                    .frame(width: 8, height: 8)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Keyboard dismiss
            Button(action: dismissKeyboard) {
                Image(systemName: "keyboard.chevron.compact.down")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
    
    // MARK: - Inline Picker View
    private var inlinePickerView: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    activeInlinePicker = .none
                }
            }) {
                Image(systemName: "arrow.left")
            }
            .buttonStyle(PlainButtonStyle())
            
            // Color picker scroll view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(getColorsForActivePicker(), id: \.self) { color in
                        Button(action: {
                            applyColor(color)
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                activeInlinePicker = .none
                            }
                        }) {
                            Circle()
                                .fill(color == .clear ? Color.white : color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                                        .frame(width: 28, height: 28)
                                )
                                .overlay(
                                    // X for clear color
                                    color == .clear ? 
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundColor(.primary) : nil
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: activeInlinePicker)
    }
    
    // MARK: - Helper Functions
    private func getColorsForActivePicker() -> [Color] {
        switch activeInlinePicker {
        case .textColor:
            return textColors
        case .highlightColor:
            return highlightColors
        case .underlineColor:
            return underlineColors
        case .none:
            return []
        }
    }
    
    private func applyColor(_ color: Color) {
        switch activeInlinePicker {
        case .textColor:
            applyTextColor(color)
            currentTextColor = color
        case .highlightColor:
            applyHighlightColor(color)
            currentHighlightColor = color
        case .underlineColor:
            applyUnderlineColor(color)
            currentUnderlineColor = color
        case .none:
            break
        }
    }
    
    // MARK: - Formatting Functions (Basic implementations - you can enhance these)
    private func applyBold() {
        currentIsBold.toggle()
        print("Apply bold: \(currentIsBold)")
    }
    
    private func applyItalic() {
        currentIsItalic.toggle()
        print("Apply italic: \(currentIsItalic)")
    }
    
    private func applyTextColor(_ color: Color) {
        print("Apply text color: \(color)")
    }
    
    private func applyHighlightColor(_ color: Color) {
        print("Apply highlight color: \(color)")
    }
    
    private func applyUnderlineColor(_ color: Color) {
        print("Apply underline color: \(color)")
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
