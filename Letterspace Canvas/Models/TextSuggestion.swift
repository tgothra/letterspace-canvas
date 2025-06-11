import Foundation

struct TextSuggestion: Identifiable {
    enum SuggestionType {
        case grammar
        case style
        case vocabulary
        
        var icon: String {
            switch self {
            case .grammar:
                return "checkmark.circle"
            case .style:
                return "pencil.circle"
            case .vocabulary:
                return "wand.and.stars"
            }
        }
        
        var color: String {
            switch self {
            case .grammar:
                return "red"
            case .style:
                return "blue"
            case .vocabulary:
                return "green"
            }
        }
    }
    
    let id = UUID()
    let originalText: String
    let suggestedText: String
    let reason: String
    let type: SuggestionType
} 