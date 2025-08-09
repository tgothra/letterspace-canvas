import SwiftUI

#if os(iOS)
import UIKit

private struct ScreenEnvironmentKey: EnvironmentKey {
    static let defaultValue: UIScreen = UIScreen.main
}

extension EnvironmentValues {
    var screen: UIScreen {
        get { self[ScreenEnvironmentKey.self] }
        set { self[ScreenEnvironmentKey.self] = newValue }
    }
}
#endif


