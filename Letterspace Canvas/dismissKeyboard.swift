#if os(macOS)
import AppKit

extension NSResponder {
    func dismissKeyboard() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}
#endif
