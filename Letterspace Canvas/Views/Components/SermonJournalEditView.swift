import SwiftUI
import AVFoundation

struct SermonJournalEditView: View {
    let originalEntry: SermonJournalEntry
    let document: Letterspace_CanvasDocument
    let allDocuments: [Letterspace_CanvasDocument]
    let onDismiss: () -> Void
    
    @State private var journalEntry: SermonJournalEntry
    @State private var showSermonPicker = false
    @State private var showScripturePicker = false
    @State private var showingSermonDocument: Letterspace_CanvasDocument? = nil
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    init(entry: SermonJournalEntry, document: Letterspace_CanvasDocument, allDocuments: [Letterspace_CanvasDocument], onDismiss: @escaping () -> Void) {
        self.originalEntry = entry
        self.document = document
        self.allDocuments = allDocuments
        self.onDismiss = onDismiss
        
        // Initialize with existing entry data
        self._journalEntry = State(initialValue: entry)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section with entry type, date, and attach buttons
                    headerSection

                    scripturePillsSection
                    
                    if journalEntry.kind == .sermon {
                        emotionalStateSection
                    }

                    scriptureCardsSection
                    
                    // Reflection prompts (includes What are you studying?)
                    reflectionSection
                    
                    // Energy and wellness tracking - hide for study notes
                    if journalEntry.kind != .study {
                        wellnessSection
                    }
                    
                    // AI suggestions (if available)
                    if let suggestions = journalEntry.aiSuggestions {
                        aiSuggestionsSection(suggestions)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            #if os(iOS)
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            #endif
            .navigationTitle("Edit Journal Entry")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        updateJournalEntry()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button("Update") {
                        updateJournalEntry()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            #endif
        }
        .sheet(isPresented: $showSermonPicker) {
            ReflectionSelectionView(
                documents: allDocuments,
                onSelectDocument: { selected in
                    // Create a new journal entry with the selected sermon
                    var newEntry = SermonJournalEntry(sermonId: selected.id)
                    
                    // Copy over existing data to the new entry
                    newEntry.kind = journalEntry.kind
                    newEntry.entryDate = journalEntry.entryDate
                    newEntry.feelings = journalEntry.feelings
                    newEntry.spiritualAtmosphere = journalEntry.spiritualAtmosphere
                    newEntry.godRevealedNew = journalEntry.godRevealedNew
                    newEntry.testimoniesAndBreakthroughs = journalEntry.testimoniesAndBreakthroughs
                    newEntry.improvementNotes = journalEntry.improvementNotes
                    newEntry.followUpNotes = journalEntry.followUpNotes
                    newEntry.energyLevel = journalEntry.energyLevel
                    newEntry.spiritualFulfillment = journalEntry.spiritualFulfillment
                    newEntry.physicalEnergy = journalEntry.physicalEnergy
                    newEntry.emotionalState = journalEntry.emotionalState
                    newEntry.title = journalEntry.title
                    newEntry.aiSuggestions = journalEntry.aiSuggestions
                    
                    // Replace the current journal entry
                    journalEntry = newEntry
                    showSermonPicker = false
                },
                onDismiss: { showSermonPicker = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $showingSermonDocument) { sermon in
            SermonDocumentView(document: sermon) {
                showingSermonDocument = nil
            }
            #if os(macOS)
            .frame(width: 900, height: 700)
            #endif
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showScripturePicker) {
            BibleGlobalSearchModal(
                onSelectReference: { book, chapter, verse in
                    let ref = ScriptureReference(
                        book: book,
                        chapter: chapter,
                        verse: String(verse),
                        displayText: "\(book) \(chapter):\(verse)"
                    )
                    if journalEntry.attachedScriptures == nil { journalEntry.attachedScriptures = [] }
                    journalEntry.attachedScriptures?.append(ref)
                    showScripturePicker = false
                },
                onSelectPassage: { passage in
                    if journalEntry.attachedScriptures == nil { journalEntry.attachedScriptures = [] }
                    journalEntry.attachedScriptures?.append(passage)
                    showScripturePicker = false
                },
                onDismiss: {
                    showScripturePicker = false
                }
            )
        }
    }
    
    // Copy all the UI sections from SermonJournalView
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date row
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(theme.accent)
                    DatePicker(
                        "Entry Date", 
                        selection: Binding(get: { journalEntry.entryDate }, set: { journalEntry.entryDate = $0 }),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "en_US"))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
            }
            
            HStack {
                Menu {
                    ForEach(ReflectionKind.allCases) { kind in
                        Button {
                            journalEntry.kind = kind
                        } label: {
                            HStack {
                                Image(systemName: iconForKind(kind))
                                Text(kind.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: iconForKind(journalEntry.kind))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(theme.accent)
                        
                        Text(journalEntry.kind.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.accent)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.accent.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if journalEntry.kind == .sermon {
                    if let attachedSermon = allDocuments.first(where: { $0.id == journalEntry.sermonId }) {
                        HStack(spacing: 8) {
                            Button(action: {
                                showingSermonDocument = attachedSermon
                            }) {
                                Text(attachedSermon.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                var newEntry = SermonJournalEntry(sermonId: "")
                                newEntry.kind = journalEntry.kind
                                newEntry.entryDate = journalEntry.entryDate
                                newEntry.feelings = journalEntry.feelings
                                newEntry.spiritualAtmosphere = journalEntry.spiritualAtmosphere
                                newEntry.godRevealedNew = journalEntry.godRevealedNew
                                newEntry.testimoniesAndBreakthroughs = journalEntry.testimoniesAndBreakthroughs
                                newEntry.improvementNotes = journalEntry.improvementNotes
                                newEntry.followUpNotes = journalEntry.followUpNotes
                                newEntry.energyLevel = journalEntry.energyLevel
                                newEntry.spiritualFulfillment = journalEntry.spiritualFulfillment
                                newEntry.physicalEnergy = journalEntry.physicalEnergy
                                newEntry.emotionalState = journalEntry.emotionalState
                                newEntry.title = journalEntry.title
                                newEntry.aiSuggestions = journalEntry.aiSuggestions
                                journalEntry = newEntry
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color.blue.opacity(0.1))
                        )
                        .overlay(
                            Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    } else {
                        Button(action: { showSermonPicker = true }) {
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
                } else if journalEntry.kind == .study {
                    Button(action: { showScripturePicker = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.book.closed")
                            Text("Add Scripture")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.background.opacity(0.5))
        )
    }
    
    private var scripturePillsSection: some View {
        Group {
            if journalEntry.kind == .study, let scriptures = journalEntry.attachedScriptures, !scriptures.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(scriptures) { scripture in
                            HStack(spacing: 8) {
                                Text(scripture.fullReference)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.purple)
                                    .lineLimit(1)
                                
                                Button(action: {
                                    if var list = journalEntry.attachedScriptures {
                                        list.removeAll { $0.id == scripture.id }
                                        journalEntry.attachedScriptures = list
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.purple.opacity(0.1))
                            )
                            .overlay(
                                Capsule().stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, 0) // Remove extra padding since we're already padding the HStack
            } else {
                EmptyView()
            }
        }
    }

    private var scriptureCardsSection: some View {
        Group {
            if journalEntry.kind == .study, let scriptures = journalEntry.attachedScriptures, !scriptures.isEmpty {
                VStack(spacing: 12) {
                    ForEach(scriptures) { ref in
                        ScriptureAttachmentCard(reference: ref)
                    }
                }
                .padding(.horizontal, 0) // Remove extra padding to match prompt cards
            } else {
                EmptyView()
            }
        }
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
            
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: bindingForPrompt(prompt))
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                            .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                    )
                
                // Voice recording button for each prompt
                VoiceRecordingButton(
                    text: bindingForPrompt(prompt),
                    placeholder: prompt.placeholder,
                    onAudioSaved: { audioURL, transcript in
                        // Save the audio URL and transcript to the journal entry
                        journalEntry.voiceNoteURL = audioURL
                        if journalEntry.transcription?.isEmpty != false {
                            journalEntry.transcription = transcript
                        } else {
                            journalEntry.transcription = (journalEntry.transcription ?? "") + "\n\n" + transcript
                        }
                    }
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
    
    private func updateJournalEntry() {
        journalEntry.updatedAt = Date()
        if journalEntry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if journalEntry.kind == .sermon {
                if let attachedDoc = allDocuments.first(where: { $0.id == journalEntry.sermonId }) {
                    journalEntry.title = "Reflection • \(attachedDoc.title)"
                } else {
                    journalEntry.title = "Reflection • Custom Entry"
                }
            } else {
                let df = DateFormatter()
                df.dateStyle = .medium
                journalEntry.title = "\(journalEntry.kind.title) • \(df.string(from: journalEntry.entryDate))"
            }
        }
        SermonJournalService.shared.save(entry: journalEntry)
    }
    
    private func formattedDateWithDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func iconForKind(_ kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "book.pages"
        case .personal: return "face.smiling"
        case .prayer: return "hands.sparkles"
        case .study: return "book"
        }
    }
}