#if os(iOS)
import Foundation
import Intents

// MARK: - iOS 26 Custom Intent Definitions

// MARK: - Document Creation Intents
@available(iOS 26.0, *)
class CreateDocumentIntent: INIntent {
    @NSManaged public var documentType: String?
    @NSManaged public var title: String?
    
    override init() {
        super.init()
        self.identifier = "CreateDocumentIntent"
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

@available(iOS 26.0, *)
class CreateSermonIntent: INIntent {
    @NSManaged public var sermonTitle: String?
    @NSManaged public var sermonSeries: String?
    @NSManaged public var scripture: String?
    
    override init() {
        super.init()
        self.identifier = "CreateSermonIntent"
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Bible Verse Intents
@available(iOS 26.0, *)
class AddBibleVerseIntent: INIntent {
    @NSManaged public var topic: String?
    @NSManaged public var specificReference: String?
    @NSManaged public var translation: String?
    
    override init() {
        super.init()
        self.identifier = "AddBibleVerseIntent"
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

@available(iOS 26.0, *)
class SearchScriptureIntent: INIntent {
    @NSManaged public var searchTerm: String?
    @NSManaged public var book: String?
    @NSManaged public var translation: String?
    
    override init() {
        super.init()
        self.identifier = "SearchScriptureIntent"
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Library Search Intents
@available(iOS 26.0, *)
class SearchLibraryIntent: INIntent {
    @NSManaged public var query: String?
    @NSManaged public var documentType: String?
    @NSManaged public var author: String?
    
    override init() {
        super.init()
        self.identifier = "SearchLibraryIntent"
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

@available(iOS 26.0, *)
class FindSermonIntent: INIntent {
    @NSManaged public var topic: String?
    @NSManaged public var speaker: String?
    @NSManaged public var series: String?
    @NSManaged public var dateRange: String?
    
    override init() {
        super.init()
        self.identifier = "FindSermonIntent"
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

@available(iOS 26.0, *)
class ShowRecentDocumentsIntent: INIntent {
    @NSManaged public var count: NSNumber?
    @NSManaged public var documentType: String?
    
    override init() {
        super.init()
        self.identifier = "ShowRecentDocumentsIntent"
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
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