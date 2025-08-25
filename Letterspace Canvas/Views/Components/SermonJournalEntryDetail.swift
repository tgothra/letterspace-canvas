import SwiftUI
import AVFoundation

struct SermonJournalEntryDetail: View {
    let entry: SermonJournalEntry
    let onDismiss: () -> Void
    
    @State private var showingSermonDocument: Letterspace_CanvasDocument? = nil
    @State private var showingEditForm: Bool = false
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var audioPlayback = AudioPlaybackService.shared

    private var accentColor: Color {
        switch entry.kind {
        case .sermon: return .blue
        case .personal: return .pink
        case .prayer: return .purple
        case .study: return .teal
        }
    }

    private var backgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(.windowBackgroundColor)
        #endif
    }
    
    private var originalDocumentForEditing: Letterspace_CanvasDocument {
        if !entry.sermonId.isEmpty {
            return Letterspace_CanvasDocument.load(id: entry.sermonId) ?? Letterspace_CanvasDocument(
                title: "Unknown Sermon",
                id: entry.sermonId
            )
        } else {
            return Letterspace_CanvasDocument(
                title: "Custom Entry",
                id: ""
            )
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    // Sermon deep link
                    if let sermon = Letterspace_CanvasDocument.load(id: entry.sermonId) {
                        sermonLinkSection(sermon: sermon)
                    }

                    if entry.kind == .study, let scriptures = entry.attachedScriptures, !scriptures.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "text.book.closed.fill")
                                    .foregroundStyle(.purple)
                                Text("Attached Scriptures")
                                    .font(.headline)
                                    .foregroundStyle(theme.primary)
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(scriptures) { ref in
                                    ScriptureAttachmentCard(reference: ref)
                                }
                            }
                        }
                    }

                    // Voice memo section (if available and not attached to specific content)
                    //     voiceMemoSection(url: voiceURL)
                    // }

                    if !entry.feelings.isEmpty {
                        enhancedSection(
                            title: feelingsTitle(for: entry.kind), 
                            content: entry.feelings,
                            icon: feelingsIcon(for: entry.kind),
                            color: .pink
                        )
                    }
                    
                    if !entry.spiritualAtmosphere.isEmpty {
                        enhancedSection(
                            title: atmosphereTitle(for: entry.kind), 
                            content: entry.spiritualAtmosphere,
                            icon: atmosphereIcon(for: entry.kind),
                            color: .purple
                        )
                    }
                    
                    if !entry.godRevealedNew.isEmpty {
                        enhancedSection(
                            title: revelationTitle(for: entry.kind), 
                            content: entry.godRevealedNew,
                            icon: revelationIcon(for: entry.kind),
                            color: .yellow
                        )
                    }
                    
                    if !entry.testimoniesAndBreakthroughs.isEmpty {
                        enhancedSection(
                            title: testimoniesTitle(for: entry.kind), 
                            content: entry.testimoniesAndBreakthroughs,
                            icon: testimoniesIcon(for: entry.kind),
                            color: .green
                        )
                    }

                    if !entry.improvementNotes.isEmpty {
                        enhancedSection(
                            title: improvementTitle(for: entry.kind), 
                            content: entry.improvementNotes,
                            icon: improvementIcon(for: entry.kind),
                            color: .orange
                        )
                    }

                    if !entry.followUpNotes.isEmpty {
                        enhancedSection(
                            title: followUpTitle(for: entry.kind), 
                            content: entry.followUpNotes,
                            icon: followUpIcon(for: entry.kind),
                            color: .blue
                        )
                    }
                    
                    // Energy and emotional state section
                    if entry.kind != .study {
                        energySection
                    }
                    
                    // AI-generated suggestions (if available)
                    if let suggestions = entry.aiSuggestions {
                        enhancedSection(
                            title: "AI Suggestions", 
                            content: suggestions.summary,
                            icon: "sparkles",
                            color: .mint
                        )
                    }
                }
                .padding(20)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Journal Detail")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Edit") {
                        showingEditForm = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) { 
                    Button("Done", action: onDismiss) 
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Edit") {
                        showingEditForm = true
                    }
                }
                ToolbarItem(placement: .automatic) { 
                    Button("Done", action: onDismiss) 
                }
                #endif
            }
        }
        .sheet(isPresented: $showingEditForm) {
            SermonJournalEditView(
                entry: entry,
                document: originalDocumentForEditing,
                allDocuments: loadAllDocuments(),
                onDismiss: {
                    showingEditForm = false
                }
            )
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
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.and.text.magnifyingglass")
                    .foregroundStyle(accentColor)
                    .font(.system(size: 24, weight: .semibold))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.kind.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.primary)
                    
                    Text(formatted(entry.entryDate))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.secondary)
                }
                
                Spacer()
            }
            
            // Emotional state with styling
            if entry.kind != .study {
                HStack(spacing: 12) {
                    Text(entry.emotionalState.emoji)
                        .font(.system(size: 28))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Emotional State")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.secondary)
                        
                        Text(entry.emotionalState.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(entry.emotionalState.color)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(entry.emotionalState.color.opacity(colorScheme == .dark ? 0.15 : 0.08))
                )
            }
        }
    }

    private func sermonLinkSection(sermon: Letterspace_CanvasDocument) -> some View {
        Button(action: {
            showingSermonDocument = sermon
        }) {
            HStack(spacing: 12) {
                sermonThumbnail(for: sermon)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Related Sermon")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                    
                    Text(sermon.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.primary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(theme.accent)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.accent.opacity(colorScheme == .dark ? 0.15 : 0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var energySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Energy Levels")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.primary)
            }
            
            VStack(spacing: 12) {
                energyRow(title: "Overall Energy", value: entry.energyLevel, color: .green, icon: "battery.100")
                energyRow(title: "Spiritual Fulfillment", value: entry.spiritualFulfillment, color: .purple, icon: "flame.fill")
                energyRow(title: "Physical Energy", value: entry.physicalEnergy, color: .orange, icon: "figure.run")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.15 : 0.08))
        )
    }

    private func energyRow(title: String, value: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(value) / 10.0, height: 8)
                    }
                }
                .frame(width: 60, height: 8)
                
                Text("\(value)/10")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
    }
    
    private func enhancedSection(title: String, content: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.primary)
            }
            
            Text(content.isEmpty ? "—" : content)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(theme.primary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Voice memo playback (if available and this is the first non-empty section)
            if let voiceURL = entry.voiceNoteURL, shouldShowVoiceMemo(for: title) {
                voicePlaybackView(url: voiceURL)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(colorScheme == .dark ? 0.15 : 0.08))
        )
    }
    
    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    @ViewBuilder
    private func sermonThumbnail(for document: Letterspace_CanvasDocument) -> some View {
        #if os(macOS)
        if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
           !headerElement.content.isEmpty,
           let imagesPath = Letterspace_CanvasDocument.getAppDocumentsDirectory()?.appendingPathComponent("Images"),
           let image = NSImage(contentsOf: imagesPath.appendingPathComponent(headerElement.content)) {
            PlatformImageView(platformImage: image, label: "Sermon Header")
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.accent.opacity(0.2))
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(theme.accent)
                    .font(.system(size: 20, weight: .semibold))
            }
        }
        #else
        if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
           !headerElement.content.isEmpty,
           let imagesPath = Letterspace_CanvasDocument.getAppDocumentsDirectory()?.appendingPathComponent("Images"),
           let data = try? Data(contentsOf: imagesPath.appendingPathComponent(headerElement.content)),
           let image = UIImage(data: data) {
            PlatformImageView(platformImage: image, label: "Sermon Header")
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.accent.opacity(0.2))
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(theme.accent)
                    .font(.system(size: 20, weight: .semibold))
            }
        }
        #endif
    }

    private func loadAllDocuments() -> [Letterspace_CanvasDocument] {
        var results: [Letterspace_CanvasDocument] = []
        if let appDir = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
            if let files = try? FileManager.default.contentsOfDirectory(at: appDir, includingPropertiesForKeys: nil) {
                for url in files where url.pathExtension == "canvas" {
                    if let data = try? Data(contentsOf: url),
                       let doc = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                        results.append(doc)
                    }
                }
            }
        }
        return results.sorted { ($0.modifiedAt ?? $0.createdAt) > ($1.modifiedAt ?? $1.createdAt) }
    }

    // MARK: - Section Title Helpers
    private func feelingsTitle(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "Feelings"
        case .study: return "Personal Reflection"
        case .personal: return "Personal Experience"
        case .prayer: return "Prayer Experience"
        }
    }
    
    private func feelingsIcon(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "heart.fill"
        case .study: return "brain.head.profile"
        case .personal: return "person.fill.checkmark"
        case .prayer: return "hands.sparkles.fill"
        }
    }
    
    private func atmosphereTitle(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "Spiritual Atmosphere"
        case .study: return "Study Environment"
        case .personal: return "Spiritual Atmosphere"
        case .prayer: return "Prayer Atmosphere"
        }
    }
    
    private func atmosphereIcon(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "flame.fill"
        case .study: return "book.closed.fill"
        case .personal: return "flame.fill"
        case .prayer: return "cloud.fill"
        }
    }
    
    private func revelationTitle(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "Revelation While Preaching"
        case .study: return "Key Insights & Takeaways"
        case .personal: return "Spiritual Insights"
        case .prayer: return "What God Revealed"
        }
    }
    
    private func revelationIcon(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "lightbulb.fill"
        case .study: return "key.fill"
        case .personal: return "eye.fill"
        case .prayer: return "sparkles"
        }
    }
    
    private func testimoniesTitle(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "Testimonies & Breakthroughs"
        case .study: return "Applications & Connections"
        case .personal: return "Breakthroughs & Growth"
        case .prayer: return "Answered Prayers & Testimonies"
        }
    }
    
    private func testimoniesIcon(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "person.2.fill"
        case .study: return "arrow.triangle.branch"
        case .personal: return "arrow.up.heart.fill"
        case .prayer: return "checkmark.seal.fill"
        }
    }
    
    private func improvementTitle(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "Improvements for Next Time"
        case .study: return "Areas for Further Study"
        case .personal: return "Growth Areas"
        case .prayer: return "Prayer Improvements"
        }
    }
    
    private func improvementIcon(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "arrow.up.circle.fill"
        case .study: return "magnifyingglass.circle.fill"
        case .personal: return "leaf.arrow.triangle.circlepath"
        case .prayer: return "arrow.clockwise.circle.fill"
        }
    }
    
    private func followUpTitle(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "Follow-Up"
        case .study: return "Questions for Further Study"
        case .personal: return "Next Steps"
        case .prayer: return "Ongoing Prayer Focus"
        }
    }
    
    private func followUpIcon(for kind: ReflectionKind) -> String {
        switch kind {
        case .sermon: return "arrow.forward.circle.fill"
        case .study: return "questionmark.circle.fill"
        case .personal: return "arrow.right.circle.fill"
        case .prayer: return "repeat.circle.fill"
        }
    }
    
    private func voiceMemoSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Voice Memo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.primary)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    AudioPlaybackService.shared.playAudio(url: url)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Play Audio Recording")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.blue)
                            
                            if let transcription = entry.transcription, !transcription.isEmpty {
                                Text("Includes voice transcription")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.secondary)
                            } else {
                                Text("Tap to play voice memo")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            ForEach(0..<4) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(.blue.opacity(0.6))
                                    .frame(width: 3, height: CGFloat.random(in: 8...20))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
                    .stroke(Color.blue.opacity(0.15), lineWidth: 1)
            )
            
            // Show transcription if available
            if let transcription = entry.transcription, !transcription.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.quote")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("Voice Transcription")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.primary)
                    }
                    
                    Text(transcription)
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                        .lineSpacing(2)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.03))
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.08))
        )
    }
    
    // MARK: - Voice Memo Helpers
    private func shouldShowVoiceMemo(for title: String) -> Bool {
        // Debug logging
        if entry.voiceNoteURL != nil {
            print("🎵 Voice memo exists for entry kind: \(entry.kind)")
            print("🎵 Checking section: \(title)")
            print("🎵 Feelings empty: \(entry.feelings.isEmpty)")
            print("🎵 Atmosphere empty: \(entry.spiritualAtmosphere.isEmpty)")
            print("🎵 Revelation empty: \(entry.godRevealedNew.isEmpty)")
        }
        
        // Show voice memo in the first non-empty section regardless of entry type
        // Priority order: feelings, spiritual atmosphere, revelation, testimonies, improvements, follow-up
        
        if title == feelingsTitle(for: entry.kind) && !entry.feelings.isEmpty {
            print("🎵 Showing voice memo in feelings section")
            return true
        } else if title == atmosphereTitle(for: entry.kind) && !entry.spiritualAtmosphere.isEmpty && entry.feelings.isEmpty {
            print("🎵 Showing voice memo in atmosphere section")
            return true
        } else if title == revelationTitle(for: entry.kind) && !entry.godRevealedNew.isEmpty && entry.feelings.isEmpty && entry.spiritualAtmosphere.isEmpty {
            print("🎵 Showing voice memo in revelation section")
            return true
        } else if title == testimoniesTitle(for: entry.kind) && !entry.testimoniesAndBreakthroughs.isEmpty && entry.feelings.isEmpty && entry.spiritualAtmosphere.isEmpty && entry.godRevealedNew.isEmpty {
            print("🎵 Showing voice memo in testimonies section")
            return true
        } else if title == improvementTitle(for: entry.kind) && !entry.improvementNotes.isEmpty && entry.feelings.isEmpty && entry.spiritualAtmosphere.isEmpty && entry.godRevealedNew.isEmpty && entry.testimoniesAndBreakthroughs.isEmpty {
            print("🎵 Showing voice memo in improvements section")
            return true
        } else if title == followUpTitle(for: entry.kind) && !entry.followUpNotes.isEmpty && entry.feelings.isEmpty && entry.spiritualAtmosphere.isEmpty && entry.godRevealedNew.isEmpty && entry.testimoniesAndBreakthroughs.isEmpty && entry.improvementNotes.isEmpty {
            print("🎵 Showing voice memo in follow-up section")
            return true
        }
        
        return false
    }
    
    private func voicePlaybackView(url: URL) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                playAudio(url: url)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: audioPlayback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audioPlayback.isPlaying ? "Playing Voice Memo" : "Play Voice Memo")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                        
                        if let transcription = entry.transcription, !transcription.isEmpty {
                            Text("Includes transcription")
                                .font(.system(size: 11))
                                .foregroundColor(theme.secondary)
                        } else {
                            Text("Tap to hear audio")
                                .font(.system(size: 11))
                                .foregroundColor(theme.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Mini waveform
                    HStack(spacing: 1) {
                        ForEach(0..<5) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.blue.opacity(0.6))
                                .frame(width: 2, height: CGFloat.random(in: 6...14))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.05))
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func playAudio(url: URL) {
        print("🎵 Attempting to play audio: \(url.path)")
        print("🎵 File exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        do {
            // Setup audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            
            if audioPlayback.isPlaying {
                audioPlayback.stopAudio()
            } else {
                audioPlayback.playAudio(url: url)
            }
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
}