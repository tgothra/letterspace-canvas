import SwiftUI

// MARK: - Supporting Types
// These types are referenced in the components above

struct Series: Identifiable {
    let id = UUID()
    let name: String
    var description: String?
    var color: Color?
}