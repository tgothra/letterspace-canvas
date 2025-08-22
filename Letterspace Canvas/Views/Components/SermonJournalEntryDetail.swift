import SwiftUI

struct SermonJournalEntryDetail: View {
    let entry: SermonJournalEntry
    let onDismiss: () -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme

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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    // Sermon deep link
                    if let sermon = Letterspace_CanvasDocument.load(id: entry.sermonId) {
                        sermonLinkSection(sermon: sermon)
                    }

                    if !entry.feelings.isEmpty {
                        enhancedSection(
                            title: "Feelings", 
                            content: entry.feelings,
                            icon: "heart.fill",
                            color: .pink
                        )
                    }
                    
                    if !entry.spiritualAtmosphere.isEmpty {
                        enhancedSection(
                            title: "Spiritual Atmosphere", 
                            content: entry.spiritualAtmosphere,
                            icon: "flame.fill",
                            color: .purple
                        )
                    }
                    
                    if !entry.godRevealedNew.isEmpty {
                        enhancedSection(
                            title: "Revelation While Preaching", 
                            content: entry.godRevealedNew,
                            icon: "lightbulb.fill",
                            color: .yellow
                        )
                    }
                    
                    if !entry.testimoniesAndBreakthroughs.isEmpty {
                        enhancedSection(
                            title: "Testimonies & Breakthroughs", 
                            content: entry.testimoniesAndBreakthroughs,
                            icon: "person.2.fill",
                            color: .green
                        )
                    }

                    if !entry.improvementNotes.isEmpty {
                        enhancedSection(
                            title: "Improvements for Next Time", 
                            content: entry.improvementNotes,
                            icon: "arrow.up.circle.fill",
                            color: .orange
                        )
                    }

                    if !entry.followUpNotes.isEmpty {
                        enhancedSection(
                            title: "Follow-Up", 
                            content: entry.followUpNotes,
                            icon: "arrow.forward.circle.fill",
                            color: .blue
                        )
                    }
                    
                    // Energy and emotional state section
                    energySection
                    
                    if let suggestions = entry.aiSuggestions {
                        enhancedSection(
                            title: "AI Suggestions", 
                            content: suggestions.summary,
                            icon: "sparkles",
                            color: .mint
                        )
                    }
                    
                    if let transcription = entry.transcription {
                        enhancedSection(
                            title: "Voice Transcription", 
                            content: transcription,
                            icon: "waveform",
                            color: .indigo
                        )
                    }
                }
                .padding(20)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Journal Detail")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done", action: onDismiss) }
                #else
                ToolbarItem(placement: .automatic) { Button("Done", action: onDismiss) }
                #endif
            }
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

    private func sermonLinkSection(sermon: Letterspace_CanvasDocument) -> some View {
        Button(action: {
            NotificationCenter.default.post(name: NSNotification.Name("OpenDocumentById"), object: entry.sermonId)
            onDismiss()
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
            PlatformImageView(platformImage: image)
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
            PlatformImageView(platformImage: image)
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
}