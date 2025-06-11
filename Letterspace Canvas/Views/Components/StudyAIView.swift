import SwiftUI

struct StudyAIView: View {
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var isProcessing: Bool = false
    @State private var references: [String] = []
    @State private var shouldSaveToDocument: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Study AI")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Ask a question about Scripture")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Question input
            TextField("What does it truly mean to live by faith?", text: $question)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.vertical, 8)
            
            Button(action: {
                isProcessing = true
                askBibleQuestion(question: question)
            }) {
                Text(isProcessing ? "Searching Scripture..." : "Ask")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(question.isEmpty || isProcessing)
            
            if !answer.isEmpty {
                // Answer section
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Answer")
                            .font(.headline)
                        
                        Text(answer)
                            .padding()
                            .background(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.lightGray).opacity(0.2))
                            .cornerRadius(8)
                        
                        // Scripture references
                        if !references.isEmpty {
                            Text("Scripture References")
                                .font(.headline)
                                .padding(.top, 8)
                            
                            ForEach(references, id: \.self) { reference in
                                Text(reference)
                                    .font(.subheadline)
                                    .padding(.vertical, 2)
                            }
                        }
                        
                        // Save option
                        Toggle("Save to current document", isOn: $shouldSaveToDocument)
                            .padding(.top, 8)
                        
                        Button(action: {
                            saveToDocument()
                        }) {
                            Text("Save")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(!shouldSaveToDocument)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 400, maxWidth: 600)
    }
    
    func askBibleQuestion(question: String) {
        // Check token availability before making the call
        let estimatedTokens = question.count / 4 + 800 // Rough estimate
        if !TokenUsageService.shared.canUseTokens(estimatedTokens) {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.answer = "Token limit reached. Please purchase more tokens to ask Bible questions."
                self.references = []
            }
            return
        }
        
        // Call the AI service with a properly crafted prompt
        let apiService = AIService.shared
        
        let prompt = """
        Provide an answer to the following Bible-related question:
        "\(question)"
        
        Base your answer entirely on Biblical content. Include direct scripture references.
        Format your answer with:
        1. A clear, concise response (3-5 sentences)
        2. Key scripture passages that address the question
        3. List the references separately at the end in this format: [Book Chapter:Verse]
        
        DO NOT make up content or citations. If you're unsure, indicate this clearly.
        """
        
        apiService.generateText(prompt: prompt) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let response):
                    // Parse the response to separate the answer and references
                    (self.answer, self.references) = self.parseResponse(response)
                case .failure(let error):
                    self.answer = "Error: \(error.localizedDescription)"
                    self.references = []
                }
            }
        }
    }
    
    func parseResponse(_ response: String) -> (String, [String]) {
        // Simple parsing logic to extract references from the response
        let lines = response.components(separatedBy: .newlines)
        var answerParts: [String] = []
        var refs: [String] = []
        var isReferenceSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmedLine.isEmpty {
                continue
            }
            
            // Check if we've reached the references section
            if trimmedLine.lowercased().contains("reference") || isReferenceSection {
                isReferenceSection = true
                
                // Extract book chapter:verse pattern
                let pattern = "([A-Za-z0-9 ]+) ([0-9]+:[0-9]+-?[0-9]*)"
                let regex = try? NSRegularExpression(pattern: pattern)
                
                if let regex = regex, let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
                    if match.numberOfRanges >= 3 {
                        let bookRange = Range(match.range(at: 1), in: trimmedLine)!
                        let verseRange = Range(match.range(at: 2), in: trimmedLine)!
                        let book = String(trimmedLine[bookRange])
                        let verse = String(trimmedLine[verseRange])
                        refs.append("\(book) \(verse)")
                    } else {
                        // If it doesn't match the pattern but we're in references section
                        // and it's not a heading, add it as a reference
                        if !trimmedLine.lowercased().contains("reference") && 
                           !trimmedLine.hasSuffix(":") {
                            refs.append(trimmedLine)
                        }
                    }
                } else {
                    // If it doesn't match the pattern but we're in references section
                    // and it's not a heading, add it as a reference
                    if !trimmedLine.lowercased().contains("reference") && 
                       !trimmedLine.hasSuffix(":") {
                        refs.append(trimmedLine)
                    }
                }
            } else {
                // Add to answer
                answerParts.append(trimmedLine)
            }
        }
        
        return (answerParts.joined(separator: "\n"), refs)
    }
    
    func saveToDocument() {
        let formattedContent = """
        ## Bible Study: \(question)
        
        \(answer)
        
        **Scripture References:**
        \(references.joined(separator: "\n"))
        """
        
        // Post notification to add this content to the current document
        NotificationCenter.default.post(
            name: NSNotification.Name("AddContentToDocument"),
            object: nil,
            userInfo: ["content": formattedContent]
        )
        
        // Reset the save flag
        shouldSaveToDocument = false
    }
} 