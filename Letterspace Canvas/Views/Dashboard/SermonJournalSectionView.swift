#if os(macOS) || os(iOS)
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Sermon Journal Section View (Dashboard)
struct SermonJournalSectionView: View {
    // MARK: - Properties
    let documents: [Letterspace_CanvasDocument]
    let onSelectDocument: (Letterspace_CanvasDocument) -> Void
    let onShowSermonJournal: (Letterspace_CanvasDocument) -> Void
    let onShowAllJournalEntries: () -> Void
    let onShowJournalFeed: () -> Void
    
    @Environment(\.themeColors) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var colorTheme: ColorThemeManager
    @ObservedObject private var journalService = SermonJournalService.shared
    
    // MARK: - Body
    var body: some View {
        HStack {
            journalEntriesCard
                .frame(width: 250, height: 260)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Journal Entries Card
    @ViewBuilder
    private var journalEntriesCard: some View {
        Button {
            onShowJournalFeed()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Colored section (pastel)
                VStack(alignment: .leading, spacing: 8) {
                    let isLightOnColor = (colorTheme.currentTheme.id == "punchy") || colorTheme.hasGradients
                    HStack(spacing: 8) {
                        Image(systemName: "book.pages")
                            .foregroundStyle(isLightOnColor ? .white : .black)
                            .font(.system(size: 18, weight: .semibold))
                        Text("Journal")
                            .font(.custom("InterTight-Bold", size: 17))
                            .foregroundStyle(isLightOnColor ? .white : .black)
                        Spacer()
                    }
                    
                    if let lastEntry = journalService.entries().first {
                        Text("Last entry \(relativeDate(lastEntry.createdAt))")
                            .font(.custom("InterTight-Regular", size: 14))
                            .foregroundStyle(isLightOnColor ? .white.opacity(0.9) : .black.opacity(0.7))
                            .lineLimit(1)
                    } else {
                        Text("No entries yet")
                            .font(.custom("InterTight-Regular", size: 14))
                            .foregroundStyle(isLightOnColor ? .white.opacity(0.9) : .black.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Pills
                    HStack(spacing: 6) {
                        let total = journalService.entries().count
                        Text("\(total) Entries")
                            .font(.custom("InterTight-Medium", size: 11))
                            .foregroundStyle(isLightOnColor ? .white : .black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((isLightOnColor ? Color.white.opacity(0.22) : Color.black.opacity(0.1)), in: Capsule())
                        Spacer()
                    }
                }
                .padding(16)
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        Color.white
                        if let gradients = colorTheme.gradients {
                            Rectangle().fill(gradients.journalGradient)
                        } else {
                            Rectangle().fill(colorTheme.currentTheme.journalCards?.background ?? colorTheme.currentTheme.curatedCards.journal)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Explore row
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(.primary)
                    Text("Open Feed")
                        .foregroundStyle(.primary)
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 4)
            }
            .padding(16)
            .background({
                if colorScheme == .dark {
                    #if os(iOS)
                    return Color(.systemGray6)
                    #else
                    return Color(.controlBackgroundColor)
                    #endif
                } else {
                    #if os(iOS)
                    return Color(.systemBackground)
                    #else
                    return Color(.windowBackgroundColor)
                    #endif
                }
            }())
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 8, x: 0, y: 2)
            .frame(height: 240)
        }
        .buttonStyle(.plain)
    }
    
    private var borderColor: Color {
        #if os(iOS)
        return Color(.separator)
        #else
        return Color(.separatorColor)
        #endif
    }

    // MARK: - Helper Functions
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Data Sources for Journal Cards
    var journalPendingSermons: [Letterspace_CanvasDocument] {
        // Sermons preached in the last 14 days without a journal entry
        let recent = documents.filter { doc in
            guard let last = doc.variations.compactMap({ $0.datePresented }).max() else { return false }
            return Date().timeIntervalSince(last) < 14 * 24 * 3600
        }
        let journalIds = Set(journalService.entries().map { $0.sermonId })
        return recent.filter { !journalIds.contains($0.id) }
    }
    
    var recentCompletedSermons: [Letterspace_CanvasDocument] {
        // Sermons with entries, most recent 3
        let journalIdsOrdered = journalService.entries()
            .map { $0.sermonId }
        var seen = Set<String>()
        var ordered: [Letterspace_CanvasDocument] = []
        for id in journalIdsOrdered where !seen.contains(id) {
            seen.insert(id)
            if let doc = documents.first(where: { $0.id == id }) {
                ordered.append(doc)
            } else if let loaded = Letterspace_CanvasDocument.load(id: id) {
                ordered.append(loaded)
            }
            if ordered.count >= 3 { break }
        }
        return ordered
    }
    
    func latestJournalEntry(for sermonId: String) -> SermonJournalEntry? {
        journalService.entries().first { $0.sermonId == sermonId }
    }
}

// MARK: - Sermon Journal Card
struct SermonJournalCard: View {
    let document: Letterspace_CanvasDocument
    let onTap: () -> Void
    @Environment(\.themeColors) var theme
    
    private var lastPreachedDate: Date? {
        document.variations.compactMap { $0.datePresented }.max()
    }
    
    private var timeSincePreached: String {
        guard let date = lastPreachedDate else { return "Not preached yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Preached \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                LinearGradient(colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        AngularGradient(gradient: Gradient(colors: [Color.white.opacity(0.15), .clear, .clear, Color.white.opacity(0.15)]), center: .center)
                            .blendMode(.softLight)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Image(systemName: "book.pages.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Text(timeSincePreached)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.15)))
                    }
                    
                    Text(document.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if !document.subtitle.isEmpty {
                        Text(document.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 13))
                        Text("Add Reflection")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .padding(16)
            }
            .frame(width: 280, height: 160)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Latest Entry Card
struct LatestEntryCard: View {
    let entry: SermonJournalEntry
    let onTap: () -> Void
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
        let opacity = (colorScheme == .dark) ? 0.22 : 0.12
        return accentColor.opacity(opacity)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(backgroundColor)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.and.text.magnifyingglass")
                            .foregroundStyle(accentColor)
                            .font(.system(size: 16, weight: .semibold))
                        Text(entry.kind.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.secondary)
                        Spacer()
                    }
                    
                    Text(sermonTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.primary)
                        .lineLimit(2)
                    Text(formatted(entry.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary)

                    HStack(spacing: 8) {
                        Text(entry.emotionalState.emoji)
                            .font(.system(size: 16))
                        Text(entry.emotionalState.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(entry.emotionalState.color)
                    }
                    .padding(.vertical, 2)

                    if let summary = entry.aiSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                    HStack(spacing: 6) {
                        Text("Open")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.primary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(accentColor)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var sermonTitle: String {
        Letterspace_CanvasDocument.load(id: entry.sermonId)?.title ?? "Untitled Sermon"
    }
    
    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Journal Feed View
struct JournalFeedView: View {
    let onDismiss: () -> Void
    @ObservedObject private var service = SermonJournalService.shared
    @State private var isGenerating: Set<String> = []
    @State private var selectedEntryForDetail: SermonJournalEntry? = nil
    @State private var showingSermonDocument: Letterspace_CanvasDocument? = nil
    @State private var showingJournalForm: Bool = false
    @State private var showingHealthMeter: Bool = false
    @Environment(\.themeColors) var theme

    @State private var selectedTab: JournalFeedTab = .all

    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedMonthKey: String? = nil

    // Group entries by month (yyyy-MM)
    private func monthTitle(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return key }
        var comps = DateComponents(); comps.year = y; comps.month = m
        let date = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }

    private func entries(for tab: JournalFeedTab) -> [SermonJournalEntry] {
        let all = service.entries()
        let base: [SermonJournalEntry]
        switch tab {
        case .all: base = all
        case .sermon: base = all.filter { $0.kind == .sermon }
        case .personal: base = all.filter { $0.kind == .personal }
        case .prayer: base = all.filter { $0.kind == .prayer }
        case .study: base = all.filter { $0.kind == .study }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { e in
            let fields = [
                e.aiSummary ?? "",
                e.feelings,
                e.spiritualAtmosphere,
                e.godRevealedNew,
                e.testimoniesAndBreakthroughs,
                e.improvementNotes,
                e.followUpNotes
            ].map { $0.lowercased() }
            return fields.contains(where: { $0.contains(q) })
        }
    }

    private func groupedByMonthSorted(for tab: JournalFeedTab) -> [(key: String, value: [SermonJournalEntry])] {
        let source = entries(for: tab)
        let grouped = Dictionary(grouping: source) { entry in
            let comps = Calendar.current.dateComponents([.year, .month], from: entry.createdAt)
            let y = comps.year ?? 0, m = comps.month ?? 0
            return String(format: "%04d-%02d", y, m)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        Group {
            #if os(macOS)
            NavigationStack {
                journalContent
            }
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: "Search entries"
            )
            .applySearchMinimizeIfAvailable()
            #else
            NavigationStack {
                journalContent
            }
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: "Search entries"
            )
            .applySearchMinimizeIfAvailable()
            #endif
        }
        .sheet(isPresented: $showingHealthMeter) {
            SermonHealthMeterView(onDismiss: { showingHealthMeter = false })
        }
    }

    private var journalContent: some View {
        Group {
            if service.entries().isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text("No journal entries yet")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Tap + to add a custom reflection or attach one to a sermon.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        // Header section showing current view
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: tabIcon(selectedTab))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(theme.primary)
                                
                                Text("\(selectedTab.title) Entries")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(theme.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingHealthMeter = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 14, weight: .medium))
                                        Text("Health")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.pink.opacity(0.1))
                                    )
                                    .foregroundColor(.pink)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if !searchText.isEmpty {
                                Text("Searching for \"\(searchText)\"")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(theme.secondary)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
                        
                        let sections = groupedByMonthSorted(for: selectedTab)
                        ForEach(sections, id: \.key) { section in
                            let month = section.key
                            let entries = section.value
                            let title = monthTitle(month)

                            // Month header
                            Text(title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.secondary)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                .id(monthId(selectedTab, month))

                            // Journal entries for this month
                            ForEach(entries) { entry in
                                JournalListRow(
                                    entry: entry,
                                    onTap: {
                                        selectedEntryForDetail = entry
                                    },
                                    onOpenSermon: { sermon in
                                        showingSermonDocument = sermon
                                    }
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        onRemoveEntry(entry.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                
                                // Custom divider
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(height: 0.5)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .navigationTitle("Journal")
                .toolbar {
                    #if os(iOS)
                    // Non-scrollable horizontal picker with evenly distributed icons
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 0) {
                            ForEach(JournalFeedTab.allCases, id: \.self) { tab in
                                Button(action: { 
                                    selectedTab = tab
                                }) {
                                    Image(systemName: tabIcon(tab))
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(selectedTab == tab ? .white : .primary)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle().fill(selectedTab == tab ? .blue : Color(.systemGray6))
                                        )
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }

                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            ForEach(availableMonths(for: selectedTab), id: \.self) { key in
                                Button(monthTitle(key)) {
                                    selectedMonthKey = key
                                }
                            }
                        } label: {
                            Label("Jump", systemImage: "calendar")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingJournalForm = true
                        }) {
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done", action: onDismiss)
                    }
                    #else
                    // macOS toolbar with segmented control
                    ToolbarItem(placement: .automatic) {
                        Picker("Filter", selection: $selectedTab) {
                            ForEach(JournalFeedTab.allCases, id: \.self) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 360)
                    }

                    // Reposition search in toolbar on macOS 15+
                    if #available(macOS 15.0, *) {
                        DefaultToolbarItem(kind: .search, placement: .automatic)
                    }

                    ToolbarItem(placement: .automatic) {
                        Menu {
                            ForEach(availableMonths(for: selectedTab), id: \.self) { key in
                                Button(monthTitle(key)) {
                                    selectedMonthKey = key
                                }
                            }
                        } label: {
                            Label("Jump", systemImage: "calendar")
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        Button(action: {
                            showingJournalForm = true
                        }) {
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        Button("Done", action: onDismiss)
                    }
                    #endif
                }
                .task {
                    _ = await service.regenerateMissingSummaries()
                }
            }
        }
        .sheet(isPresented: $showingJournalForm) {
            // Create a default document for new journal entries
            let defaultDoc = Letterspace_CanvasDocument(
                title: "New Journal Entry",
                id: ""
            )
            SermonJournalView(
                document: defaultDoc,
                allDocuments: loadAllDocuments(),
                onDismiss: {
                    showingJournalForm = false
                }
            )
        }
        .sheet(item: $selectedEntryForDetail) { entry in
            SermonJournalEntryDetail(entry: entry) {
                selectedEntryForDetail = nil
            }
            #if os(macOS)
            .frame(width: 750, height: 650)
            #endif
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
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

    // MARK: - Helper Functions for List Management
    private func onRemoveEntry(_ entryId: String) {
        service.deleteEntry(id: entryId)
    }

    private func monthId(_ tab: JournalFeedTab, _ key: String) -> String {
        "month-\(tab.key)-\(key)"
    }

    private func availableMonths(for tab: JournalFeedTab) -> [String] {
        groupedByMonthSorted(for: tab).map(\.key)
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

    private func tabIcon(_ tab: JournalFeedTab) -> String {
        switch tab {
        case .all: return "list.bullet"
        case .sermon: return "book.pages"
        case .personal: return "face.smiling"
        case .prayer: return "hands.sparkles"
        case .study: return "book"
        }
    }

    enum JournalFeedTab: CaseIterable, Hashable {
        case all, sermon, personal, prayer, study

        var title: String {
            switch self {
            case .all: return "All"
            case .sermon: return "Sermon"
            case .personal: return "Personal"
            case .prayer: return "Prayer"
            case .study: return "Study Notes"
            }
        }

        var key: String {
            switch self {
            case .all: return "all"
            case .sermon: return "sermon"
            case .personal: return "personal"
            case .prayer: return "prayer"
            case .study: return "study"
            }
        }
    }
}

struct JournalListRow: View {
    let entry: SermonJournalEntry
    let onTap: () -> Void
    let onOpenSermon: ((Letterspace_CanvasDocument) -> Void)?
    @Environment(\.themeColors) var theme

    private var kindColor: Color {
        switch entry.kind {
        case .sermon: return .blue
        case .personal: return .pink
        case .prayer: return .purple
        case .study: return .teal
        }
    }

    private var summaryLine: String {
        if let s = entry.aiSummary, !s.isEmpty {
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !entry.feelings.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return entry.feelings.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !entry.spiritualAtmosphere.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return entry.spiritualAtmosphere.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !entry.godRevealedNew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return entry.godRevealedNew.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "—"
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a, EEE, M/d/yyyy"
        return f.string(from: entry.createdAt).uppercased()
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Colored left accent bar with rounded corners
                RoundedRectangle(cornerRadius: 2)
                    .fill(kindColor)
                    .frame(width: 4)
                
                HStack(spacing: 12) {
                    // Icon for entry type - CHANGE: Use consistent icons
                    Image(systemName: kindIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(kindColor)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(entry.kind.title.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(kindColor)
                                .tracking(0.6)
                            
                            // Show sermon link pill for sermon entries
                            if entry.kind == .sermon, !entry.sermonId.isEmpty,
                               let sermon = Letterspace_CanvasDocument.load(id: entry.sermonId) {
                                Button(action: {
                                    onOpenSermon?(sermon)
                                }) {
                                    Text(sermon.title)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.blue)
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule().fill(Color.blue.opacity(0.1))
                                        )
                                        .overlay(
                                            Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Show scripture pills for study note entries
                            if entry.kind == .study, let scriptures = entry.attachedScriptures, !scriptures.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(Array(scriptures.prefix(2)), id: \.id) { scripture in
                                        Text(formatScriptureReference(scripture))
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(.teal)
                                            .lineLimit(1)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(Color.teal.opacity(0.1))
                                            )
                                            .overlay(
                                                Capsule().stroke(Color.teal.opacity(0.3), lineWidth: 0.5)
                                            )
                                    }
                                    
                                    // Show "+X more" if there are more than 2 scriptures
                                    if scriptures.count > 2 {
                                        Text("+\(scriptures.count - 2)")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(.teal)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(Color.teal.opacity(0.1))
                                            )
                                            .overlay(
                                                Capsule().stroke(Color.teal.opacity(0.3), lineWidth: 0.5)
                                            )
                                    }
                                }
                            }
                            
                            Spacer()
                        }

                        Text(summaryLine)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(theme.primary)
                            .lineLimit(7)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            Text(timeString)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.secondary)
                                .tracking(0.4)

                            // Voice memo indicator
                            if entry.voiceNoteURL != nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.blue)
                                    Text("Voice")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color.blue.opacity(0.1))
                                )
                                .overlay(
                                    Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
                                )
                            }

                            Spacer(minLength: 8)

                            // Only show emotional state for non-study entries
                            if entry.kind != .study {
                                HStack(spacing: 6) {
                                    Text(entry.emotionalState.emoji)
                                        .font(.system(size: 12))
                                    Text(entry.emotionalState.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(entry.emotionalState.color.opacity(0.15))
                                )
                                .foregroundStyle(entry.emotionalState.color)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var kindIcon: String {
        switch entry.kind {
        case .sermon: return "book.pages"
        case .personal: return "face.smiling"
        case .prayer: return "hands.sparkles"
        case .study: return "book"
        }
    }
    
    private func formatScriptureReference(_ scripture: String) -> String {
        // Simple formatting to keep scripture references concise
        let components = scripture.components(separatedBy: " ")
        if components.count >= 2 {
            let book = components[0]
            let reference = components[1]
            return "\(book) \(reference)"
        }
        return scripture
    }

    private func formatScriptureReference(_ scripture: ScriptureReference) -> String {
        // Use the existing fullReference property for concise display
        let fullRef = scripture.fullReference
        
        // For very long book names, abbreviate them
        if fullRef.hasPrefix("1 Chronicles") {
            return fullRef.replacingOccurrences(of: "1 Chronicles", with: "1 Chr")
        } else if fullRef.hasPrefix("2 Chronicles") {
            return fullRef.replacingOccurrences(of: "2 Chronicles", with: "2 Chr")
        } else if fullRef.hasPrefix("1 Corinthians") {
            return fullRef.replacingOccurrences(of: "1 Corinthians", with: "1 Cor")
        } else if fullRef.hasPrefix("2 Corinthians") {
            return fullRef.replacingOccurrences(of: "2 Corinthians", with: "2 Cor")
        } else if fullRef.hasPrefix("1 Thessalonians") {
            return fullRef.replacingOccurrences(of: "1 Thessalonians", with: "1 Thes")
        } else if fullRef.hasPrefix("2 Thessalonians") {
            return fullRef.replacingOccurrences(of: "2 Thessalonians", with: "2 Thes")
        } else if fullRef.hasPrefix("Philippians") {
            return fullRef.replacingOccurrences(of: "Philippians", with: "Phil")
        } else if fullRef.hasPrefix("Colossians") {
            return fullRef.replacingOccurrences(of: "Colossians", with: "Col")
        } else if fullRef.hasPrefix("Revelation") {
            return fullRef.replacingOccurrences(of: "Revelation", with: "Rev")
        }
        
        return fullRef
    }
}

// MARK: - Preach It Again Card
struct PreachItAgainCard: View {
    let document: Letterspace_CanvasDocument
    let onTap: () -> Void
    @Environment(\.themeColors) var theme
    
    private var lastPreachedDate: Date? {
        document.variations.compactMap { $0.datePresented }.max()
    }
    
    private var timeSincePreached: String {
        guard let date = lastPreachedDate else { return "Never preached" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var preachingHistory: String {
        let count = document.variations.filter { $0.datePresented != nil }.count
        return "\(count) time\(count == 1 ? "" : "s")"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "megaphone.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Text(preachingHistory)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.15)))
                }
                
                Text(document.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if !document.subtitle.isEmpty {
                    Text(document.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 13))
                    Text("Preach Again")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.white)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .background(
            LinearGradient(colors: [Color.orange.opacity(0.85), Color.red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(
                    AngularGradient(gradient: Gradient(colors: [Color.white.opacity(0.15), .clear, .clear, Color.white.opacity(0.15)]), center: .center)
                        .blendMode(.softLight)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        )
        .frame(width: 280, height: 160)
    }
}

#if os(iOS)
// Search toolbar minimize on supported OS
private extension View {
    @ViewBuilder
    func applySearchMinimizeIfAvailable() -> some View {
        if #available(iOS 18.0, *) {
            self.searchToolbarBehavior(.minimize)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyStableTabBarInsetsIfAvailable() -> some View {
        if #available(iOS 18.0, *) {
            // 60 approximates tab bar height + a touch of breathing room; keeps inset stable during minimize/expand
            self.contentMargins(.bottom, 60, for: .scrollContent)
        } else {
            self
        }
    }
}
#endif

#endif