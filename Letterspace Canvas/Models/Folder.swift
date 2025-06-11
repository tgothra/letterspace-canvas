import Foundation

struct Folder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isEditing: Bool
    var subfolders: [Folder]
    var parentId: UUID?
    var documentIds: Set<String>  // Add document IDs storage
    
    enum CodingKeys: String, CodingKey {
        case id, name, isEditing, subfolders, parentId, documentIds
    }
    
    init(id: UUID = UUID(), name: String, isEditing: Bool = false, subfolders: [Folder] = [], parentId: UUID? = nil, documentIds: Set<String> = []) {
        self.id = id
        self.name = name
        self.isEditing = isEditing
        self.subfolders = subfolders
        self.parentId = parentId
        self.documentIds = documentIds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isEditing = try container.decodeIfPresent(Bool.self, forKey: .isEditing) ?? false
        subfolders = try container.decode([Folder].self, forKey: .subfolders)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        documentIds = try container.decodeIfPresent(Set<String>.self, forKey: .documentIds) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isEditing, forKey: .isEditing)
        try container.encode(subfolders, forKey: .subfolders)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(documentIds, forKey: .documentIds)
    }
    
    // Implement Equatable
    static func == (lhs: Folder, rhs: Folder) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.isEditing == rhs.isEditing &&
               lhs.subfolders == rhs.subfolders &&
               lhs.parentId == rhs.parentId &&
               lhs.documentIds == rhs.documentIds
    }
} 