import Foundation
import PDFKit
import Combine

// Enum to represent the type of library item
enum LibraryItemType: Codable {
    case pdf
    case webLink
    case file
}

// Represents a text chunk and its vector embedding
struct LibraryChunk: Codable, Identifiable {
    let id: UUID
    let text: String
    var vector: [Double]? // Store the embedding vector (optional initially)
    // Consider adding parentItemId if needed: let parentItemId: UUID
}

// Struct to represent an item in the user's library
struct UserLibraryItem: Identifiable, Codable {
    let id: UUID
    var type: LibraryItemType
    var title: String
    var source: String // URL string or file path
    // Remove raw content, store chunks instead
    // var content: String 
    var chunks: [LibraryChunk]? // Store chunks and vectors here
    let dateAdded: Date
    var isEmbeddingComplete: Bool = false // Track embedding status
    
    // Initializer
    init(id: UUID, type: LibraryItemType, title: String, source: String, chunks: [LibraryChunk]? = nil, dateAdded: Date, isEmbeddingComplete: Bool = false) {
        self.id = id
        self.type = type
        self.title = title
        self.source = source
        self.chunks = chunks
        self.dateAdded = dateAdded
        self.isEmbeddingComplete = isEmbeddingComplete
    }
    
    // Convenience to get all text content if needed (e.g., for basic search fallback)
    var allContentText: String {
        return chunks?.map { $0.text }.joined(separator: "\n\n") ?? ""
    }
}

// Service to manage the user's library items
class UserLibraryService: ObservableObject {
    @Published var libraryItems: [UserLibraryItem] = []
    
    // Static instance for preloading
    private static var preloadedInstance: UserLibraryService?
    
    // Simple in-memory storage for now
    
    // MARK: - Preloading
    
    static func preload() {
        if preloadedInstance == nil {
            Task.detached(priority: .background) {
                let instance = UserLibraryService()
                await MainActor.run {
                    preloadedInstance = instance
                }
            }
        }
    }
    
    static func getPreloadedInstance() -> UserLibraryService {
        return preloadedInstance ?? UserLibraryService()
    }
    
    // MARK: - iCloud Helpers

    // Gets the root URL of the app's ubiquitous container
    private func getUbiquitousContainerURL() -> URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)
    }

    // Gets the URL for the "LibraryPdfs" directory within the iCloud container, creating it if needed.
    // Made public so LibraryView can construct full paths for opening PDFs
    public func getLibraryPdfsDirectoryURL() -> URL? {
        guard let containerURL = getUbiquitousContainerURL() else {
            print("❌ iCloud container URL not found. Is iCloud enabled and logged in?")
            return nil
        }
        
        let documentsURL = containerURL.appendingPathComponent("Documents") // Standard subdirectory
        let pdfsDirectoryURL = documentsURL.appendingPathComponent("LibraryPdfs")
        
        // Create the directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: pdfsDirectoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: pdfsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                print("☁️ Created LibraryPdfs directory in iCloud: \(pdfsDirectoryURL.path)")
            } catch {
                print("❌ Failed to create LibraryPdfs directory in iCloud: \(error.localizedDescription)")
                return nil
            }
        }
        return pdfsDirectoryURL
    }
    
    // MARK: - Initialization
    
    init() {
        // Load items from persistence on init
        loadItems()
    }
    
    // MARK: - Item Management
    
    func addItem(item: UserLibraryItem) {
        // Basic validation to avoid duplicates by source
        if !libraryItems.contains(where: { $0.source == item.source }) {
            libraryItems.append(item)
            saveItems() // Persist changes
            print("Added Library Item: \(item.title)")
        } else {
            print("Library Item from source \(item.source) already exists.")
        }
    }
    
    func deleteItem(id: UUID) {
        libraryItems.removeAll { $0.id == id }
        saveItems() // Persist changes
        print("Deleted Library Item with ID: \(id)")
    }
    
    // MARK: - Content Extraction (Placeholders)
    
    func extractTextFromPDF(url: URL, completion: @escaping (String?) -> Void) {
        
        // --- Determine the actual URL to use ---
        var effectiveURL: URL
        let sourceString = url.absoluteString // Or get this from the UserLibraryItem if available
        
        // Check if the sourceString looks like just a filename (our new iCloud storage format)
        if !sourceString.contains("/") && sourceString.hasSuffix(".pdf") {
            // Assume it's a filename in our iCloud LibraryPdfs directory
            if let pdfsDirectory = getLibraryPdfsDirectoryURL() {
                effectiveURL = pdfsDirectory.appendingPathComponent(sourceString)
                print("☁️ Reconstructed iCloud PDF URL: \(effectiveURL.path)")
            } else {
                print("❌ Cannot reconstruct iCloud URL, container not available for filename: \(sourceString)")
                completion(nil)
                return
            }
        } else {
            // Assume it's a full original URL (file path or web url passed directly)
            effectiveURL = url
            print("📄 Using provided URL directly: \(effectiveURL.path)")
        }
        // --- End URL determination ---
        
        // First check if this might be an iCloud file that needs downloading
        // Use effectiveURL for checks and operations below
        let resourceValues = try? effectiveURL.resourceValues(forKeys: [.ubiquitousItemIsDownloadingKey, .ubiquitousItemDownloadingStatusKey, .isUbiquitousItemKey])
        let isDownloading = resourceValues?.ubiquitousItemIsDownloading ?? false
        let downloadStatus = resourceValues?.ubiquitousItemDownloadingStatus
        let isUbiquitous = resourceValues?.isUbiquitousItem ?? false
        
        print("📄 iCloud status for file: \(effectiveURL.lastPathComponent)")
        print("   - Is Ubiquitous: \(isUbiquitous)")
        print("   - Is downloading: \(isDownloading)")
        print("   - Download status: \(downloadStatus?.rawValue ?? "unknown")")
        
        // If it's an iCloud file that's not downloaded yet, use NSFileCoordinator to coordinate access
        if isUbiquitous && downloadStatus != .current {
            print("📥 Starting download of iCloud file...")
            
            // Use NSFileCoordinator to handle iCloud file access
            let fileCoordinator = NSFileCoordinator(filePresenter: nil)
            var coordinatorError: NSError?
            
            fileCoordinator.coordinate(readingItemAt: effectiveURL, options: .withoutChanges, error: &coordinatorError) { coordinatedURL in
                // This block might be called after the file is downloaded or available.
                // We can now proceed to read the content from coordinatedURL.
                print("🤝 Coordinated read access granted for: \(coordinatedURL.path)")
                 // Re-run extraction logic using the coordinated URL
                 self.processPdfContent(from: coordinatedURL, completion: completion)
            }
            
            if let error = coordinatorError {
                print("⚠️ File coordination error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
            
            return // Exit here, coordination block will handle the rest
        }
        
        // Continue with normal processing if not an iCloud download issue, or if coordination wasn't needed
        processPdfContent(from: effectiveURL, completion: completion)
    }
    
    // Helper function to contain the actual PDF processing logic
    private func processPdfContent(from url: URL, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var extractedText = ""
            
            print("📄 Attempting to process PDF content from: \(url)")
            print("   - Is File URL: \(url.isFileURL)")
            print("   - Path: \(url.path)")
            
            // Directly try to read the file data first
            do {
                let fileData = try Data(contentsOf: url, options: .mappedIfSafe)
                print("   - Successfully read \(fileData.count) bytes from file")
                
                if fileData.count == 0 {
                    print("⚠️ File appears to be empty (0 bytes).")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // Now try to create PDFDocument from data instead of URL
                if let pdfDocument = PDFDocument(data: fileData) {
                    // Check if document is protected/encrypted
                    if pdfDocument.isEncrypted {
                        print("⚠️ PDF is encrypted/password protected: \(url.lastPathComponent)")
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                    
                    // Check if the PDF has any pages
                    if pdfDocument.pageCount == 0 {
                        print("⚠️ PDF has no pages: \(url.lastPathComponent)")
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                    
                    // Try to extract text from each page
                    for i in 0..<pdfDocument.pageCount {
                        if let page = pdfDocument.page(at: i) {
                            let pageString = page.string ?? ""
                            extractedText += pageString
                            print("   - Page \(i+1): \(pageString.isEmpty ? "No text found" : "\(pageString.prefix(50))...")")
                        }
                    }
                    
                    // Check if we got any text at all
                    if extractedText.isEmpty && pdfDocument.pageCount > 0 {
                        print("⚠️ PDF appears to be image-based or contain no extractable text: \(url.lastPathComponent)")
                        // Try to extract at least page count info
                        print("   - PDF has \(pdfDocument.pageCount) pages but no extractable text")
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                    
                    print("✓ Successfully extracted \(extractedText.count) characters from PDF: \(url.lastPathComponent)")
                    DispatchQueue.main.async { completion(extractedText.isEmpty ? nil : extractedText) }
                } else {
                    print("⚠️ Failed to create PDFDocument from data: \(url.lastPathComponent)")
                    print("   - File data was read successfully, but PDFKit couldn't parse it as PDF")
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                print("⚠️ Failed to read file data: \(error.localizedDescription)")
                
                // Try the original URL method as fallback
                if let pdfDocument = PDFDocument(url: url) {
                    // Process as before...
                    // (Keeping this as a fallback, but it's unlikely to work if file data reading failed)
                    print("   - Fallback: Trying PDFDocument(url:) method")
                    
                    // Extract text using the same logic as above
                    for i in 0..<pdfDocument.pageCount {
                        if let page = pdfDocument.page(at: i) {
                            extractedText += page.string ?? ""
                        }
                    }
                    
                    DispatchQueue.main.async { completion(extractedText.isEmpty ? nil : extractedText) }
                } else {
                    print("⚠️ Both file data and URL methods failed to create PDFDocument")
                    DispatchQueue.main.async { completion(nil) }
                }
            }
        }
    }
    
    // Basic placeholder - web content extraction is complex
    func extractTextFromWebLink(url: URL, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            // TODO: Implement robust web scraping/content extraction
            // For now, just fetch raw HTML as a basic example
            do {
                let htmlContent = try String(contentsOf: url, encoding: .utf8)
                // Very basic cleanup (could use regex or a parsing library)
                let plainText = htmlContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                                           .trimmingCharacters(in: .whitespacesAndNewlines)
                
                DispatchQueue.main.async { completion(plainText.isEmpty ? nil : plainText) }
            } catch {
                print("Error fetching web content: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    // MARK: - Searching (Placeholder)
    
    struct LibrarySearchResult {
        let item: UserLibraryItem
        let relevantSnippet: String // Or potentially multiple snippets
    }
    
    // Simple text search for now - Searches the reconstructed text
    func searchLibrary(query: String) -> [LibrarySearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        
        var results: [LibrarySearchResult] = []
        let lowercasedQuery = query.lowercased()
        
        for item in libraryItems {
            // Use the allContentText computed property instead of item.content
            let searchableText = item.allContentText 
            if let range = searchableText.lowercased().range(of: lowercasedQuery) {
                // Create a snippet around the found range using searchableText
                let snippetLength = 200 // Adjust as needed
                let startIndex = searchableText.index(range.lowerBound, offsetBy: -snippetLength/2, limitedBy: searchableText.startIndex) ?? searchableText.startIndex
                let endIndex = searchableText.index(range.upperBound, offsetBy: snippetLength/2, limitedBy: searchableText.endIndex) ?? searchableText.endIndex
                let snippet = String(searchableText[startIndex..<endIndex])
                
                results.append(LibrarySearchResult(item: item, relevantSnippet: "...\(snippet)..."))
            }
            // Optional: Also search titles
            else if item.title.lowercased().contains(lowercasedQuery) {
                 results.append(LibrarySearchResult(item: item, relevantSnippet: "Title match: \(item.title)"))
            }
        }
        print("TEXT search for '\(query)' found \(results.count) results.")
        return results
    }
    
    // MARK: - Vector Search

    // Calculates cosine similarity between two vectors
    private func cosineSimilarity(_ vecA: [Double], _ vecB: [Double]) -> Double {
        guard vecA.count == vecB.count, !vecA.isEmpty else {
            return 0.0 // Return 0 if vectors are incompatible or empty
        }
        
        var dotProduct: Double = 0.0
        var normA: Double = 0.0
        var normB: Double = 0.0
        
        for i in 0..<vecA.count {
            dotProduct += vecA[i] * vecB[i]
            normA += vecA[i] * vecA[i]
            normB += vecB[i] * vecB[i]
        }
        
        let magnitudeA = sqrt(normA)
        let magnitudeB = sqrt(normB)
        
        if magnitudeA == 0.0 || magnitudeB == 0.0 {
            return 0.0 // Avoid division by zero
        }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }

    // Searches the library items for chunks most similar to the query vector
    // Now returns tuples of (chunk, sourceItemTitle)
    func searchLibraryByVector(queryVector: [Double], topN: Int = 3) -> [(chunk: LibraryChunk, sourceItemTitle: String)] {
        var chunkSimilarities: [(chunk: LibraryChunk, similarity: Double, itemTitle: String)] = []

        for item in libraryItems {
            // Only search items where embedding is complete
            guard item.isEmbeddingComplete, let chunks = item.chunks else { continue }
            
            for chunk in chunks {
                // Ensure the chunk has a vector
                guard let chunkVector = chunk.vector else { continue }
                
                // Calculate similarity
                let similarity = cosineSimilarity(queryVector, chunkVector)
                
                // Store chunk and its similarity score
                if similarity > 0.0 { // Basic threshold to avoid unrelated matches
                     chunkSimilarities.append((chunk: chunk, similarity: similarity, itemTitle: item.title))
                }
            }
        }

        // Sort by similarity descending
        chunkSimilarities.sort { $0.similarity > $1.similarity }

        // Take the top N results and map to the new return type
        let topResults = chunkSimilarities.prefix(topN).map { (chunk: $0.chunk, sourceItemTitle: $0.itemTitle) }
        
        print("Vector search found \(topResults.count) relevant chunks (top \(topN)).")
        return topResults
    }
    
    // MARK: - Persistence (Using iCloud Container)
    
    // Returns the URL for the metadata file in the iCloud container
    private func getLibraryMetadataURL() -> URL? {
        guard let containerURL = getUbiquitousContainerURL() else { return nil }
        // Store metadata directly in the Documents subdirectory
        let documentsURL = containerURL.appendingPathComponent("Documents")
        
        // Ensure Documents directory exists (might not initially)
        if !FileManager.default.fileExists(atPath: documentsURL.path) {
            do {
                try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("❌ Failed to create Documents directory in iCloud: \(error.localizedDescription)")
                return nil
            }
        }
        
        return documentsURL.appendingPathComponent("letterspace_library.json")
    }
    
    // Make saveItems internal so it can be called from LibraryView
    func saveItems() {
        // Move iCloud save operations to background thread
        Task.detached(priority: .utility) {
            guard let metadataURL = self.getLibraryMetadataURL() else {
                print("❌ Cannot save library metadata: iCloud container URL not available.")
                return
            }
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted // Optional: for readability
                let data = try encoder.encode(self.libraryItems)
                try data.write(to: metadataURL, options: .atomic)
                print("☁️ Library metadata saved to iCloud: \(metadataURL.path) with \(self.libraryItems.count) items")
                // Print a summary of item types
                let pdfCount = self.libraryItems.filter { $0.type == .pdf }.count
                let webCount = self.libraryItems.filter { $0.type == .webLink }.count
                let fileCount = self.libraryItems.filter { $0.type == .file }.count
                print("  - PDFs: \(pdfCount), Web Links: \(webCount), Files: \(fileCount)")
            } catch {
                print("❌ Error saving library metadata to iCloud: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadItems() {
        // Move iCloud operations to background thread to prevent main thread blocking
        Task.detached(priority: .utility) {
            guard let metadataURL = self.getLibraryMetadataURL() else {
                print("❌ Cannot load library metadata: iCloud container URL not available.")
                await MainActor.run {
                    self.libraryItems = []
                }
                return
            }
            
            guard FileManager.default.fileExists(atPath: metadataURL.path) else {
                 print("☁️ No saved library metadata found at iCloud location: \(metadataURL.path)")
                 await MainActor.run {
                     self.libraryItems = [] // Ensure it's empty if file doesn't exist
                 }
                return
            }
            
            do {
                let data = try Data(contentsOf: metadataURL)
                let items = try JSONDecoder().decode([UserLibraryItem].self, from: data)
                print("☁️ Loaded \(items.count) library items from iCloud: \(metadataURL.path)")
                
                await MainActor.run {
                    self.libraryItems = items
                }
            } catch {
                print("‼️ Failed to load/decode library items from iCloud: \(error). Clearing potentially corrupt data or starting fresh.")
                await MainActor.run {
                    self.libraryItems = [] // Reset to empty state
                }
            }
        }
    }
    
    // MARK: - Chunking
    
    // Simple chunking by paragraphs (double newlines) or fixed size as fallback
    private func chunkText(_ text: String, maxChunkSize: Int = 500) -> [String] {
        var chunks: [String] = []
        let paragraphs = text.components(separatedBy: "\n\n")
        
        var currentChunk = ""
        for paragraph in paragraphs {
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedParagraph.isEmpty else { continue }
            
            // Estimate tokens (very rough)
            let paragraphTokens = trimmedParagraph.count / 3 // Adjust denominator as needed
            let currentChunkTokens = currentChunk.count / 3
            
            if currentChunkTokens + paragraphTokens <= maxChunkSize {
                // Add paragraph to current chunk
                currentChunk += (currentChunk.isEmpty ? "" : "\n\n") + trimmedParagraph
            } else {
                // Current chunk is full, save it
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                // Start new chunk with current paragraph
                // If paragraph itself is too large, split it (basic split)
                if paragraphTokens > maxChunkSize {
                     chunks.append(contentsOf: splitLargeText(trimmedParagraph, maxSize: maxChunkSize))
                     currentChunk = ""
                } else {
                    currentChunk = trimmedParagraph
                }
            }
        }
        
        // Add the last remaining chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        print("Chunked text into \(chunks.count) chunks.")
        return chunks
    }
    
    // Helper to split text that exceeds max size (simple split by sentences/words)
    private func splitLargeText(_ text: String, maxSize: Int) -> [String] {
        var subChunks: [String] = []
        var remainingText = text
        while !remainingText.isEmpty {
            // Find suitable split point (sentence or word near maxSize)
            var splitIndex = remainingText.index(remainingText.startIndex, offsetBy: maxSize * 3, limitedBy: remainingText.endIndex) ?? remainingText.endIndex
            
            // Try to find a sentence end before the split index
            if let sentenceEndRange = remainingText.range(of: ".", options: .backwards, range: remainingText.startIndex..<splitIndex) {
                 splitIndex = remainingText.index(after: sentenceEndRange.lowerBound)
            } else if let wordEndRange = remainingText.range(of: " ", options: .backwards, range: remainingText.startIndex..<splitIndex) { // Or word end
                 splitIndex = remainingText.index(after: wordEndRange.lowerBound)
            }

            subChunks.append(String(remainingText[..<splitIndex]))
            remainingText = String(remainingText[splitIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return subChunks
    }
    
    // MARK: - Item Management & Processing (Needs Update)
    
    // We need an async function to handle adding and processing
    func addAndProcessItem(sourceURL: URL, type: LibraryItemType, completion: @escaping (Result<UserLibraryItem, Error>) -> Void) {
        let title = sourceURL.lastPathComponent // Basic title
        
        print("Processing \(type) item: \(title)...")
        
        // 1. Extract Text
        extractText(from: sourceURL, type: type) { [weak self] extractedTextResult in
            guard let self = self else { return }
            
            switch extractedTextResult {
            case .success(let textContent):
                 guard !textContent.isEmpty else {
                    let error = NSError(domain: "UserLibraryService", code: 1, 
                                      userInfo: [NSLocalizedDescriptionKey: "Could not extract text or content is empty."])
                    print("❌ Failed to add/process \(type) '\(title)': \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                 }
                 
                 // 2. Chunk Text
                 let textChunks = self.chunkText(textContent)
                 guard !textChunks.isEmpty else {
                     let error = NSError(domain: "UserLibraryService", code: 2, 
                                      userInfo: [NSLocalizedDescriptionKey: "Failed to chunk extracted text."])
                     print("❌ Failed to add/process \(type) '\(title)': \(error.localizedDescription)")
                     completion(.failure(error))
                     return
                 }
                 
                 // Create item ID beforehand
                 let newItemID = UUID()
                 let pdfFilename = "\(newItemID.uuidString).pdf" // Unique filename
                 
                 // Create initial item (without vectors yet, source is temporary)
                 let initialChunks = textChunks.map { LibraryChunk(id: UUID(), text: $0, vector: nil) }
                 // NOTE: source is initially set to the temp/original URL, will be updated after copy
                 var newItem = UserLibraryItem(id: newItemID, type: type, title: title, source: sourceURL.absoluteString, chunks: initialChunks, dateAdded: Date(), isEmbeddingComplete: false)
                 
                 // Add item to list immediately (UI can show processing state)
                 DispatchQueue.main.async {
                     self.libraryItems.append(newItem)
                     print("✓ Added \(type) item '\(title)' with \(textChunks.count) chunks (pending copy & embed).")
                 }
                 
                 // 3. Copy PDF to iCloud (Before Embedding)
                 guard let pdfsDirectoryURL = self.getLibraryPdfsDirectoryURL() else {
                     completion(.failure(NSError(domain: "UserLibraryService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not get iCloud PDF directory URL."])))
                     // Consider removing the prematurely added item?
                     DispatchQueue.main.async {
                         self.libraryItems.removeAll { $0.id == newItemID } 
                     }
                     return
                 }
                 let destinationURL = pdfsDirectoryURL.appendingPathComponent(pdfFilename)
                 
                 do {
                     // Use the original source URL provided to the function for the copy
                     // Ensure security scope is still active if needed, or use the temp URL if that's what was passed
                     try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                     print("☁️ Copied PDF to iCloud: \(destinationURL.path)")
                     
                     // NOW update the item's source to just the filename
                     newItem.source = pdfFilename 
                     // Update in the array immediately (main thread needed)
                      DispatchQueue.main.async {
                         if let index = self.libraryItems.firstIndex(where: { $0.id == newItemID }) {
                             self.libraryItems[index].source = pdfFilename
                         }
                     }
                     
                 } catch {
                     print("❌ Failed to copy PDF to iCloud: \(error.localizedDescription)")
                     completion(.failure(NSError(domain: "UserLibraryService", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to copy PDF to iCloud: \(error.localizedDescription)"])))
                     // Remove the prematurely added item
                     DispatchQueue.main.async {
                          self.libraryItems.removeAll { $0.id == newItemID } 
                     }
                     return
                 }
                 
                 // 4. Generate Embeddings (Async)
                 AIService.shared.generateEmbeddings(textChunks: textChunks) { embeddingResult in
                     DispatchQueue.main.async { // Ensure UI updates happen on main thread
                         switch embeddingResult {
                         case .success(let vectors):
                             guard vectors.count == newItem.chunks?.count else {
                                 print("❌ Error: Embedding vector count mismatch for '\(title)'.")
                                 // Update item state to reflect failed embedding?
                                 completion(.failure(NSError(domain: "UserLibraryService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Embedding vector count mismatch."])))
                                 return
                             }
                             
                             // Update chunks with vectors
                             if var updatedChunks = newItem.chunks {
                                 for i in 0..<updatedChunks.count {
                                     updatedChunks[i].vector = vectors[i]
                                 }
                                 newItem.chunks = updatedChunks
                                 newItem.isEmbeddingComplete = true // Mark as complete
                                 
                                 // Update the item in our main array
                                 if let index = self.libraryItems.firstIndex(where: { $0.id == newItem.id }) {
                                     self.libraryItems[index] = newItem
                                     self.saveItems() // SAVE metadata AFTER successful embedding
                                     print("✓ Successfully embedded item: \(newItem.title)")
                                     completion(.success(newItem)) // Notify success
                                 } else {
                                     // This shouldn't happen if we added it earlier
                                     completion(.failure(NSError(domain: "UserLibraryService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to find item to update after embedding."])))
                                 }
                             } else {
                                // Should not happen if chunks were created
                                completion(.failure(NSError(domain: "UserLibraryService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Item chunks were nil during embedding update."])))
                             }
                             
                         case .failure(let error):
                             print("❌ Failed to generate embeddings for '\(title)': \(error)")
                             // Update item state to reflect failed embedding?
                             DispatchQueue.main.async {
                                 self.libraryItems.removeAll { $0.id == newItemID } 
                                 // Also delete the copied iCloud PDF?
                                 try? FileManager.default.removeItem(at: destinationURL)
                             }
                             completion(.failure(error))
                         }
                     }
                 }
                 
            case .failure(let error):
                print("❌ Failed to add/process \(type) '\(title)': \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // Helper to choose text extraction based on type
    private func extractText(from url: URL, type: LibraryItemType, completion: @escaping (Result<String, Error>) -> Void) {
        switch type {
        case .pdf:
            extractTextFromPDF(url: url) { content in
                if let content = content {
                    completion(.success(content))
                } else {
                    completion(.failure(NSError(domain: "UserLibraryService", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to extract text from PDF."])))
                }
            }
        case .webLink:
            extractTextFromWebLink(url: url) { content in
                 if let content = content {
                    completion(.success(content))
                } else {
                    completion(.failure(NSError(domain: "UserLibraryService", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to extract text from Web Link."])))
                }
            }
        case .file:
            // Extract text from a generic file
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    completion(.success(content))
                } catch {
                    print("⚠️ Failed to extract text from file: \(url.lastPathComponent) - \(error.localizedDescription)")
                    completion(.failure(NSError(domain: "UserLibraryService", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to extract text from File."])))
                }
            }
        }
    }
} 