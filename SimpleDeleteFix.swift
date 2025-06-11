import Foundation
import AppKit
import SwiftUI

// Simple fix for the right-click delete functionality
// This approach uses the same pattern as the multi-select delete button

/*
Replace the handleDelete method with this simplified version:

@objc private func handleDelete(_ sender: NSMenuItem) {
    print("handleDelete called")
    if let documentIds = sender.representedObject as? [String] {
        print("Document IDs to delete: \(documentIds)")
        selectedDocuments = Set(documentIds)
        deleteSelectedDocuments()
    } else if let documentId = sender.representedObject as? String {
        print("Single document ID to delete: \(documentId)")
        selectedDocuments = Set([documentId])
        deleteSelectedDocuments()
    } else if let document = sender.representedObject as? Letterspace_CanvasDocument {
        print("Document to delete: \(document.id)")
        selectedDocuments = Set([document.id])
        deleteSelectedDocuments()
    } else {
        print("No document IDs found in representedObject")
        if let obj = sender.representedObject {
            print("representedObject is of type: \(type(of: obj))")
        }
    }
}
*/ 