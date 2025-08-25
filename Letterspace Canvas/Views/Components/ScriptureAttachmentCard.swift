import SwiftUI

struct ScriptureAttachmentCard: View {
    let reference: ScriptureReference
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var verses: [BibleVerse] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with reference
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(reference.fullReference)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text("•")
                    .foregroundColor(.secondary)
                Text("KJV")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading...")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.system(size: 12))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(verses) { verse in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(extractVerseNumber(from: verse.reference))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.purple)
                                .frame(width: 18)
                            
                            Text(verse.text)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .contextMenu {
            Button {
                copyScriptureText()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .onAppear {
            Task {
                await loadScripture()
            }
        }
    }
    
    private func loadScripture() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            verses = []
        }
        do {
            let result = try await BibleAPI.searchVerses(
                query: reference.fullReference,
                translation: "KJV",
                mode: .reference
            )
            await MainActor.run {
                verses = result.verses
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func copyScriptureText() {
        let scriptureText = formatScriptureForCopy()
        
        #if os(iOS)
        UIPasteboard.general.string = scriptureText
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(scriptureText, forType: .string)
        #endif
    }
    
    private func formatScriptureForCopy() -> String {
        guard !verses.isEmpty else { return reference.fullReference }
        
        var result = "\(reference.fullReference) (KJV)\n\n"
        
        for verse in verses {
            let verseNumber = extractVerseNumber(from: verse.reference)
            result += "\(verseNumber) \(verse.text)\n"
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractVerseNumber(from ref: String) -> Int {
        let comps = ref.split(separator: ":")
        if comps.count > 1 {
            return Int(comps[1].split(separator: "-").first ?? Substring("1")) ?? 1
        }
        return 1
    }
}