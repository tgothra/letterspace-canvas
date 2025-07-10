import SwiftUI
import Foundation
import CoreGraphics

struct ListColumn: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    
    // Add flex proportion method
    func flexProportion() -> CGFloat {
        switch id {
        case "name":
            return 2.0  // Name column gets double the flex space
        case "series":
            return 1.2  // Series gets slightly more than standard
        case "location":
            return 1.4  // Increased from 1.0 to 1.4 to make location wider
        case "date", "createdDate", "presentedDate":
            return 0.6  // Reduced from 0.8 to 0.6 to make date columns narrower
        default:
            return 1.0
        }
    }
    
    var width: CGFloat {
        // Minimum widths for each column type
        switch id {
        case "name":
            return 250  // Base width for name column
        case "series":
            return 180  // Fixed width for series
        case "location":
            return 150  // Fixed width for location
        case "date", "createdDate", "presentedDate":
            return 110  // Fixed width for date columns
        default:
            return calculateWidth(for: [])
        }
    }
    
    // Calculate width based on content
    func calculateWidth(for documents: [Letterspace_CanvasDocument]) -> CGFloat {
        // Base padding
        let padding: CGFloat = 40
        let minWidth: CGFloat = 100
        
        // For series, location, and date columns, return fixed width
        if id == "series" {
            return 180
        }
        if id == "location" {
            return 150
        }
        if id == "date" || id == "createdDate" || id == "presentedDate" {
            return 110
        }
        
        let maxWidth: CGFloat = documents.reduce(CGFloat(title.count * 10)) { maxWidth, doc in
            let content: String = {
                switch id {
                // Note: Need the actual Letterspace_CanvasDocument definition
                // to properly calculate content width here.
                // For now, returning an empty string.
                default:
                    return ""
                }
            }()
            
            return max(maxWidth, CGFloat(content.count * 10))
        }
        
        return max(minWidth, maxWidth + padding)
    }
    
    static let name = ListColumn(id: "name", title: "Name", icon: "doc.text")
    static let series = ListColumn(id: "series", title: "Series", icon: "folder")
    static let location = ListColumn(id: "location", title: "Location", icon: "location")
    static let date = ListColumn(id: "date", title: "Last Modified", icon: "clock")
    static let createdDate = ListColumn(id: "createdDate", title: "Created On", icon: "calendar")
    static let presentedDate = ListColumn(id: "presentedDate", title: "Presented On", icon: "calendar.badge.clock")
    
    // Add allColumns for easy access
    static let allColumns: [ListColumn] = [
        .name,
        .series,
        .location,
        .date,
        .createdDate,
        .presentedDate
    ]
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ListColumn, rhs: ListColumn) -> Bool {
        return lhs.id == rhs.id
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Add width for documents function within the struct instead of as an extension
    // Note: The 'calculateWidth' function relies on Letterspace_CanvasDocument,
    // which is not defined in this file. This will cause a compile error.
    // We'll need to either pass the document type or the relevant properties.
    func width(for documents: [Letterspace_CanvasDocument]) -> CGFloat {
        switch id {
        case "name":
            return 250  // Changed from 350 to 250
        default:
            return calculateWidth(for: documents)
        }
    }
}

// Placeholder for Letterspace_CanvasDocument if not available globally
// You should replace this with the actual definition or necessary imports
// REMOVING THIS BLOCK:
// struct Letterspace_CanvasDocument: Decodable, Identifiable { 
//     var id: String = UUID().uuidString
//     var title: String = ""
//     // Add other properties used by calculateWidth if necessary
// } 