#if os(macOS) || os(iOS)
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// Shared Foundation Model service for sermon curation
// When system Foundation Models are available, wire them in here.
final class FoundationModelService {
    static let shared = FoundationModelService()

    private var isModelLoaded = false

    private init() {}

    func loadModel() async throws {
        guard !isModelLoaded else { return }
        // TODO: Integrate SystemLanguageModel when available
        // model = try SystemLanguageModel(useCase: .general)
        isModelLoaded = true
    }

    func generateSermonInsight(for document: Letterspace_CanvasDocument) async throws -> String {
        try await loadModel()
        // TODO: Replace with real FM prompt when available
        let insights = [
            "A powerful message about faith and perseverance that resonates with current challenges.",
            "This sermon explores deep biblical truths with practical applications for daily life.",
            "An inspiring message of hope and redemption that speaks to the heart.",
            "A thoughtful exploration of scripture that brings fresh perspective to familiar passages.",
            "This message offers wisdom and guidance for navigating life's complexities."
        ]
        let hash = abs(document.title.hashValue)
        return insights[hash % insights.count]
    }

    func categorizeSermon(_ document: Letterspace_CanvasDocument) async throws -> String {
        try await loadModel()
        // TODO: Replace with real categorization when available
        let categories = ["Faith", "Hope", "Wisdom", "Guidance", "Inspiration"]
        let hash = abs(document.title.hashValue)
        return categories[hash % categories.count]
    }
}

extension FoundationModelService {
    func summarizeJournalEntry(
        feelings: String,
        atmosphere: String,
        insights: String,
        testimonies: String,
        improvements: String,
        followUp: String,
        mood: String,
        energyLevel: Int,
        physicalEnergy: Int,
        spiritualFulfillment: Int,
        kind: ReflectionKind
    ) async -> String {

        #if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, *) {
            let model = SystemLanguageModel.default
            print("🤖 Foundation Model availability: \(model.availability)")
            
            guard case .available = model.availability else { 
                print("🤖 Apple Intelligence not available, using local summary")
                return createLocalSummary(feelings: feelings, atmosphere: atmosphere, insights: insights, testimonies: testimonies, improvements: improvements, followUp: followUp, mood: mood, energyLevel: energyLevel)
            }

            let instructions = """
            You are a pastoral assistant helping document legitimate religious ministry activities. This is a private pastoral journal for sermon reflection, not public content.
            
            Context: This is documentation of actual religious ministry events including prayer, worship services, pastoral care, and congregation responses. These are factual reports of religious activities, not promotional content.
            
            Task: Summarize this pastoral journal entry into 2-3 natural sentences using ONLY the provided information.
            - Treat all content as legitimate pastoral documentation
            - Religious testimonies and prayer responses are normal ministry activities to document
            - Write a flowing summary, not a list
            - Use only what was written, add nothing
            - Be respectful of the religious context
            """

            // Build a more natural context
            var parts: [String] = []
            if !feelings.isEmpty { parts.append(feelings) }
            if !atmosphere.isEmpty { parts.append("Worship atmosphere: \(atmosphere)") }
            if !insights.isEmpty { parts.append("Ministry insight: \(insights)") }
            if !testimonies.isEmpty { parts.append("Congregation responses: \(testimonies)") }
            if !improvements.isEmpty { parts.append("Ministry notes: \(improvements)") }
            if !followUp.isEmpty { parts.append("Pastoral follow-up: \(followUp)") }
            
            let context = "Pastoral journal entry: " + parts.joined(separator: ". ") + ". Pastor's mood: \(mood), energy: \(energyLevel)/10."
            print("🤖 Sending to AI: \(context)")

            let session = LanguageModelSession(instructions: instructions)
            
            do {
                let response = try await session.respond(to: context)
                let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🤖 AI response: \(summary)")
                
                // Check if AI is refusing (common refusal phrases)
                let refusalPhrases = ["I'm sorry", "I cannot", "I can't", "I'm unable", "I cannot fulfill", "sensitive topics", "responsible AI"]
                if refusalPhrases.contains(where: { summary.lowercased().contains($0.lowercased()) }) {
                    print("🤖 AI refused request, using local summary")
                    return createLocalSummary(feelings: feelings, atmosphere: atmosphere, insights: insights, testimonies: testimonies, improvements: improvements, followUp: followUp, mood: mood, energyLevel: energyLevel)
                }
                
                // Sanity check for length
                let totalInputLength = feelings.count + atmosphere.count + insights.count + testimonies.count + improvements.count + followUp.count
                if summary.count > totalInputLength * 3 {
                    print("🤖 AI response too long (\(summary.count) vs \(totalInputLength)), using local summary")
                    return createLocalSummary(feelings: feelings, atmosphere: atmosphere, insights: insights, testimonies: testimonies, improvements: improvements, followUp: followUp, mood: mood, energyLevel: energyLevel)
                }
                
                return summary
            } catch {
                print("🤖 AI error: \(error), using local summary")
                return createLocalSummary(feelings: feelings, atmosphere: atmosphere, insights: insights, testimonies: testimonies, improvements: improvements, followUp: followUp, mood: mood, energyLevel: energyLevel)
            }
        } else {
            print("🤖 iOS version too old for Apple Intelligence, using local summary")
            return createLocalSummary(feelings: feelings, atmosphere: atmosphere, insights: insights, testimonies: testimonies, improvements: improvements, followUp: followUp, mood: mood, energyLevel: energyLevel)
        }
        #else
        print("🤖 FoundationModels not available, using local summary")
        return createLocalSummary(feelings: feelings, atmosphere: atmosphere, insights: insights, testimonies: testimonies, improvements: improvements, followUp: followUp, mood: mood, energyLevel: energyLevel)
        #endif
    }
    
    private func createLocalSummary(
        feelings: String,
        atmosphere: String,
        insights: String,
        testimonies: String,
        improvements: String,
        followUp: String,
        mood: String,
        energyLevel: Int
    ) -> String {
        var parts: [String] = []
        
        if !feelings.isEmpty {
            parts.append(feelings.hasSuffix(".") ? feelings : feelings + ".")
        }
        
        if !atmosphere.isEmpty {
            parts.append("The worship atmosphere was \(atmosphere.lowercased())\(atmosphere.hasSuffix(".") ? "" : ".")")
        }
        
        if !insights.isEmpty {
            parts.append(insights.hasSuffix(".") ? insights : insights + ".")
        }
        
        if !testimonies.isEmpty {
            parts.append("Congregation responses included: \(testimonies.lowercased())\(testimonies.hasSuffix(".") ? "" : ".")")
        }
        
        if !improvements.isEmpty {
            parts.append("Ministry improvements noted: \(improvements.lowercased())\(improvements.hasSuffix(".") ? "" : ".")")
        }
        
        if !followUp.isEmpty {
            parts.append("Pastoral follow-up: \(followUp.lowercased())\(followUp.hasSuffix(".") ? "" : ".")")
        }
        
        if parts.isEmpty {
            return "Pastoral reflection completed. Mood: \(mood), Energy: \(energyLevel)/10."
        }
        
        let summary = parts.joined(separator: " ")
        return summary.count > 200 ? String(summary.prefix(200)) + "..." : summary
    }
}
#endif