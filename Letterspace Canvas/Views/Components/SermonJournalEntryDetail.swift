import SwiftUI

struct SermonJournalEntryDetail: View {
    let entry: SermonJournalEntry
    let onDismiss: () -> Void
    
    @Environment(\.themeColors) var theme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Sermon deep link
                    if let sermon = Letterspace_CanvasDocument.load(id: entry.sermonId) {
                        Button(action: {
                            // Post a notification so Dashboard can open this sermon
                            NotificationCenter.default.post(name: NSNotification.Name("OpenDocumentById"), object: entry.sermonId)
                            onDismiss()
                        }) {
                            HStack(spacing: 10) {
                                sermonThumbnail(for: sermon)
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sermon.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(theme.primary)
                                        .lineLimit(1)
                                    Text(formatted(entry.createdAt))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    section(title: "Date", content: formatted(entry.createdAt))
                    section(title: "Feelings", content: entry.feelings)
                    section(title: "Spiritual Atmosphere", content: entry.spiritualAtmosphere)
                    section(title: "Revelation While Preaching", content: entry.godRevealedNew)
                    section(title: "Testimonies / Breakthroughs", content: entry.testimoniesAndBreakthroughs)
                    section(title: "Energy Levels", content: "Overall: \(entry.energyLevel)  •  Spiritual: \(entry.spiritualFulfillment)  •  Physical: \(entry.physicalEnergy)")
                    section(title: "Emotional State", content: entry.emotionalState.rawValue.capitalized)
                    if let suggestions = entry.aiSuggestions {
                        section(title: "AI Suggestions", content: suggestions.summary)
                    }
                    if let transcription = entry.transcription {
                        section(title: "Transcription", content: transcription)
                    }
                }
                .padding(20)
            }
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
    
    private func section(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondary)
            Text(content.isEmpty ? "—" : content)
                .font(.system(size: 16))
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
        }
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
            Image(systemName: "rectangle.and.text.magnifyingglass")
                .foregroundStyle(theme.accent)
                .background(Color.gray.opacity(0.1))
        }
        #else
        if let headerElement = document.elements.first(where: { $0.type == .headerImage }),
           !headerElement.content.isEmpty,
           let imagesPath = Letterspace_CanvasDocument.getAppDocumentsDirectory()?.appendingPathComponent("Images"),
           let data = try? Data(contentsOf: imagesPath.appendingPathComponent(headerElement.content)),
           let image = UIImage(data: data) {
            PlatformImageView(platformImage: image)
        } else {
            Image(systemName: "rectangle.and.text.magnifyingglass")
                .foregroundStyle(theme.accent)
                .background(Color.gray.opacity(0.1))
        }
        #endif
    }
}
