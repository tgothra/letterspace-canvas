import Foundation
import AppKit
import SwiftUI

// ===== STEP 1: Add this extension to your HomeView.swift file =====
// Add this at the top of the file, after the imports

extension NSMenuItem {
    func setDocumentIdForDeletion(_ documentId: String) {
        self.representedObject = [documentId]
        print("Set representedObject to: \([documentId])")
    }
}

// ===== STEP 2: Replace the handleDelete method with this improved version =====
// Find the existing handleDelete method (around line 3284) and replace it with this:

/*
@objc private func handleDelete(_ sender: NSMenuItem) {
    print("handleDelete called")
    print("representedObject type: \(type(of: sender.representedObject))")
    print("representedObject value: \(String(describing: sender.representedObject))")
    
    if let documentIds = sender.representedObject as? [String] {
        print("Document IDs to delete: \(documentIds)")
        onDelete?(documentIds)
    } else if let documentId = sender.representedObject as? String {
        print("Single document ID to delete: \(documentId)")
        onDelete?([documentId])
    } else if let document = sender.representedObject as? Letterspace_CanvasDocument {
        print("Document to delete: \(document.id)")
        onDelete?([document.id])
    } else {
        print("No document IDs found in representedObject")
        if let obj = sender.representedObject {
            print("representedObject is of type: \(type(of: obj))")
        } else {
            print("representedObject is nil")
        }
    }
}
*/

// ===== STEP 3: Update the context menu creation code =====
// Find the context menu creation code (around line 3210) and update it:

/*
// Create context menu
let menu = NSMenu()
menu.items = [
    NSMenuItem(title: "Pin", action: #selector(handlePin(_:)), keyEquivalent: ""),
    NSMenuItem(title: "Mark as WIP", action: #selector(handleWIP(_:)), keyEquivalent: ""),
    NSMenuItem(title: "Add to Calendar", action: #selector(handleCalendar(_:)), keyEquivalent: ""),
    NSMenuItem.separator(),
    NSMenuItem(title: "Create Variation", action: #selector(handleCreateVariation(_:)), keyEquivalent: ""),
    NSMenuItem(title: "Duplicate", action: #selector(handleDuplicate(_:)), keyEquivalent: ""),
    NSMenuItem.separator(),
    NSMenuItem(title: "Delete", action: #selector(handleDelete(_:)), keyEquivalent: "")
]

// Set represented objects for menu items
menu.items[0].representedObject = [document.id]
menu.items[1].representedObject = [document.id]
menu.items[2].representedObject = document.id
menu.items[4].representedObject = document
menu.items[5].representedObject = document

// Use the extension method for the delete item
menu.items[7].setDocumentIdForDeletion(document.id)

// Update menu item states based on current status
menu.items[0].state = coordinator.pinnedDocuments.contains(document.id) ? .on : .off
menu.items[1].state = coordinator.wipDocuments.contains(document.id) ? .on : .off
menu.items[2].state = coordinator.calendarDocuments.contains(document.id) ? .on : .off

NSMenu.popUpContextMenu(menu, with: event, for: self)
*/ 