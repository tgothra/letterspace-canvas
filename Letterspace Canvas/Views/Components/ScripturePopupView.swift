import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ScripturePopupView: View {
    let reference: ScriptureReference?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var scriptureText: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black.opacity(0.8) : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with beautiful design
                headerView
                
                // Content area
                contentView
                
                // Footer with action buttons
                footerView
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    #if os(macOS)
                    .fill(colorScheme == .dark ? Color(.controlBackgroundColor) : Color.white)
                    #elseif os(iOS)
                    .fill(colorScheme == .dark ? Color(.systemBackground) : Color.white)
                    #endif
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .frame(width: 550, height: 650)
        }
        .onAppear {
            loadScriptureText()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.6))
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.top, 16)
            }
            
            // Scripture icon and title
            VStack(spacing: 16) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                    .symbolRenderingMode(.hierarchical)
                
                if let reference = reference {
                    Text(reference.fullReference)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Scripture")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.blue.opacity(0.1) : Color.blue.opacity(0.05),
                    colorScheme == .dark ? Color.clear : Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if !scriptureText.isEmpty {
                    scriptureContentView
                } else {
                    emptyStateView
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("Loading scripture...")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .symbolRenderingMode(.multicolor)
            
            Text("Unable to Load Scripture")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    private var scriptureContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Parse and display verses beautifully
            let lines = scriptureText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if index == 0 {
                    // First line is usually the reference - style it differently
                    Text(line)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.bottom, 4)
                } else {
                    // Verse content
                    scriptureVerseView(line)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func scriptureVerseView(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Verse number (if present)
            if let verseMatch = text.range(of: #"^\d+"#, options: .regularExpression) {
                let verseNumber = String(text[verseMatch])
                let verseText = String(text[text.index(verseMatch.upperBound, offsetBy: 0)...]).trimmingCharacters(in: .whitespaces)
                
                Text(verseNumber)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 24, alignment: .leading)
                
                Text(verseText)
                    .font(.system(size: 16))
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // No verse number, just display the text
                Text(text)
                    .font(.system(size: 16))
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 36) // Indent to align with numbered verses
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.blue.opacity(0.03))
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Scripture Selected")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Please select a scripture reference to view its content.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                // Translation indicator
                HStack(spacing: 6) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("King James Version")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Copy Text") {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(scriptureText, forType: .string)
                        #elseif os(iOS)
                        UIPasteboard.general.string = scriptureText
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(scriptureText.isEmpty)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(
            colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.05)
        )
    }
    
    private func loadScriptureText() {
        guard let reference = reference else {
            errorMessage = "Invalid scripture reference"
            isLoading = false
            return
        }
        
        // Use the existing BibleAPI service to fetch scripture text
        Task {
            do {
                let result = try await BibleAPI.searchVerses(
                    query: reference.fullReference,
                    translation: "KJV", // Could make this configurable
                    mode: .reference
                )
                
                await MainActor.run {
                    if let firstVerse = result.verses.first {
                        // Format the scripture text nicely
                        if result.verses.count == 1 {
                            // Single verse
                            scriptureText = "\(firstVerse.reference)\n\n\(firstVerse.text)"
                        } else {
                            // Multiple verses (range)
                            let formattedVerses = result.verses.map { verse in
                                // Extract just the verse number for ranges
                                let parts = verse.reference.split(separator: ":")
                                if parts.count > 1 {
                                    let verseNum = parts[1]
                                    return "\(verseNum) \(verse.text)"
                                } else {
                                    return verse.text
                                }
                            }.joined(separator: "\n\n")
                            
                            scriptureText = "\(reference.fullReference)\n\n\(formattedVerses)"
                        }
                    } else {
                        scriptureText = "No scripture text found for \(reference.fullReference)"
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load scripture: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ScripturePopupView(reference: ScriptureReference(
        book: "Genesis",
        chapter: 1,
        verse: "1",
        displayText: "Genesis 1:1"
    ))
} 