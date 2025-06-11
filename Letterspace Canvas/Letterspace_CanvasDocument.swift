import SwiftUI
import UniformTypeIdentifiers
import CoreText
import Combine

// MARK: - Models

struct DocumentMarker: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var type: String
    var position: Int  // Position in the document where the marker is placed
    var metadata: [String: String]?  // Optional metadata dictionary
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct DocumentSeries: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var documents: [String]  // Array of document IDs in order
    var order: Int  // Order of this document in the series
    
    static func == (lhs: DocumentSeries, rhs: DocumentSeries) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.documents == rhs.documents &&
        lhs.order == rhs.order
    }
}

struct DocumentVariation: Codable, Identifiable {
    let id: UUID
    var name: String
    var documentId: String  // ID of the variation document
    var parentDocumentId: String  // ID of the original document
    var createdAt: Date
    var datePresented: Date?
    var location: String?
    var serviceTime: String?  // Time of the service
    var notes: String?  // Additional notes
    
    // Update metadata in both documents
    mutating func updateMetadata(datePresented: Date?, location: String?, serviceTime: String? = nil, notes: String? = nil) {
        self.datePresented = datePresented
        self.location = location
        self.serviceTime = serviceTime
        self.notes = notes
    }
}

struct DocumentLink: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var url: String
    var createdAt: Date
    
    static func == (lhs: DocumentLink, rhs: DocumentLink) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.url == rhs.url &&
        lhs.createdAt == rhs.createdAt
    }
}

extension UTType {
    static var exampleText: UTType {
        UTType(importedAs: "com.example.plain-text")
    }
    
    static var canvasDocument: UTType {
        UTType(importedAs: "com.timothygothra.letterspacecanvas")
    }
}

// Define a struct to handle [String: Any] for Codable conformance
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let uint = try? container.decode(UInt.self) {
            self.value = uint
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self.value {
        case is NSNull, is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int8 as Int8:
            try container.encode(int8)
        case let int16 as Int16:
            try container.encode(int16)
        case let int32 as Int32:
            try container.encode(int32)
        case let int64 as Int64:
            try container.encode(int64)
        case let uint as UInt:
            try container.encode(uint)
        case let uint8 as UInt8:
            try container.encode(uint8)
        case let uint16 as UInt16:
            try container.encode(uint16)
        case let uint32 as UInt32:
            try container.encode(uint32)
        case let uint64 as UInt64:
            try container.encode(uint64)
        case let float as Float:
            try container.encode(float)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let date as Date:
            try container.encode(date)
        case let url as URL:
            try container.encode(url)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(self.value, context)
        }
    }
}

struct Letterspace_CanvasDocument: FileDocument, Codable, Identifiable {
    var elements: [DocumentElement]
    var title: String
    var subtitle: String
    var id: String  // Unique identifier for the document
    var markers: [DocumentMarker]
    var series: DocumentSeries?
    var variations: [DocumentVariation]
    var isVariation: Bool  // Whether this document is itself a variation
    var parentVariationId: String?  // ID of the parent document if this is a variation
    var createdAt: Date
    var modifiedAt: Date
    var tags: [String]?  // Optional array of tags
    var isHeaderExpanded: Bool  // Whether the header is expanded or collapsed
    var isSubtitleVisible: Bool  // Whether the subtitle is visible or hidden
    var links: [DocumentLink]  // Array of attached links
    var summary: String?  // Optional summary of the document
    var metadata: [String: Any]?  // Dictionary to store additional metadata like location
    
    // Add a CanvasDocument property to handle AI tools integration
    var canvasDocument = CanvasDocument()
    
    init(
        title: String = "",
        subtitle: String = "",
        elements: [DocumentElement] = [],
        id: String = UUID().uuidString,
        markers: [DocumentMarker] = [],
        series: DocumentSeries? = nil,
        variations: [DocumentVariation] = [],
        isVariation: Bool = false,
        parentVariationId: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        tags: [String]? = nil,
        isHeaderExpanded: Bool = false,
        isSubtitleVisible: Bool = true,
        links: [DocumentLink] = [],
        summary: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.elements = elements
        self.id = id
        self.markers = markers
        self.series = series
        self.variations = variations
        self.isVariation = isVariation
        self.parentVariationId = parentVariationId
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.isHeaderExpanded = isHeaderExpanded
        self.isSubtitleVisible = isSubtitleVisible
        self.links = links
        self.summary = summary
        self.metadata = metadata
        
        // Initialize the canvasDocument with content derived from elements
        let combinedText = elements.map { $0.content }.joined(separator: "\n\n")
        self.canvasDocument = CanvasDocument()
        self.canvasDocument.content = NSAttributedString(string: combinedText)
        self.canvasDocument.metadata.title = title
    }
    
    // Create a variation of this document
    mutating func createVariation(name: String, location: String?, serviceTime: String? = nil, notes: String? = nil) -> Letterspace_CanvasDocument {
        // Create new document as a copy of this one
        var variationDoc = Letterspace_CanvasDocument(
            title: name,
            subtitle: self.subtitle,
            elements: self.elements,
            id: UUID().uuidString,
            markers: self.markers,
            series: nil,
            isVariation: true,
            parentVariationId: self.id,
            createdAt: Date(),
            modifiedAt: Date(),
            summary: self.summary
        )
        
        // Create variation record in original document
        let variation = DocumentVariation(
            id: UUID(),
            name: name,
            documentId: variationDoc.id,
            parentDocumentId: self.id,
            createdAt: Date(),
            datePresented: nil,
            location: location,
            serviceTime: serviceTime,
            notes: notes
        )
        
        // Add variation record to original document
        variations.append(variation)
        
        // Add parent document as a variation in the new document
        let parentVariation = DocumentVariation(
            id: UUID(),
            name: self.title,
            documentId: self.id,
            parentDocumentId: variationDoc.id,
            createdAt: Date(),
            datePresented: nil,
            location: nil,
            serviceTime: nil,
            notes: nil
        )
        variationDoc.variations = [parentVariation]
        
        return variationDoc
    }
    
    // Update variation metadata
    mutating func updateVariationMetadata(variationId: UUID, datePresented: Date?, location: String?) {
        if let index = variations.firstIndex(where: { $0.id == variationId }) {
            variations[index].updateMetadata(datePresented: datePresented, location: location)
            
            // Save this document to persist the changes
            save()
        }
    }
    
    // Add a marker to the document
    mutating func addMarker(id: UUID, title: String, type: String, position: Int, metadata: [String: Any]? = nil) {
        if !markers.contains(where: { $0.id == id }) {
            // Convert metadata values to strings for storage
            var stringMetadata: [String: String]? = nil
            if let metadata = metadata {
                stringMetadata = [:]
                for (key, value) in metadata {
                    stringMetadata![key] = "\(value)"
                }
            }
            
            let marker = DocumentMarker(id: id, title: title, type: type, position: position, metadata: stringMetadata)
            markers.append(marker)
            markers.sort { $0.position < $1.position }
            print("✅ Added marker \(id) to document array.")
            
            // Make sure document state is saved when markers are modified
            if type == "bookmark" {
                // Don't call save() here - let the caller handle saving
                // to avoid duplicate saves and potential race conditions
                print("📝 Bookmark added, ready for caller to save document")
            }
        } else {
            print("⚠️ Marker with ID \(id) already exists in document array.")
        }
    }
    
    // Remove a marker from the document
    mutating func removeMarker(id: UUID) {
        let countBefore = markers.count
        markers.removeAll { $0.id == id }
        let countAfter = markers.count
        
        if countBefore != countAfter {
            print("✅ Removed marker \(id) from document array. Count changed from \(countBefore) to \(countAfter).")
        } else {
            print("⚠️ Marker with ID \(id) not found in document array.")
        }
        
        // Note: We don't call save() here to avoid duplicate saves
        // The caller is responsible for calling save() after this operation
    }
    
    // Update document title when header content changes
    mutating func updateTitleFromHeader() {
        if let headerElement = elements.first(where: { $0.type == .header }),
           !headerElement.content.isEmpty {
            self.title = headerElement.content
            save()
        }
    }
    
    // Update the canvasDocument content from elements
    mutating func updateCanvasDocument() {
        let combinedText = elements.map { $0.content }.joined(separator: "\n\n")
        self.canvasDocument.content = NSAttributedString(string: combinedText)
        self.canvasDocument.metadata.title = self.title
        
        // Notify observers that the canvasDocument has changed
        self.canvasDocument.objectWillChange.send()
    }
    
    // Update the elements from canvasDocument content
    mutating func updateElementsFromCanvasDocument() {
        // This is a simplified implementation - in a real app, you'd need more sophisticated
        // parsing to convert the attributed string back to elements
        
        // For now, we'll just update the first text element if it exists
        if let index = elements.firstIndex(where: { $0.type == .textBlock }) {
            elements[index].content = canvasDocument.content.string
        } else if !elements.isEmpty {
            // If no text element exists but there are other elements, update the first one
            elements[0].content = canvasDocument.content.string
        } else {
            // If no elements exist, create a new text element
            let newElement = DocumentElement(
                type: .textBlock,
                content: canvasDocument.content.string
            )
            elements.append(newElement)
        }
        
        // Update title from metadata
        self.title = canvasDocument.metadata.title
    }
    
    // Add a method to handle updates from the canvasDocument
    mutating func handleCanvasDocumentUpdate() {
        updateElementsFromCanvasDocument()
        save()
    }
    
    // MARK: - Document Directory Helper
    
    /// Gets the documents directory - use local Documents for stability
    static func getDocumentsDirectory() -> URL? {
        // For now, use local Documents directory on all platforms for stability
        // This avoids iCloud sync issues that can cause app termination
        let localDocuments = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        print("📂 Using local Documents directory: \(localDocuments?.path ?? "nil")")
        return localDocuments
    }
    
    /// Gets the app's document storage directory (includes "Letterspace Canvas" folder)
    static func getAppDocumentsDirectory() -> URL? {
        guard let documentsPath = getDocumentsDirectory() else {
            return nil
        }
        return documentsPath.appendingPathComponent("Letterspace Canvas")
    }

    mutating func save() {
        // Update the canvasDocument before saving
        updateCanvasDocument()

        // --- DEBUGGING: Log markers array before saving ---
        print("💾 save(): Preparing to save document ID \(id).")
        print("💾 save(): Current markers array: [")
        for marker in markers {
            print("  - Marker ID: \(marker.id), Title: \"\(marker.title)\", Type: \(marker.type), Pos: \(marker.position)")
        }
        print("]")
        // --- END DEBUGGING ---

        guard let appDirectory = Self.getAppDocumentsDirectory() else {
            print("❌ Could not determine documents directory path")
            return
        }

        do {
            // Create app directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            print("📁 Created or verified app directory at: \(appDirectory.path)")
            
            let fileURL = appDirectory.appendingPathComponent("\(id).canvas")
            print("💾 Saving document to: \(fileURL.path)")
            
            let coordinator = NSFileCoordinator()
            var error: NSError?
            
            coordinator.coordinate(writingItemAt: fileURL, options: [], error: &error) { url in
                do {
                    // Update modification date
                    self.modifiedAt = Date()
                    
                    let data = try JSONEncoder().encode(self)
                    print("📦 Encoded document data size: \(data.count) bytes")
                    
                    try data.write(to: url, options: .atomic)
                    print("✅ Successfully wrote document to disk")
                    
                    // Post notification for document list update
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
                        print("📢 Posted document update notification")
                    }
                } catch {
                    print("❌ Error saving document: \(error)")
                }
            }
            
            if let error = error {
                print("❌ File coordination error: \(error)")
            }
        } catch {
            print("❌ Error creating app directory: \(error)")
        }
    }
    
    static var readableContentTypes: [UTType] { [.canvasDocument] }
    
    enum CodingKeys: String, CodingKey {
        case elements, title, subtitle, id, markers, series, variations, isVariation, parentVariationId, createdAt, modifiedAt, tags, isHeaderExpanded, isSubtitleVisible, links, summary, metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        elements = try container.decode([DocumentElement].self, forKey: .elements)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        id = try container.decode(String.self, forKey: .id)
        markers = try container.decode([DocumentMarker].self, forKey: .markers)
        series = try container.decodeIfPresent(DocumentSeries.self, forKey: .series)
        variations = try container.decode([DocumentVariation].self, forKey: .variations)
        isVariation = try container.decode(Bool.self, forKey: .isVariation)
        parentVariationId = try container.decodeIfPresent(String.self, forKey: .parentVariationId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        isHeaderExpanded = try container.decode(Bool.self, forKey: .isHeaderExpanded)
        isSubtitleVisible = try container.decodeIfPresent(Bool.self, forKey: .isSubtitleVisible) ?? true
        links = try container.decodeIfPresent([DocumentLink].self, forKey: .links) ?? []
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        
        // Handle metadata as a dictionary of AnyCodable values
        if let metadataDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata) {
            metadata = metadataDict.mapValues { $0.value }
        } else {
            metadata = nil
        }
        
        // Initialize the canvasDocument with content derived from elements
        let combinedText = elements.map { $0.content }.joined(separator: "\n\n")
        self.canvasDocument = CanvasDocument()
        self.canvasDocument.content = NSAttributedString(string: combinedText)
        self.canvasDocument.metadata.title = title
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(elements, forKey: .elements)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(id, forKey: .id)
        try container.encode(markers, forKey: .markers)
        try container.encodeIfPresent(series, forKey: .series)
        try container.encode(variations, forKey: .variations)
        try container.encode(isVariation, forKey: .isVariation)
        try container.encodeIfPresent(parentVariationId, forKey: .parentVariationId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encode(isHeaderExpanded, forKey: .isHeaderExpanded)
        try container.encode(isSubtitleVisible, forKey: .isSubtitleVisible)
        try container.encode(links, forKey: .links)
        try container.encodeIfPresent(summary, forKey: .summary)
        
        // Encode metadata as a dictionary of AnyCodable values
        if let metadataDict = metadata {
            try container.encode(metadataDict.mapValues { AnyCodable($0) }, forKey: .metadata)
        }
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let document = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.title = document.title
        self.subtitle = document.subtitle
        self.elements = document.elements
        self.id = document.id
        self.markers = document.markers
        self.series = document.series
        self.variations = document.variations
        self.isVariation = document.isVariation
        self.parentVariationId = document.parentVariationId
        self.createdAt = document.createdAt
        self.modifiedAt = document.modifiedAt
        self.tags = document.tags
        self.isHeaderExpanded = document.isHeaderExpanded
        self.isSubtitleVisible = document.isSubtitleVisible
        self.links = document.links
        self.summary = document.summary
        
        // Initialize the canvasDocument with content derived from elements
        let combinedText = elements.map { $0.content }.joined(separator: "\n\n")
        self.canvasDocument = CanvasDocument()
        self.canvasDocument.content = NSAttributedString(string: combinedText)
        self.canvasDocument.metadata.title = title
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(self)
        return FileWrapper(regularFileWithContents: data)
    }
    
    // Add a variation to this document
    mutating func addVariation(_ variationDoc: Letterspace_CanvasDocument, name: String) {
        // Create variation record for the parent document (this document)
        let variation = DocumentVariation(
            id: UUID(),
            name: name,
            documentId: variationDoc.id,
            parentDocumentId: self.id,
            createdAt: Date(),
            datePresented: nil,
            location: nil,
            serviceTime: nil,
            notes: nil
        )
        
        // Add variation record to this document
        variations.append(variation)
        
        // Save both documents
        save()
        
        var updatedVariationDoc = variationDoc
        updatedVariationDoc.save()
        
        // Post notifications to update the UI
        NotificationCenter.default.post(
            name: NSNotification.Name("DocumentListDidUpdate"), 
            object: nil
        )
    }
    
    // Create a new variation of this document and return it
    func createVariation() -> Letterspace_CanvasDocument {
        // Create new document as a copy of this one
        let variationDoc = Letterspace_CanvasDocument(
            title: self.title,
            subtitle: self.subtitle,
            elements: self.elements,
            id: UUID().uuidString,
            markers: self.markers,
            series: nil,
            isVariation: true,
            parentVariationId: self.id,
            createdAt: Date(),
            modifiedAt: Date(),
            tags: self.tags,
            isHeaderExpanded: self.isHeaderExpanded,
            isSubtitleVisible: self.isSubtitleVisible,
            links: self.links,
            summary: self.summary
        )
        
        return variationDoc
    }
    
    // Static method to load a document by ID from disk
    static func load(id: String) -> Letterspace_CanvasDocument? {
        guard let appDirectory = getAppDocumentsDirectory() else {
            print("❌ Could not access documents directory")
            return nil
        }
        
        let fileURL = appDirectory.appendingPathComponent("\(id).canvas")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedDoc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
            print("✅ Successfully loaded document: \(loadedDoc.title) (ID: \(id))")
            return loadedDoc
        } catch {
            print("❌ Error loading document \(id): \(error)")
            return nil
        }
    }

    // Helper to access metadata with proper type conversion
    func getMetadataString(for key: String) -> String? {
        return metadata?[key] as? String
    }
    
    // Helper to update metadata
    mutating func setMetadata(key: String, value: Any) {
        var updatedMetadata = metadata ?? [:]
        updatedMetadata[key] = value
        metadata = updatedMetadata
    }
    
    // A version of save() that throws errors instead of just printing them
    mutating func saveWithErrorHandling() throws {
        // Update the canvasDocument before saving
        updateCanvasDocument()
        
        // Log debug info
        print("💾 saveWithErrorHandling(): Saving document ID \(id), title: \(title)")
        
        guard let appDirectory = Self.getAppDocumentsDirectory() else {
            throw DocumentSaveError.documentsDirectoryUnavailable
        }
        
        // Create app directory if it doesn't exist
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        print("📁 Created or verified app directory at: \(appDirectory.path)")
        
        let fileURL = appDirectory.appendingPathComponent("\(id).canvas")
        print("💾 Saving document to: \(fileURL.path)")
        
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var saveError: Error?
        
        coordinator.coordinate(writingItemAt: fileURL, options: [], error: &coordinationError) { url in
            do {
                // Update modification date
                self.modifiedAt = Date()
                
                let data = try JSONEncoder().encode(self)
                try data.write(to: url, options: .atomic)
                print("✅ Successfully wrote document to disk")
            } catch {
                saveError = error
                print("❌ Error encoding or writing document: \(error)")
            }
        }
        
        // Check for errors and throw if any occurred
        if let error = coordinationError {
            throw DocumentSaveError.fileCoordinationError(error)
        }
        
        if let error = saveError {
            throw DocumentSaveError.writeError(error)
        }
        
        // Post notification for document list update
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
            print("📢 Posted document update notification")
        }
    }
}

// Define document save errors
enum DocumentSaveError: Error {
    case documentsDirectoryUnavailable
    case fileCoordinationError(NSError)
    case writeError(Error)
    case encodingError(Error)
} 