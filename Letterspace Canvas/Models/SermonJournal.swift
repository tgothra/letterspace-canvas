import Foundation
import SwiftUI

// MARK: - Sermon Journal Models

/// Represents a post-preaching reflection entry
struct SermonJournalEntry: Identifiable, Codable {
    let id: String
    let sermonId: String  // Links to the sermon document
    let createdAt: Date
    var updatedAt: Date
    // Entry title
    var title: String = ""
    // Editable reflection date; defaults to now, can be customized for custom entries
    var entryDate: Date = Date()
    // Kind of reflection entry
    var kind: ReflectionKind = .sermon
    // Optional attached sermon when kind != .sermon
    var attachedSermonId: String? = nil
    
    var attachedScriptures: [ScriptureReference]? = nil

    // Core reflection fields
    var feelings: String  // How did you feel after preaching?
    var spiritualAtmosphere: String  // What was the spiritual atmosphere like?
    var godRevealedNew: String  // Did God show you anything new while preaching?
    var testimoniesAndBreakthroughs: String  // Any testimonies, altar moments, or breakthroughs?
    // Optional extra fields for custom entries
    var improvementNotes: String = ""
    var followUpNotes: String = ""
    
    // Optional voice notes
    var voiceNoteURL: URL?
    var transcription: String?
    
    // Energy and wellness tracking
    var energyLevel: Int  // 1-10 scale
    var spiritualFulfillment: Int  // 1-10 scale
    var physicalEnergy: Int  // 1-10 scale
    var emotionalState: EmotionalState
    
    // AI-generated suggestions (populated after entry)
    var aiSuggestions: SermonFollowUpSuggestions?
    // AI-generated short summary for feed
    var aiSummary: String?
    // Optional mood label inferred from text (e.g., "Encouraged", "Heavy")
    var inferredMood: String?
    
    // Congregation feedback (if available)
    var congregationFeedback: CongregationFeedback?
    
    init(sermonId: String) {
        self.id = UUID().uuidString
        self.sermonId = sermonId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.feelings = ""
        self.spiritualAtmosphere = ""
        self.godRevealedNew = ""
        self.testimoniesAndBreakthroughs = ""
        self.energyLevel = 5
        self.spiritualFulfillment = 5
        self.physicalEnergy = 5
        self.emotionalState = .neutral
    }
}

enum ReflectionKind: String, Codable, CaseIterable, Identifiable {
    case sermon
    case personal
    case prayer
    case study
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sermon: return "Sermon"
        case .personal: return "Personal"
        case .prayer: return "Prayer"
        case .study: return "Study Note"
        }
    }
}

/// Emotional state after preaching
enum EmotionalState: String, Codable, CaseIterable {
    case energized = "Energized"
    case peaceful = "Peaceful"
    case fulfilled = "Fulfilled"
    case neutral = "Neutral"
    case drained = "Drained"
    case overwhelmed = "Overwhelmed"
    case disappointed = "Disappointed"
    case anxious = "Anxious"
    
    var color: Color {
        switch self {
        case .energized: return .green
        case .peaceful: return .blue
        case .fulfilled: return .purple
        case .neutral: return .gray
        case .drained: return .orange
        case .overwhelmed: return .red
        case .disappointed: return .brown
        case .anxious: return .yellow
        }
    }
    
    var emoji: String {
        switch self {
        case .energized: return "⚡️"
        case .peaceful: return "🕊️"
        case .fulfilled: return "✨"
        case .neutral: return "😐"
        case .drained: return "🪫"
        case .overwhelmed: return "😰"
        case .disappointed: return "😔"
        case .anxious: return "😟"
        }
    }
}

/// AI-generated follow-up suggestions
struct SermonFollowUpSuggestions: Codable {
    let devotionalIdeas: [String]  // Suggested devotionals to send
    let followUpMessages: [String]  // Ideas for follow-up sermons
    let scriptures: [String]  // Related scripture passages
    let socialMediaPosts: [String]  // Social media content suggestions
    let prayerPoints: [String]  // Prayer points based on the message
    let discussionQuestions: [String]  // Small group discussion questions
}

extension SermonFollowUpSuggestions {
    /// A human-readable summary used in compact contexts
    var summary: String {
        var parts: [String] = []
        if !devotionalIdeas.isEmpty {
            parts.append("Devotionals: " + devotionalIdeas.prefix(2).joined(separator: "; "))
        }
        if !followUpMessages.isEmpty {
            parts.append("Follow-ups: " + followUpMessages.prefix(2).joined(separator: "; "))
        }
        if !scriptures.isEmpty {
            parts.append("Scriptures: " + scriptures.prefix(3).joined(separator: ", "))
        }
        if !prayerPoints.isEmpty {
            parts.append("Prayer: " + prayerPoints.prefix(2).joined(separator: "; "))
        }
        if !discussionQuestions.isEmpty {
            parts.append("Groups: " + discussionQuestions.prefix(2).joined(separator: "; "))
        }
        if !socialMediaPosts.isEmpty {
            parts.append("Social: " + socialMediaPosts.prefix(2).joined(separator: "; "))
        }
        return parts.isEmpty ? "—" : parts.joined(separator: "\n")
    }
}

/// Congregation feedback summary
struct CongregationFeedback: Codable {
    let responseCount: Int
    let averageImpactRating: Double  // 1-10 scale
    let keyThemes: [String]  // Most mentioned themes/impacts
    let testimonies: [String]  // Specific testimonies shared
    let questions: [String]  // Questions raised by congregation
    let requestedFollowUps: [String]  // What people want to hear more about
}

/// Health tracking over time
struct SermonHealthMetrics: Codable {
    let pastorId: String
    let weeklyAverages: [WeeklyHealthAverage]
    let burnoutRiskLevel: BurnoutRiskLevel
    let recommendations: [HealthRecommendation]
    
    var lastUpdated: Date
    
    init(pastorId: String) {
        self.pastorId = pastorId
        self.weeklyAverages = []
        self.burnoutRiskLevel = .low
        self.recommendations = []
        self.lastUpdated = Date()
    }
}

struct WeeklyHealthAverage: Codable {
    let weekStarting: Date
    let averageEnergyLevel: Double
    let averageSpiritualFulfillment: Double
    let averagePhysicalEnergy: Double
    let dominantEmotionalState: EmotionalState
    let sermonCount: Int
}

enum BurnoutRiskLevel: String, Codable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var description: String {
        switch self {
        case .low: return "You're maintaining healthy energy levels"
        case .moderate: return "Consider scheduling some rest time"
        case .high: return "Your energy levels are concerning - please take a break"
        case .critical: return "Immediate rest needed - consider delegating upcoming sermons"
        }
    }
}

struct HealthRecommendation: Identifiable, Codable {
    let id: String
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Int  // 1-5, 5 being highest
    let createdAt: Date
    
    init(type: RecommendationType, title: String, description: String, priority: Int = 3) {
        self.id = UUID().uuidString
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.createdAt = Date()
    }
}

enum RecommendationType: String, Codable {
    case rest = "Rest"
    case delegation = "Delegation"
    case spiritual = "Spiritual Care"
    case physical = "Physical Wellness"
    case emotional = "Emotional Support"
    case schedule = "Schedule Adjustment"
}

// MARK: - Journal Prompt Templates

struct JournalPrompt {
    let question: String
    let placeholder: String
    let category: PromptCategory
    let isOptional: Bool
    
    // Sermon prompts
    static let sermonPrompts: [JournalPrompt] = [
        JournalPrompt(
            question: "How do you feel after preaching this message?",
            placeholder: "Describe your immediate feelings and emotional state...",
            category: .emotional,
            isOptional: false
        ),
        JournalPrompt(
            question: "What was the spiritual atmosphere like?",
            placeholder: "How did the Holy Spirit move? What did you sense in the room?",
            category: .spiritual,
            isOptional: false
        ),
        JournalPrompt(
            question: "Did God show you anything new while preaching?",
            placeholder: "Any fresh revelations, adjustments to your notes, or Spirit-led moments?",
            category: .spiritual,
            isOptional: false
        ),
        JournalPrompt(
            question: "Any testimonies, altar moments, or breakthroughs to record?",
            placeholder: "Document what you witnessed God doing in people's lives...",
            category: .impact,
            isOptional: false
        ),
        JournalPrompt(
            question: "What would you do differently if preaching this again?",
            placeholder: "Improvements, additions, or changes for future delivery...",
            category: .improvement,
            isOptional: true
        ),
        JournalPrompt(
            question: "What follow-up is needed from this message?",
            placeholder: "People to check on, topics to expand, next steps to announce...",
            category: .followUp,
            isOptional: true
        )
    ]

    // Personal reflection prompts
    static let personalPrompts: [JournalPrompt] = [
        JournalPrompt(
            question: "What are you feeling right now?",
            placeholder: "Write freely about your current emotional state...",
            category: .emotional,
            isOptional: false
        ),
        JournalPrompt(
            question: "Where did you sense God's presence today?",
            placeholder: "Moments of gratitude, peace, conviction, or guidance...",
            category: .spiritual,
            isOptional: false
        ),
        JournalPrompt(
            question: "Any people or situations to pray for?",
            placeholder: "List names, needs, and next steps...",
            category: .followUp,
            isOptional: true
        )
    ]

    // Prayer prompts
    static let prayerPrompts: [JournalPrompt] = [
        JournalPrompt(
            question: "What are you praying for today?",
            placeholder: "Petitions, intercessions, and thanksgiving...",
            category: .spiritual,
            isOptional: false
        ),
        JournalPrompt(
            question: "What do you sense God speaking?",
            placeholder: "Scriptures, impressions, confirmations...",
            category: .spiritual,
            isOptional: false
        )
    ]

    // Study Note prompts
    static let studyPrompts: [JournalPrompt] = [
        JournalPrompt(
            question: "What are you studying?",
            placeholder: "Topic, passage, or resource...",
            category: .spiritual,
            isOptional: false
        ),
        JournalPrompt(
            question: "Key insights and takeaways",
            placeholder: "Summarize what you learned...",
            category: .improvement,
            isOptional: false
        ),
        JournalPrompt(
            question: "Questions for further study",
            placeholder: "What needs more exploration?",
            category: .followUp,
            isOptional: true
        )
    ]
}

enum PromptCategory: String, CaseIterable {
    case emotional = "Emotional"
    case spiritual = "Spiritual"
    case impact = "Impact"
    case improvement = "Improvement"
    case followUp = "Follow-Up"
    
    var color: Color {
        switch self {
        case .emotional: return .blue
        case .spiritual: return .purple
        case .impact: return .green
        case .improvement: return .orange
        case .followUp: return .pink
        }
    }
    
    var icon: String {
        switch self {
        case .emotional: return "heart.fill"
        case .spiritual: return "flame.fill"
        case .impact: return "person.2.fill"
        case .improvement: return "arrow.up.circle.fill"
        case .followUp: return "arrow.forward.circle.fill"
        }
    }
}