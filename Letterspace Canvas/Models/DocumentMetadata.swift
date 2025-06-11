import Foundation

struct DocumentMetadata: Codable {
    var id: String
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var version: Int
    var tags: [String]
    var links: [DocumentLink]
    var references: [DocumentReference]
    var parentDocumentID: String?
    var childDocumentIDs: [String]
    var summary: String?
    var hasHeaderImage: Bool = false // Whether the document has a header image
    
    enum CodingKeys: CodingKey {
        case id, title, createdAt, modifiedAt, version, tags, links, references, parentDocumentID, childDocumentIDs, summary, hasHeaderImage
    }
    
    static let currentVersion: Int = 2
    
    init() {
        self.id = UUID().uuidString
        self.title = "Untitled"
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.version = DocumentMetadata.currentVersion
        self.tags = []
        self.links = []
        self.references = []
        self.parentDocumentID = nil
        self.childDocumentIDs = []
        self.summary = nil
        self.hasHeaderImage = false
    }
    
    func migrated() -> DocumentMetadata {
        var updated = self
        
        // Handle version migrations
        if version < 2 {
            // Add any migration logic for version 1 to 2
            updated.version = 2
        }
        
        return updated
    }
    
    // Document relationships
    struct DocumentLink: Codable {
        var targetID: String
        var linkText: String
        var linkType: String
    }
    
    struct DocumentReference: Codable {
        var sourceID: String
        var referenceType: String
        var snippet: String
    }
} 