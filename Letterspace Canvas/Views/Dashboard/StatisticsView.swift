#if os(macOS) || os(iOS)
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Statistics View
struct StatisticsView: View {
    // MARK: - Properties
    let documents: [Letterspace_CanvasDocument]
    let onSelectDocument: (Letterspace_CanvasDocument) -> Void
    let onShowStatistics: () -> Void
    
    @Environment(\.themeColors) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorTheme) private var colorTheme
    @State private var isGeneratingInsights: Bool = false
    @State private var aiCuratedSermons: [CuratedSermon] = []
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Colored section
            VStack(alignment: .leading, spacing: 8) {
                let isLightOnColor = (colorTheme.currentTheme.id == "punchy") || colorTheme.hasGradients
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .foregroundStyle(isLightOnColor ? .white : .black)
                        .font(.system(size: 18, weight: .semibold))
                    Text("Statistics")
                        .font(.custom("InterTight-Bold", size: 17))
                        .foregroundStyle(isLightOnColor ? .white : .black)
                    Spacer()
                }
                
                Text("Analytics and sermon insights")
                    .font(.custom("InterTight-Regular", size: 14))
                    .foregroundStyle(isLightOnColor ? .white.opacity(0.9) : .black.opacity(0.7))
                    .lineLimit(2)
                
                Spacer()
                
                // Pills showing analytics info
                HStack(spacing: 6) {
                    Text("Analytics")
                        .font(.custom("InterTight-Medium", size: 11))
                        .foregroundStyle(isLightOnColor ? .white : .black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((isLightOnColor ? Color.white.opacity(0.22) : Color.black.opacity(0.1)), in: Capsule())
                    
                    Text("Trends")
                        .font(.custom("InterTight-Medium", size: 11))
                        .foregroundStyle(isLightOnColor ? .white : .black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((isLightOnColor ? Color.white.opacity(0.22) : Color.black.opacity(0.1)), in: Capsule())
                    Spacer()
                }
            }
            .padding(16)
            .frame(height: 190)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Color.white
                    if let gradients = colorTheme.gradients {
                        Rectangle().fill(gradients.statisticsGradient)
                    } else {
                        Rectangle().fill(colorTheme.currentTheme.curatedCards.statistics)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Explore button below colored section
            Button(action: onShowStatistics) {
                HStack {
                    Text("Explore")
                        .font(.custom("InterTight-Medium", size: 14))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(colorScheme == .dark ? {
            #if os(iOS)
            return Color(.systemGray6)
            #else
            return Color(.controlBackgroundColor)
            #endif
        }() : {
            #if os(iOS)
            return Color(.systemBackground)
            #else
            return Color(.windowBackgroundColor)
            #endif
        }())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke({
                    #if os(iOS)
                    return Color(.separator)
                    #else
                    return Color(.separatorColor)
                    #endif
                }(), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 8, x: 0, y: 2)
        .frame(width: 250, height: 260)
    }
}

// MARK: - Statistics Detail View
struct StatisticsDetailView: View {
    let documents: [Letterspace_CanvasDocument]
    let onSelectDocument: (Letterspace_CanvasDocument) -> Void
    let onDismiss: () -> Void
    
    @Environment(\.themeColors) private var theme
    @State private var isGeneratingInsights: Bool = false
    @State private var aiCuratedSermons: [CuratedSermon] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Statistics Cards
                    statisticsCardsSection
                    
                    // AI Insights Section
                    aiInsightsSection
                    
                    // Popular Tags
                    popularTagsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Statistics & Analytics")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
                #endif
            }
        }
    }
    
    // MARK: - Statistics Cards Section
    private var statisticsCardsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Total sermons card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(theme.accent)
                        Text("Total Sermons")
                            .font(.custom("InterTight-Medium", size: 14))
                            .foregroundStyle(theme.primary.opacity(0.7))
                    }
                    Text("\(documents.count)")
                        .font(.custom("InterTight-Bold", size: 24))
                        .foregroundStyle(theme.primary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                
                // This month card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.green)
                        Text("This Month")
                            .font(.custom("InterTight-Medium", size: 14))
                            .foregroundStyle(theme.primary.opacity(0.7))
                    }
                    Text("\(documents.prefix(5).count)")
                        .font(.custom("InterTight-Bold", size: 24))
                        .foregroundStyle(theme.primary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }
    
    // MARK: - AI Insights Section
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI-Generated Insights")
                    .font(.custom("InterTight-Bold", size: 20))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                if isGeneratingInsights {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Generate") {
                        generateAICuratedSermons()
                    }
                    .font(.custom("InterTight-Medium", size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.accent)
                    .cornerRadius(8)
                }
            }
            
            if aiCuratedSermons.isEmpty && !isGeneratingInsights {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text("No insights generated yet")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Tap Generate to get AI-powered insights about your sermons")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Insights grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(aiCuratedSermons) { sermon in
                        CuratedSermonCard(
                            sermon: sermon,
                            curationType: .statistics,
                            onTap: onSelectDocument
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Popular Tags Section
    private var popularTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular Tags")
                .font(.custom("InterTight-Medium", size: 16))
                .foregroundStyle(theme.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Faith", "Hope", "Love", "Grace", "Wisdom"], id: \.self) { tag in
                        Text(tag)
                            .font(.custom("InterTight-Medium", size: 12))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(theme.accent.opacity(0.1))
                            )
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .contentMargins(.horizontal, 10, for: .scrollContent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helper Functions
    private func generateAICuratedSermons() {
        guard !documents.isEmpty else { 
            isGeneratingInsights = false
            return 
        }
        
        isGeneratingInsights = true
        
        Task {
            var newCuratedSermons: [CuratedSermon] = []
            let selectedDocuments = Array(documents.prefix(5))
            
            for document in selectedDocuments {
                do {
                    // Use Foundation Model for insight generation
                    let insight = try await FoundationModelService.shared.generateSermonInsight(for: document)
                    let category = try await FoundationModelService.shared.categorizeSermon(document)
                    
                    let curatedSermon = CuratedSermon(
                        document: document,
                        aiInsight: insight,
                        category: category
                    )
                    newCuratedSermons.append(curatedSermon)
                } catch {
                    // Fallback to basic insights
                    let curatedSermon = CuratedSermon(
                        document: document,
                        aiInsight: generateBasicInsight(for: document),
                        category: "General"
                    )
                    newCuratedSermons.append(curatedSermon)
                }
            }
            
            await MainActor.run {
                self.aiCuratedSermons = newCuratedSermons
                self.isGeneratingInsights = false
            }
        }
    }
    
    private func generateBasicInsight(for document: Letterspace_CanvasDocument) -> String {
        let insights = [
            "A powerful message about faith and perseverance that resonates with current challenges.",
            "This sermon explores deep biblical truths with practical applications for daily life.",
            "An inspiring message of hope and redemption that speaks to the heart.",
            "A thoughtful exploration of scripture that brings fresh perspective to familiar passages.",
            "This message offers wisdom and guidance for navigating life's complexities."
        ]
        
        // Use document title hash to get consistent insights for the same document
        let hash = abs(document.title.hashValue)
        return insights[hash % insights.count]
    }
}

// MARK: - Curated Sermon Card Component
struct CuratedSermonCard: View {
    let sermon: CuratedSermon
    let curationType: CurationType
    let onTap: (Letterspace_CanvasDocument) -> Void
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: {
            onTap(sermon.document)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Gradient background with overlay
                ZStack {
                    // Background gradient
                    LinearGradient(
                        colors: [theme.accent.opacity(0.8), theme.accent.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Content overlay
                    VStack(alignment: .leading, spacing: 8) {
                        // AI-generated insight
                        Text(sermon.aiInsight)
                            .font(.custom("InterTight-Medium", size: 14))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Sermon title
                        Text(sermon.document.title)
                            .font(.custom("InterTight-Bold", size: 16))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .padding(16)
                }
                .frame(width: 280, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Bottom info
                VStack(alignment: .leading, spacing: 4) {
                    Text(sermon.document.title)
                        .font(.custom("InterTight-Medium", size: 14))
                        .foregroundStyle(theme.primary)
                        .lineLimit(1)
                    
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: curationType.icon)
                                .font(.system(size: 10))
                            Text(sermon.category)
                                .font(.custom("InterTight-Medium", size: 12))
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.accent.opacity(0.1))
                        )
                        
                        Spacer()
                        
                        Text("Foundation AI")
                            .font(.custom("InterTight-Regular", size: 10))
                            .foregroundStyle(theme.primary.opacity(0.6))
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Curated Sermon Data Model
struct CuratedSermon: Identifiable {
    let id = UUID()
    let document: Letterspace_CanvasDocument
    let aiInsight: String
    let category: String
}

// MARK: - Curation Types for Different Views
enum CurationType: String, CaseIterable {
    case todaysDocuments = "Today's Documents"
    case sermonJournal = "Sermon Journal"
    case trending = "Meetings"           // Place Meetings after Journal
    case preachItAgain = "Preach it Again"
    case statistics = "Statistics"
    case recent = "Recently Opened"
    
    var icon: String {
        switch self {
        case .todaysDocuments: return "calendar.badge.checkmark"
        case .sermonJournal: return "book.pages.fill"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .preachItAgain: return "arrow.clockwise.circle.fill"
        case .statistics: return "chart.bar.fill"
        case .recent: return "clock.fill"
        }
    }
    
    var title: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .todaysDocuments: return "Documents you've selected for today"
        case .sermonJournal: return "Post-preaching reflections & follow-ups"
        case .trending: return "Your most engaging and impactful sermons"
        case .preachItAgain: return "Sermons ready for a fresh delivery"
        case .statistics: return "Your sermon statistics and analytics"
        case .recent: return "Recently created content that reflects current spiritual insights and growth"
        }
    }
}
#endif
