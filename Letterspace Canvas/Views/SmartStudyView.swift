import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit // For UIImage, UIResponder, etc.
#endif
import Combine
#if !os(watchOS) // WKWebView not on watchOS
import WebKit
#endif
#if !os(watchOS) && os(iOS)
import QuickLook // For QLPreviewController
#endif

// MARK: - Extension for Markdown parsing
extension String {
    func markdownToHTML(sourceDocumentTitleForLinking: String? = nil) -> String {
        var htmlContent = self
        
        // If a source document title is provided, replace placeholder with a link
        if let title = sourceDocumentTitleForLinking {
            // This is a simple placeholder. The AI needs to be instructed to output this exact string.
            let placeholder = "[Library Document]"
            // More specific placeholder if the AI can be told to include the title:
            // let placeholderWithTitle = "[Library Document: \(title)]"
            
            // Create a custom scheme link that the WKWebView can intercept
            let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            let linkHTML = "<a href=\"letterspace://open-pdf/\(encodedTitle)\" style=\"color: #1a73e8; text-decoration: underline;\">\(title) (Library Document)</a>"
            
            htmlContent = htmlContent.replacingOccurrences(of: placeholder, with: linkHTML)
            // If using the more specific placeholder:
            // htmlContent = htmlContent.replacingOccurrences(of: placeholderWithTitle, with: linkHTML)
        }
        
        // Special handling for Greek/Hebrew definitions 
        // Pattern: Greek word (transliteration): Translation (grammatical notes)
        htmlContent = htmlContent.replacingOccurrences(
            of: "([^\\n]+) \\(([^\\)]+)\\): ([^\\(]+) \\(([^\\)]+)\\)",
            with: """
            <div class="word-definition">
                <div class="term-row">
                    <span class="original-word">$1</span>
                    <span class="transliteration">($2)</span>
                    <span class="colon">:</span>
                    <span class="translation">$3</span>
                    <span class="grammar">($4)</span>
                </div>
            </div>
            """,
            options: .regularExpression
        )
        
        // Handle bullet points before/after word definitions
        htmlContent = htmlContent.replacingOccurrences(
            of: "<div class=\"word-definition\">\n<div class=\"term-row\">\n<span class=\"original-word\">•\\s+([^<]+)</span>",
            with: "<div class=\"word-definition\">\n<div class=\"term-row\">\n<span class=\"original-word\">$1</span>",
            options: .regularExpression
        )
        
        // Handle secondary definitions (with bullet points)
        htmlContent = htmlContent.replacingOccurrences(
            of: "• ([^:]+): ([^\\n]+)",
            with: """
            <div class="secondary-definition">
                <span class="bullet">•</span>
                <span class="term">$1:</span>
                <span class="meaning">$2</span>
            </div>
            """,
            options: .regularExpression
        )
        
        // Convert headers (### Header:) to styled HTML headers
        htmlContent = htmlContent.replacingOccurrences(
            of: "### ([^\\n]+)",
            with: "<h3 style='font-size: 16px; margin-top: 20px; margin-bottom: 10px; font-weight: 600; color: #202124;'>$1</h3>",
            options: .regularExpression
        )
        
        // Convert ## headers (for section titles)
        htmlContent = htmlContent.replacingOccurrences(
            of: "## ([^\\n]+)",
            with: "<h2 style='font-size: 18px; margin-top: 24px; margin-bottom: 12px; font-weight: 600; color: #202124;'>$1</h2>",
            options: .regularExpression
        )
        
        // Replace bullet points with proper HTML bullets
        htmlContent = htmlContent.replacingOccurrences(
            of: "- ([^\\n]+)",
            with: "<li style='margin-bottom: 8px; line-height: 1.5;'>$1</li>",
            options: .regularExpression
        )
        
        // Wrap bullet point lists in <ul> tags
        htmlContent = htmlContent.replacingOccurrences(
            of: "(<li[^>]*>[\\s\\S]*?</li>\\s*)(<li[^>]*>[\\s\\S]*?</li>\\s*)+",
            with: "<ul style='padding-left: 24px; margin-top: 12px; margin-bottom: 16px;'>$0</ul>",
            options: .regularExpression
        )
        
        // Convert paragraphs (text blocks separated by newlines)
        let paragraphs = htmlContent.components(separatedBy: "\n\n")
        htmlContent = paragraphs.map { paragraph in
            // Skip already processed HTML elements
            if paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               paragraph.contains("<h2") || paragraph.contains("<h3") || 
               paragraph.contains("<ul") || paragraph.contains("<li") ||
               paragraph.contains("<div class=\"word-definition\"") {
                return paragraph
            }
            return "<p style='margin-bottom: 16px; line-height: 1.5;'>\(paragraph)</p>"
        }.joined(separator: "\n")
        
        // Convert bold text
        htmlContent = htmlContent.replacingOccurrences(
            of: "\\*\\*([^*]+)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        
        // Convert italic text to regular text instead of using <em> tags
        htmlContent = htmlContent.replacingOccurrences(
            of: "\\*([^*]+)\\*",
            with: "$1",
            options: .regularExpression
        )
        
        // If a specific document title is provided for linking (meaning an answer was likely sourced from it),
        // find instances of "Source: [DOCUMENT_TITLE]" in the AI's response and make them clickable.
        if let titleToLink = sourceDocumentTitleForLinking {
            // Regex to find "Source: EOY Giving Letter - ACW Family.pdf"
            // It will capture the actual title found by the regex.
            // Using raw string literal for the regex pattern to avoid escaping issues:
            let regexPattern = #"Source: \"?([^\"\n]+)\"?([.\n]|$)"#
            
            do {
                let regex = try NSRegularExpression(pattern: regexPattern, options: [])
                let nsRange = NSRange(htmlContent.startIndex..<htmlContent.endIndex, in: htmlContent)
                
                let matches = regex.matches(in: htmlContent, options: [], range: nsRange)
                
                // Iterate backwards to avoid range issues when replacing
                for match in matches.reversed() {
                    if let capturedTitleRange = Range(match.range(at: 1), in: htmlContent) {
                        let capturedTitle = String(htmlContent[capturedTitleRange])
                        
                        // Only create a link if the captured title matches the title we expect to link
                        // (This ensures we only link the *correct* source if multiple are mentioned non-specifically)
                        // For more flexibility, we could link any title found if sourceDocumentTitleForLinking is nil
                        // or if we want to link all mentioned sources.
                        if capturedTitle.trimmingCharacters(in: .whitespacesAndNewlines) == titleToLink.trimmingCharacters(in: .whitespacesAndNewlines) {
                            let encodedTitle = capturedTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
                            let linkHTML = "<strong>Source:</strong> <a href=\"letterspace://open-pdf/\(encodedTitle)\" style=\"color: #1a73e8; text-decoration: underline;\">\(capturedTitle)</a>"
                            
                            if let rangeToReplace = Range(match.range, in: htmlContent) {
                                htmlContent.replaceSubrange(rangeToReplace, with: linkHTML)
                                print("🔗 Created link for source: \(capturedTitle)")
                            }
                        }
                    }
                }
            } catch {
                print("Error creating regex for source link: \(error)")
            }
        }
        
        // Wrap in a complete HTML document with styling
        htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
                    line-height: 1.5;
                    color: #202124;
                    font-size: 14px;
                    padding: 8px;
                    margin: 0;
                }
                
                ul {
                    list-style-type: disc;
                }
                
                p {
                    margin-top: 0;
                }
                
                h2, h3 {
                    margin-top: 20px;
                    margin-bottom: 10px;
                }
                
                /* Definition styling */
                .word-definition {
                    margin-bottom: 16px;
                    padding: 10px;
                    background-color: #f8f9fa;
                    border-radius: 8px;
                    border-left: 3px solid #4285f4;
                }
                
                .term-row {
                    display: flex;
                    flex-wrap: wrap;
                    align-items: baseline;
                    margin-bottom: 6px;
                }
                
                .original-word {
                    font-weight: bold;
                    font-size: 16px;
                    margin-right: 5px;
                    color: #1a73e8;
                }
                
                .transliteration {
                    font-style: italic;
                    color: #5f6368;
                    margin-right: 5px;
                }
                
                .colon {
                    margin-right: 5px;
                }
                
                .translation {
                    font-weight: 500;
                    margin-right: 5px;
                }
                
                .grammar {
                    color: #5f6368;
                    font-style: italic;
                }
                
                .secondary-definition {
                    margin-left: 20px;
                    margin-bottom: 8px;
                    display: flex;
                }
                
                .bullet {
                    margin-right: 5px;
                    color: #4285f4;
                }
                
                .term {
                    font-weight: 500;
                    margin-right: 5px;
                }
                
                .meaning {
                    color: #202124;
                }
            </style>
        </head>
        <body>
        \(htmlContent)
        </body>
        </html>
        """
        
        return htmlContent
    }
}

// MARK: - Web View for Rich Text
#if !os(watchOS)
struct RichTextWebView: PlatformViewRepresentable {
    var htmlContent: String
    var onOpenPDF: (String) -> Void

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
        context.coordinator.parent = self
    }
    #elseif os(iOS)
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
        context.coordinator.parent = self
    }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: RichTextWebView

        init(_ parent: RichTextWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.scheme == "letterspace", url.host == "open-pdf" {
                let documentTitle = url.lastPathComponent.removingPercentEncoding ?? ""
                if !documentTitle.isEmpty {
                    parent.onOpenPDF(documentTitle)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
#endif

// Define PlatformViewRepresentable
#if os(macOS)
protocol PlatformViewRepresentable: NSViewRepresentable { }
#elseif os(iOS)
protocol PlatformViewRepresentable: UIViewRepresentable { }
#else // Other platforms like watchOS if ever supported, or as a fallback
protocol PlatformViewRepresentable: View { }
#endif

// MARK: - Auto-focusing Text Field
#if os(macOS)
struct GeminiFocusedTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    
    init(text: Binding<String>, placeholder: String, onSubmit: @escaping () -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }
    
    func makeNSView(context: Context) -> CustomTextField {
        let textField = CustomTextField()
        textField.placeholderString = placeholder
        textField.font = .systemFont(ofSize: 14)
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.bezelStyle = .roundedBezel
        
        textField.refusesFirstResponder = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = textField.window {
                window.makeFirstResponder(textField)
                _ = textField.becomeFirstResponder()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let window = textField.window {
                window.makeFirstResponder(textField)
                if window.firstResponder != textField {
                    _ = textField.becomeFirstResponder()
                    if let panel = window.parent {
                        panel.orderFront(nil)
                        panel.makeKeyAndOrderFront(nil)
                        panel.makeFirstResponder(textField)
                    }
                }
            }
        }
        return textField
    }
    
    func updateNSView(_ nsView: CustomTextField, context: Context) {
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: GeminiFocusedTextField
        init(_ parent: GeminiFocusedTextField) {
            self.parent = parent
        }
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
    
    class CustomTextField: NSTextField {
        override var acceptsFirstResponder: Bool { return true }
        override func becomeFirstResponder() -> Bool {
            let success = super.becomeFirstResponder()
            print("⌨️ macOS TextField becomeFirstResponder: \(success)")
            return success
        }
    }
}
#elseif os(iOS)
struct GeminiFocusedTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    init(text: Binding<String>, placeholder: String, onSubmit: @escaping () -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.placeholder = placeholder
        textField.font = .systemFont(ofSize: 14)
        textField.delegate = context.coordinator
        textField.returnKeyType = .done
        
        // Styling to match macOS version (borderless, clear background)
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        
        // Request focus when the view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textField.becomeFirstResponder()
        }
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update the text field if the text is actually different
        // This prevents the keyboard from dismissing due to unnecessary updates
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: GeminiFocusedTextField

        init(_ parent: GeminiFocusedTextField) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Update text binding as user types
            let currentText = textField.text ?? ""
            if let textRange = Range(range, in: currentText) {
                let newText = currentText.replacingCharacters(in: textRange, with: string)
                parent.text = newText
            }
            return true
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            textField.resignFirstResponder()
            return true
        }
    }
}
#endif

// MARK: - Smart Study Main View

// Enum for Search Scope
enum SearchScope: String, CaseIterable, Identifiable {
    case allSources = "All Sources"
    case internetOnly = "Internet Only"
    case libraryOnly = "My PDF Library Only"
    // We can add specific PDF selection later if needed
    case bibleKnowledgeOnly = "Bible Knowledge Only"
    
    var id: String { self.rawValue }
    
    // Short display names for iPhone
    var shortDisplayName: String {
        switch self {
        case .allSources:
            return "All"
        case .internetOnly:
            return "Web"
        case .libraryOnly:
            return "Library"
        case .bibleKnowledgeOnly:
            return "Bible"
        }
    }
}

struct SmartStudyView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    // Add an explicit dismiss handler
    var onDismiss: () -> Void
    
    // View Models and Services
    @StateObject private var libraryService = UserLibraryService()
    @ObservedObject private var tokenService = TokenUsageService.shared
    
    // UI State
    @State private var userQuery = ""
    @State private var answer = ""
    @State private var isLoading = false
    @State private var savedQAs: [SmartStudyEntry] = []
    @State private var errorMessage: String? = nil
    @State private var hoverStates: [String: Bool] = [:]
    @State private var deleteButtonHover: String? = nil
    @State private var showUpgradeModal = false
    @State private var hoverCloseButton = false
    @State private var showLibrarySheet = false
    @State private var showSavedQuestionsSidebar = true
    @State private var showingPastStudiesSheet = false // For iPhone past studies modal
    @State private var hoverLibraryButton = false
    @State private var hoverSidebarButton = false
    
    // Add state for internet search
    @State private var useInternetSearch = true // Default to enabled
    @State private var searchQueries: [String] = []
    @State private var hoverSearchToggle = false
    
    // Add state for search scope
    @State private var selectedScope: SearchScope = .allSources
    
    // New state variable
    @State private var sourceDocumentTitleForAnswer: String? = nil
    @State private var scriptureReferences: [ScriptureReference] = []
    @State private var consolidatedChapterReferences: [ConsolidatedChapterReference] = []
    @State private var showingScripturePopup = false
    @State private var selectedScriptureReference: ScriptureReference? = nil
    @State private var hoveredScriptureReference: ScriptureReference? = nil
    @State private var scripturePreviewText: String = ""
    @State private var isLoadingPreview: Bool = false
    @State private var scripturePopoverStates: [String: Bool] = [:]
    @State private var chapterPopoverStates: [String: Bool] = [:]
    @State private var popoverScriptureReference: ScriptureReference? = nil
    @State private var popoverChapterReference: ConsolidatedChapterReference? = nil
    @State private var popoverHoverStates: [String: Bool] = [:]
    @State private var scriptureCache: [String: String] = [:]
    @State private var currentLoadingTask: Task<Void, Never>? = nil
    
    // For PDF Preview on iOS
    #if os(iOS)
    @State private var pdfPreviewURL: URL? = nil
    @State private var showingPdfPreview = false
    #endif
    
    var body: some View {
        mainContentView
            .onAppear {
                loadSavedQAs()
                
                #if os(macOS)
                // Force input field to be focusable
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: NSNotification.Name("FocusSmartStudyTextField"), object: nil)
                    
                    if let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.isKeyWindow }),
                       let hostingView = window.contentView?.subviews.first(where: { String(describing: type(of: $0)).contains("NSHostingView") }),
                       let textField = hostingView.firstSubview(ofType: NSTextField.self) {
                        window.makeFirstResponder(textField)
                    }
                }
                #elseif os(iOS)
                // On iOS, focus is handled by GeminiFocusedTextField using @FocusState
                #endif
            }
            .sheet(isPresented: $showUpgradeModal) {
                upgradeView
            }
            .sheet(isPresented: $showLibrarySheet) {
                LibraryView()
                    .environmentObject(libraryService)
            }
            .sheet(isPresented: $showingPastStudiesSheet) {
                // Past Studies Sheet for iPhone
                NavigationView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text("Past Studies")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                showingPastStudiesSheet = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(
                                        Circle()
                                            .fill(Color.gray.opacity(0.5))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        Divider()
                        
                        // Past Studies Content
                        if savedQAs.isEmpty {
                            VStack {
                                Spacer()
                                Text("No saved questions yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Text("Your saved Bible study questions will appear here")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(savedQAs) { qa in
                                        pastStudyListItem(qa: qa)
                                        Divider()
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .background(theme.surface)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingScripturePopup) {
                ScripturePopupView(reference: selectedScriptureReference)
            }
            #if os(iOS)
            .sheet(isPresented: $showingPdfPreview) {
                if let url = pdfPreviewURL {
                    PDFPreviewView(url: url)
                }
            }
            #endif
    }
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        // New Parent VStack
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #endif
        
        return Group {
            #if os(iOS)
            if isPhone {
                // iPhone: Wrap in ScrollView for content that might overflow
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        mainContentBody
                    }
                    .padding(.bottom, 20)  // Add bottom padding for scroll content
                }
            } else {
                // iPad: Use regular VStack
                VStack(alignment: .leading, spacing: 0) {
                    mainContentBody
                }
            }
            #else
            // macOS: Use regular VStack
            VStack(alignment: .leading, spacing: 0) {
                mainContentBody
            }
            #endif
        }
        .modifier(SmartStudyFrameModifier()) // Apply the conditional frame modifier
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
    
    // MARK: - Main Content Body
    private var mainContentBody: some View {
        Group {
            // New Top Header (Left Aligned Title)
            VStack(spacing: 0) {
                // Top row with title and close button
                HStack {
                    #if os(iOS)
                    // Add a button to toggle sidebar visibility on iPad, or show past studies on iPhone
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Button(action: {
                            withAnimation(.easeInOut) {
                                showSavedQuestionsSidebar.toggle()
                            }
                        }) {
                            Image(systemName: showSavedQuestionsSidebar ? "sidebar.left" : "sidebar.squares.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 12)
                    }
                    #endif
                    
                    Text("Smart Study")
                        .font(.system(size: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? 16 : 24 // Even smaller title for iPhone
                            #else
                            return 24 // macOS default
                            #endif
                        }(), weight: .semibold)) // Responsive title size
                    
                    Spacer() // Pushes close button to the right
                    
                    // Close button
                    closeButton
                }
                
                #if os(iOS)
                                // Second row for iPhone controls
                if UIDevice.current.userInterfaceIdiom == .phone {
                    HStack {
                        // Search Scope Picker - compact size
                        Picker("Search In:", selection: $selectedScope) {
                            ForEach(SearchScope.allCases) { scope in
                                Text(scope.shortDisplayName)
                                    .font(.system(size: 8)) // Much smaller text
                                    .tag(scope)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 8)) // Much smaller picker font
                        .scaleEffect(0.85) // Scale down the entire picker
                        .frame(width: 80) // Even smaller width
                        .frame(height: 30) // Even smaller height
                        .clipped() // Clip any overflow
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                        .onChange(of: selectedScope) { newScope in
                            // Update useInternetSearch based on scope
                            if newScope == .internetOnly || newScope == .allSources {
                                useInternetSearch = true
                            } else {
                                useInternetSearch = false
                            }
                        }
                        
                        Spacer() // Even spacing
                        
                        // Library and Saved buttons grouped together
                        HStack(spacing: 8) {
                            // Library Button - compact size
                            Button(action: {
                                showLibrarySheet = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "books.vertical")
                                        .font(.system(size: 10))
                                    Text("Library")
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.1))
                                )
                                .foregroundColor(.primary)
                                .frame(width: 80, height: 36) // Smaller to fit both buttons
                            }
                            .buttonStyle(.plain)
                            
                            // Saved Studies Button - compact size
                            Button(action: {
                                showingPastStudiesSheet = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text("Saved")
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.1))
                                )
                                .foregroundColor(.primary)
                                .frame(width: 80, height: 36) // Smaller to fit both buttons
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                } else {
                    // iPad: Keep original layout
                    HStack {
                        Spacer()
                        
                        // Search Scope Picker
                        Picker("Search In:", selection: $selectedScope) {
                            ForEach(SearchScope.allCases) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        .onChange(of: selectedScope) { newScope in
                            if newScope == .internetOnly || newScope == .allSources {
                                useInternetSearch = true
                            } else {
                                useInternetSearch = false
                            }
                        }
                        .padding(.trailing, 8)
                        
                        // Library Button
                        libraryButton
                    }
                    .padding(.top, 8)
                }
                #else
                // macOS: Keep original layout
                HStack {
                    Spacer()
                    
                    // Search Scope Picker
                    Picker("Search In:", selection: $selectedScope) {
                        ForEach(SearchScope.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    .onChange(of: selectedScope) { newScope in
                        if newScope == .internetOnly || newScope == .allSources {
                            useInternetSearch = true
                        } else {
                            useInternetSearch = false
                        }
                    }
                    .padding(.trailing, 8)
                    
                    // Library Button
                    libraryButton
                }
                .padding(.top, 8)
                #endif
            }
            .padding(.horizontal, {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 6 : 20 // Even more reduced padding for iPhone
                #else
                return 20 // macOS default
                #endif
            }()) // Responsive horizontal padding for the whole header
            .padding(.top, {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 8 : 10 // Smaller top padding for iPhone
                #else
                return 10 // macOS default
                #endif
            }())
            .padding(.bottom, {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 10 : 15 // Smaller bottom padding for iPhone
                #else
                return 15 // macOS default
                #endif
            }())
            
            Divider()
            
            // Existing Content HStack (Sidebar, Main) - Remove Toggle
            HStack(spacing: 0) {
                // Left Sidebar (Conditional) - Hide on iPhone due to space constraints
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom != .phone && showSavedQuestionsSidebar {
                    leftSidebarView
                    Divider()
                }
                #else
                if showSavedQuestionsSidebar {
                    leftSidebarView
                    Divider()
                }
                #endif
                
                // Main Content Area (Right side) - Header Removed
                rightContentArea
            }
        }
    }
    
    // MARK: - Frame Modifier for Platform-Specific Sizing
    private struct SmartStudyFrameModifier: ViewModifier {
        func body(content: Content) -> some View {
            #if os(macOS)
            content.frame(width: 1000, height: 700)
            #else // For iOS
            if UIDevice.current.userInterfaceIdiom == .pad {
                // Check orientation for iPad
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height
                let isLandscape = screenWidth > screenHeight
                
                if isLandscape {
                    // iPad Landscape: Wider but shorter, leaving blue background visible
                    content.frame(idealWidth: 1000, maxWidth: 1100, idealHeight: 700, maxHeight: 800)
                } else {
                    // iPad Portrait: Original sizing
                content.frame(idealWidth: 800, maxWidth: 900, idealHeight: 1000, maxHeight: 1150)
                }
            } else { // For iPhone
                // iPhone: Proper modal sizing instead of full-screen
                content.frame(width: 340, height: 600)
            }
            #endif
        }
    }
    
    // MARK: - Tooltip Overlay
    private var tooltipOverlay: some View {
        Group {
            // Removed - now using popover instead
        }
    }
    
    // MARK: - Header Components
    private var libraryButton: some View {
                Button {
                    showLibrarySheet = true
                } label: {
                    HStack(spacing: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        return isPhone ? 2 : 4 // Tighter spacing for iPhone
                        #else
                        return 4 // macOS default
                        #endif
                    }()) {
                    Image(systemName: "books.vertical")
                            .font(.system(size: {
                                #if os(iOS)
                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                return isPhone ? 13 : 16 // Better proportioned icon for iPhone
                                #else
                                return 16 // macOS default
                                #endif
                            }()))
                        Text({
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? "My PDF Library" : "My PDF Library" // Use full text on iPhone too
                            #else
                            return "My PDF Library" // macOS default
                            #endif
                        }())
                            .font(.system(size: {
                                #if os(iOS)
                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                return isPhone ? 12 : 14 // Match picker font size
                                #else
                                return 14 // macOS default
                                #endif
                            }()))
                    }
                    .padding(.horizontal, {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        return isPhone ? 8 : 12 // Match picker padding
                        #else
                        return 12 // macOS default
                        #endif
                    }())
                    .padding(.vertical, {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        return isPhone ? 6 : 8 // Match picker height
                        #else
                        return 8 // macOS default
                        #endif
                    }())
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(hoverLibraryButton ? 
                                     (colorScheme == .dark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.1)) : 
                                     Color.clear)
                        )
                    .foregroundColor(.secondary)
                    .frame(height: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        return isPhone ? 32 : 44 // Match picker height better
                        #else
                        return 44 // macOS default
                        #endif
                    }())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open Smart Study Library")
                .onHover { hovering in // Add hover effect
                    hoverLibraryButton = hovering
                }
                .padding(.trailing, {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 6 : 12 // Smaller trailing padding for iPhone
                    #else
                    return 12 // macOS default
                    #endif
                }())
    }
                

                
    private var closeButton: some View {
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? 10 : 14 // Smaller icon for iPhone
                            #else
                            return 14 // macOS default
                            #endif
                        }(), weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? 28 : 36 // Smaller frame for iPhone
                            #else
                            return 36 // macOS default
                            #endif
                        }(), height: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? 28 : 36 // Smaller frame for iPhone
                            #else
                            return 36 // macOS default
                            #endif
                        }())
                        .background(
                            Circle()
                                .fill(hoverCloseButton ? Color.red : Color.gray.opacity(0.5))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in // Keep existing onHover
                    hoverCloseButton = hovering
                }
            }
    
    // MARK: - Sidebar Components
    private var leftSidebarView: some View {
                    VStack(spacing: 0) {
                        // Add title back, rename, and align padding
                        Text("Saved Study")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                                                            .padding(.horizontal, {
                                    #if os(iOS)
                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                    return isPhone ? 8 : 20 // Reduced padding for iPhone
                                    #else
                                    return 20 // macOS default
                                    #endif
                                }()) // Match main content horizontal padding
                            .padding(.top, 18) // Adjusted top padding to 18
                            .padding(.bottom, 8) // Consistent bottom padding before divider
                        
                        Divider()
                        
                        // Keep the rest of the sidebar content
                        if savedQAs.isEmpty {
                            VStack {
                                Spacer()
                                Text("No saved questions yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(colorScheme == .dark ? .gray.opacity(0.8) : .gray)
                                Spacer()
                            }
                            // Removed extra padding here as title provides spacing
                        } else {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(savedQAs) { qa in
                                        savedQAListItem(qa: qa)
                                        Divider()
                                    }
                                }
                            }
                            // Removed extra padding here as title provides spacing
                        }
                        
                        Spacer()
                        
                        tokenUsageView
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                            .frame(width: {
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            return isPhone ? 0 : 220 // Hide sidebar on iPhone due to space constraints
            #else
            return 220 // macOS default
            #endif
        }())
        .background(theme.surface)
        .transition(.move(edge: .leading))
                }
                
    // MARK: - Right Content Area
    private var rightContentArea: some View {
                VStack(alignment: .leading, spacing: 0) {
                    // Removed the previous header HStack from here
                    
                    // Right side content (Question Input, Answer Area)
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? 6 : 8 // Smaller spacing for iPhone
                            #else
                            return 8 // macOS default
                            #endif
                        }()) {
                            Text("Ask a Bible Question")
                                .font(.system(size: {
                                    #if os(iOS)
                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                    return isPhone ? 14 : 16 // Smaller text for iPhone
                                    #else
                                    return 16 // macOS default
                                    #endif
                                }(), weight: .medium))
                                .padding(.horizontal, {
                                    #if os(iOS)
                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                    return isPhone ? 8 : 20 // Smaller padding for iPhone
                                    #else
                                    return 20 // macOS default
                                    #endif
                                }())
                                .padding(.top, {
                                    #if os(iOS)
                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                    return isPhone ? 12 : 18 // Smaller top padding for iPhone
                                    #else
                                    return 18 // macOS default
                                    #endif
                                }())
                            
                            HStack(spacing: 8) {
                                GeminiFocusedTextField(
                                    text: $userQuery,
                                    placeholder: "Ask a question about the Bible...",
                                    onSubmit: askQuestion
                                )
                                .frame(height: {
                                    #if os(iOS)
                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                    return isPhone ? 32 : 36 // Smaller height for iPhone
                                    #else
                                    return 36 // macOS default
                                    #endif
                                }())
                                
                                Button(action: askQuestion) {
                                    Text("Ask")
                                        .font(.system(size: {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 12 : 14 // Smaller text for iPhone
                                            #else
                                            return 14 // macOS default
                                            #endif
                                        }(), weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 8 : 12 // Smaller padding for iPhone
                                            #else
                                            return 12 // macOS default
                                            #endif
                                        }())
                                        .padding(.vertical, {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 4 : 6 // Smaller padding for iPhone
                                            #else
                                            return 6 // macOS default
                                            #endif
                                        }())
                                        .frame(height: {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 32 : 36 // Smaller height for iPhone
                                            #else
                                            return 36 // macOS default
                                            #endif
                                        }())
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .frame(width: {
                                    #if os(iOS)
                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                    return isPhone ? 60 : 80 // Smaller width for iPhone
                                    #else
                                    return 80 // macOS default
                                    #endif
                                }())
                                .disabled(userQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                            }
                            .padding(.horizontal, {
                                #if os(iOS)
                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                return isPhone ? 8 : 20 // Reduced padding for iPhone
                                #else
                                return 20 // macOS default
                                #endif
                            }())
                            .padding(.bottom, {
                                #if os(iOS)
                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                return isPhone ? 12 : 16 // Smaller bottom padding for iPhone
                                #else
                                return 16 // macOS default
                                #endif
                            }())
                        }
                        .frame(height: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? 75 : 90 // Smaller height for iPhone
                            #else
                            return 90 // macOS default
                            #endif
                        }())
                        
                        Divider()
                        
                        ZStack {
                            if isLoading {
                                VStack(spacing: 16) {
                                    Spacer().frame(height: 40)
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    Text("Thinking...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.vertical, 20)
                            } else if !answer.isEmpty {
                                answerDisplayView
                            } else if userQuery.isEmpty {
                                emptyStateView
                            } else {
                                // Show message when query exists but no answer yet
                                VStack {
                                    Spacer()
                                    Text("Enter your question and tap Ask")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Answer Display Components
    private var answerDisplayView: some View {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        // Display search queries if present
                                        if !searchQueries.isEmpty {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    Text("Google Search:")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                        .padding(.trailing, 4)
                                                    
                                                    ForEach(searchQueries, id: \.self) { query in
                                                        Link(destination: URL(string: "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")!) {
                                                            HStack(spacing: 4) {
                                                                Image(systemName: "magnifyingglass")
                                                                    .font(.system(size: 12))
                                                                Text(query)
                                                                    .font(.system(size: 12))
                                                                    .lineLimit(1)
                                                            }
                                                            .padding(.vertical, 6)
                                                            .padding(.horizontal, 10)
                                                            .background(
                                                                RoundedRectangle(cornerRadius: 16)
                                                                    .fill(Color.blue.opacity(0.1))
                                                            )
                                                            .foregroundColor(.blue)
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal, {
                                                    #if os(iOS)
                                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                    return isPhone ? 8 : 20 // Smaller padding for iPhone
                                                    #else
                                                    return 20 // macOS default
                                                    #endif
                                                }())
                                            }
                                            .padding(.vertical, 12)
                                        }
                                        
                                        HStack {
                                            Text("Answer")
                                                .font(.system(size: {
                                                    #if os(iOS)
                                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                    return isPhone ? 14 : 16 // Smaller title for iPhone
                                                    #else
                                                    return 16 // macOS default
                                                    #endif
                                                }(), weight: .medium))
                                            Spacer()
                                            Button(action: saveQA) {
                                                Label("Save", systemImage: "bookmark")
                                                    .font(.system(size: {
                                                        #if os(iOS)
                                                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                        return isPhone ? 11 : 13 // Smaller save button for iPhone
                                                        #else
                                                        return 13 // macOS default
                                                        #endif
                                                    }()))
                                            }
                                            .buttonStyle(.borderless)
                                            .controlSize(.small)
                                        }
                                        .padding(.horizontal, {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 8 : 20 // Smaller padding for iPhone
                                            #else
                                            return 20 // macOS default
                                            #endif
                                        }())
                                        .padding(.vertical, {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 8 : 12 // Smaller padding for iPhone
                                            #else
                                            return 12 // macOS default
                                            #endif
                                        }())
                                        
                                        Divider()
                                            .padding(.bottom, {
                                                #if os(iOS)
                                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                return isPhone ? 12 : 16 // Smaller padding for iPhone
                                                #else
                                                return 16 // macOS default
                                                #endif
                                            }())
                                        
                                        if let errorMessage = errorMessage {
                                            Text(errorMessage)
                                                .font(.system(size: 14))
                                                .foregroundColor(.red)
                                                .padding(.horizontal, {
                                                    #if os(iOS)
                                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                    return isPhone ? 8 : 20 // Smaller padding for iPhone
                                                    #else
                                                    return 20 // macOS default
                                                    #endif
                                                }())
                                                .padding(.vertical, 12)
                                        }
                                        
                                        // Plain text display for iPhone, RichTextWebView for others
                                        #if os(iOS)
                                        if UIDevice.current.userInterfaceIdiom == .phone {
                                            Text(answer)
                                                .font(.system(size: 14))
                                                .lineSpacing(4)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 8)
                                                .textSelection(.enabled)
                                        } else {
                                            RichTextWebView(
                                                htmlContent: answer.markdownToHTML(),
                                                onOpenPDF: openPDFFromWebView
                                            )
                                            .frame(minHeight: 200)
                                            .padding(.horizontal, 20)
                                        }
                                        #else
                                        RichTextWebView(
                                            htmlContent: answer.markdownToHTML(),
                                            onOpenPDF: openPDFFromWebView
                                        )
                                        .frame(minHeight: 200)
                                        .padding(.horizontal, 20)
                                        #endif
                                        
                        // Source information or Scripture references (moved to bottom)
                        if let sourceTitle = sourceDocumentTitleForAnswer {
                            sourceDocumentView(sourceTitle)
                        } 
                        
                        // Always show scripture references for Bible questions regardless of source
                        if !consolidatedChapterReferences.isEmpty {
                            scriptureReferencesView
                        }
                                    }
                                    .padding(.bottom, 20) // Add bottom padding for scroll content
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
                                VStack(spacing: {
                                    #if os(iOS)
                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                    return isPhone ? 12 : 16 // Smaller spacing for iPhone
                                    #else
                                    return 16 // macOS default
                                    #endif
                                }()) {
                                    Spacer().frame(height: {
                                        #if os(iOS)
                                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                        return isPhone ? 30 : 60 // Smaller top spacer for iPhone
                                        #else
                                        return 60 // macOS default
                                        #endif
                                    }())
                                    
                                    Image(systemName: "sparkles.square.filled.on.square")
                                        .font(.system(size: {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 32 : 40 // Smaller icon for iPhone
                                            #else
                                            return 40 // macOS default
                                            #endif
                                        }()))
                                        .foregroundColor(colorScheme == .dark ? Color.purple.opacity(0.8) : Color.purple.opacity(0.7))
                                    
                                    Text("Ask anything about the Bible")
                                        .font(.system(size: {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 14 : 16 // Smaller text for iPhone
                                            #else
                                            return 16 // macOS default
                                            #endif
                                        }()))
                                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : Color.gray)
                                    
                                    Text({
                                        #if os(iOS)
                                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                        return isPhone ? "Example: How old was David when he died? What does Proverbs say about wisdom? Explain the meaning of John 3:16." : "Example: How old was David when he died? What does Proverbs say about wisdom? Explain the meaning of John 3:16."
                                        #else
                                        return "Example: How old was David when he died? What does Proverbs say about wisdom? Explain the meaning of John 3:16."
                                        #endif
                                    }())
                                        .font(.system(size: {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 12 : 14 // Smaller text for iPhone
                                            #else
                                            return 14 // macOS default
                                            #endif
                                        }()))
                                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.gray.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, {
                                            #if os(iOS)
                                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                            return isPhone ? 16 : 40 // Smaller padding for iPhone
                                            #else
                                            return 40 // macOS default
                                            #endif
                                        }())

                                    if useInternetSearch {
                                        Text("Internet search is enabled for more detailed answers")
                                            .font(.system(size: {
                                                #if os(iOS)
                                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                return isPhone ? 11 : 13 // Smaller text for iPhone
                                                #else
                                                return 13 // macOS default
                                                #endif
                                            }()))
                                            .foregroundColor(colorScheme == .dark ? .blue.opacity(0.9) : .blue)
                                            .padding(.top, {
                                                #if os(iOS)
                                                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                                return isPhone ? 8 : 12 // Smaller padding for iPhone
                                                #else
                                                return 12 // macOS default
                                                #endif
                                            }())
                                    }
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Views
    
    // MARK: - Past Study List Item (for iPhone sheet)
    private func pastStudyListItem(qa: SmartStudyEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(qa.question)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(DateFormatter.shortDate.string(from: qa.date))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    // Load this Q&A into the main view
                    userQuery = qa.question
                    answer = qa.answer
                    sourceDocumentTitleForAnswer = qa.sourceDocumentTitle
                    scriptureReferences = qa.scriptureReferences ?? []
                    showingPastStudiesSheet = false
                }) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            // Load this Q&A into the main view
            userQuery = qa.question
            answer = qa.answer
            sourceDocumentTitleForAnswer = qa.sourceDocumentTitle
            scriptureReferences = qa.scriptureReferences ?? []
            showingPastStudiesSheet = false
        }
    }

    // MARK: - Saved Q&A List Item
    private func savedQAListItem(qa: SmartStudyEntry) -> some View {
        ZStack(alignment: .trailing) {
            // Main content
            Button(action: {
                userQuery = qa.question
                answer = qa.answer
            }) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(qa.question)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(qa.answer.prefix(60) + (qa.answer.count > 60 ? "..." : ""))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    #if os(macOS)
                    // Delete button (macOS hover)
                    if hoverStates[qa.id] == true {
                        Button(action: { deleteQA(id: qa.id) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(deleteButtonHover == qa.id ? .red : .gray)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                        .onHover { hovering in
                            deleteButtonHover = hovering ? qa.id : nil
                        }
                    }
                    #elseif os(iOS)
                    // Delete button (iOS always visible)
                    Button(action: { deleteQA(id: qa.id) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray) // Consistent color, can be themed
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            #if os(macOS)
            .background(
                MouseTrackingView(
                    onMouseEnter: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoverStates[qa.id] = true
                        }
                    },
                    onMouseExit: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoverStates[qa.id] = false
                            if deleteButtonHover == qa.id {
                                deleteButtonHover = nil
                            }
                        }
                    }
                )
            )
            #endif
        }
    }
    
    // MARK: - Actions
    
    private func askQuestion() {
        let currentQuery = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        answer = "" // Clear previous answer
        searchQueries = [] // Clear previous search queries
        scriptureReferences = [] // Clear previous scripture references
        consolidatedChapterReferences = [] // Clear previous consolidated references
        
        // Get the system prompt based on the current query and selected scope
        let systemPrompt = getBiblePrompt(query: currentQuery)
        
        // Call the new unified AIService method
        AIService.shared.generateSmartStudyResponse(
            prompt: systemPrompt, 
            scope: selectedScope, 
            userQuery: currentQuery, // Pass the original query for vector searching the library
            userLibraryService: libraryService // Pass the @StateObject instance
        ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    switch result {
                    case .success(let resultTuple):
                        self.answer = cleanAnswerText(resultTuple.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        self.searchQueries = resultTuple.searchQueries
                        
                        // Extract scripture references from the answer
                        self.scriptureReferences = AIService.shared.extractScriptureReferences(from: resultTuple.text)
                        
                        // Create consolidated chapter references for the UI
                        self.consolidatedChapterReferences = self.scriptureReferences.consolidatedByChapter()
                        
                        // Only set source document if we're actually using library search AND the AI used library content
                        // AND this is a question that should show library sources (not Bible-only question)
                        if (self.selectedScope == .libraryOnly || self.selectedScope == .allSources) && 
                           resultTuple.sourceDocumentTitle != nil && 
                           !isBibleQuestion(query: self.userQuery) {
                            self.sourceDocumentTitleForAnswer = resultTuple.sourceDocumentTitle
                        } else {
                            self.sourceDocumentTitleForAnswer = nil
                        }
                        
                        if self.searchQueries.isEmpty && (self.selectedScope == .allSources || self.selectedScope == .internetOnly) {
                            self.searchQueries = [currentQuery]
                        }
                        
                    case .failure(let error):
                        if let apiError = error as? AIServiceError, case .apiError(let message) = apiError {
                            if message.contains("token limit") {
                                self.errorMessage = "Token limit reached. Please purchase more tokens or wait for the next cycle."
                                self.showUpgradeModal = true
                            } else {
                                self.errorMessage = "API Error: \(message)"
                            print("🚨 Smart Study generation failed with error: \(message)")
                            // No automatic fallback here anymore as scope dictates behavior
                            }
                        } else {
                            self.errorMessage = "Error: \(error.localizedDescription)"
                        self.answer = "Sorry, an error occurred. Please try again."
                    }
                }
            }
        }
    }
    
    // Function to clean up answer text by removing source references
    private func cleanAnswerText(_ text: String) -> String {
        var cleanedText = text
        
        // Remove the library content marker if it somehow still exists
        cleanedText = cleanedText.replacingOccurrences(of: "[LIBRARY_CONTENT_USED]", with: "")
        
        // Remove common source reference patterns
        let patterns = [
            // Pattern for "This information comes from document X"
            "This information comes from( the provided)? document [\"']?([^\"'\\n.]+)[\"']?\\.",
            // Pattern for "Source: X" with optional quotes
            "Source: [\"']?([^\"'\\n.]+)[\"']?",
            // Pattern for "According to document X"
            "According to( the provided)? document [\"']?([^\"'\\n.]+)[\"']?[,.]",
            // Pattern for "Based on document X"
            "Based on( the provided)? document [\"']?([^\"'\\n.]+)[\"']?[,.]",
            // Pattern for "From document X"
            "From( the provided)? document [\"']?([^\"'\\n.]+)[\"']?[,.]"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(cleanedText.startIndex..<cleanedText.endIndex, in: cleanedText)
                cleanedText = regex.stringByReplacingMatches(in: cleanedText, options: [], range: range, withTemplate: "")
            } catch {
                print("Error creating regex for pattern \(pattern): \(error)")
            }
        }
        
        // Remove bullet points at the beginning that might be left over
        cleanedText = cleanedText.replacingOccurrences(of: "^\\s*•\\s*", with: "", options: .regularExpression)
        
        // Remove references at the end of text
        if let sourceDocTitle = sourceDocumentTitleForAnswer {
            // More specific check for the exact document title
            let escapedTitle = NSRegularExpression.escapedPattern(for: sourceDocTitle)
            do {
                let specificPattern = ".*[\"']?\(escapedTitle)[\"']?.*$"
                let regex = try NSRegularExpression(pattern: specificPattern, options: [.caseInsensitive, .anchorsMatchLines])
                let range = NSRange(cleanedText.startIndex..<cleanedText.endIndex, in: cleanedText)
                cleanedText = regex.stringByReplacingMatches(in: cleanedText, options: [], range: range, withTemplate: "")
            } catch {
                print("Error creating regex for specific document pattern: \(error)")
            }
        }
        
        // Clean up extra whitespace and newlines that might be left over
        cleanedText = cleanedText.replacingOccurrences(of: "\\n\\s*\\n\\s*\\n", with: "\n\n", options: .regularExpression)
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedText
    }
    
    // Updated helper to create Bible-focused prompt with option to force disable internet
    private func getBiblePrompt(query: String, forceDisableInternet: Bool = false) -> String {
        var promptContent = ""
        var specificInstructions = ""
        
        switch selectedScope {
        case .allSources:
            promptContent = "Answer the following Bible question, using your general knowledge, the user's provided library documents, and up-to-date information from the internet if necessary."
            specificInstructions = "Always provide specific scripture references (book, chapter, verse) from the Bible. Include relevant cross-references and related passages that support or expand on the topic. If using library documents, clearly indicate that. If using internet sources, try to summarize findings."
        case .internetOnly:
            promptContent = "Answer the following Bible question, primarily using up-to-date information from the internet."
            specificInstructions = "Always provide specific scripture references (book, chapter, verse) from the Bible. Include relevant cross-references and related passages that support the topic. Focus on providing comprehensive and accurate information from web sources with direct scripture support."
        case .libraryOnly:
            promptContent = "Answer the following question using *only* the content found within the user's provided library documents. Do not use your general knowledge or internet search."
            specificInstructions = "Always provide specific scripture references (book, chapter, verse) from the Bible. If the answer to the question is found in the provided library documents, state it clearly. Include any scripture references mentioned in the documents. If the information is not present in the documents, explicitly state that the documents do not contain the answer."
        case .bibleKnowledgeOnly:
            promptContent = "Answer the following Bible question using your general knowledge of scripture and religious studies. Do not use the user's library documents or internet search."
            specificInstructions = "Always provide specific scripture references (book, chapter, verse) from the Bible. Include relevant cross-references and related passages that support the topic. Keep the answer comprehensive with direct scripture support."
        }
        
        // This part handles the forceDisableInternet for fallback scenarios, separate from selectedScope's internet usage.
        let internetNote = (useInternetSearch && !forceDisableInternet && (selectedScope == .allSources || selectedScope == .internetOnly)) ? 
            "Internet search is permitted for this query." :
            "Internet search is NOT permitted for this query."
        
        return """
        You are a helpful Bible study assistant with expertise in cross-referencing scriptures.
        \(promptContent)
        
        Question: "\(query)"
        
        IMPORTANT SCRIPTURE FORMATTING INSTRUCTIONS:
        - Format ALL scripture references as [Book Chapter:Verse] (e.g., [John 3:16], [Genesis 1:1-3], [Romans 8:28])
        - ALWAYS include the complete text of at least 1-2 of the most relevant Bible passages in full
        - Include key cross-references and related passages that illuminate the topic, even if not directly asked
        - When discussing biblical characters, stories, or themes, provide supporting passages from different books
        - For theological concepts, include both Old and New Testament references where applicable
        
        \(specificInstructions)
        \(internetNote)
        
        CROSS-REFERENCE GUIDELINES:
        - If someone asks about a person (e.g., Peter, David, Moses), include key passages about them from multiple books
        - If someone asks about a concept (e.g., love, faith, salvation), provide supporting verses from different contexts
        - If someone asks about an event, include parallel accounts or related stories
        - Always aim to provide 3-5 relevant scripture references when possible to enrich the study
        - EVERY answer must include at least one complete scripture passage relevant to the question
        
        If the question is not directly answerable from the specified sources or is unrelated to Biblical topics, gently state that and guide the user appropriately.
        """
    }
    
    private func saveQA() {
        guard !userQuery.isEmpty, !answer.isEmpty else { return }
        
        // Include source document title and scripture references if available when saving
        let entry = SmartStudyEntry(
            id: UUID().uuidString, 
            question: userQuery, 
            answer: answer, 
            date: Date(), 
            sourceDocumentTitle: sourceDocumentTitleForAnswer,
            timestamp: Date(), // Use current date as timestamp
            scriptureReferences: scriptureReferences.isEmpty ? nil : scriptureReferences
        )
        savedQAs.append(entry)
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(savedQAs) {
            UserDefaults.standard.set(encoded, forKey: "savedSmartStudyQAs")
        }
    }
    
    private func loadSavedQAs() {
        if let savedData = UserDefaults.standard.data(forKey: "savedSmartStudyQAs"),
           let decoded = try? JSONDecoder().decode([SmartStudyEntry].self, from: savedData) {
            savedQAs = decoded
        }
    }
    
    private func deleteQA(id: String) {
        // Remove from array
        savedQAs.removeAll(where: { $0.id == id })
        
        // Save updated list to UserDefaults
        if let encoded = try? JSONEncoder().encode(savedQAs) {
            UserDefaults.standard.set(encoded, forKey: "savedSmartStudyQAs")
        }
    }
    
    // Function to be called by RichTextWebView
    private func openPDFFromWebView(documentTitle: String) {
        print("Attempting to open PDF '\(documentTitle)' from WebView link...")
        guard let itemToOpen = libraryService.libraryItems.first(where: { $0.title == documentTitle && $0.type == .pdf }),
              let pdfsDirectory = libraryService.getLibraryPdfsDirectoryURL() else {
            print("Could not find PDF '\(documentTitle)' in library or directory unavailable.")
            return
        }
        
        let fileURL = pdfsDirectory.appendingPathComponent(itemToOpen.source)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            #if os(macOS)
            NSWorkspace.shared.open(fileURL)
            print("Successfully requested to open PDF: \(fileURL.path)")
            #elseif os(iOS)
            self.pdfPreviewURL = fileURL
            self.showingPdfPreview = true
            print("iOS: Setting up to show PDF preview for: \(fileURL.path)")
            #endif
        } else {
            print("Error: PDF file not found at \(fileURL.path)")
        }
    }
    
    // MARK: - Token Usage Views
    
    private var tokenUsageView: some View {
        VStack(spacing: 4) {
            // CloudKit sync status indicator
            if tokenService.isCloudKitAvailable {
                HStack(spacing: 4) {
                    Image(systemName: "icloud")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("Synced")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    if let lastSync = tokenService.lastSyncDate {
                        Text("• \(formatSyncTime(lastSync))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 2)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("Local Only")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 2)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Usage bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(usageColor)
                        .frame(width: geo.size.width * CGFloat(tokenService.usagePercentage()), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.bottom, 2)
            
            HStack {
                Text("Tokens: \(formatNumber(tokenService.currentUsage))/\(formatNumber(tokenService.totalTokenLimit))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Buy More") {
                    showUpgradeModal = true
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue)
                .buttonStyle(.plain)
            }
            
            Text("Resets on \(formattedResetDate())")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showUpgradeModal) {
            upgradeView
        }
    }
    
    private var usageColor: Color {
        let percentage = tokenService.usagePercentage()
        if percentage < 0.7 {
            return .green
        } else if percentage < 0.9 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var upgradeView: some View {
        ZStack(alignment: .topTrailing) {
            // Main content
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 16) {
                    Text("Get More Tokens")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.top, 30)
                    
                    Text("Continue asking questions and receive Biblical insights")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 10)
                }
                
                // Current Usage section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Current Usage")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.bottom, 4)
                    
                    HStack {
                        Text("Used")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(formatNumber(tokenService.currentUsage)) tokens")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Remaining")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(formatNumber(tokenService.remainingTokens())) tokens")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Limit")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(formatNumber(tokenService.totalTokenLimit)) tokens")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                #if os(macOS)
                .background(Color(.controlBackgroundColor).opacity(0.5))
                #elseif os(iOS)
                .background(Color(.systemGray6).opacity(0.5))
                #endif
                .cornerRadius(8)
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                // Reset Date section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reset Date")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Your token usage will reset on \(formattedResetDate())")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.top, 24)
                
                Spacer()
                
                // Purchase section
                VStack(spacing: 16) {
                    Text("Purchase More Tokens")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Add 1,000,000 tokens for \(tokenService.additionalTokenPrice())")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        tokenService.purchaseAdditionalTokens()
                        showUpgradeModal = false
                    }) {
                        Text("Purchase Now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 8)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .frame(width: 400, height: 550)
            .background(Color.white)
            .cornerRadius(12)
            
            // Circular close button
            Button(action: {
                showUpgradeModal = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(hoverCloseButton ? Color.red : Color.gray.opacity(0.5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 16)
            .padding(.trailing, 16)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    hoverCloseButton = hovering
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formattedResetDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: tokenService.resetDate)
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number == Int.max {
            return "∞"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatSyncTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    // MARK: - Scripture References View
    
    private var scriptureReferencesView: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, 16)
            
            HStack(spacing: 8) {
                Text("Scripture References:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(consolidatedChapterReferences) { chapterRef in
                            chapterReferenceButton(chapterRef)
                        }
                    }
                    .padding(.horizontal, 1) // Prevent clipping
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
    
    private func chapterReferenceButton(_ chapterRef: ConsolidatedChapterReference) -> some View {
        Button(action: { 
            // Toggle the popover for this chapter
            let isCurrentlyOpen = chapterPopoverStates[chapterRef.id.uuidString] ?? false
            
            // Close all other popovers
            for key in chapterPopoverStates.keys {
                chapterPopoverStates[key] = false
                popoverHoverStates[key] = false
            }
            
            // Toggle this popover
            if !isCurrentlyOpen {
                popoverChapterReference = chapterRef
                chapterPopoverStates[chapterRef.id.uuidString] = true
                print("🎯 Opening chapter popover for: \(chapterRef.displayText)")
            } else {
                popoverChapterReference = nil
                print("🎯 Closing chapter popover for: \(chapterRef.displayText)")
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "book.fill")
                    .font(.system(size: 12))
                Text(chapterRef.displayText)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.1))
            )
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { chapterPopoverStates[chapterRef.id.uuidString] ?? false },
            set: { chapterPopoverStates[chapterRef.id.uuidString] = $0 }
        )) {
            ChapterPopoverView(chapterReference: chapterRef)
                .onAppear {
                    print("📖 Chapter popover appeared for: \(chapterRef.displayText)")
                }
                .onDisappear {
                    print("📖 Chapter popover disappeared for: \(chapterRef.displayText)")
                    chapterPopoverStates[chapterRef.id.uuidString] = false
                    if popoverChapterReference?.id == chapterRef.id {
                        popoverChapterReference = nil
                }
            }
        }
    }
    
    private func sourceDocumentView(_ sourceTitle: String) -> some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, 16)
            
            HStack(spacing: 8) {
                Text("Source Document:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
                
                Button(action: { openPDFFromWebView(documentTitle: sourceTitle) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                        Text(sourceTitle)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange.opacity(0.1))
                    )
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
    
    // Helper function to determine if a query is Bible-related
    private func isBibleQuestion(query: String) -> Bool {
        // Common Bible-related keywords
        let bibleKeywords = [
            // Bible general terms
            "bible", "scripture", "verse", "biblical", "testament", "gospel", "epistle", "holy writ",
            "word of god", "sacred text", "holy book", "passage", "chapter", "theology",
            
            // Bible events
            "creation", "flood", "exodus", "crucifixion", "resurrection", "ascension", "pentecost",
            "last supper", "passover", "rapture", "armageddon", "apocalypse", "transfiguration",
            
            // Biblical figures
            "jesus", "christ", "messiah", "god", "holy spirit", "moses", "abraham", "noah", "david", 
            "solomon", "paul", "peter", "mary", "joseph", "adam", "eve", "cain", "abel", "job", 
            "jonah", "elijah", "isaiah", "jeremiah", "daniel", "john", "matthew", "mark", "luke",
            "disciples", "apostles", "pharisees", "sadducees", 
            
            // Bible locations
            "jerusalem", "bethlehem", "nazareth", "galilee", "judea", "eden", "babylon", "jericho",
            "egypt", "sinai", "jordan", "israel", "canaan", "promised land",
            
            // Bible books
            "genesis", "exodus", "leviticus", "numbers", "deuteronomy", 
            "matthew", "mark", "luke", "john", "acts", "romans", "corinthians", 
            "galatians", "ephesians", "philippians", "colossians", "thessalonians",
            "timothy", "titus", "philemon", "hebrews", "james", "peter", "jude", "revelation",
            "psalms", "proverbs", "ecclesiastes", "isaiah", "ezekiel", "daniel", "hosea", "joel",
            "amos", "obadiah", "jonah", "micah", "nahum", "habakkuk", "zephaniah", "haggai",
            "zechariah", "malachi", "ruth", "esther", "kings", "chronicles", "samuel", "judges", "joshua",
            
            // Christian concepts
            "salvation", "faith", "sin", "redemption", "heaven", "hell", "prayer", "worship",
            "baptism", "communion", "trinity", "sermon", "parable", "miracle", "prophecy",
            "covenant", "commandment", "blessing", "church", "christian", "disciple", "prophet",
            "priest", "pastor", "rabbi", "angel", "demon", "satan", "devil"
        ]
        
        // Check if query contains any Bible keywords (case insensitive)
        let lowercaseQuery = query.lowercased()
        for keyword in bibleKeywords {
            if lowercaseQuery.contains(keyword.lowercased()) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Supporting Types

struct SmartStudyEntry: Identifiable, Codable {
    var id: String
    var question: String
    var answer: String
    var date: Date
    var sourceDocumentTitle: String? = nil // Add to model
    var timestamp: Date? // Add timestamp property
    var scriptureReferences: [ScriptureReference]? // Add scripture references property
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

// CloseButton is already defined in ScriptureCard.swift, so it's removed here 

// Remove the duplicate extension - it's already defined in DocumentEditor.swift 

// MARK: - Mouse Tracking View
#if os(macOS)
struct MouseTrackingView: NSViewRepresentable {
    var onMouseEnter: () -> Void
    var onMouseExit: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onMouseEnter = onMouseEnter
        view.onMouseExit = onMouseExit
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? TrackingView {
            view.onMouseEnter = onMouseEnter
            view.onMouseExit = onMouseExit
        }
    }
    
    class TrackingView: NSView {
        var trackingArea: NSTrackingArea?
        var onMouseEnter: (() -> Void)?
        var onMouseExit: (() -> Void)?
        
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            
            if let trackingArea = trackingArea {
                removeTrackingArea(trackingArea)
            }
            
            trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeInKeyWindow],
                owner: self,
                userInfo: nil
            )
            
            if let trackingArea = trackingArea {
                addTrackingArea(trackingArea)
            }
        }
        
        override func mouseEntered(with event: NSEvent) {
            onMouseEnter?()
        }
        
        override func mouseExited(with event: NSEvent) {
            onMouseExit?()
        }
    }
}
#endif 

#if os(iOS)
struct PDFPreviewView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No update needed from SwiftUI side usually, as QLPreviewController handles its own state.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: PDFPreviewView

        init(_ parent: PDFPreviewView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}
#endif 