import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct TranslationPreviewView: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    // Translation state
    @State private var selectedLanguage: TranslationLanguage = .spanish
    @State private var isTranslating: Bool = false
    @State private var translationProgress: Double = 0.0
    @State private var translatedTitle: String = ""
    @State private var translatedSubtitle: String = ""
    @State private var translatedContent: NSAttributedString = NSAttributedString(string: "")
    @State private var showTranslationError: Bool = false
    @State private var errorMessage: String = ""
    
    // Progressive translation state
    @State private var contentChunks: [ContentChunk] = []
    @State private var currentChunkIndex: Int = 0
    @State private var totalChunks: Int = 0
    
    // Available languages for translation
    enum TranslationLanguage: String, CaseIterable, Identifiable {
        case english = "English"
        case spanish = "Spanish"
        case french = "French"
        case german = "German"
        case italian = "Italian"
        case portuguese = "Portuguese"
        case russian = "Russian"
        case chinese = "Chinese (Simplified)"
        case japanese = "Japanese"
        case korean = "Korean"
        case arabic = "Arabic"
        case hindi = "Hindi"
        case punjabi = "Punjabi"
        
        var id: String { self.rawValue }
        
        var code: String {
            switch self {
            case .english: return "en"
            case .spanish: return "es"
            case .french: return "fr"
            case .german: return "de"
            case .italian: return "it"
            case .portuguese: return "pt"
            case .russian: return "ru"
            case .chinese: return "zh"
            case .japanese: return "ja"
            case .korean: return "ko"
            case .arabic: return "ar"
            case .hindi: return "hi"
            case .punjabi: return "pa"
            }
        }
    }
    
    // Content chunk model for progressive translation
    struct ContentChunk: Identifiable, Equatable {
        let id = UUID()
        let text: String
        var translatedText: String = ""
        var isTranslated: Bool = false
        var opacity: Double = 0.0
        
        // Implement Equatable
        static func == (lhs: ContentChunk, rhs: ContentChunk) -> Bool {
            return lhs.id == rhs.id &&
                   lhs.text == rhs.text &&
                   lhs.translatedText == rhs.translatedText &&
                   lhs.isTranslated == rhs.isTranslated &&
                   lhs.opacity == rhs.opacity
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main content
            HStack(alignment: .top, spacing: 0) {
                // Sidebar
                languageSidebarView
                
                // Preview
                translationPreviewView
            }
            
            // Footer
            footerView
        }
        .frame(width: 900, height: 700)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color.white)
        .onAppear {
            // Don't generate translation automatically on appear
            // Just show the language selection UI
        }
        .alert("Translation Error", isPresented: $showTranslationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Components
    
    // Header view
    private var headerView: some View {
        HStack {
            Text("Translate Document")
                .font(.headline)
            
            Spacer()
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // Language sidebar view
    private var languageSidebarView: some View {
        VStack(alignment: .leading, spacing: 8) { // Further reduced spacing
            Text("Target Language")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Make language list scrollable
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(TranslationLanguage.allCases) { language in
                        languageButton(language)
                    }
                }
                .padding(.trailing, 8) // Add padding for scroll bar
            }
            .frame(height: 450) // Further increased height to fill more space
            
            Spacer(minLength: 4) // Minimal spacer
            
            // Add a dedicated translate button
            if !isTranslating {
                ZStack {
                    // Background with hover effect
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .overlay(
                            TranslateButtonHoverView(color: Color.gray.opacity(0.2))
                        )
                    
                    // Button content
                    HStack {
                        Spacer()
                        Text("Translate to \(selectedLanguage.rawValue)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8) // Reduced vertical padding
                }
                .frame(width: 200, height: 36) // Set fixed dimensions for the button
                .contentShape(Rectangle())
                .onTapGesture {
                    generateTranslation()
                }
                .padding(.bottom, 4) // Reduced bottom padding
                .padding(.horizontal, 10) // Add horizontal padding to center the button
            }
        }
        .frame(width: 220)
        .padding(.top, 12)
        .padding(.bottom, 4) // Reduced bottom padding
        .padding(.horizontal, 12)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.97))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .trailing
        )
    }
    
    // Language button
    private func languageButton(_ language: TranslationLanguage) -> some View {
        ZStack {
            // Background with hover effect
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedLanguage == language ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    LanguageButtonHoverView(color: Color.gray.opacity(0.1))
                )
            
            // Button content
            HStack {
                Text(language.rawValue)
                    .font(.system(size: 14))
                
                Spacer()
                
                if selectedLanguage == language {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.blue)
                }
            }
            .padding(.vertical, 4) // Reduced vertical padding
            .padding(.horizontal, 10) // Reduced horizontal padding
        }
        .contentShape(Rectangle()) // Make entire area clickable
        .onTapGesture {
            selectedLanguage = language
            // Don't start translation immediately, just select the language
        }
    }
    
    // Hover effect view
    private struct LanguageButtonHoverView: View {
        let color: Color
        @State private var isHovered = false
        
        var body: some View {
            Rectangle()
                .fill(isHovered ? color : Color.clear)
                .cornerRadius(6)
                .onHover { hovering in
                    self.isHovered = hovering
                }
        }
    }
    
    // Hover effect view for translate button
    private struct TranslateButtonHoverView: View {
        let color: Color
        @State private var isHovered = false
        
        var body: some View {
            Rectangle()
                .fill(isHovered ? color : Color.clear)
                .cornerRadius(8)
                .onHover { hovering in
                    self.isHovered = hovering
                }
        }
    }
    
    // Translation preview view
    private var translationPreviewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with "Preview" title
            Text("Translation Preview")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.2)),
                    alignment: .bottom
                )
            
            // Document preview scroll view
            previewScrollView
        }
        .frame(minWidth: 400)
    }
    
    // Preview scroll view
    private var previewScrollView: some View {
        ScrollView {
            ScrollViewReader { scrollProxy in
                VStack(alignment: .leading, spacing: 24) {
                    // Always show progress during translation at the top
                    if isTranslating {
                        progressIndicator
                            .id("progress")
                            .padding(.bottom, 0)
                        
                        // Add divider after progress area
                        Divider()
                            .padding(.top, 0)
                            .padding(.bottom, 12)
                    }
                    
                    // Document title
                    if !translatedTitle.isEmpty {
                        Text(translatedTitle)
                            .font(.system(size: 28, weight: .bold))
                            .padding(.top, 12)
                            .transition(.opacity)
                            .id("title") // Add ID for scrolling
                    }
                    
                    // Document subtitle
                    if !translatedSubtitle.isEmpty {
                        Text(translatedSubtitle)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.top, -12)
                            .transition(.opacity)
                    }
                    
                    // Content display
                    contentDisplayView(scrollProxy: scrollProxy)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear {
                    // When view appears, scroll to the top to ensure first content is visible
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            scrollProxy.scrollTo("progress", anchor: .top)
                        }
                    }
                }
            }
        }
        // Disable scroll indicators to prevent them from covering content
        .scrollIndicators(.hidden)
    }
    
    // Content display view
    private func contentDisplayView(scrollProxy: ScrollViewProxy) -> some View {
        Group {
            if !contentChunks.isEmpty {
                progressiveContentView(scrollProxy: scrollProxy)
            } else if translatedContent.length > 0 {
                // Fallback to old method if no chunks
                Text(AttributedString(translatedContent))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if isTranslating {
                loadingView
            } else {
                VStack(spacing: 24) {
                    Text("Select a language to translate the document.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("Choose a target language from the sidebar and click on it to begin translation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 40)
            }
        }
    }
    
    // Progressive content view
    private func progressiveContentView(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Display chunks as they're translated
            chunksView
        }
        .onChange(of: contentChunks) { oldChunks, newChunks in
            handleChunksChange(newChunks: newChunks, scrollProxy: scrollProxy)
        }
    }
    
    // Progress indicator
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            // Progress bar and percentage
            ProgressView(value: translationProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(maxWidth: .infinity)
            
            // Show progress percentage with larger, bold text
            Text("\(Int(translationProgress * 100))% Complete")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 2)
            
            // Show translated paragraphs count and word count
            if !contentChunks.isEmpty {
                let translatedChunks = contentChunks.filter { !$0.translatedText.isEmpty }
                let wordCount = translatedChunks.reduce(0) { count, chunk in
                    count + chunk.translatedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                }
                
                Text("Showing \(translatedChunks.count) translated paragraphs (\(wordCount) words)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 0)
                    .id("debug")
            }
        }
    }
    
    // Chunks view
    private var chunksView: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(Array(contentChunks.enumerated()), id: \.element.id) { index, chunk in
                if !chunk.translatedText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        // Special handling for first chunk to ensure it's always visible
                        if index == 0 {
                            Text(chunk.translatedText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("firstChunk")
                        } else {
                            // Regular display for other chunks
                            Text(chunk.translatedText)
                                .opacity(chunk.opacity)
                                .animation(.easeIn(duration: 0.5), value: chunk.opacity)
                                .textSelection(.enabled)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("chunk\(index)")
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    // Loading view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            // Show progress percentage
            Text("\(Int(translationProgress * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Progress bar
            ProgressView(value: translationProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 40)
    }
    
    // Footer view
    private var footerView: some View {
        VStack(spacing: 16) {
            // Divider
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2))
            
            // Buttons
            HStack {
                // Left side notice
                Text("Translations powered by Gemini AI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Cancel button
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(width: 120, height: 40)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Create Variation button
                Button {
                    createTranslationVariation()
                } label: {
                    Text("Create Translation")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 170, height: 40)
                        .background(translatedContent.length > 0 ? Color.blue : Color.gray)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(translatedContent.length == 0)
                .padding(.leading, 10)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Helper Methods
    
    // Handle chunks change
    private func handleChunksChange(newChunks: [ContentChunk], scrollProxy: ScrollViewProxy) {
        // Break up the complex expression into simpler parts
        let hasChunks = !newChunks.isEmpty
        
        // Check if first chunk has been translated
        if hasChunks && newChunks.indices.contains(0) {
            let firstChunkTranslated = newChunks[0].translatedText.isEmpty == false
            
            // When chunks are updated, scroll to the top to ensure first paragraph is visible
            // Only do this once when the first chunk is translated
            if firstChunkTranslated && self.currentChunkIndex <= 1 {
                // Use a slightly longer delay to ensure the UI has updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        // Scroll to the progress indicator only
                        scrollProxy.scrollTo("progress", anchor: .top)
                    }
                }
            }
        }
    }
    
    // Function to generate translation
    private func generateTranslation() {
        // Reset translation status
        isTranslating = true
        translationProgress = 0.0
        contentChunks = []
        currentChunkIndex = 0
        
        // Prepare original content
        let originalTitle = document.title
        let originalSubtitle = document.subtitle
        
        // Access the full NSAttributedString content and clean it
        let originalContentString = document.canvasDocument.content.string
        let cleanedContent = cleanContentForTranslation(originalContentString)
        
        // Split content into chunks for progressive translation
        let chunks = splitContentIntoChunks(cleanedContent)
        contentChunks = chunks.map { ContentChunk(text: $0) }
        totalChunks = contentChunks.count
        
        // Store original content for formatting reference
        let originalContent = NSAttributedString(string: cleanedContent)
        
        // Translate title first
        translateText(originalTitle, targetLanguage: selectedLanguage.code) { result in
            switch result {
            case .success(let translatedTitle):
                self.translatedTitle = translatedTitle
                translationProgress = 0.1
                
                // Then translate subtitle
                translateText(originalSubtitle, targetLanguage: selectedLanguage.code) { result in
                    switch result {
                    case .success(let translatedSubtitle):
                        self.translatedSubtitle = translatedSubtitle
                        translationProgress = 0.2
                        
                        // Start translating content chunks progressively
                        translateNextChunk(originalContent: originalContent)
                        
                    case .failure(let error):
                        handleTranslationError(error)
                    }
                }
                
            case .failure(let error):
                handleTranslationError(error)
            }
        }
    }
    
    // Split content into manageable chunks
    private func splitContentIntoChunks(_ content: String) -> [String] {
        // Print content for debugging
        print("Splitting content of length: \(content.count)")
        
        // If content is small enough, return as a single chunk
        if content.count < 1000 {
            print("Content is small, using as single chunk")
            return [content]
        }
        
        // Split by paragraphs first
        let paragraphs = content.components(separatedBy: "\n\n")
        print("Split into \(paragraphs.count) paragraphs")
        
        // If we have reasonable number of paragraphs, use them as chunks
        if paragraphs.count >= 3 && paragraphs.count <= 20 {
            // Make sure we don't lose any content by checking if paragraphs joined equals original
            let joinedParagraphs = paragraphs.joined(separator: "\n\n")
            if joinedParagraphs.count >= Int(Double(content.count) * 0.95) { // Convert to Int
                print("Using paragraphs as chunks: \(paragraphs.count) chunks")
                // Print first few paragraphs for debugging
                for (i, para) in paragraphs.prefix(3).enumerated() {
                    print("Paragraph \(i): \(para.prefix(50))...")
                }
                return paragraphs
            }
        }
        
        // Otherwise, create chunks of approximately 800-1000 characters
        // that try to respect paragraph boundaries
        var chunks: [String] = []
        var currentChunk = ""
        
        for paragraph in paragraphs {
            // If adding this paragraph would make the chunk too large, start a new chunk
            if currentChunk.count + paragraph.count > 800 && !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk = paragraph
            } else {
                if !currentChunk.isEmpty {
                    currentChunk += "\n\n"
                }
                currentChunk += paragraph
            }
        }
        
        // Add the last chunk if it's not empty
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        print("Created \(chunks.count) chunks with paragraph boundaries")
        
        // Verify we haven't lost content
        let totalChunksLength = chunks.joined(separator: "\n\n").count
        if totalChunksLength < Int(Double(content.count) * 0.95) { // Convert to Int
            // Fallback to simpler chunking if we lost content
            print("Content loss detected, falling back to simple chunking")
            return simpleChunk(content: content)
        }
        
        return chunks
    }
    
    // Simple chunking as a fallback
    private func simpleChunk(content: String) -> [String] {
        let chunkSize = 800
        var chunks: [String] = []
        var start = 0
        
        while start < content.count {
            let end = min(start + chunkSize, content.count)
            let startIndex = content.index(content.startIndex, offsetBy: start)
            let endIndex = content.index(content.startIndex, offsetBy: end)
            let chunk = String(content[startIndex..<endIndex])
            chunks.append(chunk)
            start += chunkSize
        }
        
        return chunks
    }
    
    // Translate chunks progressively
    private func translateNextChunk(originalContent: NSAttributedString) {
        // Check if we've translated all chunks
        if currentChunkIndex >= contentChunks.count {
            // All chunks translated, combine them into final result
            finalizeTranslation(originalContent: originalContent)
            return
        }
        
        // Get the current chunk to translate
        let chunk = contentChunks[currentChunkIndex]
        
        // Update progress
        let baseProgress = 0.2 // Title and subtitle account for 20%
        let chunkProgress = 0.8 / Double(max(1, contentChunks.count)) // Content is 80% of total, avoid division by zero
        translationProgress = baseProgress + (Double(currentChunkIndex) * chunkProgress)
        
        // Translate this chunk
        translateText(chunk.text, targetLanguage: selectedLanguage.code) { result in
            switch result {
            case .success(let translatedText):
                // Update the chunk with translated text
                DispatchQueue.main.async {
                    // Safety check to ensure index is still valid
                    guard self.currentChunkIndex < self.contentChunks.count else {
                        // Index out of range, skip to finalization
                        self.finalizeTranslation(originalContent: originalContent)
                        return
                    }
                    
                    // Process the translated text
                    var processedText = translatedText
                    
                    // Special handling for first chunk to ensure it's visible
                    if self.currentChunkIndex == 0 {
                        // Log the first chunk content for debugging
                        print("FIRST CHUNK ORIGINAL: \(chunk.text.prefix(100))")
                        print("FIRST CHUNK TRANSLATED: \(translatedText.prefix(100))")
                        
                        // Ensure the first chunk is never empty
                        if translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            processedText = "⚠️ [First paragraph was empty - please check the translation] ⚠️"
                        } else {
                            // Force visibility by adding a prefix if needed
                            let trimmed = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed != translatedText {
                                processedText = trimmed
                            }
                            
                            // Add a marker at the beginning to ensure visibility
                            processedText = processedText.replacingOccurrences(of: "\u{200B}", with: "")
                            
                            // Log the processed text
                            print("PROCESSED FIRST CHUNK: \(processedText.prefix(100))")
                        }
                    }
                    
                    // Update the chunk with translated text
                    var updatedChunk = self.contentChunks[self.currentChunkIndex]
                    updatedChunk.translatedText = processedText
                    updatedChunk.isTranslated = true
                    self.contentChunks[self.currentChunkIndex] = updatedChunk
                    
                    // Animate the chunk fading in - with safety check
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Double-check index is still valid before animating
                        guard self.currentChunkIndex < self.contentChunks.count else { return }
                        
                        // Safe to access the array now
                        let chunkIndex = self.currentChunkIndex
                        if chunkIndex < self.contentChunks.count {
                            var fadeInChunk = self.contentChunks[chunkIndex]
                            fadeInChunk.opacity = 1.0
                            self.contentChunks[chunkIndex] = fadeInChunk
                            
                            // Print debug info
                            print("Translated chunk \(chunkIndex): \(translatedText.prefix(30))...")
                        }
                    }
                    
                    // Move to next chunk
                    self.currentChunkIndex += 1
                    
                    // Update progress - safely
                    let safeChunkCount = max(1, Double(self.contentChunks.count))
                    self.translationProgress = baseProgress + (Double(self.currentChunkIndex) / safeChunkCount * 0.8)
                    
                    // Translate next chunk
                    self.translateNextChunk(originalContent: originalContent)
                }
                
            case .failure(let error):
                // If a chunk fails, we'll still try to continue with the next one
                print("Error translating chunk \(self.currentChunkIndex): \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    // Safety check to ensure index is still valid
                    guard self.currentChunkIndex < self.contentChunks.count else {
                        // Index out of range, skip to finalization
                        self.finalizeTranslation(originalContent: originalContent)
                        return
                    }
                    
                    // Mark this chunk as failed but move on
                    var updatedChunk = self.contentChunks[self.currentChunkIndex]
                    updatedChunk.translatedText = "⚠️ [Translation error for this section]"
                    updatedChunk.isTranslated = true
                    updatedChunk.opacity = 1.0
                    self.contentChunks[self.currentChunkIndex] = updatedChunk
                    
                    // Move to next chunk
                    self.currentChunkIndex += 1
                    
                    // Update progress - safely
                    let safeChunkCount = max(1, Double(self.contentChunks.count))
                    self.translationProgress = baseProgress + (Double(self.currentChunkIndex) / safeChunkCount * 0.8)
                    
                    // Continue with next chunk
                    self.translateNextChunk(originalContent: originalContent)
                }
            }
        }
    }
    
    // Finalize translation by combining all chunks and applying formatting
    private func finalizeTranslation(originalContent: NSAttributedString) {
        // Make sure we have all chunks translated
        let validChunks = contentChunks.filter { !$0.translatedText.isEmpty }
        
        // Combine all translated chunks with proper spacing
        let combinedText = validChunks.map { $0.translatedText }.joined(separator: "\n\n")
        
        // Create attributed string
        let resultString = NSMutableAttributedString(string: combinedText)
        
        // Apply formatting
        applyFormattingToTranslatedText(original: originalContent, translated: resultString)
        
        // Set as final translated content
        translatedContent = resultString
        
        // Mark translation as complete
        translationProgress = 1.0
        isTranslating = false
    }
    
    // Helper to clean content before translation
    private func cleanContentForTranslation(_ content: String) -> String {
        // Remove UUID-style image references like "86D4888D-94ED-44CF-BC0A-6B53155F2397.png"
        let uuidPattern = "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\\.png"
        let cleanedContent = content.replacingOccurrences(of: uuidPattern, with: "", options: .regularExpression)
        
        // Remove any other image filenames or patterns that might be causing issues
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff"]
        var result = cleanedContent
        
        for ext in imageExtensions {
            // Remove filename.ext patterns
            let pattern = "\\S+\\.\(ext)"
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Clean up multiple line breaks that might result from removing content
        return result.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
    }
    
    // New function to translate formatted content (kept for backward compatibility)
    private func translateFormattedContent(_ content: NSAttributedString, targetLanguage: String, 
                                         completion: @escaping (Result<NSAttributedString, Error>) -> Void) {
        // Get the full string to translate
        let plainText = content.string
        
        // Skip if text is empty
        if plainText.isEmpty {
            completion(.success(NSAttributedString()))
            return
        }
        
        // Check token availability before making the call
        let estimatedTokens = plainText.count / 4 + 800 // Rough estimate
        if !TokenUsageService.shared.canUseTokens(estimatedTokens) {
            completion(.failure(NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Token limit reached. Please purchase more tokens to continue translation."])))
            return
        }

        // Use AIService for translation
        let apiService = AIService.shared
        
        let prompt = """
        Translate the following text from English to \(selectedLanguage.rawValue).
        VERY IMPORTANT: Preserve EXACTLY the same paragraph structure, line breaks, and formatting as the original.
        Each paragraph, heading, or bullet point should maintain its position and relative structure.
        Return ONLY the translated text with exact same paragraph breaks, nothing else.
        
        Text to translate:
        "\(plainText)"
        """
        
        apiService.generateText(prompt: prompt) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let translatedText):
                    // Clean up the response - remove any quotes
                    let cleaned = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\"", with: "")
                    
                    // Create a new attributed string
                    let resultString = NSMutableAttributedString(string: cleaned)
                    
                    // Apply formatting to the translated text
                    self.applyFormattingToTranslatedText(original: content, translated: resultString)
                    
                    completion(.success(resultString))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Helper method to apply formatting from original text to translated text
    private func applyFormattingToTranslatedText(original: NSAttributedString, translated: NSMutableAttributedString) {
        // First, apply the default attributes to the entire string (basic formatting)
        if original.length > 0 {
            // Get default attributes from the start of the original
            let defaultAttrs = original.attributes(at: 0, effectiveRange: nil)
            translated.addAttributes(defaultAttrs, range: NSRange(location: 0, length: translated.length))
        }
        
        // For better formatting, we'll try to map paragraphs between original and translated
        // Get paragraphs from both strings
        let originalParagraphs = original.string.components(separatedBy: .newlines)
        let translatedParagraphs = translated.string.components(separatedBy: .newlines)
        
        // Track the current position in both strings
        var originalOffset = 0
        var translatedOffset = 0
        
        // Process each paragraph (up to the minimum number of paragraphs in both)
        let minParagraphs = min(originalParagraphs.count, translatedParagraphs.count)
        
        for i in 0..<minParagraphs {
            let originalParagraph = originalParagraphs[i]
            let translatedParagraph = translatedParagraphs[i]
            
            // Skip empty paragraphs
            if originalParagraph.isEmpty {
                originalOffset += 1 // +1 for newline
                translatedOffset += translatedParagraph.count + 1
                continue
            }
            
            // Get formatting from the middle of the original paragraph (most stable point)
            let samplePoint = min(originalParagraph.count / 2, originalParagraph.count - 1)
            if samplePoint < originalParagraph.count && originalOffset + samplePoint < original.length {
                // Get attributes at this point
                let paragraphAttrs = original.attributes(at: originalOffset + samplePoint, effectiveRange: nil)
                
                // Apply to the translated paragraph
                let translatedRange = NSRange(location: translatedOffset, length: translatedParagraph.count)
                translated.addAttributes(paragraphAttrs, range: translatedRange)
            }
            
            // Move offsets to next paragraph
            originalOffset += originalParagraph.count + 1 // +1 for newline
            translatedOffset += translatedParagraph.count + 1
        }
        
        // For headings and special formatting, look for patterns based on font size/weight
        self.detectAndApplySpecialFormatting(original: original, translated: translated)
    }
    
    // Helper method to detect and apply special formatting (headings, bold text, etc.)
    private func detectAndApplySpecialFormatting(original: NSAttributedString, translated: NSMutableAttributedString) {
        // Create an array to store ranges with special formatting
        var specialFormats: [(range: NSRange, attributes: [NSAttributedString.Key: Any])] = []
        
        // Scan the original text for special formatting
        let originalString = original.string
        var position = 0
        
        while position < originalString.count {
            var effectiveRange = NSRange()
            let attributes = original.attributes(at: position, effectiveRange: &effectiveRange)
            
            // Check if this has special formatting (bold, italics, color, etc.)
            let hasSpecialFormatting = isProbablyFormattedRange(attributes)
            if hasSpecialFormatting {
                specialFormats.append((range: effectiveRange, attributes: attributes))
            }
            
            // Move position beyond this range
            position = effectiveRange.upperBound
        }
        
        // Now attempt to apply these special formats to appropriate parts of the translated text
        // For simplicity, we'll just apply to equivalent positions proportionally
        let originalLength = originalString.count
        let translatedLength = translated.string.count
        
        for format in specialFormats {
            // Calculate the proportional position in the translated text
            let startRatio = Double(format.range.location) / Double(originalLength)
            let endRatio = Double(format.range.upperBound) / Double(originalLength)
            
            let translatedStart = Int(startRatio * Double(translatedLength))
            let translatedEnd = Int(endRatio * Double(translatedLength))
            
            // Ensure we don't exceed bounds
            let safeStart = max(0, min(translatedStart, translatedLength - 1))
            let safeEnd = max(safeStart, min(translatedEnd, translatedLength))
            
            // Apply the special formatting
            if safeEnd > safeStart {
                translated.addAttributes(format.attributes, range: NSRange(location: safeStart, length: safeEnd - safeStart))
            }
        }
    }
    
    #if os(macOS)
    // Helper to determine if a range has special formatting
    private func isProbablyFormattedRange(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        // Check for font attributes
        if let font = attributes[.font] as? NSFont {
            if font.pointSize > 16 || font.fontDescriptor.symbolicTraits.contains(.bold) || font.fontDescriptor.symbolicTraits.contains(.italic) {
                return true
            }
        }
        
        // Check for foreground color
        if let color = attributes[.foregroundColor] as? NSColor, !isDefaultTextColor(color) {
            return true
        }
        
        // Check for background color
        if let bgColor = attributes[.backgroundColor] as? NSColor, !isDefaultBackgroundColor(bgColor) {
            return true
        }
        
        // Check for other formatting attributes
        if attributes[.underlineStyle] != nil || attributes[.strikethroughStyle] != nil {
            return true
        }
        
        return false
    }
    
    // Helper to determine if a color is default text color
    private func isDefaultTextColor(_ color: NSColor) -> Bool {
        let defaultDark = NSColor.white
        let defaultLight = NSColor.black
        
        // Convert to common color space for comparison
        let colorInRGB = color.usingColorSpace(.sRGB) ?? color
        let darkInRGB = defaultDark.usingColorSpace(.sRGB) ?? defaultDark
        let lightInRGB = defaultLight.usingColorSpace(.sRGB) ?? defaultLight
        
        // Check if it's similar to either default color
        return isColorSimilar(colorInRGB, to: darkInRGB) || isColorSimilar(colorInRGB, to: lightInRGB)
    }
    
    // Helper to determine if a color is default background color
    private func isDefaultBackgroundColor(_ color: NSColor) -> Bool {
        // Default background is typically clear or white/near-white
        let defaultBgLight = NSColor.white
        let defaultBgDark = NSColor(calibratedWhite: 0.1, alpha: 1.0)
        
        // Convert to common color space for comparison
        let colorInRGB = color.usingColorSpace(.sRGB) ?? color
        let lightInRGB = defaultBgLight.usingColorSpace(.sRGB) ?? defaultBgLight
        let darkInRGB = defaultBgDark.usingColorSpace(.sRGB) ?? defaultBgDark
        
        return isColorSimilar(colorInRGB, to: lightInRGB) || isColorSimilar(colorInRGB, to: darkInRGB)
    }
    
    // Helper to compare colors with tolerance
    private func isColorSimilar(_ color1: NSColor, to color2: NSColor, tolerance: CGFloat = 0.1) -> Bool {
        let redDiff = abs(color1.redComponent - color2.redComponent)
        let greenDiff = abs(color1.greenComponent - color2.greenComponent)
        let blueDiff = abs(color1.blueComponent - color2.blueComponent)
        
        return redDiff < tolerance && greenDiff < tolerance && blueDiff < tolerance
    }
    #elseif os(iOS)
    // iOS simplified formatting check - using UIFont and UIColor
    private func isProbablyFormattedRange(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        // Check for font attributes
        if let font = attributes[.font] as? UIFont {
            if font.pointSize > 16 || font.fontDescriptor.symbolicTraits.contains(.traitBold) || font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                return true
            }
        }
        
        // Check for foreground color
        if let color = attributes[.foregroundColor] as? UIColor, !isDefaultTextColor(color) {
            return true
        }
        
        // Check for background color
        if let bgColor = attributes[.backgroundColor] as? UIColor, !isDefaultBackgroundColor(bgColor) {
            return true
        }
        
        // Check for other formatting attributes
        if attributes[.underlineStyle] != nil || attributes[.strikethroughStyle] != nil {
            return true
        }
        
        return false
    }
    
    // Helper to determine if a color is default text color
    private func isDefaultTextColor(_ color: UIColor) -> Bool {
        let defaultDark = UIColor.white
        let defaultLight = UIColor.black
        
        // Basic comparison - iOS version simplified
        return color == defaultDark || color == defaultLight || color == UIColor.label
    }
    
    // Helper to determine if a color is default background color
    private func isDefaultBackgroundColor(_ color: UIColor) -> Bool {
        // Default background is typically clear or white/near-white
        let defaultBgLight = UIColor.white
        let defaultBgDark = UIColor.systemBackground
        
        return color == defaultBgLight || color == defaultBgDark || color == UIColor.systemBackground
    }
    
    // Simplified color comparison for iOS
    private func isColorSimilar(_ color1: UIColor, to color2: UIColor, tolerance: CGFloat = 0.1) -> Bool {
        // Simplified comparison for iOS
        return color1 == color2
    }
    #endif
    
    // Function to translate text
    private func translateText(_ text: String, targetLanguage: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Skip if text is empty
        if text.isEmpty {
            completion(.success(""))
            return
        }
        
        // Check token availability before making the call
        let estimatedTokens = text.count / 4 + 800 // Rough estimate
        if !TokenUsageService.shared.canUseTokens(estimatedTokens) {
            completion(.failure(NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Token limit reached. Please purchase more tokens to continue translation."])))
            return
        }
        
        // Print the text being translated for debugging
        print("Translating text: \(text.prefix(50))...")
        
        // Use AIService for translation
        let apiService = AIService.shared
        
        let prompt = """
        Translate the following text from English to \(selectedLanguage.rawValue).
        Maintain the exact meaning and structure, only making minimal adjustments required by language structure differences.
        Return ONLY the translated text, nothing else.
        
        Text to translate:
        "\(text)"
        """
        
        apiService.generateText(prompt: prompt) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let translatedText):
                    // Clean up the response - remove any quotes
                    let cleaned = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\"", with: "")
                    print("Translation result: \(cleaned.prefix(50))...")
                    completion(.success(cleaned))
                case .failure(let error):
                    print("Translation error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Function to handle translation errors
    private func handleTranslationError(_ error: Error) {
        isTranslating = false
        errorMessage = "Translation failed: \(error.localizedDescription)"
        showTranslationError = true
    }
    
    // Function to create a translation variation
    private func createTranslationVariation() {
        print("Creating translation variation...")
        print("Translated title: \(translatedTitle)")
        print("Translated content length: \(translatedContent.length)")
        
        // Create a variation of the current document - Use the original method that's known to work
        var newVariation = document.createVariation()
        
        // Update basic properties
        newVariation.title = translatedTitle
        newVariation.subtitle = translatedSubtitle
        
        // STEP 1: Set the basic document content directly to the translated content
        newVariation.canvasDocument.content = translatedContent
        
        // STEP 2: Create a main text block element for the document
        let textElement = DocumentElement(type: .textBlock, content: translatedContent.string)
        var mutableTextElement = textElement
        mutableTextElement.attributedContent = translatedContent
        
        // STEP 3: Create new elements array with text and necessary elements
        var newElements: [DocumentElement] = []
        
        // Add title element if title is available
        if !translatedTitle.isEmpty {
            let titleElement = DocumentElement(type: .title, content: translatedTitle)
            newElements.append(titleElement)
        }
        
        // Add subtitle element if subtitle is available
        if !translatedSubtitle.isEmpty {
            let subtitleElement = DocumentElement(type: .subheader, content: translatedSubtitle)
            newElements.append(subtitleElement)
        }
        
        // Add the main text element
        newElements.append(mutableTextElement)
        
        // STEP 4: Copy any image elements from the original document
        for element in document.elements {
            if element.type == .image && !element.content.isEmpty && element.type != .headerImage {
                // Copy the image element
                newElements.append(element)
            }
        }
        
        // STEP 5: Replace the elements array
        newVariation.elements = newElements
        
        // STEP 6: Force update document to reflect changes
        newVariation.updateCanvasDocument()
        
        // STEP 7: Create a descriptive name for the variation
        let variationName = "Translation (\(selectedLanguage.rawValue))"
        
        // STEP 8: Add the variation to the document - use the API method that's known to work
        document.addVariation(newVariation, name: variationName)
        
        // STEP 9: Save the new variation
        newVariation.save()
        
        print("Created variation with ID: \(newVariation.id)")
        
        // STEP 10: Switch to the newly created translation document
        document = newVariation
        
        // Post multiple notifications to ensure UI updates
        NotificationCenter.default.post(name: NSNotification.Name("DocumentDidLoad"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("VariationsDidUpdate"), object: nil)
        
        // Close the sheet
        isPresented = false
    }
}

// Preview for development
struct TranslationPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        TranslationPreviewView(
            document: .constant(Letterspace_CanvasDocument(title: "Sample Document", subtitle: "Sample Subtitle")), 
            isPresented: .constant(true)
        )
    }
}

// Helper view to display header image in the preview
struct HeaderImagePreview: View {
    let imagePath: String
    #if os(macOS)
    @State private var image: NSImage?
    #elseif os(iOS)
    @State private var image: UIImage?
    #endif
    
    var body: some View {
        Group {
            if let image = image {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #elseif os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #endif
            } else {
                // Placeholder while loading
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // Try to load from app document directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
            let imagesDirectory = appDirectory.appendingPathComponent("Images")
            let imagePath = imagesDirectory.appendingPathComponent(imagePath)
            
            #if os(macOS)
            if let image = NSImage(contentsOf: imagePath) {
                DispatchQueue.main.async {
                    self.image = image
                }
                return
            }
            #elseif os(iOS)
            if let image = UIImage(contentsOfFile: imagePath.path) {
                DispatchQueue.main.async {
                    self.image = image
                }
                return
            }
            #endif
        }
        
        // Fallback to loading from bundle if file URL didn't work
        DispatchQueue.main.async {
            #if os(macOS)
            self.image = NSImage(named: imagePath) ?? NSImage(named: "placeholder_image")
            #elseif os(iOS)
            self.image = UIImage(named: imagePath) ?? UIImage(named: "placeholder_image")
            #endif
        }
    }
} 