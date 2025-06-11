import SwiftUI

struct AIToolsView: View {
    @Binding var document: CanvasDocument
    @State private var selectedTool: AITool = .studyAI
    @State private var documentText: String = ""
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    enum AITool: String, CaseIterable {
        case studyAI = "Study AI"
        case summarize = "Summarize"
        case grammarCheck = "Grammar"
        case vocabularyEnhance = "Vocabulary"
        
        var icon: String {
            switch self {
            case .studyAI:
                return "book.fill"
            case .summarize:
                return "doc.text.magnifyingglass"
            case .grammarCheck:
                return "checkmark.circle"
            case .vocabularyEnhance:
                return "wand.and.stars"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Tools")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Small Gemini badge
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.purple)
                    
                    Text("Powered by Gemini AI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.purple.opacity(0.1) : Color.purple.opacity(0.1))
                )
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(colorScheme == .dark ? Color(.darkGray).opacity(0.2) : Color(.lightGray).opacity(0.2))
            
            // Tool selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(AITool.allCases, id: \.self) { tool in
                        Button(action: {
                            selectedTool = tool
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: tool.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedTool == tool ? .purple : .gray)
                                
                                Text(tool.rawValue)
                                    .font(.caption)
                                    .foregroundColor(selectedTool == tool ? .primary : .secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTool == tool ? 
                                          (colorScheme == .dark ? Color.purple.opacity(0.2) : Color.purple.opacity(0.1)) : 
                                          Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(colorScheme == .dark ? Color(.darkGray).opacity(0.1) : Color(.lightGray).opacity(0.1))
            
            Divider()
            
            // Tool content
            ScrollView {
                VStack {
                    switch selectedTool {
                    case .studyAI:
                        StudyAIView()
                    case .summarize:
                        DocumentSummaryView(document: document)
                    case .grammarCheck:
                        GrammarCheckerView(text: $documentText)
                    case .vocabularyEnhance:
                        VocabularyEnhancerView(text: $documentText)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 650)
        .background(colorScheme == .dark ? Color(.black) : Color(.white))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
        .onAppear {
            documentText = document.content.string
            
            // Just to make sure we have a valid API key
            if AIService.shared.apiKey.isEmpty || AIService.shared.apiKey == "YOUR_GEMINI_API_KEY" {
                print("Warning: You need to set a valid Gemini API key in AIService.swift")
            }
        }
        .onChange(of: documentText) { oldValue, newValue in
            // Only update document if text has changed due to AI tools
            if newValue != document.content.string {
                let attributedString = NSMutableAttributedString(string: newValue)
                // Preserve existing attributes if possible
                if document.content.length > 0 {
                    let fullRange = NSRange(location: 0, length: document.content.length)
                    document.content.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
                        let overlapRange = NSRange(
                            location: min(range.location, attributedString.length),
                            length: min(range.length, max(0, attributedString.length - range.location))
                        )
                        
                        if overlapRange.length > 0 && overlapRange.location >= 0 {
                            for (key, value) in attrs {
                                attributedString.addAttribute(key, value: value, range: overlapRange)
                            }
                        }
                    }
                }
                
                // Use objectWillChange to notify observers
                document.objectWillChange.send()
                document.updateContent(attributedString)
            }
        }
    }
}

// Extension to add the AI Tools to the app
extension View {
    func withAITools(document: Binding<CanvasDocument>) -> some View {
        self.modifier(AIToolsModifier(document: document))
    }
}

struct AIToolsModifier: ViewModifier {
    @Binding var document: CanvasDocument
    @State private var showingAITools = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showingAITools.toggle()
                        }) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .padding(10)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()
                        .help("AI Tools")
                    }
                    
                    Spacer()
                }, alignment: .topTrailing
            )
            .sheet(isPresented: $showingAITools) {
                AIToolsView(document: $document)
                    .frame(width: 600, height: 650)
            }
    }
}

// Observer for adding content to document
class DocumentContentObserver {
    static let shared = DocumentContentObserver()
    
    private init() {
        setupNotificationObserver()
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AddContentToDocument"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let content = userInfo["content"] as? String {
                // This would be handled by the document view
                // We'll implement this in the appropriate view controller
                print("Content to add: \(content)")
            }
        }
    }
}

// Add initialization of the observer
extension CanvasDocument {
    static func initializeContentObserver() {
        // Just access the shared instance to initialize it
        _ = DocumentContentObserver.shared
    }
} 