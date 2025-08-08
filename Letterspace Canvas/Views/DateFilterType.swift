// Update the DateFilterType enum
enum DateFilterType {
    case modified
    case created
    
    var title: String {
        switch self {
        case .modified:
            return "Modified"
        case .created:
            return "Created"
        }
    }
} 