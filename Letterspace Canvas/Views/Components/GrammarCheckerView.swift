import SwiftUI

struct GrammarCheckerView: View {
    @Binding var text: String
    @State private var suggestions: [TextSuggestion] = []
    @State private var isChecking: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Grammar & Style")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Identify and fix grammar and style issues")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            // Suggestions section
            Group {
                if isChecking {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Checking text...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.lightGray).opacity(0.2))
                    .cornerRadius(8)
                } else if suggestions.isEmpty {
                    Text("No grammar or style issues found.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.lightGray).opacity(0.2))
                        .cornerRadius(8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(suggestions) { suggestion in
                                SuggestionRow(suggestion: suggestion) { 
                                    applySuggestion(suggestion)
                                }
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.lightGray).opacity(0.2))
                        .cornerRadius(8)
                    }
                    .frame(maxHeight: 300)
                }
            }
            
            // Action button
            Button(action: {
                checkGrammar()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Check Grammar & Style")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isChecking || text.isEmpty)
        }
        .padding()
        .frame(minWidth: 400, maxWidth: 600)
    }
    
    func checkGrammar() {
        isChecking = true
        TextChecker.shared.checkText(text) { result in
            DispatchQueue.main.async {
                isChecking = false
                
                switch result {
                case .success(let newSuggestions):
                    self.suggestions = newSuggestions
                case .failure:
                    self.suggestions = []
                }
            }
        }
    }
    
    func applySuggestion(_ suggestion: TextSuggestion) {
        if let range = text.range(of: suggestion.originalText) {
            text = text.replacingCharacters(in: range, with: suggestion.suggestedText)
            
            // Remove the applied suggestion
            suggestions.removeAll { $0.id == suggestion.id }
        }
    }
}

struct SuggestionRow: View {
    let suggestion: TextSuggestion
    let onApply: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: suggestion.type.icon)
                    .foregroundColor(Color(suggestion.type.color))
                
                Text(suggestion.type == .grammar ? "Grammar" : "Style")
                    .font(.headline)
                    .foregroundColor(Color(suggestion.type.color))
            }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.originalText)
                        .padding(6)
                        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.red, lineWidth: 1)
                        )
                }
                
                Image(systemName: "arrow.right")
                    .padding(.horizontal, 8)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.suggestedText)
                        .padding(6)
                        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.green, lineWidth: 1)
                        )
                }
            }
            
            Text(suggestion.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            
            Button(action: onApply) {
                Text("Apply Suggestion")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            .padding(.top, 4)
            
            Divider()
                .padding(.top, 8)
        }
    }
} 