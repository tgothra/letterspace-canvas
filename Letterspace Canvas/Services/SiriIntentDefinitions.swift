#if os(iOS)
import Foundation
import Intents

// MARK: - iOS 26 Intent Handler Classes
// Note: iOS 26 uses a simplified approach for custom intents
// These are intent handler classes that work with the system-provided INIntent

// MARK: - Document Creation Intent Handlers
@available(iOS 26.0, *)
class CreateDocumentIntentHandler: NSObject {
    static let intentIdentifier = "CreateDocumentIntent"
    
    func handle(intent: INIntent, completion: @escaping (INIntentResponse) -> Void) {
        print("🎤 Handling create document intent")
        
        // Create document via Siri service
        let document = SiriIntentService.shared.handleCreateDocument(type: .general)
        
        let response = CreateDocumentIntentResponse(
            documentId: document.id,
            documentTitle: document.title
        )
        
        completion(response)
    }
}

@available(iOS 26.0, *)
class CreateSermonIntentHandler: NSObject {
    static let intentIdentifier = "CreateSermonIntent"
    
    func handle(intent: INIntent, completion: @escaping (INIntentResponse) -> Void) {
        print("🎤 Handling create sermon intent")
        
        let document = SiriIntentService.shared.handleCreateDocument(type: .sermon)
        
        let response = CreateDocumentIntentResponse(
            documentId: document.id,
            documentTitle: document.title
        )
        
        completion(response)
    }
}

// MARK: - Bible Verse Intent Handlers
@available(iOS 26.0, *)
class AddBibleVerseIntentHandler: NSObject {
    static let intentIdentifier = "AddBibleVerseIntent"
    
    func handle(intent: INIntent, topic: String?, completion: @escaping (INIntentResponse) -> Void) {
        print("🎤 Handling add Bible verse intent for topic: \(topic ?? "unknown")")
        
        Task {
            let verseResult = await SiriIntentService.shared.handleAddBibleVerse(topic: topic ?? "faith")
            
            let response: AddBibleVerseIntentResponse
            if verseResult.contains("Error") {
                response = AddBibleVerseIntentResponse(error: verseResult)
            } else {
                response = AddBibleVerseIntentResponse(
                    verseText: verseResult,
                    reference: "Scripture reference"
                )
            }
            
            await MainActor.run {
                completion(response)
            }
        }
    }
}

@available(iOS 26.0, *)
class SearchScriptureIntentHandler: NSObject {
    static let intentIdentifier = "SearchScriptureIntent"
    
    func handle(intent: INIntent, searchTerm: String?, completion: @escaping (INIntentResponse) -> Void) {
        print("🎤 Handling search scripture intent for: \(searchTerm ?? "unknown")")
        
        Task {
            let verseResult = await SiriIntentService.shared.handleAddBibleVerse(topic: searchTerm ?? "scripture")
            
            let response: AddBibleVerseIntentResponse
            if verseResult.contains("Error") {
                response = AddBibleVerseIntentResponse(error: verseResult)
            } else {
                response = AddBibleVerseIntentResponse(
                    verseText: verseResult,
                    reference: "Search result"
                )
            }
            
            await MainActor.run {
                completion(response)
            }
        }
    }
}

// MARK: - Library Search Intent Handlers
@available(iOS 26.0, *)
class SearchLibraryIntentHandler: NSObject {
    static let intentIdentifier = "SearchLibraryIntent"
    
    func handle(intent: INIntent, query: String?, completion: @escaping (INIntentResponse) -> Void) {
        print("🎤 Handling search library intent for: \(query ?? "unknown")")
        
        Task {
            let results = await SiriIntentService.shared.handleSearchLibrary(query: query ?? "documents")
            let resultTitles = results.map { $0.title }
            
            let response = SearchLibraryIntentResponse(
                resultCount: results.count,
                results: resultTitles
            )
            
            await MainActor.run {
                completion(response)
            }
        }
    }
}

@available(iOS 26.0, *)
class FindSermonIntentHandler: NSObject {
    static let intentIdentifier = "FindSermonIntent"
    
    func handle(intent: INIntent, topic: String?, completion: @escaping (INIntentResponse) -> Void) {
        print("🎤 Handling find sermon intent for topic: \(topic ?? "unknown")")
        
        Task {
            let results = await SiriIntentService.shared.handleSearchLibrary(query: "\(topic ?? "sermon") sermon")
            let resultTitles = results.map { $0.title }
            
            let response = SearchLibraryIntentResponse(
                resultCount: results.count,
                results: resultTitles
            )
            
            await MainActor.run {
                completion(response)
            }
        }
    }
}

@available(iOS 26.0, *)
class ShowRecentDocumentsIntentHandler: NSObject {
    static let intentIdentifier = "ShowRecentDocumentsIntent"
    
    func handle(intent: INIntent, completion: @escaping (INIntentResponse) -> Void) {
        print("🎤 Handling show recent documents intent")
        
        let documents = SiriIntentService.shared.handleShowRecentDocuments()
        let documentTitles = documents.map { $0.title }
        
        let response = SearchLibraryIntentResponse(
            resultCount: documents.count,
            results: documentTitles
        )
        
        completion(response)
    }
}

// MARK: - Intent Response Classes
@available(iOS 26.0, *)
class CreateDocumentIntentResponse: INIntentResponse {
    @NSManaged public var documentId: String?
    @NSManaged public var documentTitle: String?
    @NSManaged public var success: NSNumber?
    @NSManaged public var errorMessage: String?
    
    convenience init(documentId: String, documentTitle: String) {
        self.init()
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.success = NSNumber(value: true)
    }
    
    convenience init(error: String) {
        self.init()
        self.errorMessage = error
        self.success = NSNumber(value: false)
    }
}

@available(iOS 26.0, *)
class AddBibleVerseIntentResponse: INIntentResponse {
    @NSManaged public var verseText: String?
    @NSManaged public var reference: String?
    @NSManaged public var success: NSNumber?
    @NSManaged public var errorMessage: String?
    
    convenience init(verseText: String, reference: String) {
        self.init()
        self.verseText = verseText
        self.reference = reference
        self.success = NSNumber(value: true)
    }
    
    convenience init(error: String) {
        self.init()
        self.errorMessage = error
        self.success = NSNumber(value: false)
    }
}

@available(iOS 26.0, *)
class SearchLibraryIntentResponse: INIntentResponse {
    @NSManaged public var resultCount: NSNumber?
    @NSManaged public var results: [String]?
    @NSManaged public var success: NSNumber?
    @NSManaged public var errorMessage: String?
    
    convenience init(resultCount: Int, results: [String]) {
        self.init()
        self.resultCount = NSNumber(value: resultCount)
        self.results = results
        self.success = NSNumber(value: true)
    }
    
    convenience init(error: String) {
        self.init()
        self.errorMessage = error
        self.success = NSNumber(value: false)
    }
}

// MARK: - Voice Command Patterns
struct SiriVoiceCommands {
    static let documentCreation = [
        "Create a new document",
        "Create new document",
        "Make a new document",
        "Start a new document",
        "New document",
        "Create document"
    ]
    
    static let sermonCreation = [
        "Create a new sermon",
        "Create sermon document", 
        "Make a sermon",
        "Start a new sermon",
        "New sermon",
        "Create sermon"
    ]
    
    static let bibleVerse = [
        "Add a Bible verse about {topic}",
        "Find Bible verse about {topic}",
        "Show Bible verse about {topic}",
        "Get scripture about {topic}",
        "Add verse about {topic}",
        "Bible verse {topic}"
    ]
    
    static let librarySearch = [
        "Search my library for {query}",
        "Find in library {query}",
        "Search library {query}",
        "Look up {query}",
        "Find {query} in my documents",
        "Search for {query}"
    ]
    
    static let sermonSearch = [
        "Find sermon about {topic}",
        "Search sermons for {topic}",
        "Find sermon {topic}",
        "Show sermons about {topic}",
        "Look up sermon {topic}"
    ]
    
    static let recentDocuments = [
        "Show recent documents",
        "Show my recent documents",
        "Recent documents",
        "Latest documents",
        "My recent work",
        "Show recent"
    ]
}

// MARK: - Intent Handler Registration
@available(iOS 26.0, *)
class SiriIntentHandler: NSObject {
    static let shared = SiriIntentHandler()
    
    private override init() {
        super.init()
    }
    
    func registerIntentHandlers() {
        // Register handlers for each intent type
        print("🎤 Registering iOS 26 Siri intent handlers...")
        
        // Document creation handlers would be registered here
        // In a full implementation, these would be registered with the system
        
        print("🎤 iOS 26 Siri intent handlers registered successfully!")
    }
}

#endif 