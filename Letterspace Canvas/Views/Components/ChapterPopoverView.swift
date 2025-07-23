import SwiftUI
#if os(iOS)
import UIKit // For .systemBackground
#endif

struct ChapterPopoverView: View {
    let chapterReference: ConsolidatedChapterReference
    @State private var chapterData: ChapterResult?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentBook: String = ""
    @State private var currentChapter: Int = 1
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    private var popoverBackgroundColor: Color {
        if colorScheme == .dark {
            #if os(macOS)
            return Color(.controlBackgroundColor)
            #elseif os(iOS)
            return Color(.systemBackground)
            #else
            return .black // Fallback for other platforms
            #endif
        } else {
            return .white
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if let chapter = chapterData {
                chapterContentView(chapter)
            } else {
                Text("No content available")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
            // Footer
            footerView
        }
        .frame(
            maxWidth: {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    return .infinity // iPhone: Use full width
                } else {
                    return 600 // iPad: Use fixed width
                }
                #else
                return 600 // macOS: Use fixed width
                #endif
            }(),
            maxHeight: {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    return .infinity // iPhone: Use full height
                } else {
                    return 650 // iPad: Use fixed height
                }
                #else
                return 650 // macOS: Use fixed height
                #endif
            }()
        )
        .background(backgroundView)
        .onAppear {
            loadChapter()
            // Initialize current chapter tracking
            currentBook = chapterReference.book
            currentChapter = chapterReference.chapter
        }
    }
    
    // Helper view for background to handle platform differences
    @ViewBuilder
    private var backgroundView: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            // iPhone: Use full background without rounded corners for sheet presentation
            Rectangle()
                .fill(popoverBackgroundColor)
        } else {
            // iPad: Use rounded rectangle
            RoundedRectangle(cornerRadius: 12)
                .fill(popoverBackgroundColor)
        }
        #else
        // macOS: Use rounded rectangle
        RoundedRectangle(cornerRadius: 12)
            .fill(popoverBackgroundColor)
        #endif
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            #if os(iOS)
            // iPhone: Add close button at the top right
            if UIDevice.current.userInterfaceIdiom == .phone {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            #endif
            
            HStack(alignment: .center, spacing: 12) {
                // Previous Chapter Button
                Button(action: { 
                    loadPreviousChapter()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Previous Chapter")
                
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .symbolRenderingMode(.hierarchical)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(currentBook) \(currentChapter)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if currentBook == chapterReference.book && currentChapter == chapterReference.chapter && chapterReference.highlightedVerses.count > 0 {
                            Text("Highlighting \(chapterReference.highlightedVerses.count) verse\(chapterReference.highlightedVerses.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        } else if currentBook != chapterReference.book || currentChapter != chapterReference.chapter {
                            Text("Browsing")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Next Chapter Button
                Button(action: { 
                    loadNextChapter()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Next Chapter")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
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
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Loading chapter...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text("Error loading chapter")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func chapterContentView(_ chapter: ChapterResult) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(chapter.verses) { verse in
                        verseView(verse, isHighlighted: isVerseHighlighted(verse))
                            .id("verse_\(extractVerseNumber(from: verse.reference))")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onAppear {
                // Scroll to highlighted verse with a small delay
                if let firstHighlighted = chapterReference.highlightedVerses.sorted().first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            proxy.scrollTo("verse_\(firstHighlighted)", anchor: .center)
                        }
                        print("📖 Scrolled to verse \(firstHighlighted)")
                    }
                }
            }
            .onChange(of: chapterData?.chapter) { oldValue, newValue in
                // Scroll to highlighted verse when chapter changes
                if let firstHighlighted = chapterReference.highlightedVerses.sorted().first,
                   currentBook == chapterReference.book && currentChapter == chapterReference.chapter {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            proxy.scrollTo("verse_\(firstHighlighted)", anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    private func verseView(_ verse: BibleVerse, isHighlighted: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Simplified verse number
            Text("\(extractVerseNumber(from: verse.reference))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHighlighted ? .white : .blue)
                .frame(width: 24, height: 24)
                .background(Circle().fill(isHighlighted ? Color.blue : Color.blue.opacity(0.12)))
            
            // Simplified verse text
            Text(verse.text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(isHighlighted ? Color.blue.opacity(0.05) : Color.clear)
    }
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("Scroll to see the full chapter")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("KJV")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.05)
            )
        }
    }
    
    private func loadChapter() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await BibleAPI.fetchChapter(
                    book: chapterReference.book,
                    chapter: chapterReference.chapter,
                    translation: "KJV",
                    focusedVerses: Array(chapterReference.highlightedVerses)
                )
                
                await MainActor.run {
                    chapterData = result
                    isLoading = false
                    currentBook = chapterReference.book
                    currentChapter = chapterReference.chapter
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func loadPreviousChapter() {
        let previousChapter = currentChapter - 1
        if previousChapter >= 1 {
            currentChapter = previousChapter
            loadChapter(book: currentBook, chapter: currentChapter)
        }
    }
    
    private func loadNextChapter() {
        let nextChapter = currentChapter + 1
        // Most books don't go beyond 150 chapters, but we'll let the API handle invalid chapters
        if nextChapter <= 150 {
            currentChapter = nextChapter
            loadChapter(book: currentBook, chapter: nextChapter)
        }
    }
    
    private func loadChapter(book: String, chapter: Int) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await BibleAPI.fetchChapter(
                    book: book,
                    chapter: chapter,
                    translation: "KJV",
                    focusedVerses: [] // No highlighted verses for navigation
                )
                
                await MainActor.run {
                    chapterData = result
                    isLoading = false
                    currentBook = book
                    currentChapter = chapter
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func isVerseHighlighted(_ verse: BibleVerse) -> Bool {
        // Only highlight verses if we're viewing the original chapter
        guard currentBook == chapterReference.book && currentChapter == chapterReference.chapter else {
            return false
        }
        
        let verseNumber = extractVerseNumber(from: verse.reference)
        return chapterReference.highlightedVerses.contains(verseNumber)
    }
    
    private func extractVerseNumber(from reference: String) -> Int {
        let components = reference.split(separator: ":")
        if components.count > 1 {
            return Int(components[1]) ?? 1
        }
        return 1
    }
}

#Preview {
    ChapterPopoverView(
        chapterReference: ConsolidatedChapterReference(
            book: "John",
            chapter: 3,
            highlightedVerses: [16, 17],
            originalReferences: []
        )
    )
} 