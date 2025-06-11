import SwiftUI

struct DocumentSummaryView: View {
    @ObservedObject var document: CanvasDocument
    @State private var summary: String = ""
    @State private var isGenerating: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Document Summary")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Generate a concise summary of your document")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            // Summary section
            Group {
                if isGenerating {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Generating summary...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.lightGray).opacity(0.2))
                    .cornerRadius(8)
                } else if summary.isEmpty {
                    Text("No summary available yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.lightGray).opacity(0.2))
                        .cornerRadius(8)
                } else {
                    ScrollView {
                        Text(summary)
                            .padding()
                            .background(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.lightGray).opacity(0.2))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            // Action buttons
            HStack {
                Button(action: {
                    isGenerating = true
                    document.generateSummary { newSummary in
                        summary = newSummary
                        isGenerating = false
                    }
                }) {
                    Text(summary.isEmpty ? "Generate Summary" : "Regenerate")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isGenerating)
                
                if !summary.isEmpty {
                    Button(action: {
                        saveToDocument()
                    }) {
                        Text("Save to Document")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(isGenerating)
                }
            }
        }
        .padding()
        .frame(minWidth: 400, maxWidth: 600)
        .onAppear {
            if let cachedSummary = document.metadata.summary {
                summary = cachedSummary
            }
        }
    }
    
    func saveToDocument() {
        let formattedContent = """
        ## Document Summary
        
        \(summary)
        """
        
        // Post notification to add this content to the current document
        NotificationCenter.default.post(
            name: NSNotification.Name("AddContentToDocument"),
            object: nil,
            userInfo: ["content": formattedContent]
        )
    }
} 