import SwiftUI

public enum TextSize: Int, CaseIterable {
    case small = 1     // 12pt
    case medium = 2    // 13pt
    case large = 3     // 14pt
    case xlarge = 4    // 15pt
    case xxlarge = 5   // 16pt
    
    public var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 13
        case .large: return 14
        case .xlarge: return 15
        case .xxlarge: return 16
        }
    }
    
    public var referenceFontSize: CGFloat {
        fontSize
    }
    
    public var label: String {
        "A\(rawValue)"
    }
    
    public mutating func cycle() {
        self = TextSize.allCases[(TextSize.allCases.firstIndex(of: self)! + 1) % TextSize.allCases.count]
    }
} 
