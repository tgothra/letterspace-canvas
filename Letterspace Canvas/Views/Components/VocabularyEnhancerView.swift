import SwiftUI

struct VocabularyEnhancerView: View {
    @Binding var text: String
    @State private var suggestions: [TextSuggestion] = []
    @State private var isEnhancing: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Vocabulary Enhancement")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Discover more precise and vivid word alternatives")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            // Suggestions section
            Group {
                if isEnhancing {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Finding vocabulary enhancements...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color(.lightGray).opacity(0.2))
                    .cornerRadius(8)
                } else if suggestions.isEmpty {
                    Text("No vocabulary enhancements available.")
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
                                    applyEnhancement(suggestion)
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
                enhanceVocabulary()
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Enhance Vocabulary")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isEnhancing || text.isEmpty)
        }
        .padding()
        .frame(minWidth: 400, maxWidth: 600)
    }
    
    func enhanceVocabulary() {
        isEnhancing = true
        TextChecker.shared.enhanceVocabulary(in: text) { result in
            DispatchQueue.main.async {
                isEnhancing = false
                
                switch result {
                case .success(let newSuggestions):
                    self.suggestions = newSuggestions
                case .failure:
                    self.suggestions = []
                }
            }
        }
    }
    
    func applyEnhancement(_ suggestion: TextSuggestion) {
        if let range = text.range(of: suggestion.originalText) {
            text = text.replacingCharacters(in: range, with: suggestion.suggestedText)
            
            // Remove the applied suggestion
            suggestions.removeAll { $0.id == suggestion.id }
        }
    }
} 