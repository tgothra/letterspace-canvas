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
        // iOS 26 Enhancement: Use user activity-based intents for better integration
        let createDocumentActivity = NSUserActivity(activityType: "com.letterspacecanvas.createDocument")
        createDocumentActivity.title = "Create New Document"
        createDocumentActivity.suggestedInvocationPhrase = "Create a new document"
        createDocumentActivity.isEligibleForSearch = true
        createDocumentActivity.isEligibleForPrediction = true
        
        let createSermonActivity = NSUserActivity(activityType: "com.letterspacecanvas.createSermon")
        createSermonActivity.title = "Create Sermon Document"
        createSermonActivity.suggestedInvocationPhrase = "Create a new sermon"
        createSermonActivity.isEligibleForSearch = true
        createSermonActivity.isEligibleForPrediction = true
        
        // Donate activities to Siri for learning
        createDocumentActivity.becomeCurrent()
        createSermonActivity.becomeCurrent()
        
        print("🎤 Successfully registered document creation intents via user activities")
    }
    
    // MARK: - Bible Verse Intents
    private func registerBibleIntents() {
        let addVerseActivity = NSUserActivity(activityType: "com.letterspacecanvas.addBibleVerse")
        addVerseActivity.title = "Add Bible Verse"
        addVerseActivity.suggestedInvocationPhrase = "Add a Bible verse about faith"
        addVerseActivity.isEligibleForSearch = true
        addVerseActivity.isEligibleForPrediction = true
        
        let searchScriptureActivity = NSUserActivity(activityType: "com.letterspacecanvas.searchScripture")
        searchScriptureActivity.title = "Search Scripture"
        searchScriptureActivity.suggestedInvocationPhrase = "Find Bible verse about hope"
        searchScriptureActivity.isEligibleForSearch = true
        searchScriptureActivity.isEligibleForPrediction = true
        
        // Donate activities
        addVerseActivity.becomeCurrent()
        searchScriptureActivity.becomeCurrent()
        
        print("🎤 Successfully registered Bible verse intents via user activities")
    }
    
    // MARK: - Library Search Intents
    private func registerLibraryIntents() {
        let searchLibraryActivity = NSUserActivity(activityType: "com.letterspacecanvas.searchLibrary")
        searchLibraryActivity.title = "Search Library"
        searchLibraryActivity.suggestedInvocationPhrase = "Search my library for sermons"
        searchLibraryActivity.isEligibleForSearch = true
        searchLibraryActivity.isEligibleForPrediction = true
        
        let findSermonActivity = NSUserActivity(activityType: "com.letterspacecanvas.findSermon")
        findSermonActivity.title = "Find Sermon"
        findSermonActivity.suggestedInvocationPhrase = "Find sermon about grace"
        findSermonActivity.isEligibleForSearch = true
        findSermonActivity.isEligibleForPrediction = true
        
        let showRecentActivity = NSUserActivity(activityType: "com.letterspacecanvas.showRecent")
        showRecentActivity.title = "Show Recent Documents"
        showRecentActivity.suggestedInvocationPhrase = "Show my recent documents"
        showRecentActivity.isEligibleForSearch = true
        showRecentActivity.isEligibleForPrediction = true
        
        // Donate activities
        searchLibraryActivity.becomeCurrent()
        findSermonActivity.becomeCurrent()
        showRecentActivity.becomeCurrent()
        
        print("🎤 Successfully registered library search intents via user activities")
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
        
        // Use the UserLibraryService's existing search method
        let searchResults = libraryService.searchLibrary(query: query)
        
        // Convert LibrarySearchResult to UserLibraryItem for return
        var items: [UserLibraryItem] = []
        
        for result in searchResults {
            // LibrarySearchResult already contains the item we need
            let item = result.item
            
            // Avoid duplicates by checking if already added
            if !items.contains(where: { $0.id == item.id }) {
                items.append(item)
            }
        }
        
        lastResult = "Found \(items.count) results for '\(query)'"
        
        // iOS 26 Enhancement: Contextual haptic feedback
        if items.isEmpty {
            HapticFeedback.impact(.medium, intensity: 0.5)
        } else {
            HapticFeedback.impact(.light, intensity: 0.8)
        }
        
        return items
    }
    
    func handleShowRecentDocuments() -> [Letterspace_CanvasDocument] {
        print("🎤 Handling show recent documents via Siri")
        lastCommand = "Show recent documents"
        
        // For now, return empty array - this would integrate with your document storage system
        let recentDocs: [Letterspace_CanvasDocument] = []
        
        lastResult = "Showing \(recentDocs.count) recent documents"
        
        // iOS 26 Enhancement: Selection haptic feedback
        HapticFeedback.selection()
        
        return recentDocs
    }
    
    // MARK: - Voice Shortcuts
    func createVoiceShortcuts() {
        guard #available(iOS 12.0, *) else { return }
        
        // iOS 26 Enhancement: Use NSUserActivity-based shortcuts for better integration
        let shortcuts = [
            createVoiceShortcut(
                phrase: "Create new document",
                activityType: "com.letterspacecanvas.createDocument",
                title: "Create New Document"
            ),
            createVoiceShortcut(
                phrase: "Create sermon document",
                activityType: "com.letterspacecanvas.createSermon",
                title: "Create Sermon Document"
            ),
            createVoiceShortcut(
                phrase: "Add Bible verse",
                activityType: "com.letterspacecanvas.addBibleVerse",
                title: "Add Bible Verse"
            ),
            createVoiceShortcut(
                phrase: "Search my library",
                activityType: "com.letterspacecanvas.searchLibrary",
                title: "Search Library"
            ),
            createVoiceShortcut(
                phrase: "Show recent documents",
                activityType: "com.letterspacecanvas.showRecent",
                title: "Show Recent Documents"
            )
        ]
        
        print("🎤 Created \(shortcuts.count) voice shortcuts")
    }
    
    private func createVoiceShortcut(phrase: String, activityType: String, title: String) -> INShortcut {
        let activity = NSUserActivity(activityType: activityType)
        activity.title = title
        activity.suggestedInvocationPhrase = phrase
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        let shortcut = INShortcut(userActivity: activity)
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

// Note: Integration with document storage system would go here
// The handleShowRecentDocuments method can be enhanced to work with
// your existing document management system when ready

#endif 