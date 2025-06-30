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
    case subheader
    
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
        case .subheader: return "Subheader"
        }
    }
}

extension NSAttributedString.Key {
    static let widthControl = NSAttributedString.Key("widthControl")
    static let isScriptureText = NSAttributedString.Key("isScriptureText")
}

struct DocumentElement: Identifiable, Codable, Transferable {
    let id: UUID
    var type: ElementType
    var content: String
    var placeholder: String
    var options: [String]
    var date: Date?
    var rtfData: Data?
    var isInline: Bool = false  // New property for inline attachments
    var scriptureRanges: [[Int]] = []  // Array of [start, length] pairs for scripture ranges
    
    var attributedContent: NSAttributedString? {
        get {
            guard let data = rtfData else { return nil }
            do {
                #if os(macOS)
                let docType = NSAttributedString.DocumentType.rtfd
                let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                    .documentType: docType
                ]
                let attributedString = try NSMutableAttributedString(data: data, options: options, documentAttributes: nil)
                #else
                // On iOS, first try to read as RTF
                let attributedString: NSMutableAttributedString
                do {
                    print("📖 iOS: Attempting to read rtfData as RTF...")
                    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                        .documentType: NSAttributedString.DocumentType.rtf
                    ]
                    attributedString = try NSMutableAttributedString(data: data, options: options, documentAttributes: nil)
                    print("📖 iOS: Successfully read as RTF - \(attributedString.length) characters")
                } catch {
                    print("❌ iOS: Failed to read as RTF: \(error)")
                    print("📖 iOS: Attempting to read rtfData as NSKeyedArchiver...")
                    // If RTF fails, try NSKeyedArchiver (our fallback format)
                    if let unarchivedString = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) {
                        attributedString = NSMutableAttributedString(attributedString: unarchivedString)
                        print("📖 iOS: Successfully read using NSKeyedArchiver - \(attributedString.length) characters")
                    } else {
                        print("❌ iOS: NSKeyedArchiver returned nil")
                        return nil
                    }
                }
                #endif
                
                // Preserve standard attributes from RTFD data, including .backgroundColor
                // No custom conversion needed anymore
                
                // Enumerate to log attributes if needed for debugging
                #if DEBUG
                var foundBGColor = false
                var foundLinks = false
                attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, _ in
                    if attributes[.backgroundColor] != nil {
                        foundBGColor = true
                        print("🎨 Loaded .backgroundColor attribute from RTFD in range \(range)")
                    }
                    if attributes[.link] != nil {
                        foundLinks = true
                        print("🔗 Loaded .link attribute from RTFD in range \(range)")
                    }
                }
                if !foundBGColor && attributedString.length > 0 {
                    print("🎨 No .backgroundColor found when loading RTFD")
                }
                if !foundLinks && attributedString.length > 0 {
                    print("🔗 No links found when loading RTFD")
                }
                #endif
                
                return attributedString // Return the string as loaded from RTFD
            } catch {
                print("Error converting RTFD data to NSAttributedString: \(error)")
                return nil
            }
        }
        set {
            print("📦 DocumentElement.attributedContent setter called")
            if let newValue = newValue {
                print("📦 Setting attributedContent with \(newValue.length) characters")
                do {
                    // Create a mutable copy to remove any custom attributes if they accidentally exist
                    let mutableString = NSMutableAttributedString(attributedString: newValue)
                    
                    // Remove any stray customHighlight attributes - we only want standard ones
                    mutableString.removeAttribute(NSAttributedString.Key("customHighlight"), 
                                                    range: NSRange(location: 0, length: mutableString.length))
                    
                    #if DEBUG
                    var highlightCount = 0
                    var linkCount = 0
                    mutableString.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: mutableString.length)) { value, range, _ in
                        #if os(macOS)
                        if value is NSColor {
                            highlightCount += 1
                        }
                        #elseif os(iOS)
                        if value is UIColor {
                            highlightCount += 1
                        }
                        #endif
                    }
                    mutableString.enumerateAttribute(.link, in: NSRange(location: 0, length: mutableString.length)) { value, range, _ in
                        if value is URL {
                            linkCount += 1
                        }
                    }
                    print("📦 Saving document with \(highlightCount) standard .backgroundColor ranges and \(linkCount) links")
                    #endif

                    // Convert directly to RTFD data, which will store standard attributes like .backgroundColor and .link
                    let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
                        .documentType: NSAttributedString.DocumentType.rtfd
                    ]
                    
                    let attributedString = NSAttributedString(attributedString: mutableString)
                    #if os(macOS)
                    rtfData = attributedString.rtfd(from: NSRange(location: 0, length: mutableString.length), documentAttributes: documentAttributes)
                    #else
                    // Fallback for iOS: attempt to serialize to a simple RTF or plain text, or handle error
                    // This will likely not preserve all attributes, especially images.
                    // For now, let's try RTF as a fallback, though it's less rich than RTFD.
                    // Or, if RTFD is critical, this path needs a proper iOS solution.
                    do {
                        print("📦 iOS: Attempting to serialize NSAttributedString to RTF...")
                        rtfData = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                        print("📦 iOS: Successfully serialized to RTF - \(rtfData?.count ?? 0) bytes")
                        print("📦 iOS: rtfData assigned to DocumentElement")
                    } catch {
                        print("❌ iOS: Error serializing NSAttributedString to RTF: \(error)")
                        print("❌ iOS: AttributedString length: \(attributedString.length)")
                        print("❌ iOS: AttributedString content preview: \"\(attributedString.string.prefix(100))...\"")
                        
                        // Let's try a different approach: Use NSKeyedArchiver to store the attributed string
                        print("📦 iOS: Attempting NSKeyedArchiver fallback...")
                        do {
                            rtfData = try NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: false)
                            print("📦 iOS: Successfully serialized using NSKeyedArchiver - \(rtfData?.count ?? 0) bytes")
                        } catch {
                            print("❌ iOS: NSKeyedArchiver also failed: \(error)")
                            // As a last resort, store plain text if RTF fails
                            // rtfData = attributedString.string.data(using: .utf8) 
                            // Or, better to leave rtfData nil if proper serialization fails
                            rtfData = nil 
                        }
                    }
                    #endif
                }
            } else {
                print("📦 Setting attributedContent to nil")
                rtfData = nil
            }
            print("📦 DocumentElement.attributedContent setter completed - rtfData is nil: \(rtfData == nil), size: \(rtfData?.count ?? 0) bytes")
        }
    }
    
    var attributedString: NSAttributedString {
        get {
            if let attributedContent = attributedContent {
                // Directly return the content loaded by the getter
                // No need to convert RTFD data again or handle custom highlights here
                return attributedContent
            }
            
            // Fallback to plain text without any styling
            return NSAttributedString(string: content)
        }
    }
    
    init(type: ElementType, content: String = "", placeholder: String = "", options: [String] = []) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.placeholder = placeholder
        self.options = options
        self.rtfData = nil
        self.isInline = false
    }
    
    // Transferable conformance
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .documentElement)
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, type, content, placeholder, options, date, rtfData, isInline, scriptureRanges
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
        print("📦 DocumentElement.decode: rtfData is nil: \(rtfData == nil), size: \(rtfData?.count ?? 0) bytes")
        isInline = try container.decodeIfPresent(Bool.self, forKey: .isInline) ?? false
        scriptureRanges = try container.decodeIfPresent([[Int]].self, forKey: .scriptureRanges) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(placeholder, forKey: .placeholder)
        try container.encode(options, forKey: .options)
        try container.encode(date, forKey: .date)
        print("📦 DocumentElement.encode: rtfData is nil: \(rtfData == nil), size: \(rtfData?.count ?? 0) bytes")
        try container.encodeIfPresent(rtfData, forKey: .rtfData)
        try container.encode(isInline, forKey: .isInline)
        try container.encode(scriptureRanges, forKey: .scriptureRanges)
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