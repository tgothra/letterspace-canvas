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
    @State private var showPicker = false
    @State private var selectedEntryForDetail: SermonJournalEntry? = nil
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
                    ScrollView {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                let sections = groupedByMonthSorted(for: selectedTab)
                                ForEach(sections, id: \.key) { section in
                                    let month = section.key
                                    let entries = section.value
                                    let title = monthTitle(month)

                                    Text(title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(theme.secondary)
                                        .padding(.top, 8)
                                        .padding(.bottom, 4)
                                        .id(monthId(selectedTab, month))

                                    ForEach(entries) { entry in
                                        JournalListRow(entry: entry) {
                                            selectedEntryForDetail = entry
                                        }
                                        .padding(.vertical, 4)
                                        Divider()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 0)
                        }
                        .onChange(of: selectedMonthKey) { old, new in
                            if let key = new {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo(monthId(selectedTab, key), anchor: .top)
                                }
                            }
                        }
                        .safeAreaPadding(.bottom, 60)
                    }
                }
                .navigationTitle("Journal")
                .toolbar {
                    #if os(iOS)
                    // Scrollable horizontal picker only - remove search button
                    ToolbarItem(placement: .bottomBar) {
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(JournalFeedTab.allCases, id: \.self) { tab in
                                        Button(action: { 
                                            selectedTab = tab
                                            // Scroll to show selected item at leading edge
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                proxy.scrollTo(tab, anchor: .leading)
                                            }
                                        }) {
                                            Text(tab.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(selectedTab == tab ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 16)
                                                .background(
                                                    Capsule().fill(selectedTab == tab ? .blue : Color(.systemGray6))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .id(tab)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .frame(maxWidth: .infinity)
                        }
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
                            NotificationCenter.default.post(name: NSNotification.Name("StartJournalCustomEntry"), object: nil)
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
                            NotificationCenter.default.post(name: NSNotification.Name("StartJournalCustomEntry"), object: nil)
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
        .sheet(isPresented: $showPicker) {
            ReflectionSelectionView(
                documents: loadAllDocuments(),
                onSelectDocument: { doc in
                    showPicker = false
                    NotificationCenter.default.post(name: NSNotification.Name("StartJournalForDocument"), object: doc)
                },
                onDismiss: { showPicker = false },
                allowCustom: true,
                onSelectNone: {
                    showPicker = false
                    NotificationCenter.default.post(name: NSNotification.Name("StartJournalCustomEntry"), object: nil)
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
        case .personal: return "person.circle"
        case .prayer: return "hands.sparkles"
        case .study: return "graduationcap"
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
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.kind.title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(kindColor)
                    .tracking(0.6)

                Text(summaryLine)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.primary)
                    .lineLimit(5)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(timeString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondary)

                    Spacer(minLength: 8)

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
                .padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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