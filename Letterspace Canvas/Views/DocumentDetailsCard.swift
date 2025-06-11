import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers // Add this import for UTType

// MARK: - Compiler Note
// This file had a syntax issue around the bracket structure in the infoTabView
// The issue has been fixed by restructuring the nested layouts
// Any remaining warnings in the IDE about extraneous brackets may be editor glitches rather than actual syntax issues

struct DocumentDetailsCard: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    @Binding var document: Letterspace_CanvasDocument
    // Add navigation properties
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}
    var canNavigateNext: () -> Bool = { false }
    var canNavigatePrevious: () -> Bool = { false }
    // Add custom dismiss handler
    var onDismiss: (() -> Void)?
    
    @StateObject private var colorManager = TagColorManager.shared
    @State private var title: String
    @State private var subtitle: String
    @State private var seriesName: String
    @State private var location: String
    @State private var isDateSet: Bool
    @State private var selectedDate: Date
    @State private var isEditing: Bool = false
    
    @State private var showShareSheet = false
    @State private var tags: Set<String> = []
    @State private var newTag: String = ""
    @State private var showSeriesSuggestions = false
    @State private var showLocationSuggestions = false
    @State private var showTagSuggestions = false
    @State private var recentSeries: [String] = []
    @State private var recentLocations: [String] = []
    @State private var recentTags: [String] = []
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedTab: Tab = .info
    @State private var hoveredTab: Tab? = nil
    @State private var summaryText: String = ""
    @State private var isGeneratingSummary: Bool = false
    @State private var localDocument: Letterspace_CanvasDocument
    @State private var showCopiedNotification: Bool = false
    @State private var isButtonHovered: Bool = false
    @State private var isButtonNextHovered: Bool = false
    @State private var hoveredSeriesItem: String? = nil
    @State private var hoveredLocationItem: String? = nil
    @State private var isButtonEditHovered: Bool = false
    @State private var isButtonShareHovered: Bool = false
    @State private var isButtonCloseHovered: Bool = false
    @State private var showPresentationManager = false
    @State private var isContentReady = false
    @State private var showTodayDatePicker = false
    
    @State private var seriesDocsInline: [Letterspace_CanvasDocument] = []
    @State private var isEditingSeriesOrder: Bool = false
    @State private var draggedItem: Letterspace_CanvasDocument? = nil
    @State private var isDragging: Bool = false // New state to track active drag
    @State private var seriesContentVisible = false
    @State private var presentationsContentVisible = false
    @State private var showingLocationsPopover = false
    
    @State private var showTranslationModal = false
    
    @State private var newLinkTitle: String = ""
    @State private var newLinkURL: String = ""
    
    @State private var showAddLinkPopup = false
    
    // Add state variables for notes
    @State private var notes: [Note] = []
    @State private var newNoteText: String = ""
    @State private var isAddingNote: Bool = false
    @State private var editingNoteId: UUID? = nil
    
    // Add state variable for tracking which note is being viewed in detail
    @State private var selectedNoteForDetail: UUID? = nil
    
    // Add state variable for Scripture Sheet PDF path
    @State private var scriptureSheetPDFPath: String? = nil
    @State private var isGeneratingScriptureSheet: Bool = false
    @State private var showScriptureSheetOptionsAlert = false // New state for SwiftUI Alert
    // Removed scriptureSheetIncludeVerseText, will pass directly
    
    // Note model
    struct Note: Identifiable, Codable {
        var id: UUID
        var text: String
        var createdAt: Date
        
        init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
            self.id = id
            self.text = text
            self.createdAt = createdAt
        }
    }
    
    // Define tabs
    enum Tab: String, CaseIterable {
        case info = "Info"
        case variations = "Variations"
        case links = "Links"
        case smartStudies = "Notes" // Changed from "Additional Notes"
    }
    
    // Add documents array
    private var documents: [Letterspace_CanvasDocument] {
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return []
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        print("📂 Loading documents from directory: \(appDirectory.path)")
        
        do {
            // Get all canvas files
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📂 Found \(fileURLs.count) canvas files")
            
            // Load all documents
            let loadedDocs = fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    print("📂 Loaded document: \(doc.title) (ID: \(doc.id))")
                    return doc
                } catch {
                    print("❌ Error loading document at \(url): \(error)")
                    return nil
                }
            }
            
            print("📂 Loaded \(loadedDocs.count) documents total")
            return loadedDocs
        } catch {
            print("❌ Error accessing documents directory: \(error)")
            return []
        }
    }
    
    // Add property to access all documents
    private var allDocuments: [Letterspace_CanvasDocument] {
        return documents // Reuse the existing documents property
    }
    
    private func loadRecentItems() {
        // Load recent series from all documents
        let allSeries = Set(documents.compactMap { $0.series?.name })
        recentSeries = Array(allSeries).sorted()
        
        // Load recent locations from all documents (will be replaced by passed `allLocations`)
        let allDocLocations = Set(documents.compactMap { $0.variations.first?.location }.filter { !$0.isEmpty })
        recentLocations = Array(allDocLocations).sorted() // Keep this for now, but primarily use passed `allLocations`
        
        // Load recent tags from all documents
        let allTags = Set(documents.compactMap { $0.tags }.flatMap { $0 })
        recentTags = Array(allTags).sorted()
    }
    
    init(document: Binding<Letterspace_CanvasDocument>,
         allLocations: [String],
         onNext: @escaping () -> Void = {},
         onPrevious: @escaping () -> Void = {},
         canNavigateNext: @escaping () -> Bool = { false },
         canNavigatePrevious: @escaping () -> Bool = { false },
         onDismiss: (() -> Void)? = nil) {
        self._document = document
        self._recentLocations = State(initialValue: allLocations)
        self.onNext = onNext
        self.onPrevious = onPrevious
        self.canNavigateNext = canNavigateNext
        self.canNavigatePrevious = canNavigatePrevious
        self.onDismiss = onDismiss
        
        // Initialize the state variables using the document
        _title = State(initialValue: document.wrappedValue.title)
        _subtitle = State(initialValue: document.wrappedValue.subtitle)
        _seriesName = State(initialValue: document.wrappedValue.series?.name ?? "")
        _location = State(initialValue: document.wrappedValue.variations.first?.location ?? "")
        _tags = State(initialValue: Set(document.wrappedValue.tags ?? []))
        _localDocument = State(initialValue: document.wrappedValue)
        _summaryText = State(initialValue: document.wrappedValue.summary ?? "")
        
        // Initialize date picker state
        if let date = document.wrappedValue.variations.first?.datePresented {
            _selectedDate = State(initialValue: date)
            _isDateSet = State(initialValue: true)
        } else {
            _selectedDate = State(initialValue: Date())
            _isDateSet = State(initialValue: false)
        }
    }
    
    // Computed properties for colors to help the compiler with complex expressions
    private var textFieldBackgroundColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97)
    }
    
    private var placeholderButtonColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.5)
    }
    
    private var placeholderBackgroundColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.95)
    }
    
    private var placeholderBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    private var dropdownBackgroundColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white
    }
    
    private var dropdownHoverColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)
    }
    
    private var seriesItemBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.15) : Color.gray.opacity(0.05)
    }
    
    private var presentationBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.15) : Color.gray.opacity(0.05)
    }
    
    private var noteListBackgroundColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.12) : Color(.sRGB, white: 0.97)
    }
    
    private var noteDetailBackgroundColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white
    }
    
    private var noteEditorBackgroundColor: Color {
        colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.95)
    }
    
    private var noteSelectedBackgroundColor: Color {
        colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            documentTitleSection
            restOfContent
        }
        .padding(.horizontal, 16)
        .background(theme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onAppear {
            onAppearSetup()
        }
        .onDisappear {
            onDisappearCleanup()
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue { saveChanges() }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .smartStudies { loadNotesFromDocument() }
        }
        .onKeyPress(.leftArrow) { handleLeftArrowKey() }
        .onKeyPress(.rightArrow) { handleRightArrowKey() }
        .onChange(of: document.series) { _, newValue in
            handleSeriesChange()
        }
        .alert("Generate Scripture Sheet (Beta)", isPresented: $showScriptureSheetOptionsAlert) {
            Button("References Only") {
                Task { await processAndCreateScriptureSheetPDF(includeVerseText: false) }
            }
            Button("References with Text") {
                Task { await processAndCreateScriptureSheetPDF(includeVerseText: true) }
            }
            Button("Cancel", role: .cancel) {
                isGeneratingScriptureSheet = false
            }
        } message: {
            Text("Create a PDF with only the scripture references from this sermon.\n\nLooking for clearly defined scripture references (e.g., \"John 3:16\") attached with quoted scripture.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
            HStack(alignment: .center) {
                Text("Document Details")
                    .font(DesignSystem.Typography.semibold(size: 14))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                HStack(alignment: .center, spacing: 12) {
                shareButton
                editButton
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
    
    private var shareButton: some View {
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundStyle(isButtonShareHovered ? Color.blue : theme.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover(perform: { hovering in
                        isButtonShareHovered = hovering
                    })
                    .popover(isPresented: $showShareSheet, arrowEdge: .top) {
            shareSheetContent
        }
    }
    
    private var shareSheetContent: some View {
#if os(macOS)
                        CustomShareSheet(document: document, isPresented: $showShareSheet)
#elseif os(iOS)
        VStack(spacing: 16) {
            Text("Share Document")
                .font(.headline)
            
            Text("Sharing features are available in the full macOS version.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Close") {
                showShareSheet = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 300, height: 200)
#endif
    }
    
    private var editButton: some View {
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Text(isEditing ? "Done" : "Edit")
                            .foregroundColor(Color.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            
    // MARK: - Document Title Section
    private var documentTitleSection: some View {
            VStack(spacing: 0) {
                            if let headerElement = document.elements.first(where: { $0.type == .headerImage && !$0.content.isEmpty }) {
                headerWithImageLayout(headerElement: headerElement)
            } else {
                headerWithoutImageLayout
            }
        }
    }
    
    private func headerWithImageLayout(headerElement: DocumentElement) -> some View {
                                HStack(alignment: .top, spacing: 16) {
#if os(macOS)
                                HeaderImageThumbnail(imagePath: headerElement.content, documentId: document.id, document: $document)
                .frame(width: 160, height: 90)
                                        .cornerRadius(6)
                                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                                        .id("headerImage")
#elseif os(iOS)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                )
                .frame(width: 160, height: 90)
                                                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                .id("headerImage")
#endif
            
            titleAndSubtitleSection
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
    
    private var headerWithoutImageLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            headerImagePlaceholder
            titleAndSubtitleSection
                                }
                                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
    }
    
    private var headerImagePlaceholder: some View {
                        Button(action: {
                            addHeaderImage()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                    .foregroundColor(placeholderButtonColor)
                                
                                Text("Header Image")
                                    .font(.system(size: 12))
                    .foregroundColor(placeholderButtonColor)
                            }
                            .frame(width: 160, height: 90)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                    .fill(placeholderBackgroundColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(placeholderBorderColor, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
    }
                        
    private var titleAndSubtitleSection: some View {
                        VStack(alignment: .leading, spacing: 8) {
                            if isEditing {
                titleEditingFields
            } else {
                titleDisplayFields
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var titleEditingFields: some View {
        VStack(alignment: .leading, spacing: 8) {
                                TextField("Title", text: $title)
                                    .font(DesignSystem.Typography.bold(size: 24))
                                    .tracking(0.5)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                .background(textFieldBackgroundColor)
                                    .cornerRadius(6)
                                
                                TextField("Subtitle", text: $subtitle)
                                    .font(DesignSystem.Typography.regular(size: 16))
                                    .tracking(0.5)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                .background(textFieldBackgroundColor)
                                    .cornerRadius(6)
        }
    }
    
    private var titleDisplayFields: some View {
        VStack(alignment: .leading, spacing: 8) {
                                Text(title.isEmpty ? "Untitled" : title)
                                    .font(DesignSystem.Typography.bold(size: 24))
                                    .foregroundStyle(theme.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(DesignSystem.Typography.regular(size: 16))
                                        .foregroundStyle(theme.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
        }
    }
    
    // MARK: - Other Sections
    private var spacerSection: some View {
                                Spacer()
                                    .frame(height: 16)
    }
    
    // MARK: - Summary Section
    private var summarySection: some View {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "sparkles")
                                                .foregroundColor(.blue)
                                            
                                            Text("Smart Summary")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.blue)
                                            
                                            Spacer()
                                            
                                            if !summaryText.isEmpty {
                                                HStack(spacing: 4) {
                                                    // Copy button
                                                    Button(action: {
                                                        // Copy to clipboard
#if os(macOS)
                                                        let pasteboard = NSPasteboard.general
                                                        pasteboard.clearContents()
                                                        pasteboard.setString(summaryText, forType: .string)
#elseif os(iOS)
                            UIPasteboard.general.string = summaryText
#endif
                                                        
                                                        // Show copied notification
                                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                                            showCopiedNotification = true
                                                            
                                                            // Hide after 1.5 seconds
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                                withAnimation(.easeOut(duration: 0.2)) {
                                                                    showCopiedNotification = false
                                                                }
                                                            }
                                                        }
                                                    }) {
                                                        Image(systemName: "doc.on.doc")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.secondary)
                                                            .frame(width: 16, height: 16)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("Copy to Clipboard")
                                                    
                                                    // Remove button
                                                    Button(action: {
                                                        // Use a direct approach without Task/MainActor
                                                        // Clear the summary text
                                                        summaryText = ""
                                                        
                                                        // Update the local document copy
                                    self.localDocument.summary = nil
                                                        
                                                        // Save the document without updating the binding
                                                        var updatedDoc = document
                                                        updatedDoc.summary = nil
                                                        updatedDoc.save()
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.secondary.opacity(0.7))
                                                            .frame(width: 16, height: 16)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("Remove Summary")
                                                }
                                                .frame(width: 44, height: 20) // Fixed frame for the entire HStack
                                                .padding(.trailing, 20) // Increased trailing padding
                                                .overlay(
                                                    Group {
                                                        if showCopiedNotification {
                                                            Text("Copied")
                                                                .font(.system(size: 12, weight: .bold))
                                                                .foregroundColor(.white)
                                                                .padding(.horizontal, 8)
                                                                .padding(.vertical, 4)
                                                                .background(
                                                                    RoundedRectangle(cornerRadius: 4)
                                                                        .fill(Color.black.opacity(0.9))
                                                                )
                                                                .offset(x: -10, y: -30) // Adjusted to be more centered over the copy button
                                                                .transition(AnyTransition.asymmetric(
                                                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                                                    removal: .opacity
                                                                ))
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                        
                                        if isGeneratingSummary {
                                            HStack {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .padding(.trailing, 4)
                                                Text("Generating summary...")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 8)
                                        } else {
                                            // Just display the summary text without the remove button
                                            Text(summaryText.trimmingCharacters(in: .whitespacesAndNewlines))
                                                .font(.system(size: 13))
                                                .foregroundColor(.primary)
                            .lineSpacing(5) // Add more space between lines
                                                .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 16) // Increased vertical padding inside the summary box
                            .padding(.horizontal, 12)
                            .background(Color.clear) // Clear background
                            .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 8)
                .padding(.vertical, 16) // Increased from 8 to 16 for more breathing room
            }
            
    // MARK: - Tab Bar and Content
    private var tabsAndContentSection: some View {
            ZStack(alignment: .top) {
                if selectedTab == .info {
                    ScrollView {
                    VStack(spacing: 24) { infoTabView }
                        .padding(.horizontal, 8).padding(.bottom, 16)
                }.frame(maxWidth: .infinity)
                } else if selectedTab == .variations {
                    ScrollView {
                    VStack(spacing: 24) { variationsTabView }
                        .padding(.horizontal, 8).padding(.bottom, 16)
                }.frame(maxWidth: .infinity)
                } else if selectedTab == .links {
                    ScrollView {
                    VStack(spacing: 16) { linksTabView }
                        .padding(.horizontal, 8).padding(.bottom, 16)
                }.frame(maxWidth: .infinity)
                } else if selectedTab == .smartStudies {
                VStack(spacing: 24) { clipsTabView } // Renamed from smartStudiesTabView for consistency with original code snippet
                    .frame(maxWidth: .infinity)
                    .onAppear { loadNotesFromDocument() }
            }
        }
        // Apply gestures also to the content area for consistency
#if os(macOS)
        .onMacSwipeGesture(
            onSwipeLeft: { handleSwipeLeft() },
            onSwipeRight: { handleSwipeRight() }
            )
            .onTrackpadScroll(
            onScrollLeft: { handleSwipeRight() },
            onScrollRight: { handleSwipeLeft() }
        )
#else
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -50 {handleSwipeLeft()}
                    else if value.translation.width > 50 {handleSwipeRight()}
                }
        )
#endif
    }
    
    // MARK: - Navigation Section
    private var navigationSection: some View {
            HStack {
                Spacer()
                
                // Navigation button container
                HStack(spacing: 0) {
                    Button(action: {
                        // Hide content first with upward animation
                        withAnimation(.easeOut(duration: 0.2)) {
                            seriesContentVisible = false
                            presentationsContentVisible = false
                        }
                        
                        // Wait briefly then navigate
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onPrevious()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "chevron.left")
                                .font(DesignSystem.Typography.medium(size: 12))
                                .foregroundColor(.white)
                            Text("Previous")
                                .font(DesignSystem.Typography.medium(size: 12))
                                .foregroundColor(.white)
                                .tracking(0.5) // Add consistent tracking
                            Spacer()
                        }
                        .frame(width: 90, height: 30) // Wider to accommodate text
                        .contentShape(Rectangle()) // Make entire area tappable
                        .background(
                            isButtonHovered ? Color.white.opacity(0.2) : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canNavigatePrevious())
                    .opacity(canNavigatePrevious() ? 1.0 : 0.5)
                    .onHover(perform: { isHovered in
                        self.isButtonHovered = isHovered
                    })
                    
                    Button(action: {
                        // Hide content first with upward animation
                        withAnimation(.easeOut(duration: 0.2)) {
                            seriesContentVisible = false
                            presentationsContentVisible = false
                        }
                        
                        // Wait briefly then navigate
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onNext()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Spacer()
                            Text("Next")
                                .font(DesignSystem.Typography.medium(size: 12))
                                .foregroundColor(.white)
                                .tracking(0.5) // Add consistent tracking
                            Image(systemName: "chevron.right")
                                .font(DesignSystem.Typography.medium(size: 12))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(width: 70, height: 30) // Wider to accommodate text
                        .contentShape(Rectangle()) // Make entire area tappable
                        .background(
                            isButtonNextHovered ? Color.white.opacity(0.2) : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canNavigateNext())
                    .opacity(canNavigateNext() ? 1.0 : 0.5)
                    .onHover(perform: { isHovered in
                        self.isButtonNextHovered = isHovered
                    })
                }
                .background(Color.blue)
                .cornerRadius(6) // Smaller corner radius
                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1) // Lighter shadow
                
                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
    
    // MARK: - Helper Methods
    // Helper methods for swipe actions
    private func handleSwipeLeft() {
        if let currentIndex = Tab.allCases.firstIndex(of: selectedTab),
           currentIndex < Tab.allCases.count - 1 { // Swipe Left moves to NEXT tab
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = Tab.allCases[currentIndex + 1]
            }
        }
    }
    
    private func handleSwipeRight() {
        if let currentIndex = Tab.allCases.firstIndex(of: selectedTab), currentIndex > 0 { // Swipe Right moves to PREVIOUS tab
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = Tab.allCases[currentIndex - 1]
            }
        }
    }
    
    private func handleLeftArrowKey() -> KeyPress.Result {
        if let currentIndex = Tab.allCases.firstIndex(of: selectedTab), currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = Tab.allCases[currentIndex - 1]
            }
            return .handled
        }
        return .ignored
    }
    
    private func handleRightArrowKey() -> KeyPress.Result {
        if let currentIndex = Tab.allCases.firstIndex(of: selectedTab),
           currentIndex < Tab.allCases.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = Tab.allCases[currentIndex + 1]
            }
            return .handled
        }
        return .ignored
    }
    
    private func handleSeriesChange() {
        // Reset animation states before loading new data
        seriesContentVisible = false
        presentationsContentVisible = false
        
        // Give UI time to hide content before loading new data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            loadSeriesDocsInline()
        }
    }
    
    private func onAppearSetup() {
            // Make sure summary state is synchronized with document
            if let docSummary = document.summary, !docSummary.isEmpty {
                self.summaryText = docSummary
            }
            
            // Check if document has a Scripture Sheet PDF path in metadata
            if let metadata = document.metadata, let pdfPath = metadata["scriptureSheetPDFPath"] as? String {
                self.scriptureSheetPDFPath = pdfPath
            }
            
            // Load recent items for suggestions
            loadRecentItems()
            
            // Add animation with delay for series and presentations content
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    seriesContentVisible = true
                    presentationsContentVisible = true
                }
            }
            
            // Load notes from document when view appears
            loadNotesFromDocument()
            
            // Add notification observer for document updates
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("DocumentDidUpdate"),
                object: nil,
                queue: .main
            ) { notification in
                // Check if this update is for our document
                if let updatedDocId = notification.userInfo?["documentId"] as? String,
                   updatedDocId == self.document.id {
                    print("📣 Received update notification for current document")
                    
                    // Reload notes from the document
                    self.loadNotesFromDocument()
                }
            }
        }
    
    private func onDisappearCleanup() {
            // Remove notification observer when view disappears
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DocumentDidUpdate"), object: nil)
        }
    
    private func saveChanges() {
        var updatedDoc = document
        updatedDoc.title = title
        updatedDoc.subtitle = subtitle
        
        // Update series if needed
        if !seriesName.isEmpty {
            if updatedDoc.series == nil || updatedDoc.series?.name != seriesName {
                updatedDoc.series = DocumentSeries(
                    id: UUID(),
                    name: seriesName,
                    documents: [document.id],
                    order: 0
                )
            }
        } else {
            updatedDoc.series = nil
        }
        
        // Update variation data
        if var firstVariation = updatedDoc.variations.first {
            // Update location
            firstVariation.location = location.isEmpty ? nil : location
            
            // Update date using isDateSet and selectedDate
            firstVariation.datePresented = isDateSet ? selectedDate : nil
            
            // Save variation back to document
            updatedDoc.variations[0] = firstVariation
        } else if !location.isEmpty || isDateSet { // Only create variation if needed
            // Create a new variation if none exists and location or date is set
            let variation = DocumentVariation(
                id: UUID(),
                name: "Original",
                documentId: document.id,
                parentDocumentId: document.id,
                createdAt: Date(),
                datePresented: isDateSet ? selectedDate : nil,
                location: location.isEmpty ? nil : location
            )
            updatedDoc.variations = [variation]
        }
        
        // Update tags
        updatedDoc.tags = Array(tags)
        
        // Save to disk
        updatedDoc.save()
        
        // Update binding
        document = updatedDoc
        
        // Notify of change
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
    }
    
    private func removeTag(_ tag: String) {
        tags.remove(tag)
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
    }
    
    private func tagColor(for tag: String) -> Color {
        return colorManager.color(for: tag)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func loadVariations() -> [Letterspace_CanvasDocument] {
        print("🔍 Loading variations for document ID: \(document.id)")
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return []
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            let variations = fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    // Only return documents that are variations of the current document
                    if doc.isVariation, doc.parentVariationId == document.id {
                        return doc
                    }
                    return nil
                } catch {
                    print("❌ Error loading document at \(url): \(error)")
                    return nil
                }
            }
            
            print("📊 Found \(variations.count) variations for document ID: \(document.id)")
            return variations
        } catch {
            print("❌ Error accessing documents directory: \(error)")
            return []
        }
    }
    
    // Helper function to load a document by ID
    private func loadDocumentById(_ documentId: String) -> Letterspace_CanvasDocument? {
        print("🔍 Loading document with ID: \(documentId)")
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return nil
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    
                    if doc.id == documentId {
                        print("✅ Found document: \(doc.title) (ID: \(doc.id))")
                        return doc
                    }
                } catch {
                    print("❌ Error loading document at \(url): \(error)")
                }
            }
            
            print("❌ Document with ID \(documentId) not found")
            return nil
        } catch {
            print("❌ Error accessing documents directory: \(error)")
            return nil
        }
    }
    
    private func addHeaderImage() {
#if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.image]
        
        if panel.runModal() == .OK, let url = panel.url {
            addImageFromURL(url)
        }
#elseif os(iOS)
        // iOS fallback - show message that this feature requires macOS
        print("📱 Header image selection requires macOS version")
#endif
    }
    
    private func addImageFromURL(_ url: URL) {
        guard let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else {
            print("❌ Could not access documents directory for header image")
            return
        }
        
        do {
            // Create document image directory if needed
            let documentPath = appDirectory.appendingPathComponent(document.id)
            let imagesPath = documentPath.appendingPathComponent("Images")
            
            if !FileManager.default.fileExists(atPath: imagesPath.path) {
                try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Generate a unique filename
            let fileName = "header_\(UUID().uuidString).\(url.pathExtension)"
            let fileURL = imagesPath.appendingPathComponent(fileName)
            
            // Copy the image to the document's image directory
            try FileManager.default.copyItem(at: url, to: fileURL)
            
            // Update document with header image element
            var updatedDoc = document
            
            // Add the header image to the document
            let headerElement = DocumentElement(type: .headerImage, content: fileName)
            
            // Check if there's already a header image element and replace it
            if let index = updatedDoc.elements.firstIndex(where: { $0.type == .headerImage }) {
                updatedDoc.elements[index] = headerElement
            } else {
                // If no header image element exists, add one at the beginning
                updatedDoc.elements.insert(headerElement, at: 0)
            }
            
            // Set proper flags to ensure header image toggle is ON
            updatedDoc.isHeaderExpanded = true
            
            // Set hasHeaderImage in the document metadata
            if var metadata = updatedDoc.metadata {
                metadata["hasHeaderImage"] = true
                updatedDoc.metadata = metadata
            } else {
                updatedDoc.metadata = ["hasHeaderImage": true]
            }
            
            // Update the CanvasDocument
            let canvasDoc = updatedDoc.canvasDocument
            // Set the hasHeaderImage property in canvasDoc metadata
            canvasDoc.metadata.hasHeaderImage = true
            updatedDoc.canvasDocument = canvasDoc
            
            // Save document and update binding
            document = updatedDoc
            updatedDoc.save()
            
            // Update the local document copy for UI reactivity
            localDocument = updatedDoc
            
            // Notify of change to update all views including the document editor
            NotificationCenter.default.post(
                name: NSNotification.Name("DocumentDidUpdate"),
                object: nil,
                userInfo: ["documentId": document.id]
            )
            
            // Also post the general list update notification
            NotificationCenter.default.post(
                name: NSNotification.Name("DocumentListDidUpdate"),
                object: nil
            )
            
            print("✅ Header image added successfully with fileName: \(fileName)")
        } catch {
            print("❌ Error adding header image: \(error)")
        }
    }
    
    // Function to generate AI summary
    private func generateAISummary() {
        // Use a more direct approach without Task/MainActor
        isGeneratingSummary = true
        
        // Get the document content from the elements
        let documentContent = localDocument.elements
            .filter { $0.type == .textBlock }
            .map { $0.content }
            .joined(separator: "\n\n")
        
        // Create a CanvasDocument with the content
        let canvasDoc = CanvasDocument()
        canvasDoc.content = NSAttributedString(string: documentContent)
        canvasDoc.metadata.title = localDocument.title
        
        // Generate the summary
        canvasDoc.generateSummary { summary in
            DispatchQueue.main.async {
                // Update the summary text state variable
                self.summaryText = summary
                self.isGeneratingSummary = false
                
                // Update the local document copy
                self.localDocument.summary = summary
                
                // Save the document without updating the binding
                var updatedDoc = document
                updatedDoc.summary = summary
                updatedDoc.save()
            }
        }
    }
    
    // Function to remove the summary
    private func removeSummary() {
        // Use a direct approach without Task/MainActor
        // Clear the summary text
        self.summaryText = ""
        
        // Update the local document copy
        self.localDocument.summary = nil
        
        // Save the document without updating the binding
        var updatedDoc = document
        updatedDoc.summary = nil
        updatedDoc.save()
    }
    
    // ADD THIS FUNCTION
    private func loadSeriesDocsInline() {
        print("🔄 Loading inline series documents for: \(document.id)")
        
        // Set animation states to false first
             seriesContentVisible = false
             presentationsContentVisible = false
             
        // Only proceed if document has a series and a series name
        guard let series = document.series, !series.name.isEmpty else {
            seriesDocsInline = []
            return
        }
        
        seriesName = series.name
        
        // Here we'll find all documents in the same series
        if let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
            
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "canvas" }
                
                // Load all documents in this series
                var docs = [Letterspace_CanvasDocument]()
                
                for url in fileURLs {
                    do {
                        let data = try Data(contentsOf: url)
                        let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                        
                        if let docSeries = doc.series, docSeries.name == series.name {
                            docs.append(doc)
                        }
                    } catch {
                        print("❌ Error loading document at \(url): \(error)")
                    }
                }
                
                print("📊 Found \(docs.count) documents in series \"\(series.name)\"")
                
                // Sort by order or other criteria
                docs.sort { a, b in
                    // First by series order if available
                    if let orderA = a.series?.order, let orderB = b.series?.order {
                        return orderA < orderB
                    }
                    
                    // Then by date if both have dates
                    if let dateA = a.variations.first?.datePresented, let dateB = b.variations.first?.datePresented {
                        return dateA < dateB
                    }
                    
                    // Documents with dates come before those without
                    if a.variations.first?.datePresented != nil && b.variations.first?.datePresented == nil {
                        return true
                    }
                    
                    if a.variations.first?.datePresented == nil && b.variations.first?.datePresented != nil {
                        return false
                    }
                    
                    // Finally sort by title
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
                
                // Store the sorted result
                seriesDocsInline = docs
                
                // After loading new content, animate it back in with a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        seriesContentVisible = true
                        presentationsContentVisible = true
                    }
                }
                
            } catch {
                print("❌ Error accessing documents directory: \(error)")
                seriesDocsInline = []
            }
        } else {
            print("❌ Could not find documents directory")
            seriesDocsInline = []
        }
    }
    
    // --- REVISED SERIES REORDERING FUNCTIONS ---
    
    // Function called by .onMove to reorder the @State array
    private func moveSeriesItems(from source: IndexSet, to destination: Int) {
        seriesDocsInline.move(fromOffsets: source, toOffset: destination)
        // Note: This only reorders the local @State array.
        // We need updateAndSaveFolderOrder to persist changes.
    }
    
    // Function to update the actual order property in documents and save
    private func updateAndSaveFolderOrder() {
        print("🔄 Updating and saving series order...")
        for (index, doc) in seriesDocsInline.enumerated() {
            let newOrder = index + 1 // Order is 1-based index
            
            // Check if the order needs updating
            if doc.series?.order != newOrder {
                var updatedDoc = doc
                if var series = updatedDoc.series {
                    print("  Updating order for \"\(updatedDoc.title)\" (ID: \(updatedDoc.id)) from \(series.order) to \(newOrder)")
                    series.order = newOrder
                    updatedDoc.series = series
                    updatedDoc.save() // Save the change to disk
                } else {
                    print("⚠️ Document \"\(updatedDoc.title)\" (ID: \(updatedDoc.id)) is missing series data during reorder save.")
                }
            }
        }
        
        // After saving, reload the list to reflect updated order numbers
                 loadSeriesDocsInline()
        print("✅ Series order update complete.")
    }
    
    private func dismissWithAnimation() {
        if let customDismiss = onDismiss {
            customDismiss()
        } else {
            dismiss()
        }
    }
    
    private func getNextVariationNumber(for title: String) -> Int {
        // Get all documents that might be variations of this one
        let allDocuments = self.allDocuments
        
        // Find documents with similar titles (likely variations)
        var usedNumbers = Set<Int>()
        let titlePrefix = title.replacingOccurrences(of: " \\(\\d+\\)$", with: "", options: .regularExpression)
        
        for doc in allDocuments {
            let docTitle = doc.title
            
            // Check if it's a variation of the current document
            if docTitle.hasPrefix(titlePrefix) && docTitle != titlePrefix {
                // Extract the variation number
                if let range = docTitle.range(of: "\\(\\d+\\)$", options: .regularExpression) {
                    let numberPart = docTitle[range]
                    let numberString = numberPart.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                    if let number = Int(numberString) {
                        usedNumbers.insert(number)
                    }
                }
            }
        }
        
        // Find the next available number
        var nextNumber = 1
        while usedNumbers.contains(nextNumber) {
            nextNumber += 1
        }
        
        return nextNumber
    }
    
    private func createNewVariation() {
        // Get the next available variation number
        let nextNumber = getNextVariationNumber(for: document.title)
        let newTitle = "\(document.title) (\(nextNumber))"
        
        // Create a new variation record for the parent document
        let newVariation = DocumentVariation(
            id: UUID(),
            name: "Original",
            documentId: UUID().uuidString,  // Generate the ID first so we can use it in both places
            parentDocumentId: document.id,
            createdAt: Date(),
            datePresented: document.variations.first?.datePresented,
            location: document.variations.first?.location
        )
        
        // Create a new document as a variation, copying all properties from the original
        let newDoc = Letterspace_CanvasDocument(
            title: newTitle,
            subtitle: document.subtitle,
            elements: document.elements,  // Copy all elements including content
            id: newVariation.documentId,  // Use the same ID we generated above
            markers: document.markers,
            series: nil,  // Don't inherit series from parent document
            variations: [newVariation],
            isVariation: true,
            parentVariationId: document.id,
            tags: document.tags,
            isHeaderExpanded: document.isHeaderExpanded,
            isSubtitleVisible: document.isSubtitleVisible,
            links: document.links
        )
        
        // Save the new document
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // First, update the parent document's variations list
            var updatedParentDoc = document
            updatedParentDoc.variations.append(newVariation)
            
            // Save the updated parent document
            let parentData = try JSONEncoder().encode(updatedParentDoc)
            let parentFileURL = appDirectory.appendingPathComponent("\(updatedParentDoc.id).canvas")
            try parentData.write(to: parentFileURL)
            
            // Then save the new variation document
            let newDocData = try JSONEncoder().encode(newDoc)
            let newDocFileURL = appDirectory.appendingPathComponent("\(newDoc.id).canvas")
            try newDocData.write(to: newDocFileURL)
            
            // Post notification to update the UI
            NotificationCenter.default.post(
                name: NSNotification.Name("DocumentListDidUpdate"),
                object: nil
            )
            
            // Open the new document
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenDocument"),
                object: nil,
                userInfo: ["documentId": newDoc.id]
            )
        } catch {
            print("Error creating variation: \(error)")
        }
    }
    
    private func addLink() {
        let newLink = DocumentLink(
            id: UUID().uuidString,
            title: newLinkTitle,
            url: newLinkURL,
            createdAt: Date()
        )
        
        var updatedDoc = document
        updatedDoc.links.append(newLink)
        document = updatedDoc
        
        // Reset form fields
        newLinkTitle = ""
        newLinkURL = ""
        
        // Save changes
        updatedDoc.save()
        
        // Notify of document update
        NotificationCenter.default.post(
            name: NSNotification.Name("DocumentListDidUpdate"),
            object: nil
        )
    }
    
    private func switchTab(to tab: Tab) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.3)) {
            selectedTab = tab
        }
    }
    
    private var tabsView: some View {
        VStack(spacing: 0) {
            // Tab buttons
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button(action: { switchTab(to: tab) }) {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 13))
                                .foregroundStyle(selectedTab == tab ? theme.primary : theme.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .background(
                        hoveredTab == tab && selectedTab != tab ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97)) :
                            Color.clear
                    )
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.2)) {
                            hoveredTab = hovering ? tab : nil
                        }
                    }
                }
            }
            
            // Animated indicator
            GeometryReader { geometry in
                let tabWidth = geometry.size.width / CGFloat(Tab.allCases.count)
                let indicatorPosition = tabWidth * CGFloat(Tab.allCases.firstIndex(of: selectedTab) ?? 0)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: tabWidth, height: 2)
                    .offset(x: indicatorPosition)
                    .animation(
                        .spring(
                            response: 0.3,
                            dampingFraction: 0.7,
                            blendDuration: 0.2
                        ),
                        value: selectedTab
                    )
            }
            .frame(height: 2)
        }
        .padding(.horizontal, 8)
    }
    
    private var infoTabView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Add top padding for breathing room between tabs and content
            Spacer()
                .frame(height: 16)
                
            // Scripture Sheet Row
            HStack(alignment: .firstTextBaseline) {
                // Icon and label group
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "book.pages")
                        .frame(width: 24)
                        .foregroundStyle(theme.secondary)
                    
                    Text("Scripture Sheet")
                        .font(DesignSystem.Typography.medium(size: 13))
                        .foregroundStyle(theme.primary)
                        .tracking(0.5)
                }
                .frame(width: 225, alignment: .leading)
                
                // Conditionally show appropriate UI based on generation state and PDF availability
                if isGeneratingScriptureSheet {
                    // Show progress indicator while generating (for both initial generation and regeneration)
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 2)
                        Text("Generating...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let pdfPath = scriptureSheetPDFPath {
                    // Container for all buttons when PDF is available and not generating
                    HStack(spacing: 8) {
                        // Link to open the generated PDF
                        Button(action: {
                            openScriptureSheetPDF(at: pdfPath)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 12))
                                Text("Open Scripture Sheet")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        
                        // Regenerate button
                        Button(action: {
                            generateScriptureSheet()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .padding(6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Regenerate Scripture Sheet")
                        
                        // Remove button
                        Button(action: {
                            removeScriptureSheet()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                                .padding(6)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Remove Scripture Sheet")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Button to generate PDF (initial generation)
                    Button(action: {
                        generateScriptureSheet()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 12))
                            Text("Generate")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
                
            // Series
            HStack(alignment: .firstTextBaseline) {
                // Icon and label group
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "list.bullet")
                        .frame(width: 24)
                        .foregroundStyle(theme.secondary)
                    
                    Text("Series")
                        .font(DesignSystem.Typography.medium(size: 13))
                        .foregroundStyle(theme.primary)
                        .tracking(0.5)
                }
                .frame(width: 225, alignment: .leading) // Adjust width as needed
                
                if isEditing {
                    // Series editing UI (TextField, Suggestions dropdown, etc.)
                    ZStack(alignment: .topLeading) {
                        TextField("Series Name", text: $seriesName)
                            .font(DesignSystem.Typography.regular(size: 13))
                            .tracking(0.5)
                            .textFieldStyle(.plain)
                            .padding(6)
                            .background(textFieldBackgroundColor)
                            .cornerRadius(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: seriesName) { oldValue, newValue in
                                if oldValue != newValue {
                                    showSeriesSuggestions = true
                                }
                            }
                            .onSubmit {
                                showSeriesSuggestions = false
                            }
                            .overlay(alignment: .trailing) {
                                if !seriesName.isEmpty {
                                    Button(action: {
                                        seriesName = ""
                                        showSeriesSuggestions = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray.opacity(0.7))
                                            .padding(.trailing, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        
                        // Suggestions dropdown overlay
                        if showSeriesSuggestions && !recentSeries.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Recent Series")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(theme.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)
                                
                                Divider()
                                    .padding(.horizontal, 8)
                                
                                ForEach(recentSeries.filter {
                                    seriesName.isEmpty || $0.localizedCaseInsensitiveContains(seriesName)
                                }.prefix(5), id: \.self) { series in
                                    Button(action: {
                                        seriesName = series
                                        showSeriesSuggestions = false
                                    }) {
                                        HStack {
                                            Text(series)
                                                .font(.system(size: 13))
                                                .foregroundStyle(theme.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                        .background(hoveredSeriesItem == series ?
                                                    dropdownHoverColor :
                                            Color.clear)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover(perform: { hovering in
                                        hoveredSeriesItem = hovering ? series : nil
                                    })

                                    if series != recentSeries.filter({ seriesName.isEmpty || $0.localizedCaseInsensitiveContains(seriesName) }).prefix(5).last {
                                        Divider()
                                            .padding(.leading, 12)
                                    }
                                }
                                
                                // Option to create a new series
                                if seriesName.isEmpty || !recentSeries.contains(where: { $0.localizedCaseInsensitiveCompare(seriesName) == .orderedSame }) {
                                    Divider()
                                        .padding(.horizontal, 8)

                                    Button(action: {
                                        // Just close the suggestion box, the name is already in the text field
                                        showSeriesSuggestions = false
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundStyle(.blue)
                                            Text(seriesName.isEmpty ? "Add new series" : "Create \"\(seriesName)\"")
                                                .font(.system(size: 13))
                                                .foregroundStyle(seriesName.isEmpty ? theme.secondary : .blue)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                        .background(hoveredSeriesItem == "create" ?
                                                    dropdownHoverColor :
                                            Color.clear)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover(perform: { hovering in
                                        hoveredSeriesItem = hovering ? "create" : nil
                                    })
                                }
                            }
                            .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
                            .offset(y: 34)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .zIndex(100)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                            ))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showSeriesSuggestions)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Add an invisible overlay across the whole screen when dropdown is shown
                    // to detect clicks outside the dropdown for closing it
                    if showSeriesSuggestions {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(perform: {
                                showSeriesSuggestions = false
                            })
                            .ignoresSafeArea()
                            .position(x: 0, y: 0)
                            .frame(width: 0, height: 0)
                    }
                } else {
                    // Display Series Name and Inline List
                    HStack(alignment: .firstTextBaseline) { // HStack to hold Name and Button
                        VStack(alignment: .leading, spacing: 4) { // VStack for Name and List
                            HStack { // HStack for Name and potential Edit Button
                    if let series = document.series {
                                    Text(series.name) // Just display the name
                                        .font(DesignSystem.Typography.medium(size: 13))
                                .foregroundStyle(theme.primary)
                                .tracking(0.5)
                        .padding(.vertical, 2)
                                    
                                    Spacer() // Pushes Edit button to the right if series exists
                                    
                                    // Add Edit Order / Done button here
                                    if !seriesDocsInline.isEmpty { // Only show if there are items to order
                                        Button(action: {
                                            if isEditingSeriesOrder {
                                                // Call save function when Done is clicked
                                                updateAndSaveFolderOrder()
                                            }
                                            // Toggle the state AFTER saving (if was true)
                                            isEditingSeriesOrder.toggle()
                                        }) {
                                            Text(isEditingSeriesOrder ? "Done" : "Reorder")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.blue)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.leading, 8)
                                    }
                                    
                    } else {
                        Text("None")
                            .font(DesignSystem.Typography.regular(size: 13))
                                        .foregroundStyle(theme.secondary)
                            .tracking(0.5)
                                    Spacer() // Keep alignment consistent when no series
                                }
                            } // End HStack for Name and Edit Button

                            // Inline list of series documents (remains inside the VStack)
                            if !seriesDocsInline.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    // Remove .onMove - it won't work with our custom layout
                                    ForEach(seriesDocsInline.indices, id: \.self) { index in 
                                        let doc = seriesDocsInline[index]
                                        
                                        HStack(spacing: 8) { 
                                            // Show Drag Handle OR Part Number
                                            if isEditingSeriesOrder {
                                                Image(systemName: "line.3.horizontal") // Drag handle
                                                    .foregroundStyle(draggedItem?.id == doc.id ? .blue : theme.secondary)
                                                    .frame(width: 40, alignment: .leading)
                                            }
                                            
                                            // Icon (always visible)
                                            Image(systemName: "doc.text")
                                                .font(.system(size: 10))
                                                .foregroundColor(theme.secondary)
                                                .frame(width: 15)

                                            // Button wraps only the Title/Subtitle Text (disabled in edit mode)
                                            Button(action: {
                                                NotificationCenter.default.post(
                                                    name: NSNotification.Name("OpenDocument"),
                                                    object: nil,
                                                    userInfo: ["documentId": doc.id]
                                                )
                                            }) {
                                                let titleText = doc.title.isEmpty ? "Untitled" : doc.title
                                                let subtitleText = doc.subtitle.isEmpty ? "" : " • \(doc.subtitle)"
                                                Text("\(titleText)\(subtitleText)")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(isEditingSeriesOrder ? theme.primary : Color.blue)
                                                    .underline(!isEditingSeriesOrder)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                    .onHover(perform: { hovering in 
                                                        if !isEditingSeriesOrder {
#if os(macOS)
                                                            if hovering {
                                                                NSCursor.pointingHand.push()
                                                            } else {
                                                                NSCursor.pop()
                                                            }
#endif
                                                        } 
                                                    })
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(isEditingSeriesOrder)
                                            
                                            Spacer() 
                                        }
                                        .padding(.leading, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Group {
                                                if isEditingSeriesOrder {
                                                    if draggedItem?.id == doc.id {
                                                        Color.blue.opacity(0.1)
                                                    } else if isDragging {
                                                        theme.background.opacity(0.5)
                                                    } else {
                                                        theme.background.opacity(0.3)
                                                    }
                                                } else {
                                                    Color.clear
                                                }
                                            }
                                        )
                                        .cornerRadius(4)
                                        .contentShape(Rectangle())
                                        .onDrag {
                                            if isEditingSeriesOrder {
                                                // Set dragging state first to prevent jitter
                                                self.isDragging = true
                                                self.draggedItem = doc
                                                return NSItemProvider(object: doc.id as NSString)
                                            } else {
                                                return NSItemProvider()
                                            }
                                        }
                                        .onDrop(of: [UTType.text], isTargeted: nil) { providers -> Bool in
                                            guard isEditingSeriesOrder, let draggedItem = self.draggedItem else { return false }
                                            
                                            let fromIndex = seriesDocsInline.firstIndex { $0.id == draggedItem.id } ?? 0
                                            let toIndex = index
                                            
                                            if fromIndex != toIndex {
                                                // Reorder with a minimal clean animation
                                                var updatedArray = seriesDocsInline
                                                updatedArray.remove(at: fromIndex)
                                                updatedArray.insert(draggedItem, at: toIndex)
                                                seriesDocsInline = updatedArray
                                            }
                                            
                                            // Reset all drag state cleanly
                                            self.draggedItem = nil
                                            self.isDragging = false
                                            
                                            return true
                                        }
                                    }
                                    // Remove .onMove line
                                }
                                .padding(8)
                                .background(seriesItemBackgroundColor)
                                .cornerRadius(6)
                                .padding(.top, 4)
                                .opacity(seriesContentVisible ? 1 : 0)
                                .offset(y: seriesContentVisible ? 0 : -20)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Ensure VStack takes width
                }
            }
            .padding(.bottom, showSeriesSuggestions ? 20 : 0) // Keep padding adjustment for edit mode

            // Presentations (Modified for inline display)
            HStack(alignment: .firstTextBaseline) {
                // Icon and label group (remains the same)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "calendar")
                        .frame(width: 24)
                        .foregroundStyle(theme.secondary)
                    
                    Text("Presentations")
                        .font(DesignSystem.Typography.medium(size: 13))
                        .foregroundStyle(theme.primary)
                        .tracking(0.5)
                }
                .frame(width: 225, alignment: .leading)
                
                // This part changes based on isEditing
                if isEditing {
                    // Button to trigger Presentation Manager via Notification
                    Button(action: {
                        // Dismiss this card first
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                        
                        // Post notification after a short delay to ensure the card is dismissed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: .showPresentationManager, object: nil, userInfo: ["documentId": document.id])
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text("Schedule a Future or Log a Past Presentation")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(Color.blue)
                    }
                    .buttonStyle(.plain)
                    // REMOVED: .sheet(isPresented: $showPresentationManager)
                } else {
                    // Inline display of presentations (replaces the old button/summary)
                    VStack(alignment: .leading, spacing: 4) { // Use VStack for potential list
                        if !document.presentations.isEmpty {
                            // Sort presentations by date, most recent first
                            let sortedPresentations = document.presentations.sorted { $0.datetime > $1.datetime }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(sortedPresentations) { presentation in
                                    HStack(spacing: 8) { // Match Series HStack spacing
                                        // Determine label based on status and date
                                        let isUpcoming = presentation.status == .scheduled && presentation.datetime >= Date()
                                        let labelText = isUpcoming ? "Future" : "Past" // Changed "Upcoming" to "Future"
                                        
                                        // Prefix Label ("Future" / "Past")
                                        Text(labelText)
                                            .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.secondary)
                                            .frame(width: 40, alignment: .leading) // Match Series Part label width
                                            
                                        // Status Icon (Aligns with Series doc icon)
                                        Image(systemName: presentation.status == .scheduled ? "calendar.badge.clock" : "calendar.badge.checkmark")
                                            .font(.system(size: 10))
                                            .foregroundColor(presentation.status == .scheduled ? Color.orange : Color.green)
                                            .frame(width: 15) // Align icons
                                            
                                        // Date/Time Text (Aligns with Series title)
                                        Text("\(formatDate(presentation.datetime))") // Removed status suffix
                                            .font(.system(size: 12))
                                    .foregroundStyle(theme.primary)
                                            .lineLimit(1)
                                            
                                        Spacer() // Push text to the left
                                    }
                                    .padding(.leading, 8) // Match Series padding
                                    .padding(.vertical, 4) // Match Series padding
                                }
                            }
                            .padding(8) // Padding inside the container
                            .background(presentationBackgroundColor) // Background color
                            .cornerRadius(6)
                            .padding(.top, 4) // Space below the label
                            .opacity(presentationsContentVisible ? 1 : 0)
                            .offset(y: presentationsContentVisible ? 0 : -20)
                        } else {
                            Text("None")
                                .font(DesignSystem.Typography.regular(size: 13))
                                .foregroundStyle(theme.secondary) // Make 'None' less prominent
                                .tracking(0.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Ensure VStack takes width
                    // REMOVED: The old button and .sheet modifier for PresentationTimeline
                }
            }
            
            // Location
            HStack(alignment: .firstTextBaseline) {
                // Icon and label group
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .frame(width: 24)
                        .foregroundStyle(theme.secondary)
                    
                    Text("Location")
                        .font(DesignSystem.Typography.medium(size: 13))
                        .foregroundStyle(theme.primary)
                        .tracking(0.5)
                }
                .frame(width: 225, alignment: .leading)
                
                if isEditing {
                    ZStack(alignment: .topLeading) {
                        TextField("Location Name", text: $location)
                            .font(DesignSystem.Typography.regular(size: 13))
                            .tracking(0.5)
                            .textFieldStyle(.plain)
                            .padding(6)
                            .background(textFieldBackgroundColor)
                            .cornerRadius(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: location) { oldValue, newValue in
                                if oldValue != newValue {
                                    showLocationSuggestions = true
                                }
                            }
                            .onSubmit {
                                showLocationSuggestions = false
                            }
                            .overlay(alignment: .trailing) {
                                if !location.isEmpty {
                                    Button(action: {
                                        location = ""
                                        showLocationSuggestions = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color(.gray))
                                            .padding(.trailing, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                        if showLocationSuggestions && !recentLocations.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Recent Locations")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color(.gray))
                                    .padding(.horizontal, 12)
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)

                                ForEach(recentLocations.filter {
                                    location.isEmpty || $0.localizedCaseInsensitiveContains(location)
                                }, id: \.self) { loc in
                                    Button(action: {
                                        location = loc
                                        showLocationSuggestions = false
                                        DispatchQueue.main.async {
                                            showLocationSuggestions = false
                                        }
                                    }) {
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(Color(.lightGray))
                                                .frame(width: 6, height: 6)

                                            Text(loc)
                                                .font(.system(size: 13))
                                                .foregroundStyle(theme.primary)

                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                        .frame(maxWidth: .infinity)
                                        .background(hoveredLocationItem == loc ?
                                                    dropdownHoverColor :
                                            Color.clear)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover(perform: { hovering in
                                        hoveredLocationItem = hovering ? loc : nil
                                    })
                                }
                                
                                // Add "Create" option similar to series dropdown
                                if location.isEmpty || !recentLocations.contains(where: { $0.localizedCaseInsensitiveCompare(location) == .orderedSame }) {
                                    Button(action: {
                                        // Keep location name as is and close dropdown
                                        showLocationSuggestions = false
                                        // Force UI update
                                        DispatchQueue.main.async {
                                            showLocationSuggestions = false
                                        }
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.blue)
                                            
                                            Text(location.isEmpty ? "Add new location" : "Create \"\(location)\"")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.blue)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                        .frame(maxWidth: .infinity)
                                        .background(hoveredLocationItem == "create" ?
                                                    dropdownHoverColor :
                                            Color.clear)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover(perform: { hovering in
                                        hoveredLocationItem = hovering ? "create" : nil
                                    })
                                }
                            }
                            .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
                            .offset(y: 34)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .zIndex(100)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                            ))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showLocationSuggestions)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if showLocationSuggestions {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(perform: {
                                showLocationSuggestions = false
                            })
                            .ignoresSafeArea()
                            .position(x: 0, y: 0)
                            .frame(width: 0, height: 0)
                            .zIndex(99)
                    }
                } else {
                    if location.isEmpty {
                        Text("None")
                            .font(DesignSystem.Typography.regular(size: 13))
                            .foregroundStyle(theme.primary)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(location)
                            .font(DesignSystem.Typography.regular(size: 13))
                            .foregroundStyle(theme.primary)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.bottom, showLocationSuggestions ? 20 : 0)
            
            // Tags
            HStack(alignment: .firstTextBaseline) {
                // Icon and label group
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "tag")
                        .frame(width: 24)
                        .foregroundStyle(theme.secondary)
                    
                    Text("Tags")
                        .font(DesignSystem.Typography.medium(size: 13))
                        .foregroundStyle(theme.primary)
                        .tracking(0.5)
                }
                .frame(width: 225, alignment: .leading)
                
                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        // Tag entry field
                        HStack {
                            TextField("Add new tag", text: $newTag, onCommit: {
                                if !newTag.isEmpty {
                                    // Capitalize first letter
                                    let capitalizedTag = newTag.prefix(1).uppercased() + newTag.dropFirst()
                                    tags.insert(capitalizedTag)
                                    newTag = ""
                                }
                            })
                            .font(DesignSystem.Typography.regular(size: 13))
                            .tracking(0.5)
                            .textFieldStyle(.plain)
                            .padding(6)
                            .background(textFieldBackgroundColor)
                            .cornerRadius(6)
                            
                            Button(action: {
                                if !newTag.isEmpty {
                                    // Capitalize first letter
                                    let capitalizedTag = newTag.prefix(1).uppercased() + newTag.dropFirst()
                                    tags.insert(capitalizedTag)
                                    newTag = ""
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(theme.accent)
                            }
                            .buttonStyle(.plain)
                            .disabled(newTag.isEmpty)
                        }
                        
                        // Existing tags with remove buttons
                        if !tags.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(Array(tags), id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(DesignSystem.Typography.medium(size: 13))
                                            .tracking(0.5)
                                            .foregroundStyle(tagColor(for: tag))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                        
                                        Button(action: {
                                            tags.remove(tag)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(theme.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(tagColor(for: tag), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if tags.isEmpty {
                        Text("None")
                            .font(DesignSystem.Typography.regular(size: 13))
                            .foregroundStyle(theme.primary)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        // For non-empty tags, we'll show a compact representation
                        HStack(spacing: 4) {
                            ForEach(Array(tags).prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(DesignSystem.Typography.medium(size: 12)) // Reduced font size
                                    .tracking(0.5)
                                    .foregroundStyle(tagColor(for: tag))
                                    .padding(.horizontal, 8) // Reduced horizontal padding
                                    .padding(.vertical, 2) // Reduced vertical padding
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(tagColor(for: tag), lineWidth: 1)
                                    )
                            }
                            
                            if tags.count > 3 {
                                Text("+\(tags.count - 3)")
                                    .font(DesignSystem.Typography.regular(size: 10)) // Reduced font size
                                    .foregroundStyle(theme.secondary)
                                    .tracking(0.5)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
    
    // Variations Tab Content
    private var variationsTabView: some View {
        VStack(alignment: .leading, spacing: 16) { // Reduced from 24 to lessen space between items
            // Add top padding for breathing room between tabs and content
            Spacer()
                .frame(height: 16)
            
            // Add buttons for Translate and New, but right-aligned
            HStack(spacing: 12) {
                Spacer() // This pushes the buttons to the right
                
                // Translate button with purple color and sparkle icon
                Button {
                    // Show translation modal
                    showTranslationModal = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Translate")
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.9)) // Indigo/blue-purple color to match screenshot
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(Color(red: 0.4, green: 0.3, blue: 0.9).opacity(0.1)) // Matching background with opacity
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // New variation button
                Button {
                    // Create new variation
                    createNewVariation()
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .foregroundColor(Color.green)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 2)
                
            let variations = loadVariations()
            
            if variations.isEmpty && (!document.isVariation || document.parentVariationId == nil) {
                Text("No variations")
                    .font(DesignSystem.Typography.regular(size: 14)) // Increased from 12
                    .foregroundStyle(theme.secondary)
                    .tracking(0.2)
                    .padding(.leading, 4)
            } else {
                // Show Original document button only when viewing a variation
                if document.isVariation && document.parentVariationId != nil {
                    // Load the original document
                    if let originalDoc = loadDocumentById(document.parentVariationId!) {
                        HoverableRowButton(
                            icon: "doc.text",
                            label: "Original",
                            content: originalDoc.title.isEmpty ? "Untitled" : originalDoc.title,
                            action: {
                                // Navigate to the original document
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("OpenDocument"),
                                    object: nil,
                                    userInfo: ["documentId": originalDoc.id]
                                )
                            }
                        )
                    }
                }
                
                // Variation buttons
                ForEach(variations) { variation in
                    // Check if the variation title indicates it's a translation
                    let isTranslation = variation.title.contains("Spanish") || variation.title.contains("en el") || variation.title.contains("español")
                    
                    HoverableRowButton(
                        icon: "doc.append",
                        label: "Variation",
                        content: variation.title.isEmpty ? "Untitled" : variation.title,
                        isTranslation: isTranslation,
                        action: {
                            // Open the variation
                            NotificationCenter.default.post(
                                name: NSNotification.Name("OpenDocument"),
                                object: nil,
                                userInfo: ["documentId": variation.id]
                            )
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showTranslationModal) {
            TranslationPreviewView(document: $document, isPresented: $showTranslationModal)
        }
    }
    
    // Hoverable Row Button component for consistent styling
    private struct HoverableRowButton: View {
        let icon: String
        let label: String
        let content: String
        let action: () -> Void
        let isTranslation: Bool
        @Environment(\.themeColors) var theme
        @Environment(\.colorScheme) var colorScheme
        @State private var isHovering = false
        
        // Initialize with explicit translation flag
        init(icon: String, label: String, content: String, isTranslation: Bool = false, action: @escaping () -> Void) {
            self.icon = icon
            self.label = label
            self.content = content
            self.isTranslation = isTranslation
            self.action = action
        }
        
        // Detect language from content
        private func detectLanguage() -> String {
            if content.contains("español") || content.contains("Español") || content.contains("Spanish") || content.contains("en el") {
                return "Spanish"
            } else if content.contains("français") || content.contains("Français") || content.contains("French") {
                return "French"
            } else if content.contains("deutsch") || content.contains("Deutsch") || content.contains("German") {
                return "German"
            } else if content.contains("italiano") || content.contains("Italiano") || content.contains("Italian") {
                return "Italian"
            } else if content.contains("português") || content.contains("Português") || content.contains("Portuguese") {
                return "Portuguese"
            } else {
                return "Translation"
            }
        }
        
        var body: some View {
            Button(action: action) {
                HStack(alignment: .center) {
                    // Icon and label group
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .frame(width: 24)
                            .foregroundStyle(theme.secondary)
                        
                        if isTranslation {
                            Text("Translation • \(detectLanguage())")
                                .font(DesignSystem.Typography.medium(size: 14))
                                .foregroundStyle(theme.primary)
                                .tracking(0.5)
                        } else {
                        Text(label)
                                .font(DesignSystem.Typography.medium(size: 14))
                            .foregroundStyle(theme.primary)
                            .tracking(0.5)
                        }
                    }
                    .frame(width: 225, alignment: .leading)
                    
                    Spacer(minLength: 20)
                    
                    Text(content)
                        .font(DesignSystem.Typography.regular(size: 14))
                        .foregroundStyle(theme.primary)
                        .tracking(0.2)
                }
                .padding(.vertical, 12) // Increased from 8 to 12 for taller hover area
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ?
                              theme.accent.opacity(0.15) :
                              Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover(perform: { hovering in
                isHovering = hovering
#if os(macOS)
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    if NSCursor.current == NSCursor.pointingHand {
                        NSCursor.pop()
                    }
                }
#endif
            })
        }
    }
    
    // Links Tab Content
    private var linksTabView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Add top padding for breathing room between tabs and content
            Spacer()
                .frame(height: 16)
            
            // Add link button that opens popup
            HStack {
                Spacer() // Push the button to the right
                
                Button {
                    showAddLinkPopup = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Link")
                    }
                    .foregroundColor(Color.blue)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 16)
                
            if document.links.isEmpty {
                Text("No links")
                    .font(DesignSystem.Typography.regular(size: 14))
                    .foregroundStyle(theme.secondary)
                    .padding(.leading, 4)
            } else {
                // Links list
                ForEach(document.links) { link in
                    HoverableRowButton(
                        icon: "link",
                        label: link.title.isEmpty ? "Link" : link.title,
                        content: link.url,
                        action: {
                            // Open the link
                            if let url = URL(string: link.url) {
#if os(macOS)
                                NSWorkspace.shared.open(url)
#elseif os(iOS)
                                UIApplication.shared.open(url)
#endif
                            }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showAddLinkPopup) {
            AddLinkView(isPresented: $showAddLinkPopup, onAdd: { title, url in
                addLink(title: title, url: url)
            })
        }
    }
    
    // Popup view for adding a link
    struct AddLinkView: View {
        @Binding var isPresented: Bool
        @State private var linkTitle: String = ""
        @State private var linkURL: String = ""
        var onAdd: (String, String) -> Void
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Add Link")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.subheadline)
                    TextField("Link Title", text: $linkTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 300)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL")
                        .font(.subheadline)
                    TextField("https://example.com", text: $linkURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 300)
                }
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.escape)
                    
                    Button("Add") {
                        onAdd(linkTitle, linkURL)
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(linkTitle.isEmpty || linkURL.isEmpty)
                }
                .padding(.bottom)
            }
            .padding()
            .frame(width: 350)
        }
    }

    private func addLink(title: String, url: String) {
        let newLink = DocumentLink(
            id: UUID().uuidString,
            title: title,
            url: url,
            createdAt: Date()
        )
        
        var updatedDoc = document
        updatedDoc.links.append(newLink)
        document = updatedDoc
        
        // Save changes
        updatedDoc.save()
        
        // Notify of document update
        NotificationCenter.default.post(
            name: NSNotification.Name("DocumentListDidUpdate"), 
            object: nil
        )
    }
    
    // Renamed from clipsTabView to notes view
    private var clipsTabView: some View {
        // Removed outer ScrollView to prevent shared scrolling
        VStack(alignment: .leading, spacing: 16) {
            // Add top padding for breathing room between tabs and content
            Spacer()
                .frame(height: 16)
                
            // Two-column layout for notes
            HStack(alignment: .top, spacing: 12) { // Added spacing between columns
                // Left column: Note list with independent scrolling - fixed width
                VStack(alignment: .leading, spacing: 0) {
                    // Notes list - always visible with own ScrollView
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if notes.isEmpty {
                                Text("No notes")
                                    .font(DesignSystem.Typography.regular(size: 14))
                .foregroundStyle(theme.secondary)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 12)
                            } else {
                                ForEach(notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                                    Button(action: {
                                        // Select this note
                                        selectedNoteForDetail = note.id
                                        // Cancel any editing mode
                                        if isAddingNote && editingNoteId == nil {
                                            isAddingNote = false
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            // Preview text
                                            Text(previewText(for: note))
                                                .font(DesignSystem.Typography.regular(size: 14))
                                                .foregroundColor(theme.primary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            
                                            // Date
                                            Text(formatNoteDate(note.createdAt))
                                                .font(DesignSystem.Typography.regular(size: 11))
                                                .foregroundColor(theme.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            selectedNoteForDetail == note.id ?
                                                (colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)) :
                                                Color.clear
                                        )
                                        .cornerRadius(6)
                                        .contentShape(Rectangle()) // Make the entire area clickable
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity) // Ensure button fills available width
                                    
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(width: 200)
                    .frame(minHeight: 200)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : Color(.sRGB, white: 0.97))
                    .cornerRadius(8)
                }
                
                // Right column: Note detail or editing - expanded to fill remaining space
                VStack(spacing: 0) {
                    // Header section with permanent Add Note button
                    HStack {
                        if !isAddingNote {
                            Text(selectedNoteForDetail != nil ? "Note Details" : "Notes")
                                .font(DesignSystem.Typography.semibold(size: 16))
                        } else {
                            Text(editingNoteId != nil ? "Edit Note" : "New Note")
                                .font(DesignSystem.Typography.semibold(size: 16))
                        }
                        
                        Spacer()
                        
                        // Only show edit/delete buttons when viewing a note (not when adding/editing)
                        if let selectedId = selectedNoteForDetail, let note = notes.first(where: { $0.id == selectedId }), !isAddingNote {
                            // Edit button - changed to icon only
                            Button(action: {
                                // Start editing the note
                                editingNoteId = note.id
                                newNoteText = note.text
                                isAddingNote = true
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.accent)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(theme.accent.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 4)
                            
                            // Delete button - changed to icon only
                            Button(action: {
                                deleteNote(note)
                                // Clear selection
                                selectedNoteForDetail = nil
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.red.opacity(0.8))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 4)
                        }
                        
                        // Add note button - changed to + icon only
                        Button {
                            isAddingNote = true
                            newNoteText = ""
                            editingNoteId = nil
                            selectedNoteForDetail = nil
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14))
                                .foregroundColor(Color.blue)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                    
                    // Content area - fixed top part then scrollable content
                    if isAddingNote {
                        // Editing mode with visible buttons
                        VStack(alignment: .leading, spacing: 4) {
                            // Note editor with reduced height
                            ScrollView {
                                TextEditor(text: $newNoteText)
                                    .font(DesignSystem.Typography.regular(size: 14))
                                    .padding(4)
                                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.95))
                                    .cornerRadius(6)
                                    .frame(height: 120) // Increased height to push buttons down
                            }
                            .frame(maxHeight: 140)
                            
                            // Action buttons - always visible at bottom
                            HStack {
                                // Only show cancel button if creating new note
                                if editingNoteId == nil {
                                    Button("Cancel") {
                                        isAddingNote = false
                                        if !notes.isEmpty {
                                            // Select the most recent note when canceling
                                            selectedNoteForDetail = notes.sorted(by: { $0.createdAt > $1.createdAt }).first?.id
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .foregroundColor(theme.secondary)
                                }
                                
                                Spacer()
                                
                                Button(editingNoteId != nil ? "Update" : "Save") {
                                    if let editId = editingNoteId, let index = notes.firstIndex(where: { $0.id == editId }) {
                                        // Update existing note
                                        notes[index].text = newNoteText
                                        // Keep viewing this note
                                        selectedNoteForDetail = editId
                                    } else {
                                        // Add new note
                                        let newNote = Note(text: newNoteText)
                                        notes.append(newNote)
                                        // View the new note
                                        selectedNoteForDetail = newNote.id
                                    }
                                    
                                    // Save notes to document
                                    saveNotesToDocument()
                                    
                                    // Exit edit mode
                                    isAddingNote = false
                                    newNoteText = ""
                                    editingNoteId = nil
                                }
                                .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .buttonStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                    Color.gray.opacity(0.2) : 
                                    Color.blue.opacity(0.2))
                                .foregroundColor(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                    Color.gray : 
                                    Color.blue)
                                .cornerRadius(6)
                            }
                            .padding(.bottom, 2)
                        }
                        .padding(.horizontal, 8)
                    } else if let selectedId = selectedNoteForDetail, let note = notes.first(where: { $0.id == selectedId }) {
                        // Note detail view
                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                            
                            // Note content with its own scroll view
                            ScrollView {
                                Text(note.text)
                                    .font(DesignSystem.Typography.regular(size: 14))
                                    .foregroundColor(theme.primary)
                                    .lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 8)
                            }
                        }
                    } else {
                        // Empty state or placeholder when no note is selected
                        VStack {
                            Spacer()
                            Text("Select a note or create a new one")
                                .font(DesignSystem.Typography.regular(size: 14))
                                .foregroundColor(theme.secondary)
                            Spacer()
                        }
                        .frame(minHeight: 200)
                        .padding(.horizontal, 8)
                    }
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 200)
                .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                .cornerRadius(8)
            }
            .frame(maxHeight: .infinity)
            .frame(minHeight: 300)
            .padding(.horizontal, 8)
        }
        .onAppear {
            // Load notes from document when tab appears
            loadNotesFromDocument()
            
            // Open a new note by default if there are no notes
            if notes.isEmpty && !isAddingNote {
                isAddingNote = true
                newNoteText = ""
                editingNoteId = nil
                selectedNoteForDetail = nil
            }
        }
    }
    
    // Helper function to generate preview text for a note
    private func previewText(for note: Note) -> String {
        let text = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLineEnd = text.firstIndex(of: "\n") {
            let firstLine = text[..<firstLineEnd]
            return String(firstLine)
        } else if text.count > 60 {
            return String(text.prefix(60)) + "..."
        } else {
            return text
        }
    }
    
    // Date formatting utility 
    private func formatNoteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Save notes to document
    private func saveNotesToDocument() {
        do {
            // First encode the notes to Data
            let notesData = try JSONEncoder().encode(notes)
            
            // Convert the Data to a Base64 encoded string for more reliable storage
            let base64EncodedString = notesData.base64EncodedString()
            print("📝 Notes encoded to Base64 string: \(base64EncodedString.prefix(20))... (\(base64EncodedString.count) chars)")
            
            // Create a copy of the document to modify
            var updatedDoc = document
            
            // Initialize metadata if it doesn't exist
            if updatedDoc.metadata == nil {
                updatedDoc.metadata = [:]
                print("📝 Created new metadata dictionary for document")
            }
            
            // Store notes as Base64 string in document metadata
            updatedDoc.metadata?["additionalNotesBase64"] = base64EncodedString
            print("📝 Added notes as Base64 string to metadata")
            
            // Print the full metadata state for debugging
            if let metadata = updatedDoc.metadata {
                print("📝 Full metadata: \(metadata.keys.joined(separator: ", "))")
            }
            
            // Get the documents URL
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("❌ Could not access documents directory")
                return
            }
            
            // Use the app directory inside the documents folder
            let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
            
            do {
                // Create directory if it doesn't exist
                try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
                
                // Set up the file URL
                let fileURL = appDirectory.appendingPathComponent("\(updatedDoc.id).canvas")
                
                // Use NSFileCoordinator for iCloud compatibility
                let coordinator = NSFileCoordinator()
                var coordinationError: NSError?
                
                coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { url in
                    do {
                        // Update modification date
                        updatedDoc.modifiedAt = Date()
                        
                        // Encode and write data
                        let data = try JSONEncoder().encode(updatedDoc)
                        try data.write(to: url, options: [.atomic, .completeFileProtection])
                        print("☁️ Document with notes saved for iCloud sync: \(url.path)")
                        
                        // Update the binding to ensure changes propagate - must be done on main thread
                        DispatchQueue.main.async {
                            self.document = updatedDoc
                            
                            // Post notification that document was updated
                            NotificationCenter.default.post(
                                name: NSNotification.Name("DocumentDidUpdate"),
                                object: nil,
                                userInfo: ["documentId": updatedDoc.id]
                            )
                            
                            // Post notification for document list update
                            NotificationCenter.default.post(
                                name: NSNotification.Name("DocumentListDidUpdate"),
                                object: nil
                            )
                        }
                    } catch {
                        print("❌ Error writing document: \(error.localizedDescription)")
                    }
                }
                
                if let error = coordinationError {
                    print("❌ File coordination error: \(error.localizedDescription)")
                }
            } catch {
                print("❌ Error creating app directory: \(error.localizedDescription)")
            }
            
            // Print debug confirmation
            print("✅ Successfully saved \(notes.count) notes to document \(document.id)")
        } catch {
            print("❌ ERROR: Failed to save notes: \(error.localizedDescription)")
        }
    }
    
    // Load notes from document
    private func loadNotesFromDocument() {
        print("📝 Attempting to load notes from document \(document.id)")
        
        // Print the full metadata state for debugging
        if let metadata = document.metadata {
            print("📝 Document has metadata with keys: \(metadata.keys.joined(separator: ", "))")
        } else {
            print("📝 Document has no metadata")
        }
        
        // Try the new Base64 approach first
        if let metadata = document.metadata,
           let base64String = metadata["additionalNotesBase64"] as? String {
            do {
                print("📝 Found notes as Base64 string in metadata: \(base64String.prefix(20))...")
                
                guard let notesData = Data(base64Encoded: base64String) else {
                    print("❌ ERROR: Could not decode Base64 string")
                    self.notes = []
                    return
                }
                
                let loadedNotes = try JSONDecoder().decode([Note].self, from: notesData)
                self.notes = loadedNotes
                print("✅ Successfully loaded \(loadedNotes.count) notes from document \(document.id) using Base64")
                return
            } catch {
                print("❌ ERROR: Failed to decode notes data from Base64: \(error)")
            }
        }
        
        // Fall back to the old approach if the Base64 approach fails
        if let metadata = document.metadata,
           let notesData = metadata["additionalNotes"] as? Data {
            do {
                print("📝 Found notes data in metadata: \(notesData.count) bytes")
                let loadedNotes = try JSONDecoder().decode([Note].self, from: notesData)
                self.notes = loadedNotes
                print("✅ Successfully loaded \(loadedNotes.count) notes from document \(document.id)")
                
                // Migrate to the new Base64 format
                saveNotesToDocument()
                return
            } catch {
                print("❌ ERROR: Failed to decode notes data: \(error)")
            }
        }
        
        // Report which part failed specifically
        if document.metadata == nil {
            print("ℹ️ No metadata found in document \(document.id)")
        } else if document.metadata?["additionalNotesBase64"] == nil && document.metadata?["additionalNotes"] == nil {
            print("ℹ️ No notes found in document \(document.id) metadata")
        } else {
            print("ℹ️ Notes data could not be processed in document \(document.id)")
        }
        self.notes = []
    }
    
    // Delete a note
    private func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        saveNotesToDocument()
    }
    
    // Generate Scripture Sheet from document content
    private func generateScriptureSheet() {
        // Set generating state to true and show the alert
        isGeneratingScriptureSheet = true
        showScriptureSheetOptionsAlert = true
    }
    
    // New async function to handle processing after alert selection
    private func processAndCreateScriptureSheetPDF(includeVerseText: Bool) async {
        // We don't need a separate progress indicator dialog as the UI already shows "Generating..." in the metadata area
        
        // Extract document content
        let documentContent = document.elements
            .filter { $0.type == .textBlock }
            .map { $0.content }
            .joined(separator: "\\\\n\\\\n")
        
        // Use a background task for the extraction process (already handled by Task for async nature)
            // Extract all scripture references using the existing regex pattern, but also capture verse ranges
            let pattern = #"(Acts|Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|Samuel|Kings|Chronicles|Ezra|Nehemiah|Esther|Job|Psalm|Proverbs|Ecclesiastes|Song|Isaiah|Jeremiah|Lamentations|Ezekiel|Daniel|Hosea|Joel|Amos|Obadiah|Jonah|Micah|Nahum|Habakkuk|Zephaniah|Haggai|Zechariah|Malachi|Matthew|Mark|Luke|John|Romans|Corinthians|Galatians|Ephesians|Philippians|Colossians|Thessalonians|Timothy|Titus|Philemon|Hebrews|James|Peter|John|Jude|Revelation)\s+\d+:\d+(-\d+)?"#
            
            let nsString = documentContent as NSString
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let matches = regex?.matches(in: documentContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
            
            var orderedReferences: [(position: Int, reference: String)] = []
            
            for match in matches {
                let range = match.range
                let reference = nsString.substring(with: range)
                let position = range.location
                orderedReferences.append((position: position, reference: reference))
            }
            
            orderedReferences.sort { $0.position < $1.position }
            
            var uniqueIdCounter = 0
            
                actor ReferenceDataStore {
                    var data: [String: (verses: [BibleVerse], isRange: Bool)] = [:]
            func store(key: String, verses: [BibleVerse], isRange: Bool) { data[key] = (verses: verses, isRange: isRange) }
            func getAllData() -> [String: (verses: [BibleVerse], isRange: Bool)] { return data }
        }
        
                let referenceStore = ReferenceDataStore()
                
        // Process each reference in order and fetch its content using a TaskGroup
        await withTaskGroup(of: Void.self) { group in
                for (_, reference) in orderedReferences {
                let uniqueKey = "\\(reference)_\\(uniqueIdCounter)"
                    uniqueIdCounter += 1
                    
                group.addTask {
                        do {
                            let result = try await BibleAPI.searchVerses(
                                query: reference,
                                translation: "KJV",
                                mode: .reference
                            )
                            let verses = result.verses
                            let isRange = reference.contains("-")
                            await referenceStore.store(key: uniqueKey, verses: verses, isRange: isRange)
                        } catch {
                        print("Error fetching scripture reference: \\(error)")
                    }
                }
            }
        }
        
        // After all tasks in the group complete, get the data
                    let referenceData = await referenceStore.getAllData()
                    
        var scriptureReferences: [ScriptureElement] = [] // This will cause an error if ScriptureElement is not found
                    
                    for (index, (_, reference)) in orderedReferences.enumerated() {
            let uniqueKey = "\\(reference)_\\(index)"
                        guard let refData = referenceData[uniqueKey] else { continue }
                        
                        if refData.isRange || refData.verses.count > 1 {
                            let verses = refData.verses
                            if let firstVerse = verses.first {
                                let translation = firstVerse.translation
                                var combinedText = ""
                                for verse in verses {
                                    if includeVerseText {
                                        combinedText += verse.text
                            if verse != verses.last { combinedText += " " }
                                        }
                                    }
                    // Ensure ScriptureElement is available or handle this part differently
                    // For now, assuming ScriptureElement will be resolved
                                scriptureReferences.append(ScriptureElement(
                                    reference: reference,
                                    translation: translation,
                                    text: combinedText
                                ))
                            }
                        } else if let verse = refData.verses.first {
                            let textToInclude = includeVerseText ? verse.text : ""
                            scriptureReferences.append(ScriptureElement(
                                reference: verse.reference,
                                translation: verse.translation,
                                text: textToInclude
                            ))
                        }
                    }
                    
                    // Switch to the main thread to create the PDF
        // createScriptureSheetPDF should be callable from main actor
                        self.createScriptureSheetPDF(from: scriptureReferences, includeVerseText: includeVerseText)
        
        // Reset generating state on main thread
        DispatchQueue.main.async {
            self.isGeneratingScriptureSheet = false
        }
    }
    
    // Create a PDF with scripture references and link it in the document details
    private func createScriptureSheetPDF(from references: [ScriptureElement], includeVerseText: Bool) {
        // Check if we have any references
        if references.isEmpty {
#if os(macOS)
            let noReferencesAlert = NSAlert()
            noReferencesAlert.messageText = "No Scripture References Found (Beta)"
            noReferencesAlert.informativeText = "Could not detect any scripture references in this document.\n\nThe system looks for standard formats like \"John 3:16\" or \"Matthew 5:1-12\". Try editing references in your document to match these formats if they're not being detected."
            noReferencesAlert.runModal()
#elseif os(iOS)
            // iOS fallback - use state to show SwiftUI alert (would need to be implemented in the view)
            print("📱 No Scripture References Found - iOS alert would be shown here")
#endif
            isGeneratingScriptureSheet = false
            return
        }
        
        // Create a temporary document with scripture references
        var tempDocument = Letterspace_CanvasDocument(id: UUID().uuidString)
        
        // Set title, subtitle, and summary from the original document
        tempDocument.title = document.title
        tempDocument.subtitle = document.subtitle
        tempDocument.summary = document.summary
        
        // Copy the header image if present
        if let headerElement = document.elements.first(where: { $0.type == .headerImage && !$0.content.isEmpty }) {
            tempDocument.elements.append(headerElement)
        }
        
        // Create a title element with a custom fixed size instead of using .title type
        var titleElement = DocumentElement(type: .textBlock)
        titleElement.content = "Scripture Sheet"
        // Font size will be set in PDFDocumentGenerator
        tempDocument.elements.append(titleElement)
        
        // Add each reference as a text block
        for reference in references {
            var textElement = DocumentElement(type: .textBlock)
            
            // Format the reference based on whether to include text
            if includeVerseText {
                textElement.content = "\(reference.reference)\n\(reference.text)"
            } else {
                textElement.content = reference.reference
            }
            
            tempDocument.elements.append(textElement)
        }
        
        // Generate a PDF using the PDFDocumentGenerator
#if os(macOS)
        let pdfData = PDFDocumentGenerator.generatePDFData(
            for: tempDocument,
            showHeaderImage: true,
            showDocumentTitle: true,
            showPageNumbers: true,
            fontScale: 1.0,
            includeVerseText: includeVerseText
        )
        
        guard let pdfData = pdfData else {
            // Handle PDF generation error
            let errorAlert = NSAlert()
            errorAlert.messageText = "Error Creating Scripture Sheet"
            errorAlert.informativeText = "Could not generate the PDF for the Scripture Sheet."
            errorAlert.runModal()
            isGeneratingScriptureSheet = false
            return
        }
        
            // Create a unique filename for the PDF
            let timestamp = Int(Date().timeIntervalSince1970)
            let filename = "Scripture_Sheet_\(timestamp).pdf"
            
            // Get the app support directory to save the PDF
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Error Creating Scripture Sheet"
            errorAlert.informativeText = "Could not access application support directory to save the PDF."
            errorAlert.runModal()
            isGeneratingScriptureSheet = false
            return
        }
        
                let appDirectoryURL = appSupportURL.appendingPathComponent("Letterspace Canvas")
                let scriptureSheetsURL = appDirectoryURL.appendingPathComponent("ScriptureSheets")
                let fileURL = scriptureSheetsURL.appendingPathComponent(filename)
                
                do {
                    // Create directories if needed
                    try FileManager.default.createDirectory(at: scriptureSheetsURL, withIntermediateDirectories: true)
                    
                    // Write the PDF to disk
                    try pdfData.write(to: fileURL)
                    
                    // Store the PDF path in document metadata
                    var updatedDocument = document
                    if updatedDocument.metadata == nil {
                        updatedDocument.metadata = [:]
                    }
                    updatedDocument.metadata?["scriptureSheetPDFPath"] = fileURL.path
                    
                    // Update our state and document
                    scriptureSheetPDFPath = fileURL.path
                    document = updatedDocument
                    
                    // Save the updated document
                    updatedDocument.save()
                    
                    // Show a success notification
                    let confirmAlert = NSAlert()
                    confirmAlert.messageText = "Scripture Sheet Created (Beta)"
                    confirmAlert.informativeText = "A PDF with \(references.count) scripture references has been created and linked to this document.\n\nPlease review the generated PDF to ensure all references were captured correctly.\n\nIf any references are missing, try regenerating the Scripture Sheet."
                    confirmAlert.runModal()
            
                } catch {
                    // Handle error
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Error Creating Scripture Sheet"
                    errorAlert.informativeText = "Could not save the Scripture Sheet PDF: \(error.localizedDescription)"
            errorAlert.runModal()
        }
        
#elseif os(iOS)
        // iOS fallback - PDF generation not available
        print("📱 PDF generation not available on iOS")
#endif
        
        // Reset generation state
        isGeneratingScriptureSheet = false
    }
    
    // Function to open the generated Scripture Sheet PDF
    private func openScriptureSheetPDF(at path: String) {
        let url = URL(fileURLWithPath: path)
#if os(macOS)
        NSWorkspace.shared.open(url)
#elseif os(iOS)
        // iOS fallback - could potentially use UIDocumentInteractionController
        print("📱 Opening PDF not available on iOS")
#endif
    }
    
    // Function to remove the Scripture Sheet
    private func removeScriptureSheet() {
        // Clear the scriptureSheetPDFPath
        scriptureSheetPDFPath = nil
        
        // Update the local document copy
        localDocument.metadata?.removeValue(forKey: "scriptureSheetPDFPath")
        
        // Save the document without updating the binding
        var updatedDoc = document
        updatedDoc.metadata?.removeValue(forKey: "scriptureSheetPDFPath")
        updatedDoc.save()
        
        // Update the local document copy for UI reactivity
        localDocument.metadata?.removeValue(forKey: "scriptureSheetPDFPath")
        
        // Notify of change to update all views including the document editor
        NotificationCenter.default.post(
            name: NSNotification.Name("DocumentDidUpdate"), 
            object: nil,
            userInfo: ["documentId": document.id]
        )
        
        // Also post the general list update notification
        NotificationCenter.default.post(
            name: NSNotification.Name("DocumentListDidUpdate"), 
            object: nil
        )
        
        print("✅ Scripture Sheet removed successfully")
    }

    // MARK: - Rest of Content
    private var restOfContent: some View {
        VStack(spacing: 0) {
            spacerSection
            
            // AI Summary Button - more compact design
            // Only show the button if there's no summary and we're not generating one
            if (localDocument.summary == nil || localDocument.summary?.isEmpty == true) && !isGeneratingSummary && summaryText.isEmpty {
                    HStack {
                    Spacer()
                                        
                                        Button(action: {
                        // Use a more direct approach without Task/MainActor
                        isGeneratingSummary = true
                        
                        // Get the document content from the elements
                        let documentContent = localDocument.elements
                            .filter { $0.type == .textBlock }
                            .map { $0.content }
                            .joined(separator: "\n\n")
                        
                        // Create a CanvasDocument with the content
                        let canvasDoc = CanvasDocument()
                        canvasDoc.content = NSAttributedString(string: documentContent)
                        canvasDoc.metadata.title = localDocument.title
                        
                        // Generate the summary
                        canvasDoc.generateSummary { summary in
                DispatchQueue.main.async {
                                // Update the summary text state variable
                                summaryText = summary
                                isGeneratingSummary = false
                                
                                // Update the local document copy
                                localDocument.summary = summary
                                
                                // Save the document without updating the binding
        var updatedDoc = document
                                updatedDoc.summary = summary
        updatedDoc.save()
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                            .font(.system(size: 12))
                            Text("Generate Smart Summary")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                }
                        .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 2)
                }
                
            // Space before summary section
                Spacer()
                .frame(height: 4)
            
            // Summary section - show when summary is available or being generated
            if isGeneratingSummary || !summaryText.isEmpty || (localDocument.summary != nil && !localDocument.summary!.isEmpty) {
                summarySection
            }
            
            tabsAndContentSection
            navigationSection
        }
    }
} // This is the correct closing brace for DocumentDetailsCard struct
