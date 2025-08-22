import Foundation
import UserNotifications
import SwiftUI

/// Service to manage sermon journal automatic prompting and notifications
class SermonJournalService: ObservableObject {
    static let shared = SermonJournalService()
    
    @Published var pendingJournalPrompts: [SermonJournalPrompt] = []
    @Published var showingAutoPrompt = false
    @Published var currentPromptDocument: Letterspace_CanvasDocument?
    @Published private(set) var allEntries: [SermonJournalEntry] = []
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var scheduledNotifications: Set<String> = []
    
    private init() {
        requestNotificationPermission()
        schedulePeriodicCheck()
        loadEntriesFromDisk()
    }
    
    /// Request notification permissions
    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Sermon journal notifications authorized")
            } else if let error = error {
                print("❌ Notification authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Schedule automatic prompts for recently preached sermons
    func scheduleJournalPrompts(for documents: [Letterspace_CanvasDocument]) {
        let now = Date()
        let calendar = Calendar.current
        
        for document in documents {
            // Check each variation for recent preaching dates
            for variation in document.variations {
                guard let preachingDate = variation.datePresented else { continue }
                
                // Check if sermon was preached within the last 24 hours
                let timeSincePreaching = now.timeIntervalSince(preachingDate)
                let hoursAgo = timeSincePreaching / 3600
                
                if hoursAgo > 0 && hoursAgo <= 24 {
                    // Check if we've already prompted for this sermon
                    if !hasJournalEntry(for: document.id) && !hasPendingPrompt(for: document.id) {
                        schedulePrompt(for: document, preachingDate: preachingDate)
                    }
                }
            }
        }
    }

    // MARK: - Persistence for Journal Entries
    private let entriesKey = "talle_sermon_journal_entries"

    func save(entry: SermonJournalEntry) {
        var updated = allEntries
        if let index = updated.firstIndex(where: { $0.id == entry.id }) {
            updated[index] = entry
        } else {
            updated.insert(entry, at: 0)
        }
        allEntries = updated
        persistEntriesToDisk()

        summarizeEntry(entry)
    }

    func entries() -> [SermonJournalEntry] {
        allEntries.sorted { $0.createdAt > $1.createdAt }
    }

    func entries(for sermonId: String) -> [SermonJournalEntry] {
        entries().filter { $0.sermonId == sermonId }
    }

    // Update a single entry in place and persist
    func updateEntry(id: String, mutate: (inout SermonJournalEntry) -> Void) {
        if let index = allEntries.firstIndex(where: { $0.id == id }) {
            var copy = allEntries[index]
            mutate(&copy)
            allEntries[index] = copy
            persistEntriesToDisk()
        }
    }

    // Delete an entry
    func deleteEntry(id: String) {
        allEntries.removeAll { $0.id == id }
        persistEntriesToDisk()
    }

    private func persistEntriesToDisk() {
        do {
            let data = try JSONEncoder().encode(allEntries)
            UserDefaults.standard.set(data, forKey: entriesKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("❌ Failed to encode sermon journal entries: \(error)")
        }
    }

    private func loadEntriesFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([SermonJournalEntry].self, from: data)
            self.allEntries = decoded
        } catch {
            print("❌ Failed to decode sermon journal entries: \(error)")
        }
    }
    
    /// Schedule a prompt for a specific sermon
    private func schedulePrompt(for document: Letterspace_CanvasDocument, preachingDate: Date) {
        let prompt = SermonJournalPrompt(
            id: "\(document.id)_\(preachingDate.timeIntervalSince1970)",
            sermonId: document.id,
            sermonTitle: document.title,
            preachingDate: preachingDate,
            createdAt: Date()
        )
        
        pendingJournalPrompts.append(prompt)
        
        // Schedule immediate prompt (with a small delay to avoid overwhelming)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showPrompt(for: document)
        }
        
        // Also schedule a notification for later if not completed
        scheduleNotification(for: prompt)
    }
    
    /// Show the journal prompt UI
    private func showPrompt(for document: Letterspace_CanvasDocument) {
        currentPromptDocument = document
        showingAutoPrompt = true
    }
    
    /// Schedule a push notification reminder
    private func scheduleNotification(for prompt: SermonJournalPrompt) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Reflect 📖"
        content.body = "How did preaching \"\(prompt.sermonTitle)\" go? Capture your thoughts while they're fresh."
        content.sound = .default
        content.userInfo = [
            "type": "sermon_journal",
            "sermonId": prompt.sermonId,
            "promptId": prompt.id
        ]
        
        // Schedule for 2 hours after preaching if not already journaled
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7200, repeats: false) // 2 hours
        
        let request = UNNotificationRequest(
            identifier: prompt.id,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule journal notification: \(error.localizedDescription)")
            } else {
                print("✅ Scheduled journal notification for: \(prompt.sermonTitle)")
                self.scheduledNotifications.insert(prompt.id)
            }
        }
    }
    
    /// Check if a journal entry already exists for this sermon
    private func hasJournalEntry(for sermonId: String) -> Bool {
        // TODO: Check persistent storage for existing journal entries
        // For now, return false to always allow prompting
        return false
    }
    
    /// Check if we already have a pending prompt for this sermon
    private func hasPendingPrompt(for sermonId: String) -> Bool {
        return pendingJournalPrompts.contains { $0.sermonId == sermonId }
    }
    
    /// Mark a prompt as completed (journal entry created)
    func markPromptCompleted(for sermonId: String) {
        pendingJournalPrompts.removeAll { $0.sermonId == sermonId }
        
        // Cancel any scheduled notifications for this sermon
        let notificationIds = scheduledNotifications.filter { $0.contains(sermonId) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(notificationIds))
        
        scheduledNotifications.subtract(notificationIds)
    }
    
    /// Dismiss the current prompt without creating a journal entry
    func dismissCurrentPrompt() {
        showingAutoPrompt = false
        currentPromptDocument = nil
    }
    
    /// Schedule periodic checks for new sermons that need journal prompts
    private func schedulePeriodicCheck() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in // Check every 5 minutes
            // This would be called with the current document list from the main app
            // self.checkForNewSermonPrompts()
        }
    }
    
    /// Clean up old prompts and notifications
    func cleanupOldPrompts() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        
        // Remove prompts older than 3 days
        let oldPrompts = pendingJournalPrompts.filter { $0.createdAt < cutoffDate }
        for prompt in oldPrompts {
            markPromptCompleted(for: prompt.sermonId)
        }
    }
    
    /// Get suggestions for automatic follow-up actions
    func getSuggestedActions(for document: Letterspace_CanvasDocument) -> [SermonFollowUpAction] {
        var actions: [SermonFollowUpAction] = []
        
        // Analyze sermon content and suggest follow-ups
        if document.title.lowercased().contains("baptism") {
            actions.append(SermonFollowUpAction(
                type: .followUpMessage,
                title: "Baptism Follow-Up",
                description: "Consider scheduling baptisms for those who responded",
                priority: .high
            ))
        }
        
        if document.title.lowercased().contains("prayer") {
            actions.append(SermonFollowUpAction(
                type: .prayerPoints,
                title: "Prayer Ministry",
                description: "Connect with prayer team about specific requests mentioned",
                priority: .medium
            ))
        }
        
        // Always suggest these standard follow-ups
        actions.append(SermonFollowUpAction(
            type: .socialMedia,
            title: "Social Media",
            description: "Share key quotes and insights from your message",
            priority: .low
        ))
        
        actions.append(SermonFollowUpAction(
            type: .congregationCheck,
            title: "Check on Congregation",
            description: "Follow up with individuals who seemed impacted",
            priority: .medium
        ))
        
        return actions
    }

    func summarizeEntry(_ entry: SermonJournalEntry) {
        Task {
            let summary = await FoundationModelService.shared.summarizeJournalEntry(
                feelings: entry.feelings,
                atmosphere: entry.spiritualAtmosphere,
                insights: entry.godRevealedNew,
                testimonies: entry.testimoniesAndBreakthroughs,
                improvements: entry.improvementNotes,
                followUp: entry.followUpNotes,
                mood: entry.emotionalState.rawValue,
                energyLevel: entry.energyLevel,
                physicalEnergy: entry.physicalEnergy,
                spiritualFulfillment: entry.spiritualFulfillment,
                kind: entry.kind
            )
            if !summary.isEmpty {
                self.updateEntry(id: entry.id) { entry in
                    entry.aiSummary = summary
                }
            }
        }
    }

    @discardableResult
    func regenerateMissingSummaries() async -> Int {
        var count = 0
        for e in allEntries where (e.aiSummary == nil || e.aiSummary?.isEmpty == true) {
            let summary = await FoundationModelService.shared.summarizeJournalEntry(
                feelings: e.feelings,
                atmosphere: e.spiritualAtmosphere,
                insights: e.godRevealedNew,
                testimonies: e.testimoniesAndBreakthroughs,
                improvements: e.improvementNotes,
                followUp: e.followUpNotes,
                mood: e.emotionalState.rawValue,
                energyLevel: e.energyLevel,
                physicalEnergy: e.physicalEnergy,
                spiritualFulfillment: e.spiritualFulfillment,
                kind: e.kind
            )
            if !summary.isEmpty {
                updateEntry(id: e.id) { entry in
                    entry.aiSummary = summary
                }
                count += 1
            }
        }
        return count
    }
}

// MARK: - Supporting Data Models

struct SermonJournalPrompt: Identifiable {
    let id: String
    let sermonId: String
    let sermonTitle: String
    let preachingDate: Date
    let createdAt: Date
}

struct SermonFollowUpAction: Identifiable {
    let id = UUID()
    let type: ActionType
    let title: String
    let description: String
    let priority: Priority
    
    enum ActionType {
        case followUpMessage
        case prayerPoints
        case socialMedia
        case congregationCheck
        case devotional
        case smallGroupQuestions
    }
    
    enum Priority {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}

// MARK: - Automatic Prompt View

struct AutomaticJournalPromptView: View {
    let document: Letterspace_CanvasDocument
    let onStartJournal: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.themeColors) var theme
    @State private var showingSuggestions = false
    @State private var suggestions: [SermonFollowUpAction] = []
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 48))
                    .foregroundColor(theme.accent)
                
                Text("Time to Reflect")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primary)
                
                Text("How did preaching \"\(document.title)\" go?")
                    .font(.headline)
                    .foregroundColor(theme.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Quick reflection prompts
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick check-in:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    promptPreview("How do you feel after preaching?")
                    promptPreview("What was the spiritual atmosphere like?")
                    promptPreview("Did God show you anything new?")
                    promptPreview("Any testimonies or breakthroughs?")
                }
            }
            .padding(.horizontal, 20)
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: onStartJournal) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Start Journal Entry")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    showingSuggestions = true
                    suggestions = SermonJournalService.shared.getSuggestedActions(for: document)
                }) {
                    HStack {
                        Image(systemName: "lightbulb")
                        Text("Show Follow-Up Suggestions")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
                
                Button("Maybe Later", action: onDismiss)
                    .font(.subheadline)
                    .foregroundColor(theme.secondary)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.accent.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingSuggestions) {
            FollowUpSuggestionsView(suggestions: suggestions, document: document) {
                showingSuggestions = false
            }
        }
    }
    
    private func promptPreview(_ text: String) -> some View {
        HStack {
            Circle()
                .fill(theme.accent.opacity(0.3))
                .frame(width: 6, height: 6)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(theme.secondary)
        }
    }
}

struct FollowUpSuggestionsView: View {
    let suggestions: [SermonFollowUpAction]
    let document: Letterspace_CanvasDocument
    let onDismiss: () -> Void
    
    @Environment(\.themeColors) var theme
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        suggestionCard(suggestion)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Follow-Up Actions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done", action: onDismiss)
                }
            }
            #endif
        }
    }
    
    private func suggestionCard(_ suggestion: SermonFollowUpAction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(suggestion.priority.color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
                
                Text(suggestion.description)
                    .font(.subheadline)
                    .foregroundColor(theme.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(suggestion.priority.color.opacity(0.05))
                .stroke(suggestion.priority.color.opacity(0.2), lineWidth: 1)
        )
    }
}