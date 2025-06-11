#if os(macOS)
import SwiftUI
import AppKit

// Define custom TextField that can be focused
struct ScriptureBlockTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.font = .systemFont(ofSize: 14)
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.isBezeled = false
        textField.drawsBackground = false
        
        // Make it become first responder immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = textField.window {
                window.makeFirstResponder(textField)
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.placeholderString = placeholder
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ScriptureBlockTextField
        
        init(_ parent: ScriptureBlockTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

// Define the color theme struct
struct ScriptureBlockTheme {
    // ... existing code ...
}

class BibleSearchPopover: NSPopover {
    var onVerseSelect: ((DocumentElement) -> Void)?
    
    init(onVerseSelect: @escaping (DocumentElement) -> Void) {
        super.init()
        
        self.onVerseSelect = onVerseSelect
        self.behavior = .transient
        self.animates = true
        
        // Create the search view
        let searchView = ScriptureBlock { verse in
            self.close()
            var scriptureElement = DocumentElement(type: .scripture)
            scriptureElement.content = "\(verse.reference)|\(verse.translation)|\(verse.text)"
            onVerseSelect(scriptureElement)
        }
        
        // Create and configure the hosting view
        let hostingController = NSHostingController(rootView: searchView)
        self.contentViewController = hostingController
        self.contentSize = NSSize(width: 500, height: 400)
        
        // Force dark appearance
        self.appearance = NSAppearance(named: .darkAqua)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

struct ScriptureBlock: View {
    @State private var searchText = ""
    @State private var searchResults: [BibleVerse] = []
    @State private var selectedTranslation = "KJV"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.themeColors) var theme
    var onVerseSelect: ((BibleVerse) -> Void)?
    
    private let availableTranslations = ["KJV", "ASV", "WEB", "YLT"]
    
    init(onVerseSelect: ((BibleVerse) -> Void)? = nil) {
        self.onVerseSelect = onVerseSelect
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Search bar and translations
            HStack(spacing: 8) {
                // Translations
                ForEach(availableTranslations, id: \.self) { translation in
                    Button(action: {
                        selectedTranslation = translation
                        if !searchText.isEmpty {
                            searchBibleVerse()
                        }
                    }) {
                        Text(translation)
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedTranslation == translation ? 
                                theme.accent.opacity(0.2) : 
                                theme.surface)
                            .foregroundStyle(selectedTranslation == translation ?
                                theme.accent :
                                theme.secondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Search field
            HStack {
                ScriptureBlockTextField(
                    text: $searchText,
                    placeholder: "Search Bible verses...",
                    onSubmit: searchBibleVerse
                )
                .frame(maxWidth: .infinity)
                
                Button("Search") {
                    searchBibleVerse()
                }
            }
            .padding(.horizontal)
            
            // Loading, error, or results
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding()
            } else if !searchResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(searchResults) { verse in
                            Button(action: {
                                onVerseSelect?(verse)
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verse.reference)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(theme.secondary)
                                    Text(verse.text)
                                        .font(.system(size: 14))
                                        .foregroundStyle(theme.primary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.surface)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .background(theme.background)
        .cornerRadius(8)
    }
    
    private func searchBibleVerse() {
        guard !searchText.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await BibleAPI.searchVerses(
                    query: searchText,
                    translation: selectedTranslation,
                    mode: .reference
                )
                await MainActor.run {
                    searchResults = result.verses
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// Preview provider for SwiftUI canvas
struct ScriptureBlock_Previews: PreviewProvider {
    static var previews: some View {
        ScriptureBlock()
    }
}
#endif 
