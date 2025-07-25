#if os(iOS)
import Foundation
import Intents
import IntentsUI
import SwiftUI

// MARK: - iOS 26 Enhanced Siri Integration Service
@available(iOS 26.0, *)
class SiriIntentService: NSObject, ObservableObject {
    static let shared = SiriIntentService()
    
    @Published var isRegistered = false
    @Published var lastCommand: String?
    @Published var lastResult: String?
    
    private override init() {
        super.init()
        setupSiriIntents()
    }
    
    // MARK: - Siri Intent Registration
    private func setupSiriIntents() {
        print("🎤 Setting up iOS 26 Siri intents...")
        
        // Register custom intents for document creation
        registerDocumentIntents()
        
        // Register Bible verse intents
        registerBibleIntents()
        
        // Register library search intents
        registerLibraryIntents()
        
        isRegistered = true
        print("🎤 iOS 26 Siri intents registered successfully!")
    }
    
    // MARK: - Document Creation Intents
    private func registerDocumentIntents() {
        // Create New Document Intent
        let createDocumentIntent = INIntent()
        createDocumentIntent.identifier = "CreateDocumentIntent"
        
        // Create Sermon Document Intent
        let createSermonIntent = INIntent()
        createSermonIntent.identifier = "CreateSermonIntent"
        
        // Donate intents to Siri for learning
        let createDocInteraction = INInteraction(intent: createDocumentIntent, response: nil)
        createDocInteraction.donate { error in
            if let error = error {
                print("🎤 Error donating create document intent: \(error)")
            } else {
                print("🎤 Successfully donated create document intent")
            }
        }
        
        let createSermonInteraction = INInteraction(intent: createSermonIntent, response: nil)
        createSermonInteraction.donate { error in
            if let error = error {
                print("🎤 Error donating create sermon intent: \(error)")
            } else {
                print("🎤 Successfully donated create sermon intent")
            }
        }
    }
    
    // MARK: - Bible Verse Intents
    private func registerBibleIntents() {
        // Add Bible Verse Intent
        let addVerseIntent = INIntent()
        addVerseIntent.identifier = "AddBibleVerseIntent"
        
        // Search Scripture Intent
        let searchScriptureIntent = INIntent()
        searchScriptureIntent.identifier = "SearchScriptureIntent"
        
        // Donate Bible intents
        let addVerseInteraction = INInteraction(intent: addVerseIntent, response: nil)
        addVerseInteraction.donate { error in
            if let error = error {
                print("🎤 Error donating add verse intent: \(error)")
            } else {
                print("🎤 Successfully donated add verse intent")
            }
        }
        
        let searchScriptureInteraction = INInteraction(intent: searchScriptureIntent, response: nil)
        searchScriptureInteraction.donate { error in
            if let error = error {
                print("🎤 Error donating search scripture intent: \(error)")
            } else {
                print("🎤 Successfully donated search scripture intent")
            }
        }
    }
    
    // MARK: - Library Search Intents
    private func registerLibraryIntents() {
        // Search Library Intent
        let searchLibraryIntent = INIntent()
        searchLibraryIntent.identifier = "SearchLibraryIntent"
        
        // Find Sermon Intent
        let findSermonIntent = INIntent()
        findSermonIntent.identifier = "FindSermonIntent"
        
        // Show Recent Documents Intent
        let showRecentIntent = INIntent()
        showRecentIntent.identifier = "ShowRecentDocumentsIntent"
        
        // Donate library intents
        let searchLibraryInteraction = INInteraction(intent: searchLibraryIntent, response: nil)
        searchLibraryInteraction.donate { error in
            if let error = error {
                print("🎤 Error donating search library intent: \(error)")
            } else {
                print("🎤 Successfully donated search library intent")
            }
        }
        
        let findSermonInteraction = INInteraction(intent: findSermonIntent, response: nil)
        findSermonInteraction.donate { error in
            if let error = error {
                print("🎤 Error donating find sermon intent: \(error)")
            } else {
                print("🎤 Successfully donated find sermon intent")
            }
        }
        
        let showRecentInteraction = INInteraction(intent: showRecentIntent, response: nil)
        showRecentInteraction.donate { error in
            if let error = error {
                print("🎤 Error donating show recent intent: \(error)")
            } else {
                print("🎤 Successfully donated show recent intent")
            }
        }
    }
    
    // MARK: - Intent Handlers
    func handleCreateDocument(type: DocumentType = .general) -> Letterspace_CanvasDocument {
        print("🎤 Handling create document via Siri: \(type)")
        lastCommand = "Create \(type.rawValue) document"
        
        let docId = UUID().uuidString
        let title = type == .sermon ? "New Sermon" : "Untitled"
        let placeholder = type == .sermon ? "Start your sermon preparation..." : "Start typing..."
        
        var document = Letterspace_CanvasDocument(
            title: title,
            subtitle: "",
            elements: [DocumentElement(type: .textBlock, content: "", placeholder: placeholder)],
            id: docId,
            markers: [],
            series: nil,
            variations: [],
            isVariation: false,
            parentVariationId: nil,
            createdAt: Date(),
            modifiedAt: Date(),
            tags: type == .sermon ? ["sermon"] : nil,
            isHeaderExpanded: false,
            isSubtitleVisible: true,
            links: []
        )
        
        document.save()
        lastResult = "Created \(title) successfully"
        
        // iOS 26 Enhancement: Provide haptic feedback
        HapticFeedback.impact(.medium, intensity: 0.8)
        
        return document
    }
    
    func handleAddBibleVerse(topic: String) async -> String {
        print("🎤 Handling add Bible verse via Siri: \(topic)")
        lastCommand = "Add Bible verse about \(topic)"
        
        // Use AI service to find relevant Bible verse
        let prompt = """
        Find a relevant Bible verse about "\(topic)". 
        Respond with just the verse reference and text in this format:
        [Book Chapter:Verse] - "Verse text"
        
        Example: [John 3:16] - "For God so loved the world..."
        """
        
        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                AIService.shared.generateText(prompt: prompt) { result in
                    continuation.resume(with: result)
                }
            }
            
            lastResult = "Found Bible verse about \(topic)"
            
            // iOS 26 Enhancement: Success haptic feedback
            HapticFeedback.impact(.light, intensity: 0.7)
            
            return result
        } catch {
            print("🎤 Error finding Bible verse: \(error)")
            lastResult = "Could not find Bible verse about \(topic)"
            
            // iOS 26 Enhancement: Error haptic feedback
            HapticFeedback.impact(.heavy, intensity: 0.5)
            
            return "Error finding Bible verse: \(error.localizedDescription)"
        }
    }
    
    func handleSearchLibrary(query: String) async -> [UserLibraryItem] {
        print("🎤 Handling search library via Siri: \(query)")
        lastCommand = "Search library for \(query)"
        
        let libraryService = UserLibraryService()
        let results = libraryService.searchLibrary(query: query)
        
        lastResult = "Found \(results.count) results for '\(query)'"
        
        // iOS 26 Enhancement: Contextual haptic feedback
        if results.isEmpty {
            HapticFeedback.impact(.medium, intensity: 0.5)
        } else {
            HapticFeedback.impact(.light, intensity: 0.8)
        }
        
        return results
    }
    
    func handleShowRecentDocuments() -> [Letterspace_CanvasDocument] {
        print("🎤 Handling show recent documents via Siri")
        lastCommand = "Show recent documents"
        
        // Get recent documents from document manager
        let recentDocs = DocumentManager.shared.getRecentDocuments(limit: 10)
        
        lastResult = "Showing \(recentDocs.count) recent documents"
        
        // iOS 26 Enhancement: Selection haptic feedback
        HapticFeedback.selection()
        
        return recentDocs
    }
    
    // MARK: - Voice Shortcuts
    func createVoiceShortcuts() {
        guard #available(iOS 12.0, *) else { return }
        
        // Create shortcuts for common actions
        let shortcuts = [
            createVoiceShortcut(
                phrase: "Create new document",
                identifier: "CreateDocumentIntent",
                title: "Create New Document"
            ),
            createVoiceShortcut(
                phrase: "Create sermon document",
                identifier: "CreateSermonIntent", 
                title: "Create Sermon Document"
            ),
            createVoiceShortcut(
                phrase: "Add Bible verse",
                identifier: "AddBibleVerseIntent",
                title: "Add Bible Verse"
            ),
            createVoiceShortcut(
                phrase: "Search my library",
                identifier: "SearchLibraryIntent",
                title: "Search Library"
            ),
            createVoiceShortcut(
                phrase: "Show recent documents",
                identifier: "ShowRecentDocumentsIntent",
                title: "Show Recent Documents"
            )
        ]
        
        print("🎤 Created \(shortcuts.count) voice shortcuts")
    }
    
    private func createVoiceShortcut(phrase: String, identifier: String, title: String) -> INShortcut {
        let intent = INIntent()
        intent.identifier = identifier
        
        let shortcut = INShortcut(intent: intent)
        return shortcut
    }
}

// MARK: - Supporting Types
enum DocumentType: String, CaseIterable {
    case general = "document"
    case sermon = "sermon"
    case study = "study"
    case notes = "notes"
}

// MARK: - Document Manager Extension
extension DocumentManager {
    static let shared = DocumentManager()
    
    func getRecentDocuments(limit: Int = 10) -> [Letterspace_CanvasDocument] {
        // This would integrate with your existing document storage
        // For now, return empty array - you can implement based on your storage system
        return []
    }
}

// MARK: - UserLibraryService Extension
extension UserLibraryService {
    func searchLibrary(query: String) -> [UserLibraryItem] {
        // Filter library items based on query
        return libraryItems.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
            item.chunks.contains { chunk in
                chunk.text.localizedCaseInsensitiveContains(query)
            }
        }
    }
}

#endif 