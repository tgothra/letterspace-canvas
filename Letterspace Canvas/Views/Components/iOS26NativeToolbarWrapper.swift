#if os(iOS)
import SwiftUI
import UIKit

// MARK: - iOS 26 Native Toolbar Wrapper
@available(iOS 26.0, *)
struct iOS26NativeToolbarWrapper: View {
    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    @State private var nativeTextService = iOS26NativeTextService.shared
    @State private var showColorPicker = false
    @State private var showHighlightPicker = false
    @State private var showStylePicker = false
    @State private var showAlignmentPicker = false
    @State private var showLinkPicker = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Text Style
                styleButton
                
                Divider()
                    .frame(height: 20)
                
                // Basic Formatting
                basicFormattingButtons
                
                Divider()
                    .frame(height: 20)
                
                // Color Controls
                colorControls
                
                Divider()
                    .frame(height: 20)
                
                // Alignment
                alignmentButton
                
                Divider()
                    .frame(height: 20)
                
                // Advanced Features
                advancedFeatures
                
                Divider()
                    .frame(height: 20)
                
                // Sermon-Specific Features
                sermonFeatures
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 50)
        .background(Color(UIColor.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.systemGray4)),
            alignment: .top
        )
    }
    
    // MARK: - Style Button
    private var styleButton: some View {
        Button(action: {
            showStylePicker.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                Text("Style")
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.primary)
        }
        .popover(isPresented: $showStylePicker) {
            stylePickerView
        }
    }
    
    private var stylePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            stylePickerButton("Title", style: "title")
            stylePickerButton("Heading", style: "heading")
            stylePickerButton("Subheading", style: "subheading")
            stylePickerButton("Body", style: "body")
            stylePickerButton("Caption", style: "caption")
        }
        .padding()
        .frame(minWidth: 120)
    }
    
    private func stylePickerButton(_ label: String, style: String) -> some View {
        Button(label) {
            nativeTextService.applyTextStyle(style, text: &text, selection: &selection)
            showStylePicker = false
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Basic Formatting
    private var basicFormattingButtons: some View {
        HStack(spacing: 8) {
            formatButton(
                icon: "bold",
                isActive: currentFormatting.isBold,
                action: { nativeTextService.toggleBold(text: &text, selection: &selection) }
            )
            
            formatButton(
                icon: "italic",
                isActive: currentFormatting.isItalic,
                action: { nativeTextService.toggleItalic(text: &text, selection: &selection) }
            )
            
            formatButton(
                icon: "underline",
                isActive: currentFormatting.isUnderlined,
                action: { nativeTextService.toggleUnderline(text: &text, selection: &selection) }
            )
        }
    }
    
    // MARK: - Color Controls
    private var colorControls: some View {
        HStack(spacing: 8) {
            Button(action: {
                showColorPicker.toggle()
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "textformat")
                    Rectangle()
                        .frame(width: 12, height: 3)
                        .foregroundColor(currentFormatting.textColor ?? .primary)
                }
                .foregroundColor(.primary)
            }
            .popover(isPresented: $showColorPicker) {
                colorPickerView(isHighlight: false)
            }
            
            Button(action: {
                showHighlightPicker.toggle()
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "highlighter")
                    Rectangle()
                        .frame(width: 12, height: 3)
                        .foregroundColor(currentFormatting.backgroundColor ?? .clear)
                }
                .foregroundColor(.primary)
            }
            .popover(isPresented: $showHighlightPicker) {
                colorPickerView(isHighlight: true)
            }
        }
    }
    
    private func colorPickerView(isHighlight: Bool) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 4), spacing: 8) {
            ForEach(colorOptions, id: \.self) { color in
                Button(action: {
                    if isHighlight {
                        nativeTextService.applyHighlight(color, text: &text, selection: &selection)
                        showHighlightPicker = false
                    } else {
                        nativeTextService.applyTextColor(color, text: &text, selection: &selection)
                        showColorPicker = false
                    }
                }) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 0.5)
                        )
                }
            }
        }
        .padding()
        .frame(width: 160)
    }
    
    private var colorOptions: [Color] {
        [
            .black, .red, .blue, .green,
            .orange, .purple, .pink, .yellow,
            .gray, .brown, .cyan, .mint
        ]
    }
    
    // MARK: - Alignment
    private var alignmentButton: some View {
        Button(action: {
            showAlignmentPicker.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: alignmentIcon)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.primary)
        }
        .popover(isPresented: $showAlignmentPicker) {
            alignmentPickerView
        }
    }
    
    private var alignmentIcon: String {
        switch currentFormatting.alignment {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }
    
    private var alignmentPickerView: some View {
        VStack(spacing: 8) {
            alignmentPickerButton("Left", alignment: .leading, icon: "text.alignleft")
            alignmentPickerButton("Center", alignment: .center, icon: "text.aligncenter")
            alignmentPickerButton("Right", alignment: .trailing, icon: "text.alignright")
        }
        .padding()
        .frame(minWidth: 100)
    }
    
    private func alignmentPickerButton(_ label: String, alignment: TextAlignment, icon: String) -> some View {
        Button(action: {
            nativeTextService.applyAlignment(alignment, text: &text, selection: &selection)
            showAlignmentPicker = false
        }) {
            HStack {
                Image(systemName: icon)
                Text(label)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Advanced Features
    private var advancedFeatures: some View {
        HStack(spacing: 8) {
            formatButton(
                icon: "list.bullet",
                isActive: false, // TODO: Detect bullet list
                action: { nativeTextService.toggleBulletList(text: &text, selection: &selection) }
            )
            
            Button(action: {
                showLinkPicker.toggle()
            }) {
                Image(systemName: currentFormatting.hasLink ? "link.circle.fill" : "link")
                    .foregroundColor(currentFormatting.hasLink ? .blue : .primary)
            }
            .popover(isPresented: $showLinkPicker) {
                linkPickerView
            }
        }
    }
    
    private var linkPickerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Link")
                .font(.headline)
            
            TextField("Link Text", text: .constant(getSelectedText()))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("URL", text: .constant(""))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button("Cancel") {
                    showLinkPicker = false
                }
                
                Spacer()
                
                Button("Add") {
                    nativeTextService.insertLink(
                        linkText: getSelectedText(),
                        linkURL: "https://example.com",
                        text: &text,
                        selection: &selection
                    )
                    showLinkPicker = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 250)
    }
    
    // MARK: - Sermon Features
    private var sermonFeatures: some View {
        HStack(spacing: 8) {
            formatButton(
                icon: "book.bible",
                isActive: false,
                action: { nativeTextService.highlightAsScripture(text: &text, selection: &selection) }
            )
            
            formatButton(
                icon: "bookmark",
                isActive: false, // TODO: Detect bookmark
                action: { nativeTextService.toggleBookmark(text: &text, selection: &selection) }
            )
        }
    }
    
    // MARK: - Helper Views
    private func formatButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(isActive ? .white : .primary)
                .frame(width: 24, height: 24)
                .background(isActive ? Color.blue : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
    
    // MARK: - Helper Functions
    private var currentFormatting: FormattingState {
        nativeTextService.getCurrentFormatting(text: text, selection: selection)
    }
    
    private func getSelectedText() -> String {
        guard case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty else {
            return ""
        }
        return String(text[ranges].characters)
    }
}

// MARK: - Preview
@available(iOS 26.0, *)
struct iOS26NativeToolbarWrapper_Previews: PreviewProvider {
    static var previews: some View {
        iOS26NativeToolbarWrapper(
            text: .constant(AttributedString("Sample text for formatting")),
            selection: .constant(AttributedTextSelection())
        )
    }
} 
#endif

