import SwiftUI
import AVFoundation

struct SermonJournalView: View {
    let document: Letterspace_CanvasDocument
    let allDocuments: [Letterspace_CanvasDocument]
    let onDismiss: () -> Void
    
    @State private var journalEntry: SermonJournalEntry
    @State private var showSermonPicker = false
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var showingHealthMeter = false
    @State private var isGeneratingAISuggestions = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    init(document: Letterspace_CanvasDocument, allDocuments: [Letterspace_CanvasDocument], onDismiss: @escaping () -> Void) {
        self.document = document
        self.allDocuments = allDocuments
        self.onDismiss = onDismiss
        self._journalEntry = State(initialValue: SermonJournalEntry(sermonId: document.id))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Date & Type section (new)
                    dateAndTypeSection
                    // Header section
                    headerSection
                    
                    // Reflection prompts
                    reflectionSection
                    
                    // Energy and wellness tracking
                    wellnessSection
                    
                    // AI suggestions (if available)
                    if let suggestions = journalEntry.aiSuggestions {
                        aiSuggestionsSection(suggestions)
                    }
                    
                    // Save and action buttons
                    actionButtonsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Sermon Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveJournalEntry()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingHealthMeter) {
            SermonHealthMeterView(onDismiss: { showingHealthMeter = false })
        }
        .sheet(isPresented: $showSermonPicker) {
            ReflectionSelectionView(
                documents: allDocuments,
                onSelectDocument: { selected in
                    journalEntry.attachedSermonId = selected.id
                    showSermonPicker = false
                },
                onDismiss: { showSermonPicker = false }
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    private var dateAndTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .foregroundColor(theme.accent)
                DatePicker(
                    "Entry Date",
                    selection: Binding(get: { journalEntry.entryDate }, set: { journalEntry.entryDate = $0 }),
                    displayedComponents: [.date]
                )
                .labelsHidden()
                Spacer()
                Picker("Kind", selection: Binding(get: { journalEntry.kind }, set: { journalEntry.kind = $0 })) {
                    ForEach(ReflectionKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
        }
        .padding(.horizontal, 20)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.book.closed.fill")
                    .font(.title2)
                    .foregroundColor(theme.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    if journalEntry.kind == .sermon {
                        Text("Journal")
                            .font(.subheadline)
                            .foregroundColor(theme.secondary)
                    } else {
                        Text("Journal · \(journalEntry.kind.title)")
                            .font(.subheadline)
                            .foregroundColor(theme.secondary)
                    }
                }
                
                Spacer()
                
                if journalEntry.kind == .sermon {
                    Button(action: {
                        showSermonPicker = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "paperclip")
                            Text("Attach Sermon")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Quick emotional state picker
            emotionalStateSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.background.opacity(0.5))
        )
    }
    
    private var emotionalStateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How are you feeling after preaching?")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(EmotionalState.allCases, id: \.self) { state in
                    Button(action: {
                        journalEntry.emotionalState = state
                    }) {
                        VStack(spacing: 4) {
                            Text(state.emoji)
                                .font(.title2)
                            
                            Text(state.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(journalEntry.emotionalState == state ? state.color.opacity(0.2) : Color.gray.opacity(0.1))
                        )
                        .foregroundColor(journalEntry.emotionalState == state ? state.color : theme.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var reflectionSection: some View {
        VStack(spacing: 20) {
            ForEach(promptsForKind(journalEntry.kind), id: \.question) { prompt in
                reflectionPromptView(prompt)
            }
        }
    }

    private func promptsForKind(_ kind: ReflectionKind) -> [JournalPrompt] {
        switch kind {
        case .sermon:
            return JournalPrompt.sermonPrompts
        case .personal:
            return JournalPrompt.personalPrompts
        case .prayer:
            return JournalPrompt.prayerPrompts
        case .study:
            return JournalPrompt.studyPrompts
        }
    }
    
    private func reflectionPromptView(_ prompt: JournalPrompt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: prompt.category.icon)
                    .font(.headline)
                    .foregroundColor(prompt.category.color)
                
                Text(prompt.question)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
                
                Spacer()
                
                if prompt.isOptional {
                    Text("Optional")
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.secondary.opacity(0.2))
                        )
                }
            }
            
            VStack(alignment: .trailing, spacing: 8) {
                TextEditor(text: bindingForPrompt(prompt))
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                            .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(prompt.category.color.opacity(0.05))
                .stroke(prompt.category.color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var wellnessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.headline)
                    .foregroundColor(.pink)
                
                Text("Energy & Wellness Check")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
            }
            
            VStack(spacing: 16) {
                energySlider(
                    title: "Spiritual Fulfillment",
                    value: $journalEntry.spiritualFulfillment,
                    icon: "flame.fill",
                    color: .purple
                )
                
                energySlider(
                    title: "Physical Energy",
                    value: $journalEntry.physicalEnergy,
                    icon: "bolt.fill",
                    color: .orange
                )
                
                energySlider(
                    title: "Overall Energy",
                    value: $journalEntry.energyLevel,
                    icon: "battery.100",
                    color: .green
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.pink.opacity(0.05))
                .stroke(Color.pink.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func energySlider(title: String, value: Binding<Int>, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
                
                Spacer()
                
                Text("\(value.wrappedValue)/10")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) }
            ), in: 1...10, step: 1)
            .accentColor(color)
        }
    }
    
    private func aiSuggestionsSection(_ suggestions: SermonFollowUpSuggestions) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                Text("AI Follow-Up Suggestions")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                suggestionCard("Devotionals", suggestions.devotionalIdeas, "book.fill", .blue)
                suggestionCard("Social Posts", suggestions.socialMediaPosts, "megaphone.fill", .green)
                suggestionCard("Scriptures", suggestions.scriptures, "text.book.closed.fill", .purple)
                suggestionCard("Prayer Points", suggestions.prayerPoints, "hands.sparkles.fill", .orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.05))
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func suggestionCard(_ title: String, _ items: [String], _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
            }
            
            Text("\(items.count) suggestions")
                .font(.caption)
                .foregroundColor(theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                generateAISuggestions()
            }) {
                HStack {
                    if isGeneratingAISuggestions {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    
                    Text(isGeneratingAISuggestions ? "Generating Suggestions..." : "Generate AI Follow-Up Suggestions")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.accent)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isGeneratingAISuggestions)
            
            Button(action: {
                showingHealthMeter = true
            }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("View Sermon Health Trends")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.pink.opacity(0.1))
                .foregroundColor(.pink)
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func bindingForPrompt(_ prompt: JournalPrompt) -> Binding<String> {
        switch prompt.category {
        case .emotional:
            return $journalEntry.feelings
        case .spiritual:
            if prompt.question.contains("atmosphere") {
                return $journalEntry.spiritualAtmosphere
            } else {
                return $journalEntry.godRevealedNew
            }
        case .impact:
            return $journalEntry.testimoniesAndBreakthroughs
        case .improvement:
            return $journalEntry.improvementNotes
        case .followUp:
            return $journalEntry.followUpNotes
        }
    }
    
    private func toggleVoiceRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // Implementation for voice recording
        isRecording = true
        // TODO: Implement actual recording logic
    }
    
    private func stopRecording() {
        // Implementation for stopping recording
        isRecording = false
        // TODO: Implement actual stop recording logic
    }
    
    private func generateAISuggestions() {
        isGeneratingAISuggestions = true
        
        // Mock AI generation - in real implementation, call AIService
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let suggestions = SermonFollowUpSuggestions(
                devotionalIdeas: [
                    "A 3-day devotional on the main theme of your sermon",
                    "Weekly reflection questions for small groups",
                    "Personal prayer guide based on your message"
                ],
                followUpMessages: [
                    "A deeper dive into the secondary points you touched on",
                    "Practical application sermon for next week",
                    "Q&A session addressing congregation questions"
                ],
                scriptures: [
                    "Related passages that support your main theme",
                    "Cross-references that expand the biblical context",
                    "Complementary verses for further study"
                ],
                socialMediaPosts: [
                    "Key quote graphics from your sermon",
                    "Thought-provoking questions for engagement",
                    "Encouragement posts based on your message"
                ],
                prayerPoints: [
                    "Prayers for applying the sermon's truth",
                    "Intercession for specific congregation needs",
                    "Thanksgiving for what God revealed"
                ],
                discussionQuestions: [
                    "Small group questions for deeper study",
                    "Family devotion discussion starters",
                    "Personal reflection prompts"
                ]
            )
            
            journalEntry.aiSuggestions = suggestions
            isGeneratingAISuggestions = false
        }
    }
    
    private func saveJournalEntry() {
        journalEntry.updatedAt = Date()
        if journalEntry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if journalEntry.kind == .sermon {
                journalEntry.title = "Reflection • \(document.title)"
            } else {
                let df = DateFormatter()
                df.dateStyle = .medium
                journalEntry.title = "\(journalEntry.kind.title) • \(df.string(from: journalEntry.entryDate))"
            }
        }
        SermonJournalService.shared.save(entry: journalEntry)
    }
}

// MARK: - Supporting Views

struct SermonHealthMeterView: View {
    let onDismiss: () -> Void
    
    @State private var healthMetrics = SermonHealthMetrics(pastorId: "current_pastor")
    @Environment(\.themeColors) var theme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Burnout risk indicator
                    burnoutRiskSection
                    
                    // Weekly trends
                    weeklyTrendsSection
                    
                    // Recommendations
                    recommendationsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Sermon Health Meter")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var burnoutRiskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.pink)
                
                Text("Current Health Status")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Burnout Risk Level")
                        .font(.subheadline)
                        .foregroundColor(theme.secondary)
                    
                    Text(healthMetrics.burnoutRiskLevel.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(healthMetrics.burnoutRiskLevel.color)
                }
                
                Spacer()
                
                Circle()
                    .fill(healthMetrics.burnoutRiskLevel.color)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    )
            }
            
            Text(healthMetrics.burnoutRiskLevel.description)
                .font(.subheadline)
                .foregroundColor(theme.secondary)
                .padding(.top, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(healthMetrics.burnoutRiskLevel.color.opacity(0.1))
                .stroke(healthMetrics.burnoutRiskLevel.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var weeklyTrendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Weekly Trends")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
            }
            
            Text("Track your energy and fulfillment patterns over time")
                .font(.subheadline)
                .foregroundColor(theme.secondary)
            
            // Placeholder for chart
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 120)
                .overlay(
                    Text("Weekly trends chart would appear here")
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Health Recommendations")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
            }
            
            if healthMetrics.recommendations.isEmpty {
                Text("Great job! No immediate recommendations. Keep maintaining your current wellness practices.")
                    .font(.subheadline)
                    .foregroundColor(theme.secondary)
            } else {
                ForEach(healthMetrics.recommendations) { recommendation in
                    recommendationCard(recommendation)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func recommendationCard(_ recommendation: HealthRecommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(priorityColor(recommendation.priority))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primary)
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(priorityColor(recommendation.priority).opacity(0.1))
        )
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        case 2: return .blue
        default: return .green
        }
    }
}

#Preview {
    SermonJournalView(
        document: Letterspace_CanvasDocument(
            title: "The Power of Faith",
            subtitle: "Finding Strength in Uncertain Times",
            elements: [],
            id: "preview",
            createdAt: Date(),
            modifiedAt: Date()
        ),
        allDocuments: [],
        onDismiss: {}
    )
}