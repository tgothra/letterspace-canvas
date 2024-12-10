import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ElementType: String, Codable {
    case header
    case title
    case headerImage
    case image
    case textBlock
    case dropdown
    case date
    case multiSelect
    case chart
    case signature
    case table
    case scripture
    
    var description: String {
        switch self {
        case .image: return "Logo or graphic"
        case .textBlock: return "Multiple line text"
        case .table: return "Columns & rows"
        case .dropdown: return "Select from list"
        case .date: return "Select date & time"
        case .multiSelect: return "Select multiple items"
        case .chart: return "Graph line elements"
        case .signature: return "Collect signatures"
        case .header: return "Static titles & text"
        case .title: return "Title"
        case .headerImage: return "Header Image"
        case .scripture: return "Bible verse"
        }
    }
}

struct DocumentElement: Identifiable, Codable, Transferable {
    let id: UUID
    var type: ElementType
    var content: String
    var placeholder: String
    var options: [String]
    var date: Date?
    private var rtfData: Data?  // Store RTF data for attributed content
    
    var attributedContent: NSAttributedString? {
        get {
            guard let data = rtfData else { return nil }
            do {
                return try NSAttributedString(data: data,
                                            options: [.documentType: NSAttributedString.DocumentType.rtf],
                                            documentAttributes: nil)
            } catch {
                print("Error converting RTF data to NSAttributedString: \(error)")
                return nil
            }
        }
        set {
            if let newValue = newValue {
                do {
                    rtfData = try newValue.data(from: NSRange(location: 0, length: newValue.length),
                                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                } catch {
                    print("Error converting NSAttributedString to RTF data: \(error)")
                    rtfData = nil
                }
            } else {
                rtfData = nil
            }
        }
    }
    
    init(type: ElementType, content: String = "", placeholder: String = "", options: [String] = []) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.placeholder = placeholder
        self.options = options
        self.rtfData = nil
    }
    
    // Transferable conformance
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .documentElement)
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, type, content, placeholder, options, date, rtfData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ElementType.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        placeholder = try container.decode(String.self, forKey: .placeholder)
        options = try container.decode([String].self, forKey: .options)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        rtfData = try container.decodeIfPresent(Data.self, forKey: .rtfData)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(placeholder, forKey: .placeholder)
        try container.encode(options, forKey: .options)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(rtfData, forKey: .rtfData)
    }
}

// Custom UTType for our document element
extension UTType {
    static var documentElement: UTType {
        UTType(importedAs: "com.timothygothra.letterspace.documentElement")
    }
}

// Add Equatable conformance to DocumentElement
extension DocumentElement: Equatable {
    static func == (lhs: DocumentElement, rhs: DocumentElement) -> Bool {
        lhs.id == rhs.id && 
        lhs.type == rhs.type && 
        lhs.content == rhs.content
    }
} 