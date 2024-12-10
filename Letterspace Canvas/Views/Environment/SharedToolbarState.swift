import SwiftUI

private struct SharedToolbarStateKey: EnvironmentKey {
    static let defaultValue: Binding<UUID?> = .constant(nil)
}

extension EnvironmentValues {
    var sharedToolbarState: Binding<UUID?> {
        get { self[SharedToolbarStateKey.self] }
        set { self[SharedToolbarStateKey.self] = newValue }
    }
} 