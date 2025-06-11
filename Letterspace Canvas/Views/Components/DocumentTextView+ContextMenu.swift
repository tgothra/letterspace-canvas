#if os(macOS)
import AppKit

extension DocumentTextView {
    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        // Add standard editing actions
        menu.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        // Add other app-specific items if needed. 
        // For example, a "Format" submenu or "Toggle Bookmark".
        // menu.addItem(NSMenuItem.separator())
        // let formatMenuItem = menu.addItem(withTitle: "Format", action: nil, keyEquivalent: "")
        // let formatSubmenu = NSMenu()
        // formatSubmenu.addItem(withTitle: "Bold", action: #selector(toggleBold(_:)), keyEquivalent: "b") // Assuming toggleBold is available
        // formatSubmenu.addItem(withTitle: "Italic", action: #selector(toggleItalic(_:)), keyEquivalent: "i") // Assuming toggleItalic is available
        // menu.setSubmenu(formatSubmenu, for: formatMenuItem)

        if menu.items.isEmpty {
            return super.menu(for: event)
        }
        
        return menu
    }
}
#endif 