import SwiftUI
import UniformTypeIdentifiers
import Combine

enum DocumentError: Error {
    case readError(Error)
    case writeError(Error)
    case corruptedFile
    case invalidMetadata
}

extension UTType {
    static var letterspaceCanvas: UTType {
        UTType(exportedAs: "com.timothygothra.letterspacecanvas")
    }
}

class CanvasDocument: FileDocument, ObservableObject {
    @Published var content: NSAttributedString
    @Published var metadata: DocumentMetadata
    private let coordinator = NSFileCoordinator()
    private var currentURL: URL?
    
    static var readableContentTypes: [UTType] { [.letterspaceCanvas] }
    
    init() {
        self.content = NSAttributedString(string: "")
        self.metadata = DocumentMetadata()
    }
    
    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw DocumentError.corruptedFile
        }
        
        // Try to read as a document bundle
        if let wrapper = FileWrapper(serializedRepresentation: data) {
            // Read content
            if let contentData = wrapper.fileWrappers?["content.rtfd"]?.regularFileContents,
               let attributedString = try? NSAttributedString(data: contentData, 
                                                            options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                                            documentAttributes: nil) {
                self.content = attributedString
            } else {
                self.content = NSAttributedString(string: "")
            }
            
            // Read metadata
            if let metadataData = wrapper.fileWrappers?["metadata.json"]?.regularFileContents,
               let metadata = try? JSONDecoder().decode(DocumentMetadata.self, from: metadataData) {
                // Handle version migration if needed
                if metadata.version < DocumentMetadata.currentVersion {
                    self.metadata = metadata.migrated()
                } else {
                    self.metadata = metadata
                }
            } else {
                self.metadata = DocumentMetadata()
            }
        } else {
            // Fallback for legacy or corrupted files
            if let string = String(data: data, encoding: .utf8) {
                self.content = NSAttributedString(string: string)
            } else {
                self.content = NSAttributedString(string: "")
            }
            self.metadata = DocumentMetadata()
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Create document bundle
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        
        do {
            // Save content as RTFD
            let contentData = try content.data(from: NSRange(location: 0, length: content.length),
                                             documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
            let contentWrapper = FileWrapper(regularFileWithContents: contentData)
            wrapper.addFileWrapper(contentWrapper)
            contentWrapper.preferredFilename = "content.rtfd"
            
            // Save metadata as JSON
            let metadataData = try JSONEncoder().encode(metadata)
            let metadataWrapper = FileWrapper(regularFileWithContents: metadataData)
            wrapper.addFileWrapper(metadataWrapper)
            metadataWrapper.preferredFilename = "metadata.json"
            
            return wrapper
        } catch {
            throw DocumentError.writeError(error)
        }
    }
    
    // MARK: - Document State Management
    
    func updateContent(_ newContent: NSAttributedString) {
        self.content = newContent
        metadata.modifiedAt = Date()
    }
    
    func updateMetadata(_ newMetadata: DocumentMetadata) {
        // Handle version migration if needed
        if newMetadata.version < DocumentMetadata.currentVersion {
            self.metadata = newMetadata.migrated()
        } else {
            self.metadata = newMetadata
        }
        metadata.modifiedAt = Date()
    }
    
    // MARK: - AI Features

    func generateSummary(completion: @escaping (String) -> Void) {
        // Extract plain text from the attributed string
        let plainText = content.string
        
        // Skip if document is too short
        if plainText.count < 50 {
            completion("Document is too short to summarize.")
            return
        }
        
        // Check token availability before making the call
        let estimatedTokens = plainText.count / 4 + 800 // Rough estimate
        if !TokenUsageService.shared.canUseTokens(estimatedTokens) {
            completion("Token limit reached. Please purchase more tokens to generate summary.")
            return
        }

        // Call AI API for summarization
        let apiService = AIService.shared
        
        let prompt = """
        Generate a concise sermon summary for the following text.
        The summary MUST be under 450 characters (including spaces and punctuation).
        It should:
        - Clearly explain the main points and message of the sermon in a natural, easy-to-understand way.
        - Be optimized for SEO by naturally incorporating 2-3 key phrases or concepts from the sermon text that people might search for.
        - Focus on conveying the essence of the sermon for someone who didn't hear it.

        Text to summarize:
        \(plainText.prefix(2000))
        """
        
        apiService.generateText(prompt: prompt) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let summary):
                    // Store the summary in metadata
                    self.metadata.summary = summary
                    completion(summary)
                case .failure:
                    completion("Unable to generate summary at this time.")
                }
            }
        }
    }
    
    // MARK: - Document Relationships
    
    func addLink(to targetDocument: CanvasDocument, linkText: String, linkType: String) {
        let link = DocumentMetadata.DocumentLink(
            targetID: targetDocument.metadata.id,
            linkText: linkText,
            linkType: linkType
        )
        metadata.links.append(link)
        metadata.modifiedAt = Date()
    }
    
    func addReference(from sourceDocument: CanvasDocument, referenceType: String, snippet: String) {
        let reference = DocumentMetadata.DocumentReference(
            sourceID: sourceDocument.metadata.id,
            referenceType: referenceType,
            snippet: snippet
        )
        metadata.references.append(reference)
        metadata.modifiedAt = Date()
    }
    
    func setParentDocument(_ parent: CanvasDocument?) {
        metadata.parentDocumentID = parent?.metadata.id
        metadata.modifiedAt = Date()
    }
    
    func addChildDocument(_ child: CanvasDocument) {
        metadata.childDocumentIDs.append(child.metadata.id)
        metadata.modifiedAt = Date()
    }
    
    // MARK: - File Operations
    
    func save(to url: URL) throws {
        var coordinatorError: NSError?
        var saveError: Error?
        
        coordinator.coordinate(writingItemAt: url, options: [], error: &coordinatorError) { url in
            do {
                let bundle = DocumentBundle(content: self.content, metadata: self.metadata)
                let wrapper = try bundle.createFileWrapper()
                try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
                self.currentURL = url
            } catch {
                saveError = error
            }
        }
        
        if let error = coordinatorError ?? saveError {
            throw DocumentError.writeError(error)
        }
    }
    
    var fileURL: URL? {
        return currentURL
    }
}

class DocumentBundle {
    var content: NSAttributedString
    var metadata: DocumentMetadata
    
    init(content: NSAttributedString, metadata: DocumentMetadata) {
        self.content = content
        self.metadata = metadata
    }
    
    init(data: Data) throws {
        // Initialize with defaults
        self.content = NSAttributedString(string: "")
        self.metadata = DocumentMetadata()
        
        // Try to read as a document bundle
        if let wrapper = FileWrapper(serializedRepresentation: data) {
            // Read content
            if let contentData = wrapper.fileWrappers?["content.rtfd"]?.regularFileContents,
               let attributedString = try? NSAttributedString(data: contentData, 
                                                            options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                                            documentAttributes: nil) {
                self.content = attributedString
            }
            
            // Read metadata
            if let metadataData = wrapper.fileWrappers?["metadata.json"]?.regularFileContents,
               let metadata = try? JSONDecoder().decode(DocumentMetadata.self, from: metadataData) {
                self.metadata = metadata
            }
        }
    }
    
    func createFileWrapper() throws -> FileWrapper {
        // Create directory wrapper
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        
        // Save content as RTFD
        let contentData = try content.data(from: NSRange(location: 0, length: content.length),
                                         documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        let contentWrapper = FileWrapper(regularFileWithContents: contentData)
        wrapper.addFileWrapper(contentWrapper)
        contentWrapper.preferredFilename = "content.rtfd"
        
        // Save metadata as JSON
        let metadataData = try JSONEncoder().encode(metadata)
        let metadataWrapper = FileWrapper(regularFileWithContents: metadataData)
        wrapper.addFileWrapper(metadataWrapper)
        metadataWrapper.preferredFilename = "metadata.json"
        
        return wrapper
    }
} 